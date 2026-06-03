# TeXDock

TeXDock is a self-hosted LaTeX runtime management project based on stable ShareLaTeX / Overleaf Docker image snapshots.

This repository does **not** treat `overleaf/overleaf` as the runtime upstream.

The core idea is:

```text
stable ShareLaTeX / Overleaf Docker image
        ↓
vendor runtime snapshot
        ↓
TeXDock master baseline
        ↓
feature branches
        ↓
custom Docker image
        ↓
docker compose / toolkit deployment
```

## Project Goal

TeXDock is not a full Overleaf rewrite.

It is intended to maintain a controlled, reproducible, self-hosted runtime baseline for ShareLaTeX / Overleaf Community Edition style deployments.

The first-stage goals are:

* keep a stable runtime code baseline;
* import known-good code from Docker image snapshots;
* avoid depending on unstable source `main`;
* develop small management, diagnostic, logging, and deployment features;
* eventually build a custom ShareLaTeX-compatible Docker image;
* run the custom image using Docker Compose or Overleaf Toolkit.

## Repository Model

This repository uses three kinds of sources.

### 1. Reference source

```text
reference-overleaf/main
```

This points to:

```text
https://github.com/overleaf/overleaf.git
```

It is only used for reading and comparing official source layout.

It must not be merged into `master`.

### 2. Vendor runtime snapshot

```text
vendor/sharelatex-image-YYYY-MM-DD
```

This branch stores source code extracted from a known-good ShareLaTeX / Overleaf Docker image.

It is the runtime source of truth.

Vendor branches are read-only snapshots and should not be edited manually.

### 3. Product baseline

```text
master
```

This branch contains TeXDock's working baseline.

Feature branches should be created from `master`.

Custom runtime changes are eventually merged back into `master`.

## Branch Rules

```text
reference-overleaf/main
  Read-only official source reference.
  Fetch only. Do not merge.

vendor/sharelatex-image-*
  Read-only runtime snapshot from stable Docker image.
  Do not develop features here.

master
  TeXDock product baseline.
  Feature work starts here.

integration/runtime-import-*
  Temporary branch used to import selected vendor code into master.

feat/*
  Feature development branches.

release/*
  Image build and release preparation branches.
```

## Common Workflow

### 1. Update reference source

```bash
scripts/update-reference-overleaf.sh
```

This only fetches the latest official Overleaf source for reading.

It does not merge anything.

### 2. Create a vendor snapshot

First extract the stable image source to a directory outside this repository.

Then run:

```bash
scripts/create-vendor-snapshot.sh \
  vendor/sharelatex-image-2026-06-03 \
  /absolute/path/to/extracted-sharelatex-source
```

This creates an orphan vendor branch and imports the extracted runtime source.

### 3. Import selected runtime code into master

```bash
git switch master
git switch -c integration/runtime-import-2026-06-03

git restore --source=vendor/sharelatex-image-2026-06-03 -- server-ce services libraries package.json

git status
git diff --stat

git add .
git commit -m "runtime: import stable sharelatex image source"

git switch master
git merge integration/runtime-import-2026-06-03
```

### 4. Develop features

```bash
git switch master
git switch -c feat/admin-diagnostics
```

After development and testing:

```bash
git switch master
git merge feat/admin-diagnostics
```

## Important Rule

Do not run:

```bash
git merge reference-overleaf/main
git rebase reference-overleaf/main
```

`overleaf/overleaf` is reference material, not the runtime upstream.

The runtime baseline comes from stable Docker image snapshots.

