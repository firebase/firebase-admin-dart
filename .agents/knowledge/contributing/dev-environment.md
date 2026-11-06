---
type: Constraint
title: What a working checkout needs
description: Working on the SDK needs Dart at or above the SDK floor, Java 21+ for the Firestore emulator, Node.js with `firebase-tools` for the emulators, a newer Node.js to regenerate the Pipeline fixtures, and `addlicense` for the CI header check.
tags: [contributing, setup, tooling]
agents_md: always
governs:
  - CONTRIBUTING.md
sources:
  - id: prerequisites
    resource: ../../../CONTRIBUTING.md
    symbol: "### Prerequisites"
    title: CONTRIBUTING's prerequisites and setup
  - id: addlicense-install
    resource: ../../../CONTRIBUTING.md
    symbol: "**Install addlicense:**"
    title: CONTRIBUTING's addlicense install and check commands
  - id: melos-hooks
    resource: ../../../pubspec.yaml
    symbol: "post: ./scripts/gen-version.sh"
    title: melos as a root dev dependency, and its bootstrap and version hooks
  - id: golden-node-engine
    resource: ../../../packages/google_cloud_firestore/tool/pipeline_golden/package.json
    symbol: '"engines"'
    title: The Node.js version the Pipeline tools require
---

# Constraint

A working checkout needs:

- Dart at or above the `environment.sdk` constraint in the pubspecs.
- Java 21+, for the Firestore emulator.
- Node.js and the Firebase CLI (`firebase-tools`), for the emulators.
- The Node.js version in the `engines` field of `tool/pipeline_golden/package.json` and `tool/pipeline_api_parity/package.json`, to regenerate the Pipeline golden fixtures or the Node API snapshot.[^golden-node-engine]
- `addlicense`, to run the CI license-header check locally.[^addlicense-install]

CONTRIBUTING.md's "Prerequisites", "Setup" and "License Headers" sections say how to install them.[^prerequisites]

The workspace, as it is set up:

- A plain `dart pub get` at the repo root resolves the whole workspace. That is enough to develop.
- melos is a root dev dependency, so `dart run melos …` works without a global install.
- `melos bootstrap` and `melos version` run `scripts/gen-version.sh`, which rewrites `version.g.dart`.[^melos-hooks] CI runs `melos bootstrap`.

# Why

The maintainers' stated reasons: CONTRIBUTING.md says Java 21+ is "required for the Firestore emulator"; the `@google-cloud/firestore` release the Pipeline tools pin needs a newer Node.js; and CI checks license headers with `addlicense`.

# Enforced by

Not enforced; a convention.

# Rules for agents

- **Should:** install a missing tool only when the user asks, following CONTRIBUTING.md's setup sections.
- **Must not:** duplicate install recipes in the knowledge base or AGENTS.md. Point to CONTRIBUTING.md instead.
- **Must not:** set up credentials.

# Related

- [What emulator tests need](/tests/emulator-requirements.md)
- [The pub workspace and melos](/repo/workspace-and-melos.md)
- [License headers](/conventions/license-headers.md)
- [Prod and WIF test runs](/tests/prod-and-wif.md)
- [Minimum Dart SDK](/dependencies/min-dart-sdk.md)

[^golden-node-engine]: The Pipeline tools' `engines` field
[^addlicense-install]: CONTRIBUTING's addlicense instructions
[^prerequisites]: CONTRIBUTING's prerequisites and setup
[^melos-hooks]: The melos hooks in the root pubspec
