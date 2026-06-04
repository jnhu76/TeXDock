# Runtime Version

TeXDock uses the runtime environment from:

```text
sharelatex/sharelatex:5.5.8
```

Detected runtime versions:

```text
node: v22.15.1
npm:  10.9.2
```

Host development version files:

```text
.nvmrc
.node-version
```

Both should match the Node.js version detected inside the runtime image.

These files are used only for host-side editor/tooling alignment. TeXDock's current mainline does not use host-side `npm install`, `yarn install`, or source-build compilation.
