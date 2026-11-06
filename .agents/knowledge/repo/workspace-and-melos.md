---
type: Constraint
title: One pub workspace, with melos on top
description: The repo is a single pub workspace of four members, and CI runs `melos bootstrap`, whose post hook regenerates `version.g.dart`.
tags: [repo, workspace, melos]
agents_md: when-touching
governs:
  - pubspec.yaml
  - packages/*/pubspec.yaml
sources:
  - id: workspace-members
    resource: ../../../pubspec.yaml
    symbol: "workspace:"
    title: The workspace members in the root pubspec
  - id: melos-config
    resource: ../../../pubspec.yaml
    symbol: "melos:"
    title: Melos as a root dev dependency, its `docs` script and its bootstrap and version hooks
  - id: gen-version
    resource: ../../../scripts/gen-version.sh
    title: The post hook that writes `version.g.dart`
  - id: process-coverage
    resource: ../../../scripts/process_coverage.dart
    symbol: coverage.lcov
    title: Fails if a `packages/*` directory has no `coverage.lcov`
---

# Constraint

The repo is one pub workspace. The root pubspec's `workspace:` lists its four members: `firebase_admin_sdk`, its `example` and `example_server_app`, and `google_cloud_firestore`. Each member has `resolution: workspace`.[^workspace-members]

- `firebase_admin_sdk` depends on `google_cloud_firestore` by version range. Inside the workspace, that range resolves to the local package.
- A plain `dart pub get` from the root resolves the whole workspace, and is enough to develop.
- Melos is a root dev dependency, so `dart run melos …` works without a global install.[^melos-config]
- `melos bootstrap` and `melos version` run `scripts/gen-version.sh` as a post hook, which rewrites `version.g.dart`.[^gen-version]
- `melos run docs` runs the docs script.

# Why

- Melos and the root-pubspec layout: the maintainers' stated reason, given while Invertase maintained the repo, is that this is the standard on most Invertase repositories and has served them well at scale.
- Coverage: `scripts/coverage.sh` states that it uses `test_with_coverage` because "dart test --coverage doesn't work with resolution: workspace".

# Enforced by

- CI runs `dart pub global activate melos` and `melos bootstrap` in every job of `build.yml` except `check-license-header`. `e2e_pipeline.yml` uses a plain `dart pub get`.
- `scripts/process_coverage.dart` fails if any `packages/*` directory lacks a `coverage.lcov`.[^process-coverage]

# Rules for agents

- **Must:** to add a package, list it in `workspace:` in the root pubspec, give it `resolution: workspace`, and make sure `scripts/process_coverage.dart` will find a `coverage.lcov` in it.
- **Must:** when `firebase_admin_sdk` starts using a new `google_cloud_firestore` API, raise its lower bound on `google_cloud_firestore`. The workspace resolves the local package, which hides the problem locally.
- **Must not:** add path dependencies or `pubspec_overrides.yaml` to link packages.

# Related

- [version.g.dart is generated from the pubspec](/generated/version-g-dart.md)
- [Releases are manual and done by Google maintainers](/release/release-process.md)
- [API docs are pub.dev dartdoc](/generated/api-docs.md)
- [Coverage threshold in CI](/tests/coverage-threshold.md)

[^workspace-members]: `workspace:` in the root pubspec
[^melos-config]: Melos in the root pubspec
[^gen-version]: `scripts/gen-version.sh`
[^process-coverage]: `scripts/process_coverage.dart`
