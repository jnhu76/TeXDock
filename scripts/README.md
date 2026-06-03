# scripts/

This directory contains helper scripts for maintaining TeXDock's branch and source workflow.

The scripts here are intentionally conservative.

They are designed to avoid accidental merges from `overleaf/overleaf` and to keep vendor runtime snapshots clean.

## Scripts

### `update-reference-overleaf.sh`

Fetches the latest official Overleaf source into the `reference-overleaf` remote.

This script is reference-only.

It does not merge anything.

Usage:

```bash
scripts/update-reference-overleaf.sh
```

What it does:

```text
1. Adds the reference-overleaf remote if missing.
2. Disables tag import from that remote.
3. Fetches the latest branches from overleaf/overleaf.
4. Prints recent commits from reference-overleaf/main.
```

Allowed follow-up commands:

```bash
git log --oneline reference-overleaf/main
git show reference-overleaf/main:path/to/file
git diff master..reference-overleaf/main -- path/to/file
git switch --detach reference-overleaf/main
```

Forbidden commands:

```bash
git merge reference-overleaf/main
git rebase reference-overleaf/main
git pull reference-overleaf main
```

### `create-vendor-snapshot.sh`

Creates an orphan vendor branch from an extracted stable Docker image source directory.

Usage:

```bash
scripts/create-vendor-snapshot.sh \
  vendor/sharelatex-image-2026-06-03 \
  /absolute/path/to/extracted-sharelatex-source
```

Important requirements:

```text
- The source directory must be outside this repository.
- The working tree must be clean.
- The target branch name must start with vendor/.
- The vendor branch must not already exist.
```

What it does:

```text
1. Creates an orphan vendor branch.
2. Removes all existing repository files from the working tree.
3. Copies the extracted source into the repository root.
4. Adds README.vendor.md if missing.
5. Commits the imported snapshot.
```

The vendor branch is read-only after creation.

Do not develop features on vendor branches.

## Making Scripts Executable

After creating or editing a script:

```bash
chmod +x scripts/name.sh
git add scripts/name.sh
git update-index --chmod=+x scripts/name.sh
```

Check that Git recorded executable permission:

```bash
git ls-files -s scripts/name.sh
```

Expected mode:

```text
100755
```

Or check staged mode changes:

```bash
git diff --cached --summary
```

Expected output may include:

```text
mode change 100644 => 100755 scripts/name.sh
```

## Safety Rules

Before running scripts that modify branches:

```bash
git status
```

The working tree should be clean.

Never run vendor snapshot creation from inside an uncommitted working directory.

Never import extracted image source from a path inside this repository.

## Suggested Workflow

```bash
# 1. Update official reference source
scripts/update-reference-overleaf.sh

# 2. Create a clean vendor snapshot from extracted image source
scripts/create-vendor-snapshot.sh \
  vendor/sharelatex-image-2026-06-03 \
  /absolute/path/to/extracted-sharelatex-source

# 3. Return to master
git switch master

# 4. Create an integration branch
git switch -c integration/runtime-import-2026-06-03

# 5. Restore selected paths from vendor
git restore --source=vendor/sharelatex-image-2026-06-03 -- server-ce services libraries package.json

# 6. Commit and merge after review
git add .
git commit -m "runtime: import stable sharelatex image source"

git switch master
git merge integration/runtime-import-2026-06-03
```

## Core Rule

Scripts in this directory support this source model:

```text
reference-overleaf/main  = read-only source reference
vendor/sharelatex-*      = read-only runtime snapshot
master                   = product baseline
feat/*                   = feature development
release/*                = image build preparation
```

