#!/usr/bin/env bash
set -euo pipefail

BRANCH="${1:-}"
SOURCE_DIR="${2:-}"

if [[ -z "$BRANCH" || -z "$SOURCE_DIR" ]]; then
  echo "Usage:"
  echo "  $0 vendor/sharelatex-image-YYYY-MM-DD /absolute/path/to/extracted-source"
  exit 1
fi

if [[ "$BRANCH" != vendor/* ]]; then
  echo "ERROR: vendor branch name must start with vendor/"
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: not inside a git repository"
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel)"
SOURCE_DIR="$(realpath "$SOURCE_DIR")"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "ERROR: source directory does not exist: $SOURCE_DIR"
  exit 1
fi

# Do not allow importing from inside the repo, because the orphan cleanup will delete it.
case "$SOURCE_DIR" in
  "$ROOT"/*)
    echo "ERROR: source directory must be outside this repository."
    echo "Repo root:   $ROOT"
    echo "Source dir:  $SOURCE_DIR"
    exit 1
    ;;
esac

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: working tree is not clean."
  echo "Commit or stash your changes first."
  git status --short
  exit 1
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "ERROR: branch already exists: $BRANCH"
  exit 1
fi

echo "About to create orphan vendor branch:"
echo "  branch: $BRANCH"
echo "  source: $SOURCE_DIR"
echo
echo "This will remove all files from the working tree except .git."
echo "Type CREATE_VENDOR to continue:"
read -r CONFIRM

if [[ "$CONFIRM" != "CREATE_VENDOR" ]]; then
  echo "Aborted."
  exit 1
fi

git switch --orphan "$BRANCH"

# Remove tracked files from the index/worktree.
git rm -rf . >/dev/null 2>&1 || true

# Remove untracked files, but keep .git.
find "$ROOT" -mindepth 1 -maxdepth 1 ! -name ".git" -exec rm -rf {} +

# Copy source snapshot into repo root.
if command -v rsync >/dev/null 2>&1; then
  rsync -a --exclude ".git" "$SOURCE_DIR"/ "$ROOT"/
else
  cp -a "$SOURCE_DIR"/. "$ROOT"/
fi

cd "$ROOT"

# Add a minimal vendor README if absent.
if [[ ! -f README.vendor.md ]]; then
  cat > README.vendor.md <<EOF
# Vendor Runtime Snapshot

This branch is a clean runtime source snapshot imported from a stable ShareLaTeX / Overleaf Docker image.

Branch:

\`\`\`text
$BRANCH
\`\`\`

Source directory used during import:

\`\`\`text
$SOURCE_DIR
\`\`\`

Rules:

- Do not develop features on this branch.
- Do not patch files on this branch.
- Do not merge this branch directly into master.
- Import selected paths into master only through an integration branch.
EOF
fi

git add .

if git diff --cached --quiet; then
  echo "ERROR: nothing to commit. Source directory may be empty."
  exit 1
fi

git commit -m "vendor: import sharelatex image snapshot ${BRANCH#vendor/}"

echo
echo "Created vendor snapshot branch:"
echo "  $BRANCH"
echo
echo "Next step:"
echo "  git switch master"
echo "  git switch -c integration/runtime-import-YYYY-MM-DD"
echo "  git restore --source=$BRANCH -- server-ce services libraries package.json"

