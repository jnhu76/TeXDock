# TeXDock Git Branch Policy

This repository does not treat `overleaf/overleaf` as the runtime upstream.

The real runtime baseline comes from a stable Docker image snapshot, such as `sharelatex/sharelatex:<tag>` or a verified custom ShareLaTeX image.

## Branch Roles

### `master`

Product baseline branch.

This branch contains the TeXDock runtime source that will be modified, tested, and eventually built into a custom Docker image.

Rules:

* Feature branches must be created from `master`.
* Release branches must be created from `master`.
* Do not directly merge `reference-overleaf/main` into `master`.
* Do not rebase `master` onto `reference-overleaf/main`.

---

### `reference-overleaf/main`

Reference-only remote tracking branch.

Source:

```text
https://github.com/overleaf/overleaf.git
```

Purpose:

* Read official source layout.
* Check how official code organizes Dockerfiles, services, and build scripts.
* Compare files manually when needed.
* Investigate upstream issues, commits, or pull requests.

Rules:

* Fetch only.
* Do not merge into `master`.
* Do not rebase onto it.
* Do not treat it as the runtime source of truth.

Allowed commands:

```bash
git fetch --prune reference-overleaf
git log --oneline reference-overleaf/main
git show reference-overleaf/main:path/to/file
git diff master..reference-overleaf/main -- path/to/file
```

Forbidden commands:

```bash
git merge reference-overleaf/main
git rebase reference-overleaf/main
git pull reference-overleaf main
```

---

### `vendor/sharelatex-image-YYYY-MM-DD`

Stable runtime snapshot branch.

This branch stores source code extracted from a known-good ShareLaTeX / Overleaf Docker image.

Purpose:

* Preserve an immutable runtime source snapshot.
* Record exactly which image was used.
* Serve as the only valid source for refreshing runtime code in `master`.

Rules:

* Create it as an orphan branch.
* Keep it clean.
* Do not develop features on it.
* Do not manually patch it.
* Do not merge it directly into `master`.

Suggested branch names:

```text
vendor/sharelatex-image-2026-06-03
vendor/sharelatex-image-5.4.0
vendor/sharelatex-image-5.4.0-2026-06-03
```

Each vendor branch should contain:

```text
README.vendor.md
image-manifest.json
server-ce/
services/
libraries/
package.json
lock files if needed
```

---

### `integration/runtime-import-YYYY-MM-DD`

Temporary branch used to import selected runtime code from a vendor snapshot into `master`.

Purpose:

* Restore selected paths from a vendor branch.
* Resolve conflicts.
* Run smoke tests.
* Merge back into `master` only after validation.

Example:

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

---

### `feat/*`

Feature development branches.

Examples:

```text
feat/admin-diagnostics
feat/log-tracing
feat/deploy-helper
```

Rules:

* Create from `master`.
* Merge back into `master` after review.
* Do not modify vendor branches.
* Avoid touching core runtime paths unless the feature explicitly requires it.

---

## Core Principle

```text
reference-overleaf = official source reference, read-only
vendor/image-*     = stable runtime snapshot, read-only
master             = TeXDock product baseline
feat/*             = TeXDock feature work
release/*          = Docker image build preparation
```

The project must not follow `overleaf/overleaf` main directly.

The project follows stable Docker image snapshots.

