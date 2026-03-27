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

If `origin` still points to upstream, prefer using `fork` and `upstream`
explicitly in commands to avoid ambiguity.

## Branch Strategy

- `main`
  Keep close to upstream. Use it as the clean sync branch.

- `feature/<name>`
  Use one branch per feature. These branches should be scoped, reviewable, and
  PR-friendly.

- `arcofs/custom`
  This is the integration branch for the user's actual personal build. Any
  feature the user wants in their private packaged app must be merged into this
  branch.

Current expected contents of `arcofs/custom`:

- Microsoft shared mailbox support from `feature/microsoft-shared-mailboxes`

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

- explain the user-visible behavior
- explain the technical model at a high level
- include validation steps run locally
- mention limitations and scope
- avoid mixing unrelated cleanup into feature PRs

