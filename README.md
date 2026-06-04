# TeXDock

TeXDock is a self-hosted LaTeX runtime management project based on stable ShareLaTeX / Overleaf Docker image snapshots.

TeXDock does **not** treat `overleaf/overleaf` GitHub `main` as the runtime upstream.

The runtime source of truth is the tested Docker image, for example:

```text
sharelatex/sharelatex:5.5.8
```

The core idea is:

```text
stable ShareLaTeX / Overleaf Docker image
        ↓
vendor runtime snapshot
        ↓
TeXDock master baseline
        ↓
controlled service adoption
        ↓
temporary build context
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
* extract known-good code from Docker image snapshots;
* avoid depending on unstable upstream source `main`;
* keep vendor runtime snapshots read-only;
* adopt only selected services into `master` when modification is needed;
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
vendor/sharelatex-image-5.5.8
```

This branch stores service source code extracted from a known-good ShareLaTeX / Overleaf Docker image.

For the current baseline, the image is:

```text
sharelatex/sharelatex:5.5.8
```

The vendor branch is treated as a read-only runtime snapshot.

Do not develop features on this branch.

Do not manually edit service code on this branch.

Do not merge this branch into `master`.

### 3. Product baseline

```text
master
```

This branch contains the TeXDock working baseline.

It contains:

```text
README.md
docs/
scripts/
Dockerfile
build/
services/
```

The `services/` directory in `master` is intentionally not a full copy of vendor services.

Only services that TeXDock has explicitly adopted and may modify should appear in `master/services/`.

Services not present in `master/services/` are loaded from the vendor snapshot during build-context assembly.

## Branch Rules

```text
reference-overleaf/main
  Read-only official source reference.
  Fetch only. Do not merge.

vendor/sharelatex-image-*
  Read-only runtime snapshot extracted from stable Docker image.
  Do not develop features here.
  Do not manually modify service code here.

master
  TeXDock product baseline.
  Feature work starts here.
  Contains project skeleton and adopted services only.

feat/*
  Feature development branches.

build/*
  Build workflow, Dockerfile, mirror, and image assembly work.

release/*
  Image build and release preparation branches.
```

## Directory Layout

Recommended local layout:

```text
/home/hoo/Projects/
├── TeXDock/                         # master
│   ├── README.md
│   ├── docs/
│   ├── scripts/
│   ├── Dockerfile
│   ├── build/
│   │   └── services.txt
│   └── services/
│       └── README.md
│
└── texdock-vendor/                  # vendor/sharelatex-image-5.5.8
    └── overleaf/
        └── services/
            ├── chat/
            ├── clsi/
            ├── contacts/
            ├── docstore/
            ├── document-updater/
            ├── filestore/
            ├── history-v1/
            ├── notifications/
            ├── project-history/
            └── real-time/
```

Do not put the vendor worktree inside the main repository.

Recommended:

```text
/home/hoo/Projects/texdock-vendor
```

Not recommended:

```text
/home/hoo/Projects/TeXDock/textdock-vendor
```

## Runtime Baseline

The current baseline image is:

```text
sharelatex/sharelatex:5.5.8
```

Observed runtime inside the image:

```text
node: v22.15.1
npm:  10.9.2
yarn: not-found

node path:
/usr/bin/node

npm path:
/usr/bin/npm

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

Rules:

* use Node.js `22.15.1`;
* use npm `10.9.2`;
* do not assume `yarn` exists;
* do not infer runtime versions from the upstream GitHub repository;
* the Docker image runtime is the source of truth.

## Common Workflow

### 1. Update reference source

```bash
./scripts/update-reference-overleaf.sh
```

This only fetches the latest official Overleaf source for reading and comparison.

It does not merge anything.

Do not run:

```bash
git merge reference-overleaf/main
git rebase reference-overleaf/main
```

`overleaf/overleaf` is reference material, not the runtime upstream.

## 2. Extract service source code from Docker image

To extract `/overleaf/services` from a ShareLaTeX / Overleaf Docker image:

```bash
./scripts/extract_services.sh sharelatex/sharelatex:5.5.8 ./extracted_services --force
```

Parameters:

* `sharelatex/sharelatex:5.5.8`: Docker image tag;
* `./extracted_services`: output directory;
* `--force`: force overwrite existing output directory.

The extracted services will be located at:

```text
./extracted_services/overleaf/services/
```

## 3. Create or update vendor snapshot

Vendor snapshots should be stored on orphan branches.

Example branch:

```text
vendor/sharelatex-image-5.5.8
```

The vendor branch stores the extracted runtime services.

It should be considered read-only after import.

A vendor branch is not a development branch.

## 4. Create vendor worktree

Create a separate worktree for the vendor snapshot:

```bash
cd /home/hoo/Projects/TeXDock

git worktree add ../texdock-vendor vendor/sharelatex-image-5.5.8
```

Check:

```bash
ls ../texdock-vendor/overleaf/services
```

Expected service directories include:

```text
chat
clsi
contacts
docstore
document-updater
filestore
history-v1
notifications
project-history
real-time
```

If a stale worktree record exists:

```bash
git worktree prune
git worktree list
```

## 5. Adopt a service before modifying it

Do not modify service code directly in the vendor worktree.

Wrong:

```bash
cd ../texdock-vendor
vim overleaf/services/clsi/xxx.js
```

Correct:

```bash
cd /home/hoo/Projects/TeXDock

cp -a ../texdock-vendor/overleaf/services/clsi services/clsi

git add services/clsi
git commit -m "services: adopt clsi from sharelatex 5.5.8"
```

The first commit should be a pure import commit.

After that, modify the adopted service:

```bash
vim services/clsi/xxx.js

git add services/clsi
git commit -m "services: customize clsi for texdock"
```

This keeps history clean:

```text
commit A: original service adoption
commit B: TeXDock modification
```

## 6. Declare services included in final image

The file:

```text
build/services.txt
```

declares which services should be included in the final image.

Example:

```text
chat
clsi
contacts
docstore
document-updater
filestore
history-v1
notifications
project-history
real-time
```

The final image should not rely on accidental directory scanning.

It should be assembled from this explicit service list.

## 7. Prepare build context

The final Docker image is not built directly from `master` or directly from `vendor`.

It is built from a temporary assembled context:

```text
.build/context
```

The intended assembly logic is:

```text
1. Copy TeXDock master project skeleton.
2. Read build/services.txt.
3. For each service:
   - if services/<service> exists in master, use the master version;
   - otherwise use ../texdock-vendor/overleaf/services/<service>.
4. Generate .build/context.
5. Build Docker image from .build/context.
```

Run:

```bash
./scripts/prepare-build-context.sh
```

Then build:

```bash
docker build -t texdock:dev .build/context
```

## 8. Dockerfile and China mirrors

Dockerfile mirror changes should be committed separately from service adoption.

Recommended rule:

```text
build/mirror changes != service import changes != business changes
```

For npm, use npm because the current runtime does not include yarn:

```dockerfile
RUN npm config set registry https://registry.npmmirror.com
```

Before changing system package sources, inspect the image OS first:

```bash
./scripts/check-image-runtime.sh sharelatex/sharelatex:5.5.8
```

Do not blindly replace Debian/Ubuntu sources without checking `/etc/os-release`.

## Checking Docker Image Runtime

To inspect the Node.js runtime environment inside a ShareLaTeX / Overleaf Docker image:

```bash
./scripts/check-image-runtime.sh sharelatex/sharelatex:5.5.8
```

This script displays:

* OS information;
* Node.js, npm, and yarn versions;
* binary paths;
* PATH environment variable;
* Node binary details;
* installed packages via `dpkg`;
* apt policy for `nodejs`.

This helps verify the runtime environment before extracting source code or planning compatibility changes.

## Important Rules

### Do not merge reference source

Do not run:

```bash
git merge reference-overleaf/main
git rebase reference-overleaf/main
```

### Do not merge vendor snapshot into master

Do not run:

```bash
git merge vendor/sharelatex-image-5.5.8 --allow-unrelated-histories
```

### Do not modify vendor services directly

Do not develop inside:

```text
../texdock-vendor/overleaf/services/
```

### Do not bulk-copy vendor services into master

Do not run:

```bash
cp -r ../texdock-vendor/overleaf/services/* services/
```

Do not run:

```bash
rsync -a ../texdock-vendor/overleaf/services/ services/
```

Only adopt a service when TeXDock needs to modify or explicitly manage it.

## Recommended Commit Order

Recommended sequence:

```text
1. chore: import sharelatex project skeleton without services
2. docs: document vendor services development model
3. scripts: add build context assembler
4. build: declare services included in image
5. build: use China mirrors in Dockerfile
6. services: adopt clsi from sharelatex 5.5.8
7. services: customize clsi for texdock
```

Keep different concerns in separate commits:

```text
project skeleton
documentation
build scripts
Dockerfile mirrors
service adoption
service modification
```

## Summary

TeXDock uses this model:

```text
vendor saves original services;
master saves project skeleton and adopted services;
build/services.txt declares final services;
scripts/prepare-build-context.sh assembles a temporary build context;
Docker builds from .build/context.
```

Most important rule:

```text
Do not develop in vendor.
Do not merge vendor into master.
Do not blindly copy all services into master.
Adopt first, modify second, build through an assembled context.
```
