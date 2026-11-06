---
type: Constraint
title: Other generated, compiled or mirrored files
description: The task-queue fixture's compiled JS and the Node tool lockfiles are committed, the root `README.md` is a symlink to the admin package README, and `doc/api/` is generated and git-ignored.
tags: [generated, repo]
agents_md: when-touching
governs:
  - README.md
  - packages/firebase_admin_sdk/test/fixtures/task_queue_functions/**
  - doc/**
sources:
  - id: compiled-fixture
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/task_queue_functions/lib/index.js
    title: The compiled task-queue fixture (committed)
  - id: fixture-source
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/task_queue_functions/src/index.ts
    title: The fixture's TypeScript source
  - id: root-readme
    resource: ../../../README.md
    title: The root README, a symlink to the admin package README
  - id: gitignore
    resource: ../../../.gitignore
    symbol: doc/api
    title: "`doc/api` is git-ignored"
---

# Constraint

Besides `version.g.dart` and the Pipeline fixtures, these files are generated, compiled or mirrored:

- `packages/firebase_admin_sdk/test/fixtures/task_queue_functions/lib/index.js` and `index.js.map` are compiled from `src/index.ts` and committed.[^compiled-fixture][^fixture-source] `scripts/coverage.sh` rebuilds them.
- The three `package-lock.json` files are committed. The `tool/pipeline_*` ones are installed with `npm ci`, and the `task_queue_functions` one with `npm install` (in `scripts/coverage.sh`).
- The root `README.md` is a symlink to `packages/firebase_admin_sdk/README.md`.[^root-readme]
- `doc/api/` is generated output and git-ignored.[^gitignore]

# Why

Why the root README is a symlink and why the compiled JS is committed isn't recorded. Ask a maintainer before changing either.

The likely reason for the symlink (not recorded): it keeps the GitHub landing page and the pub.dev README identical.

# Enforced by

`.gitignore` ignores `doc/api`, and `scripts/coverage.sh` rebuilds the fixture. Nothing else enforces these.

# Rules for agents

- **Must:** edit `packages/firebase_admin_sdk/README.md`, not the root `README.md`.
- **Must:** change `src/index.ts`, not `lib/index.js`, then rebuild.
- **Must not:** replace the root `README.md` symlink with a file.

# Related

- [What emulator tests need](/tests/emulator-requirements.md)
- [No committed lockfiles or overrides](/dependencies/no-lockfiles-or-overrides.md)
- [API docs](/generated/api-docs.md)
- [version.g.dart](/generated/version-g-dart.md)

[^compiled-fixture]: The compiled task-queue fixture
[^fixture-source]: The fixture's TypeScript source
[^root-readme]: The root README symlink
[^gitignore]: The root `.gitignore`
