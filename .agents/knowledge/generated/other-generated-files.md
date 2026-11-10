---
type: Constraint
title: Other generated, compiled or mirrored files, and API docs
description: The root `README.md` is a symlink to the admin package README, the task-queue fixture's compiled JS is committed and rebuilt from its TypeScript, and the API reference is pub.dev dartdoc, with no docs workflow and nothing that checks dartdoc is present.
tags: [generated, repo, docs]
agents_md: when-touching
governs:
  - README.md
  - packages/firebase_admin_sdk/test/fixtures/task_queue_functions/**
  - doc/**
  - scripts/generate-docs.sh
sources:
  - id: fixture-source
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/task_queue_functions/src/index.ts
    title: The fixture's TypeScript source
  - id: compiled-fixture
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/task_queue_functions/lib/index.js
    title: The compiled task-queue fixture (committed)
  - id: root-readme
    resource: ../../../README.md
    title: The root README, a symlink to the admin package README
  - id: melos-docs
    resource: ../../../pubspec.yaml
    symbol: generate-docs.sh
    title: The melos `docs` script
  - id: generate-docs
    resource: ../../../scripts/generate-docs.sh
    symbol: dart doc
    title: The docs script, which writes to the git-ignored `doc/api/`
  - id: doc-index
    resource: ../../../doc/index.html
    title: The hand-written landing page
  - id: contributing-docs
    resource: ../../../CONTRIBUTING.md
    symbol: "### Documentation"
    title: CONTRIBUTING's dartdoc rules
---

# Where it lives

- Enforced by: nothing; review only.
- The fixture and its committed build: `src/index.ts` and `lib/index.js` in `packages/firebase_admin_sdk/test/fixtures/task_queue_functions/`.[^fixture-source][^compiled-fixture]
- The root README, a symlink to `packages/firebase_admin_sdk/README.md`: `README.md`.[^root-readme]
- Local API docs: the `docs` script, which runs `generate-docs.sh`, in the root `pubspec.yaml`,[^melos-docs] and `dart doc` in `scripts/generate-docs.sh`.[^generate-docs] `doc/index.html` is a hand-written landing page.[^doc-index]
- The dartdoc rule for public APIs: `### Documentation` in `CONTRIBUTING.md`.[^contributing-docs]

# Constraint

- The root `README.md` is a symlink to the admin package README.
- The task-queue fixture's compiled `lib/index.js` and its source map are committed. `scripts/coverage.sh` and CONTRIBUTING's emulator setup rebuild them and run `npm install` in the fixture, which can leave a rebuild-only diff and lockfile churn (see [No committed lockfiles or overrides](/dependencies/no-lockfiles-or-overrides.md)).
- The API reference is the dartdoc on pub.dev. No workflow builds or deploys docs. The repo's GitHub Pages site is the last deployment of an earlier docs workflow that was dropped, and nothing updates it.
- Nothing checks that a public API has dartdoc; the lints check only the references inside it.

# Why

- Why the root README is a symlink and why the compiled JS is committed isn't recorded. Ask a maintainer before changing either. The likely reason for the symlink (not recorded): it keeps the GitHub landing page and the pub.dev README identical.
- Why rebuild-only and lockfile changes in the fixture stay out of commits isn't recorded. The likely reason (not recorded): they come from local tool versions, not from a source change.
- The maintainers' stated reason for dropping the docs workflow, phrased as a question: it wasn't really needed.

# Rules for agents

- **Must:** edit `packages/firebase_admin_sdk/README.md`, not the root `README.md`.
- **Must not:** replace the root `README.md` symlink with a file.
- **Must:** change the fixture's `src/index.ts`, not `lib/index.js`, then rebuild and commit both.
- **Must not:** commit `task_queue_functions/node_modules`, or a rebuild-only change to its `lib/index.js` when `src/index.ts` didn't change.
- **Should:** leave out of your commits the `package-lock.json` churn in that fixture that `npm install` can cause.
- **Must:** add dartdoc to every new public API, as CONTRIBUTING.md › Documentation asks. Nothing checks it.
- **Ask first:** before reintroducing a docs deployment workflow.

# Related

- [No committed lockfiles or dependency overrides](/dependencies/no-lockfiles-or-overrides.md)
- [Inject test doubles and use the guarded emulator helpers](/tests/helpers-and-injection.md)
- [The pub workspace, melos and local setup](/repo/workspace-and-melos.md)
- [version.g.dart is generated from the pubspec](/generated/version-g-dart.md)

[^fixture-source]: The fixture's TypeScript source
[^compiled-fixture]: The compiled task-queue fixture
[^root-readme]: The root README symlink
[^melos-docs]: The melos `docs` script
[^generate-docs]: `scripts/generate-docs.sh`
[^doc-index]: `doc/index.html`
[^contributing-docs]: CONTRIBUTING's documentation rules
