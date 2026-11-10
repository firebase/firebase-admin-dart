---
type: Constraint
title: The pub workspace, melos and local setup
description: A root `dart pub get` resolves the whole pub workspace and melos runs from the root dev dependency without a global install; local resolution hides a too-low lower bound on `google_cloud_firestore`, and tools and credentials are set up only when the user asks.
tags: [repo, workspace, melos, setup]
agents_md: always
governs:
  - pubspec.yaml
  - packages/*/pubspec.yaml
  - CONTRIBUTING.md
sources:
  - id: workspace-members
    resource: ../../../pubspec.yaml
    symbol: "workspace:"
    title: The workspace members in the root pubspec
  - id: melos-config
    resource: ../../../pubspec.yaml
    symbol: "melos:"
    title: Melos as a root dev dependency, with its scripts and hooks
  - id: process-coverage
    resource: ../../../scripts/process_coverage.dart
    symbol: coverage.lcov
    title: Fails if a `packages/*` directory has no `coverage.lcov`
  - id: admin-firestore-range
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "google_cloud_firestore: '>="
    title: The admin package's range on `google_cloud_firestore`
  - id: prerequisites
    resource: ../../../CONTRIBUTING.md
    symbol: "### Prerequisites"
    title: CONTRIBUTING's prerequisites and setup
  - id: contributing-melos
    resource: ../../../CONTRIBUTING.md
    symbol: dart pub global activate melos
    title: CONTRIBUTING's global melos install
  - id: golden-node-engine
    resource: ../../../packages/google_cloud_firestore/tool/pipeline_golden/package.json
    symbol: '"engines"'
    title: The Node.js version the Pipeline tools require
---

# Where it lives

- Enforced by: `scripts/process_coverage.dart`, which fails when a `packages/*` directory has no `coverage.lcov`.[^process-coverage] The rest is review only.
- The members, and melos's scripts and hooks: `workspace:` and `melos:` in the root `pubspec.yaml`.[^workspace-members][^melos-config]
- The admin package's range on Firestore: `google_cloud_firestore: '>=` in `packages/firebase_admin_sdk/pubspec.yaml`.[^admin-firestore-range]
- The tools a checkout needs: `### Prerequisites` in `CONTRIBUTING.md` (addlicense is under `### License Headers`),[^prerequisites] and, for the Pipeline tools, `"engines"` in `tool/pipeline_golden/package.json` and `tool/pipeline_api_parity/package.json`.[^golden-node-engine]
- CONTRIBUTING.md's global melos install, which is optional: `dart pub global activate melos`, in Prerequisites and Setup.[^contributing-melos]

# Constraint

- A plain `dart pub get` at the repo root resolves the whole workspace, and is enough to develop.
- CONTRIBUTING.md installs melos globally; that's optional, since `dart run melos …` works from the root dev dependency, though CI uses the global install. What `melos bootstrap` regenerates is in [version.g.dart is generated from the pubspec](/generated/version-g-dart.md).
- `firebase_admin_sdk` depends on `google_cloud_firestore` by version range. Inside the workspace, that range resolves to the local package, so a lower bound that is too low doesn't show up locally.
- The Pipeline tools need the Node.js version in their `engines` field, which CONTRIBUTING.md's prerequisites don't list.

# Why

- Melos and the root-pubspec layout: the maintainers' stated reason is that this is the standard on most Invertase repositories and has served them well at scale.
- The Node.js version: the maintainers' stated reason is that the `@google-cloud/firestore` release the Pipeline tools pin needs a newer Node.js.

# Rules for agents

- **Must:** to add a package, list it in `workspace:` in the root pubspec, give it `resolution: workspace`, and make sure a coverage script writes a `coverage.lcov` in it.
- **Must:** when `firebase_admin_sdk` starts using a new `google_cloud_firestore` API, raise its lower bound on `google_cloud_firestore`. What that means for the release is in [the release process](/release/release-process.md).
- **Must not:** add path dependencies or `pubspec_overrides.yaml` to link packages.
- **Should:** install a missing tool only when the user asks, following CONTRIBUTING.md's setup sections.
- **Must not:** set up or create credentials (see [Prod and WIF test runs](/tests/prod-and-wif.md)).

# Related

- [version.g.dart is generated from the pubspec](/generated/version-g-dart.md)
- [Releases are manual and done by Google maintainers](/release/release-process.md)
- [Other generated, compiled or mirrored files, and API docs](/generated/other-generated-files.md)
- [What CI runs, the coverage gate, and what gates merging](/ci/trigger-matrix.md)
- [Minimum Dart SDK](/dependencies/min-dart-sdk.md)

[^workspace-members]: `workspace:` in the root pubspec
[^melos-config]: Melos in the root pubspec
[^process-coverage]: `scripts/process_coverage.dart`
[^admin-firestore-range]: `firebase_admin_sdk`'s pubspec
[^prerequisites]: CONTRIBUTING's prerequisites
[^contributing-melos]: CONTRIBUTING's global melos install
[^golden-node-engine]: The Pipeline tools' `engines` field
