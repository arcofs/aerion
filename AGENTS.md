# AGENTS.md

This repository is used in two modes:

1. `upstream/main`
   The original project from `hkdb/aerion`.

2. `arcofs/custom`
   The user's long-lived personal branch that contains custom features the user
   wants to keep in their own packaged build, even if those features are not yet
   merged upstream.

## Remotes

Expected git remotes:

- `upstream` -> `https://github.com/hkdb/aerion.git`
- `fork` -> `https://github.com/arcofs/aerion.git`

This repository is intentionally configured without relying on `origin`.
Future work should use `fork` and `upstream` explicitly.

## Branch Strategy

- `main`
  Keep close to upstream. Use it as the clean sync branch.
  Expected tracking branch: `upstream/main`

- `feature/<name>`
  Use one branch per feature. These branches should be scoped, reviewable, and
  PR-friendly.

- `arcofs/custom`
  This is the integration branch for the user's actual personal build. Any
  feature the user wants in their private packaged app must be merged into this
  branch.
  Expected tracking branch: `fork/arcofs/custom`

Current expected contents of `arcofs/custom`:

- Microsoft shared mailbox support from `feature/microsoft-shared-mailboxes`

Current branch layout:

- `main` tracks `upstream/main`
- `feature/microsoft-shared-mailboxes` tracks `fork/feature/microsoft-shared-mailboxes`
- `arcofs/custom` tracks `fork/arcofs/custom`

## Working Rules For Codex

- Do not develop directly on `main` unless the user explicitly asks for it.
- Prefer creating new work from `arcofs/custom` when the user wants to keep all
  previously added custom features in the resulting build.
- Prefer creating a new feature branch from `arcofs/custom` for each new custom
  feature, then merge it back into `arcofs/custom` when complete.
- If the user wants to submit a PR upstream, the feature should also remain
  isolated on its own `feature/<name>` branch when practical.
- Do not delete or rewrite the user's custom branches unless explicitly asked.
- Do not assume upstream has accepted custom features yet.

## Recommended Workflow

### Sync upstream changes

Update `main` from upstream:

```bash
git checkout main
git fetch upstream
git merge upstream/main
git push fork main
```

### Start a new custom feature

Start from the user's integrated custom branch:

```bash
git checkout arcofs/custom
git pull --ff-only fork arcofs/custom
git checkout -b feature/<new-feature>
```

### Finish a custom feature

Merge the feature back into the custom branch:

```bash
git checkout arcofs/custom
git merge feature/<new-feature>
git push fork arcofs/custom
```

If the feature should be proposed upstream, also push the feature branch and open
a PR from the fork to `hkdb/aerion`.

### Keep the custom branch current

After syncing `main` from upstream, merge it into the custom branch:

```bash
git checkout arcofs/custom
git merge main
git push fork arcofs/custom
```

## Building The User's Version

To build the user's packaged version with all custom features, build from:

- `arcofs/custom`, or
- a feature branch created from `arcofs/custom`

Do not build from `main` if the user expects custom features to be present.

Typical build commands:

```bash
export PATH=/home/tom/.local/bin:/home/tom/.local/go/bin:$PATH
make build
./build/bin/aerion
```

### Local deploy workflow on this machine

For this repository on the user's Linux PC, prefer the one-command local deploy
path:

```bash
git checkout arcofs/custom
make local-deploy
```

This runs `scripts/local-deploy.sh`, which:

- adds `/home/tom/.local/bin` and `/home/tom/.local/go/bin` to `PATH` for the command
- builds the current branch
- installs the binary and desktop assets into `/usr/local`
- removes the user Flatpak `io.github.hkdb.Aerion` if it is still installed, so
  the launcher opens the custom local build instead of the public Flatpak

Repeat deployments do not require uninstalling the existing `/usr/local`
installation first. `make install-linux` overwrites the previous local install
in place. Only the Flatpak may need removal, and the deploy script handles that
idempotently.

## Validation Expectations

Before finalizing meaningful changes, prefer to run:

```bash
npm run check --prefix frontend
npm run build --prefix frontend
PATH=/home/tom/.local/go/bin:$PATH go test ./...
```

If system packages are missing, tell the user the exact `sudo apt-get install`
commands needed.

## PR Expectations

When opening upstream PRs for custom features:

- first check the status of `hkdb/aerion#89` and `wailsapp/wails#5087`; if both
  are merged, the spellcheck feature PR can be opened upstream against
  `hkdb/aerion`
- explain the user-visible behavior
- explain the technical model at a high level
- include validation steps run locally
- mention limitations and scope
- avoid mixing unrelated cleanup into feature PRs
