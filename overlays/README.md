# TeXDock Runtime Overlays

This directory stores TeXDock runtime overlay files.

`overlays/overleaf/` maps to `/overleaf/` inside the runtime image.

Only put files that TeXDock intentionally overrides.

Do not copy the whole `/overleaf` directory here.
Do not copy the whole `services/` directory here.
Do not mount `./overlays/overleaf` as `/overleaf`.

Development flow:

1. Extract one file or a small directory from `sharelatex/sharelatex:5.5.8`.
2. Modify it under `overlays/overleaf/...`.
3. Bind mount the exact file or small directory into a running container.
4. Restart the relevant service.
5. Verify behavior.
6. Commit the overlay file.
7. Build a release image using `server-ce/Dockerfile-runtime`.

Unmodified files remain provided by the official runtime image.
