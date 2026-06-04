#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${IMAGE:-sharelatex/sharelatex:5.5.8}"

echo "Inspecting runtime image:"
echo "  IMAGE: $IMAGE"
echo

NODE_VERSION_RAW="$(docker run --rm --entrypoint sh "$IMAGE" -lc 'node -v')"
NPM_VERSION="$(docker run --rm --entrypoint sh "$IMAGE" -lc 'npm -v')"

NODE_VERSION="${NODE_VERSION_RAW#v}"

if [[ -z "$NODE_VERSION" ]]; then
  echo "ERROR: failed to detect Node.js version from image: $IMAGE" >&2
  exit 1
fi

if [[ -z "$NPM_VERSION" ]]; then
  echo "ERROR: failed to detect npm version from image: $IMAGE" >&2
  exit 1
fi

printf '%s\n' "$NODE_VERSION" > .nvmrc
printf '%s\n' "$NODE_VERSION" > .node-version

mkdir -p docs

cat > docs/runtime-version.md <<EOF
# Runtime Version

TeXDock uses the runtime environment from:

\`\`\`text
$IMAGE
\`\`\`

Detected runtime versions:

\`\`\`text
node: $NODE_VERSION_RAW
npm:  $NPM_VERSION
\`\`\`

Host development version files:

\`\`\`text
.nvmrc
.node-version
\`\`\`

Both should match the Node.js version detected inside the runtime image.

These files are used only for host-side editor/tooling alignment. TeXDock's current mainline does not use host-side \`npm install\`, \`yarn install\`, or source-build compilation.
EOF

echo "Updated:"
echo "  .nvmrc          -> $NODE_VERSION"
echo "  .node-version   -> $NODE_VERSION"
echo "  docs/runtime-version.md"
