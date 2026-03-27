<script lang="ts">
  import { onMount, onDestroy } from 'svelte'
  import Icon from '@iconify/svelte'
  import { Editor, Extension } from '@tiptap/core'
  import StarterKit from '@tiptap/starter-kit'
  import Link from '@tiptap/extension-link'
  import Underline from '@tiptap/extension-underline'
  import Placeholder from '@tiptap/extension-placeholder'
  import Image from '@tiptap/extension-image'
  import TextStyle from '@tiptap/extension-text-style'
  import Color from '@tiptap/extension-color'
  import TextAlign from '@tiptap/extension-text-align'
  import Table from '@tiptap/extension-table'
  import TableRow from '@tiptap/extension-table-row'
  import TableCell from '@tiptap/extension-table-cell'
  import TableHeader from '@tiptap/extension-table-header'
  import FontSize from 'tiptap-extension-font-size'
  import { _ } from '$lib/i18n'

  // Extended TextStyle to also handle legacy <font> tags
  const ExtendedTextStyle = TextStyle.extend({
    parseHTML() {
      return [
        { tag: 'span' },
        { tag: 'font' },  // Handle legacy <font> tags
      ]
    },
  })

  // Extended Color to handle legacy <font color="..."> tags
  const ExtendedColor = Color.extend({
    addGlobalAttributes() {
      return [
        {
          types: this.options.types,
          attributes: {
            color: {
              default: null,
              parseHTML: (element: HTMLElement) => {
                // Check for inline style color first
                const styleColor = element.style.color?.replace(/['"]+/g, '')
                if (styleColor) return styleColor
                // Check for legacy <font color="..."> attribute
                if (element.tagName === 'FONT') {
                  return element.getAttribute('color')
                }
                return null
              },
              renderHTML: (attributes: Record<string, string>) => {
                if (!attributes.color) {
                  return {}
                }
                return {
                  style: `color: ${attributes.color}`,
                }
              },
            },
          },
        },
      ]
    },
  })

  // Extended Table extensions to preserve inline style attributes
  const ExtendedTable = Table.extend({
    addAttributes() {
      return {
        ...this.parent?.(),
        style: {
          default: null,
          parseHTML: (element: HTMLElement) => element.getAttribute('style'),
          renderHTML: (attributes: Record<string, string>) => {
            if (!attributes.style) return {}
            return { style: attributes.style }
          },
        },
      }
    },
  })

  const ExtendedTableCell = TableCell.extend({
    addAttributes() {
      return {
        ...this.parent?.(),
        style: {
          default: null,
          parseHTML: (element: HTMLElement) => element.getAttribute('style'),
          renderHTML: (attributes: Record<string, string>) => {
            if (!attributes.style) return {}
            return { style: attributes.style }
          },
        },
      }
    },
  })

  const ExtendedTableHeader = TableHeader.extend({
    addAttributes() {
      return {
        ...this.parent?.(),
        style: {
          default: null,
          parseHTML: (element: HTMLElement) => element.getAttribute('style'),
          renderHTML: (attributes: Record<string, string>) => {
            if (!attributes.style) return {}
            return { style: attributes.style }
          },
        },
      }
    },
  })

  function normalizeStyle(style: string | null | undefined): string | null {
    if (!style) return null
    const cleaned = style
      .split(';')
      .map(part => part.trim())
      .filter(Boolean)
      .join('; ')
    return cleaned ? `${cleaned};` : null
  }

  function stripImageDimensionStyles(style: string | null | undefined): string | null {
    if (!style) return null
    const filtered = style
      .split(';')
      .map(part => part.trim())
      .filter(part => part && !/^width\s*:/i.test(part) && !/^height\s*:/i.test(part))
      .join('; ')
    return filtered ? `${filtered};` : null
  }

  function buildImageStyle(
    width: string | null | undefined,
    height: string | null | undefined,
    style: string | null | undefined
  ): string | null {
    const parts: string[] = []
    const baseStyle = stripImageDimensionStyles(style)
    if (baseStyle) {
      parts.push(baseStyle.replace(/;$/, ''))
    }
    if (width) {
      parts.push(`width: ${width}px`)
    }
    if (height) {
      parts.push(`height: ${height}px`)
    } else if (width) {
      parts.push('height: auto')
    }
    return parts.length > 0 ? `${parts.join('; ')};` : null
  }

  function parseImageDimension(value: string | null | undefined): string | null {
    if (!value) return null
    const match = value.match(/\d+/)
    return match ? match[0] : null
  }

  function getImageDimensionFromElement(element: HTMLElement, property: 'width' | 'height'): string | null {
    const attrValue = element.getAttribute(property)
    if (attrValue) {
      return parseImageDimension(attrValue)
    }
    const styleValue = element.style[property]
    return parseImageDimension(styleValue)
  }

  const ExtendedImage = Image.extend({
    addAttributes() {
      return {
        ...this.parent?.(),
        width: {
          default: null,
          parseHTML: (element: HTMLElement) => getImageDimensionFromElement(element, 'width'),
          renderHTML: (attributes: Record<string, string>) => {
            if (!attributes.width) return {}
            return { width: attributes.width }
          },
        },
        height: {
          default: null,
          parseHTML: (element: HTMLElement) => getImageDimensionFromElement(element, 'height'),
          renderHTML: (attributes: Record<string, string>) => {
            if (!attributes.height) return {}
            return { height: attributes.height }
          },
        },
        style: {
          default: null,
          parseHTML: (element: HTMLElement) => normalizeStyle(element.getAttribute('style')),
          renderHTML: (attributes: Record<string, string>) => {
            const style = buildImageStyle(attributes.width, attributes.height, attributes.style)
            return style ? { style } : {}
          },
        },
      }
    },
  })

  // Custom extension to make Enter insert <br> instead of new paragraph
  // Optimized with direct ProseMirror transaction for better performance
  const LineBreakOnEnter = Extension.create({
    name: 'lineBreakOnEnter',
    priority: 1000,
    addKeyboardShortcuts() {
      return {
        Enter: () => {
          const { view } = this.editor
          const { state } = view
          const { schema, selection, storedMarks } = state
          
          const hardBreakType = schema.nodes.hardBreak
          if (!hardBreakType) return false
          
          const fromPos = selection.$from
          if (fromPos.parent.type.spec.isolating) return false
          
          const marks = storedMarks || 
            (selection.$to.parentOffset && selection.$from.marks()) || 
            []
          
          let tr = state.tr.replaceSelectionWith(hardBreakType.create(), false)
          
          if (marks.length > 0) {
            tr = tr.ensureMarks(marks)
          }
          
          tr.scrollIntoView()
          view.dispatch(tr)
          return true
        },
      }
    },
  })

  interface Props {
    /** HTML content of the signature */
    value?: string
    /** Placeholder text when empty */
    placeholder?: string
    /** Callback when content changes */
    onchange?: (html: string) => void
  }

  interface SignatureImageAttrs {
    src: string
    alt?: string
    title?: string
    width?: string
    height?: string
    style?: string
  }

  let { value = '', placeholder = 'Enter your signature...', onchange }: Props = $props()

  let editorElement: HTMLElement | undefined = $state()
  let editor: Editor | null = null
  let isUpdatingFromProp = false
  
  // Track active formatting states - updated via transaction listener for performance
  let activeStates = $state({
    bold: false,
    italic: false,
    underline: false,
    strike: false,
    link: false,
  })

  // Current text color
  let currentColor = $state<string | null>(null)
  let showColorPicker = $state(false)

  // Current text alignment
  let currentAlign = $state<'left' | 'center' | 'right'>('left')

  // Table context
  let isInTable = $state(false)

  // Raw HTML mode
  let rawHtmlMode = $state(false)
  let rawHtmlContent = $state('')

  // Current font size
  let currentFontSize = $state<string>('')
  let showFontSizePicker = $state(false)

  // Selected image state
  let isImageSelected = $state(false)
  let selectedImageWidth = $state('')
  const largeImageThresholdPx = 320
  const defaultLargeImageWidthPx = 240
  const imageWidthPresets = ['120', '180', '240']

  // Font size options
  const fontSizes = ['10px', '12px', '14px', '16px', '18px', '20px', '24px', '28px', '32px']

  // Preset colors for quick selection
  const presetColors = [
    '#000000', '#374151', '#6b7280', // Grays
    '#dc2626', '#ea580c', '#ca8a04', // Warm
    '#16a34a', '#0891b2', '#2563eb', // Cool
    '#7c3aed', '#c026d3', '#e11d48', // Vibrant
  ]
  
  // Update active states from editor
  function updateActiveStates() {
    if (!editor) return
    activeStates = {
      bold: editor.isActive('bold'),
      italic: editor.isActive('italic'),
      underline: editor.isActive('underline'),
      strike: editor.isActive('strike'),
      link: editor.isActive('link'),
    }
    // Get current text color
    const colorAttr = editor.getAttributes('textStyle').color
    currentColor = colorAttr || null
    // Get current text alignment
    if (editor.isActive({ textAlign: 'center' })) {
      currentAlign = 'center'
    } else if (editor.isActive({ textAlign: 'right' })) {
      currentAlign = 'right'
    } else {
      currentAlign = 'left'
    }
    // Get current font size
    const fontSizeAttr = editor.getAttributes('textStyle').fontSize
    currentFontSize = fontSizeAttr || ''
    // Check if cursor is inside a table
    isInTable = editor.isActive('table')
    isImageSelected = editor.isActive('image')
    if (isImageSelected) {
      const imageAttrs = editor.getAttributes('image')
      selectedImageWidth = imageAttrs.width || ''
    } else {
      selectedImageWidth = ''
    }
  }

  onMount(() => {
    editor = new Editor({
      element: editorElement,
      extensions: [
        StarterKit.configure({
          // Disable heading for signatures - keep it simple
          heading: false,
        }),
        LineBreakOnEnter,  // Make Enter insert <br> instead of new paragraph
        Underline,
        ExtendedTextStyle,  // Required for Color extension (extended for better paste support)
        ExtendedColor,      // Text color support (extended for font tags and inline styles)
        FontSize,           // Font size support
        TextAlign.configure({
          types: ['paragraph'],  // Apply to paragraphs
        }),
        // Table support
        ExtendedTable.configure({
          resizable: false,
          HTMLAttributes: {
            class: 'border-collapse',
          },
        }),
        TableRow,
        ExtendedTableCell,
        ExtendedTableHeader,
        Link.configure({
          openOnClick: false,
          HTMLAttributes: {
            class: 'text-primary underline',
          },
        }),
        ExtendedImage.configure({
          inline: true,
          allowBase64: true,
          HTMLAttributes: {
            class: 'max-w-full h-auto',
          },
        }),
        Placeholder.configure({
          placeholder,
        }),
      ],
      content: value,
      editorProps: {
        attributes: {
          class: 'signature-editor focus:outline-none min-h-[100px] p-3',
        },
        // Handle paste events for images
        handlePaste: (view, event) => {
          const items = event.clipboardData?.items
          if (!items) return false
          
          for (const item of items) {
            if (item.type.startsWith('image/')) {
              event.preventDefault()
              const file = item.getAsFile()
              if (file) {
                handleImageFile(file)
              }
              return true
            }
          }
          // Allow HTML paste (for importing signatures)
          return false
        },
        // Handle drop events for images
        handleDrop: (view, event, slice, moved) => {
          if (moved) return false
          
          const files = event.dataTransfer?.files
          if (!files?.length) return false
          
          for (const file of files) {
            if (file.type.startsWith('image/')) {
              event.preventDefault()
              handleImageFile(file)
              return true
            }
          }
          return false
        },
      },
      onUpdate: () => {
        if (!isUpdatingFromProp) {
          onchange?.(editor?.getHTML() || '')
        }
      },
      onTransaction: () => {
        // Update toolbar button states on selection/content changes
        updateActiveStates()
      },
    })
    
    // Initial state update
    updateActiveStates()
  })

  onDestroy(() => {
    editor?.destroy()
  })

  // Update editor when value prop changes externally
  $effect(() => {
    if (editor && !rawHtmlMode && value !== editor.getHTML()) {
      isUpdatingFromProp = true
      editor.commands.setContent(value)
      isUpdatingFromProp = false
    }
  })

  // Handle image file (paste or drop)
  async function handleImageFile(file: File) {
    try {
      const dataUrl = await readFileAsDataUrl(file)
      const attrs = await buildInsertedImageAttributes(dataUrl, file.name)
      editor?.chain().focus().setImage(attrs).run()
    } catch (err) {
      console.error('Failed to insert image:', err)
    }
  }

  function readFileAsDataUrl(file: File): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onload = () => resolve(reader.result as string)
      reader.onerror = () => reject(reader.error)
      reader.readAsDataURL(file)
    })
  }

  function loadImageDimensions(src: string): Promise<{ width: number; height: number }> {
    return new Promise((resolve, reject) => {
      const image = new window.Image()
      image.onload = () => resolve({
        width: image.naturalWidth,
        height: image.naturalHeight,
      })
      image.onerror = () => reject(new Error('Failed to load image dimensions'))
      image.src = src
    })
  }

  async function buildInsertedImageAttributes(src: string, alt?: string): Promise<SignatureImageAttrs> {
    const attrs: SignatureImageAttrs = { src }
    if (alt) {
      attrs.alt = alt
    }

    try {
      const { width } = await loadImageDimensions(src)
      if (width > largeImageThresholdPx) {
        attrs.width = String(defaultLargeImageWidthPx)
        attrs.style = buildImageStyle(attrs.width, null, null) || ''
      }
    } catch (err) {
      console.warn('Unable to determine image size, inserting original dimensions', err)
    }

    return attrs
  }

  // Toolbar actions
  function toggleBold() {
    editor?.chain().focus().toggleBold().run()
  }

  function toggleItalic() {
    editor?.chain().focus().toggleItalic().run()
  }

  function toggleUnderline() {
    editor?.chain().focus().toggleUnderline().run()
  }

  function toggleStrike() {
    editor?.chain().focus().toggleStrike().run()
  }

  function insertLink() {
    const url = prompt('Enter URL:')
    if (url) {
      editor?.chain().focus().setLink({ href: url }).run()
    }
  }

  function removeLink() {
    editor?.chain().focus().unsetLink().run()
  }

  function insertImageUrl() {
    const url = prompt('Enter image URL:')
    if (!url) return

    void (async () => {
      const attrs = await buildInsertedImageAttributes(url)
      editor?.chain().focus().setImage(attrs).run()
    })()
  }

  function insertImageFile() {
    const input = document.createElement('input')
    input.type = 'file'
    input.accept = 'image/*'
    input.onchange = async (e) => {
      const file = (e.target as HTMLInputElement).files?.[0]
      if (file) {
        await handleImageFile(file)
      }
    }
    input.click()
  }

  // Color functions
  function setColor(color: string) {
    editor?.chain().focus().setColor(color).run()
    showColorPicker = false
  }

  function removeColor() {
    editor?.chain().focus().unsetColor().run()
    showColorPicker = false
  }

  function handleCustomColor(event: Event) {
    const input = event.target as HTMLInputElement
    setColor(input.value)
  }

  function toggleColorPicker() {
    showColorPicker = !showColorPicker
    showFontSizePicker = false  // Close font size picker if open
  }

  // Close pickers when clicking outside
  function handleClickOutside(event: MouseEvent) {
    const target = event.target as HTMLElement
    if (!target.closest('.color-picker-container')) {
      showColorPicker = false
    }
    if (!target.closest('.font-size-picker-container')) {
      showFontSizePicker = false
    }
  }

  // Font size functions
  function setFontSize(size: string) {
    editor?.chain().focus().setFontSize(size).run()
    showFontSizePicker = false
  }

  function toggleFontSizePicker() {
    showFontSizePicker = !showFontSizePicker
    showColorPicker = false  // Close color picker if open
  }

  // Alignment functions
  function setAlign(align: 'left' | 'center' | 'right') {
    editor?.chain().focus().setTextAlign(align).run()
  }

  // Table functions
  function insertTable() {
    editor?.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run()
  }

  function deleteTable() {
    editor?.chain().focus().deleteTable().run()
  }

  // Pretty-print HTML with indentation for readability in raw mode
  function formatHtml(html: string): string {
    const blockTags = /^(p|div|table|thead|tbody|tr|td|th|ul|ol|li|blockquote|hr|br)$/i

    // Insert newlines around block-level tags
    let result = html
      .replace(/>\s*</g, '>\n<')  // Newline between adjacent tags
      .trim()

    const lines = result.split('\n')
    const formatted: string[] = []
    let depth = 0

    for (const rawLine of lines) {
      const line = rawLine.trim()
      if (!line) continue

      // Check if line starts with a closing block tag
      const closingMatch = line.match(/^<\/(\w+)/)
      if (closingMatch && blockTags.test(closingMatch[1])) {
        depth = Math.max(0, depth - 1)
      }

      formatted.push('  '.repeat(depth) + line)

      // Check for opening block tags (not self-closing)
      const openingMatch = line.match(/^<(\w+)/)
      if (openingMatch && blockTags.test(openingMatch[1]) && !line.match(/\/>$/) && !line.match(/^<br/i)) {
        // Only increase depth if the line doesn't also close the same tag
        const tagName = openingMatch[1]
        if (!line.includes(`</${tagName}>`)) {
          depth++
        }
      }
    }

    return formatted.join('\n')
  }

  // Raw HTML toggle
  function toggleRawHtml() {
    if (!rawHtmlMode) {
      // Switching to raw HTML mode - use value prop (preserves custom HTML attributes
      // that TipTap strips) rather than editor.getHTML() which normalizes away unknowns
      rawHtmlContent = formatHtml(value || '')
      rawHtmlMode = true
      return
    }
    // Switching back to WYSIWYG mode
    isUpdatingFromProp = true
    editor?.commands.setContent(rawHtmlContent)
    isUpdatingFromProp = false
    rawHtmlMode = false
    onchange?.(editor?.getHTML() || '')
  }

  function handleRawHtmlInput(event: Event) {
    rawHtmlContent = (event.target as HTMLTextAreaElement).value
    onchange?.(rawHtmlContent)
  }

  function applyImageWidth(width: string) {
    const normalizedWidth = parseImageDimension(width)
    if (!normalizedWidth || !editor) return

    const imageAttrs = editor.getAttributes('image')
    editor.chain().focus().updateAttributes('image', {
      width: normalizedWidth,
      height: null,
      style: buildImageStyle(normalizedWidth, null, imageAttrs.style),
    }).run()
    selectedImageWidth = normalizedWidth
  }

  function clearImageSize() {
    if (!editor) return

    const imageAttrs = editor.getAttributes('image')
    editor.chain().focus().updateAttributes('image', {
      width: null,
      height: null,
      style: stripImageDimensionStyles(imageAttrs.style),
    }).run()
    selectedImageWidth = ''
  }

  function handleImageWidthInput(event: Event) {
    selectedImageWidth = (event.target as HTMLInputElement).value
  }

  function applyTypedImageWidth() {
    applyImageWidth(selectedImageWidth)
  }
</script>

<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
<div class="border border-input rounded-md overflow-hidden bg-background" role="toolbar" aria-label={$_('aria.signatureEditor')} tabindex="-1" onclick={handleClickOutside}>
  <!-- Toolbar -->
  <div class="flex flex-wrap items-center gap-0.5 px-2 py-1.5 border-b border-border bg-muted/30">
    {#if !rawHtmlMode}
      <button
        type="button"
        onclick={toggleBold}
        class="p-1.5 rounded hover:bg-muted transition-colors"
        class:bg-muted={activeStates.bold}
        title={$_('editor.bold')}
      >
        <Icon icon="mdi:format-bold" class="w-4 h-4" />
      </button>
      <button
        type="button"
        onclick={toggleItalic}
        class="p-1.5 rounded hover:bg-muted transition-colors"
        class:bg-muted={activeStates.italic}
        title={$_('editor.italic')}
      >
        <Icon icon="mdi:format-italic" class="w-4 h-4" />
      </button>
      <button
        type="button"
        onclick={toggleUnderline}
        class="p-1.5 rounded hover:bg-muted transition-colors"
        class:bg-muted={activeStates.underline}
        title={$_('editor.underline')}
      >
        <Icon icon="mdi:format-underline" class="w-4 h-4" />
      </button>
      <button
        type="button"
        onclick={toggleStrike}
        class="p-1.5 rounded hover:bg-muted transition-colors"
        class:bg-muted={activeStates.strike}
        title={$_('editor.strikethrough')}
      >
        <Icon icon="mdi:format-strikethrough" class="w-4 h-4" />
      </button>

      <!-- Color Picker -->
      <div class="relative color-picker-container" role="presentation" onclick={(e) => e.stopPropagation()}>
        <button
          type="button"
          onclick={toggleColorPicker}
          class="p-1.5 rounded hover:bg-muted transition-colors flex items-center gap-0.5"
          class:bg-muted={showColorPicker}
          title={$_('editor.textColor')}
        >
          <Icon icon="mdi:format-color-text" class="w-4 h-4" />
          <div
            class="w-3 h-1 rounded-sm"
            style="background-color: {currentColor || '#000000'}"
          ></div>
        </button>

        {#if showColorPicker}
          <div class="absolute top-full left-0 mt-1 p-2 bg-popover border border-border rounded-md shadow-lg z-50">
            <div class="grid grid-cols-4 gap-1 mb-2">
              {#each presetColors as color}
                <button
                  type="button"
                  onclick={() => setColor(color)}
                  class="w-6 h-6 rounded border border-border hover:scale-110 transition-transform"
                  style="background-color: {color}"
                  title={color}
                ></button>
              {/each}
            </div>
            <div class="flex items-center gap-2 pt-2 border-t border-border">
              <input
                type="color"
                value={currentColor || '#000000'}
                onchange={handleCustomColor}
                class="w-6 h-6 rounded cursor-pointer"
                title={$_('editor.customColor')}
              />
              <button
                type="button"
                onclick={removeColor}
                class="text-xs text-muted-foreground hover:text-foreground"
              >
                {$_('editor.reset')}
              </button>
            </div>
          </div>
        {/if}
      </div>

      <!-- Font Size Picker -->
      <div class="relative font-size-picker-container" role="presentation" onclick={(e) => e.stopPropagation()}>
        <button
          type="button"
          onclick={toggleFontSizePicker}
          class="p-1.5 rounded hover:bg-muted transition-colors flex items-center gap-0.5 text-xs min-w-[40px] justify-center"
          class:bg-muted={showFontSizePicker}
          title={$_('editor.fontSize')}
        >
          {currentFontSize || '14px'}
        </button>

        {#if showFontSizePicker}
          <div class="absolute top-full left-0 mt-1 py-1 bg-popover border border-border rounded-md shadow-lg z-50 min-w-[60px]">
            {#each fontSizes as size}
              <button
                type="button"
                onclick={() => setFontSize(size)}
                class="w-full px-3 py-1 text-left text-sm hover:bg-muted transition-colors"
                class:bg-muted={currentFontSize === size}
              >
                {size}
              </button>
            {/each}
          </div>
        {/if}
      </div>

      <div class="w-px h-4 bg-border mx-1"></div>

      <!-- Alignment buttons -->
      <button
        type="button"
        onclick={() => setAlign('left')}
        class="p-1.5 rounded hover:bg-muted transition-colors"
        class:bg-muted={currentAlign === 'left'}
        title={$_('editor.alignLeft')}
      >
        <Icon icon="mdi:format-align-left" class="w-4 h-4" />
      </button>
      <button
        type="button"
        onclick={() => setAlign('center')}
        class="p-1.5 rounded hover:bg-muted transition-colors"
        class:bg-muted={currentAlign === 'center'}
        title={$_('editor.alignCenter')}
      >
        <Icon icon="mdi:format-align-center" class="w-4 h-4" />
      </button>
      <button
        type="button"
        onclick={() => setAlign('right')}
        class="p-1.5 rounded hover:bg-muted transition-colors"
        class:bg-muted={currentAlign === 'right'}
        title={$_('editor.alignRight')}
      >
        <Icon icon="mdi:format-align-right" class="w-4 h-4" />
      </button>

      <!-- Table -->
      <div class="w-px h-4 bg-border mx-1"></div>

      <button
        type="button"
        onclick={insertTable}
        class="p-1.5 rounded hover:bg-muted transition-colors"
        title={$_('editor.insertTable')}
      >
        <Icon icon="mdi:table" class="w-4 h-4" />
      </button>
      {#if isInTable}
        <button
          type="button"
          onclick={deleteTable}
          class="p-1.5 rounded hover:bg-muted transition-colors text-destructive"
          title={$_('editor.deleteTable')}
        >
          <Icon icon="mdi:table-remove" class="w-4 h-4" />
        </button>
      {/if}

      <div class="w-px h-4 bg-border mx-1"></div>

      <button
        type="button"
        onclick={insertLink}
        class="p-1.5 rounded hover:bg-muted transition-colors"
        class:bg-muted={activeStates.link}
        title={$_('editor.insertLink')}
      >
        <Icon icon="mdi:link" class="w-4 h-4" />
      </button>
      {#if activeStates.link}
        <button
          type="button"
          onclick={removeLink}
          class="p-1.5 rounded hover:bg-muted transition-colors text-destructive"
          title={$_('editor.removeLink')}
        >
          <Icon icon="mdi:link-off" class="w-4 h-4" />
        </button>
      {/if}

      <div class="w-px h-4 bg-border mx-1"></div>

      <button
        type="button"
        onclick={insertImageUrl}
        class="p-1.5 rounded hover:bg-muted transition-colors"
        title={$_('editor.insertImageUrl')}
      >
        <Icon icon="mdi:image-outline" class="w-4 h-4" />
      </button>
      <button
        type="button"
        onclick={insertImageFile}
        class="p-1.5 rounded hover:bg-muted transition-colors"
        title={$_('editor.insertImageFile')}
      >
        <Icon icon="mdi:image-plus" class="w-4 h-4" />
      </button>

      {#if isImageSelected}
        <div class="w-px h-4 bg-border mx-1"></div>

        <div class="flex items-center gap-1.5">
          {#each imageWidthPresets as presetWidth}
            <button
              type="button"
              onclick={() => applyImageWidth(presetWidth)}
              class="px-2 py-1 text-xs rounded hover:bg-muted transition-colors"
              class:bg-muted={selectedImageWidth === presetWidth}
              title={$_('editor.imageWidthPreset', { values: { width: presetWidth } })}
            >
              {presetWidth}px
            </button>
          {/each}
          <input
            type="number"
            min="1"
            step="1"
            class="w-20 h-8 px-2 text-xs bg-background border border-input rounded"
            value={selectedImageWidth}
            oninput={handleImageWidthInput}
            onchange={applyTypedImageWidth}
            placeholder="px"
            title={$_('editor.imageWidth')}
          />
          <button
            type="button"
            onclick={clearImageSize}
            class="px-2 py-1 text-xs rounded hover:bg-muted transition-colors"
            title={$_('editor.resetImageSize')}
          >
            {$_('editor.reset')}
          </button>
        </div>
      {/if}
    {/if}

    <!-- HTML toggle (always visible, pushed to far right) -->
    <div class="flex-1"></div>
    <button
      type="button"
      onclick={toggleRawHtml}
      class="p-1.5 rounded hover:bg-muted transition-colors"
      class:bg-muted={rawHtmlMode}
      title={rawHtmlMode ? $_('editor.visualMode') : $_('editor.htmlMode')}
    >
      <Icon icon={rawHtmlMode ? 'mdi:eye' : 'mdi:code-tags'} class="w-4 h-4" />
    </button>
  </div>

  <!-- Editor -->
  {#if rawHtmlMode}
    <textarea
      class="w-full min-h-[100px] p-3 font-mono text-sm bg-background text-foreground border-none outline-none resize-y"
      value={rawHtmlContent}
      oninput={handleRawHtmlInput}
      spellcheck="false"
    ></textarea>
  {:else}
    <div bind:this={editorElement} class="min-h-[100px]"></div>
  {/if}
</div>

<style>
  :global(.ProseMirror p.is-editor-empty:first-child::before) {
    color: #adb5bd;
    content: attr(data-placeholder);
    float: left;
    height: 0;
    pointer-events: none;
  }

  /* Table styling */
  :global(.ProseMirror table) {
    border-collapse: collapse;
    margin: 0;
    overflow: hidden;
    table-layout: fixed;
  }

  :global(.ProseMirror td),
  :global(.ProseMirror th) {
    border: 1px solid hsl(var(--border));
    box-sizing: border-box;
    min-width: 1em;
    padding: 6px 8px;
    position: relative;
    vertical-align: top;
  }

  :global(.ProseMirror th) {
    background-color: hsl(var(--muted));
    font-weight: 600;
  }
</style>
