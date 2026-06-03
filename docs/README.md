# docs/

This directory contains TeXDock project rules, design notes, and operational runbooks.

The documents here define how this repository should be maintained.

## Recommended Documents

### `git-branch-policy.md`

Defines the branch model.

It explains the roles of:

```text
master
reference-overleaf/main
vendor/sharelatex-image-*
integration/runtime-import-*
feat/*
release/*
```

This is the most important document for avoiding accidental merges from `overleaf/overleaf`.

### `runtime-baseline.md`

Records the current stable runtime source.

Suggested content:

```text
Runtime baseline:
- source image:
- image tag:
- image digest:
- extracted at:
- extracted by:
- imported vendor branch:
- imported into master commit:
```

This file answers:

```text
Where did this runtime code come from?
Which Docker image is the source of truth?
```

### `image-code-mapping.md`

Records how files extracted from a Docker image map into this repository.

Example:

```text
Image path                         Repo path
/overleaf/services/web             services/web
/overleaf/services/clsi            services/clsi
/overleaf/services/docstore        services/docstore
/overleaf/services/filestore       services/filestore
/overleaf/server-ce                server-ce
```

This prevents future confusion about which paths came from the image.

### `patch-policy.md`

Defines what TeXDock is allowed to modify.

Suggested categories:

```text
Allowed:
- management pages
- diagnostic APIs
- log tracing
- deployment helpers
- smoke tests
- Docker Compose configuration

Caution:
- user management
- compile service
- file storage
- Mongo schema
- editor integration

Avoid for now:
- real-time collaboration
- history system
- comments
- track changes
- large permission model changes
```

### `build-image-runbook.md`

Describes how to build a custom ShareLaTeX-compatible Docker image from the TeXDock baseline.

It should include:

```text
1. required tools;
2. base image;
3. build command;
4. image tag convention;
5. smoke test checklist;
6. rollback procedure.
```

### `smoke-test.md`

Defines the minimum test checklist before accepting a runtime import or release.

Suggested checklist:

```text
- containers start successfully;
- web service is reachable;
- /launchpad opens;
- admin user can be created;
- login works;
- project can be created;
- main.tex can be edited;
- PDF compilation works;
- compile logs are visible;
- data persists after restart.
```

## Document Rules

Keep docs short and operational.

Each document should answer one concrete question.

Avoid large theory documents unless they directly help with maintenance or deployment.

## Current Core Principle

```text
reference-overleaf = read-only official source reference
vendor/image-*     = stable runtime source snapshot
master             = TeXDock product baseline
feat/*             = feature work
release/*          = Docker image release preparation
```

The project follows stable Docker image snapshots, not `overleaf/overleaf` main.

