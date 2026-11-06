---
type: Constraint
title: Minimum Dart SDK
description: Every pubspec declares the same minimum Dart SDK (`sdk:`), and code must analyze on that floor and run on the stable and beta SDKs.
tags: [dependencies, dart-sdk, ci]
agents_md: when-touching
governs:
  - "**/pubspec.yaml"
  - .github/workflows/build.yml
sources:
  - id: root-pubspec
    resource: ../../../pubspec.yaml
    symbol: "environment:"
    title: The workspace root's SDK constraint
  - id: admin-pubspec
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "environment:"
    title: "`firebase_admin_sdk`'s SDK constraint"
  - id: firestore-pubspec
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: Spans the releases that run on the minimum
    title: "`google_cloud_firestore`'s SDK constraint and the `analyzer` range chosen around it"
  - id: lint-job
    resource: ../../../.github/workflows/build.yml
    symbol: "name: Lint (Dart"
    title: The `lint` job, which analyzes on the SDK floor, stable and dev
---

# Constraint

Every package, both admin examples and the workspace root declare the same minimum Dart SDK in `environment.sdk`.[^root-pubspec][^admin-pubspec][^firestore-pubspec] That constraint is the SDK floor.

- Code must analyze on the floor, and run on the stable and beta SDKs.
- Library code uses null-aware elements (`'tenant_id': ?tenantId`), which need Dart 3.8, so the floor can't drop below 3.8 without code changes.

`CONTRIBUTING.md`'s prerequisites and the admin README also state the floor.

# Why

- The reason for the specific floor isn't recorded. Ask a maintainer before changing it.
- The likely reason it can't be much lower (not recorded): pub workspaces need Dart 3.6, and null-aware elements need 3.8.
- The `analyzer` dev-dependency range in `google_cloud_firestore` is chosen around the floor. Its comment states that it spans the releases that run on the minimum SDK and the newer ones.[^firestore-pubspec]

# Enforced by

- The pubspecs' `environment.sdk` constraints.
- The CI `lint` job runs `dart analyze` on the floor, stable and dev, in `packages/firebase_admin_sdk` only.[^lint-job]
- Tests run only on stable and beta, so nothing runs the tests on the floor.

# Rules for agents

- **Must:** when adding a dependency, check its newest version that still supports the SDK floor, as the `analyzer` range does.
- **Must not:** use language features or SDK APIs newer than the SDK floor. Dot shorthands, for example, need Dart 3.10.
- **Must not:** raise the SDK floor without maintainer agreement.

# Related

- [Lints, analysis and formatting](/ci/lint-and-format.md)
- [Resolvable in Flutter workspaces and for firebase_functions](/dependencies/flutter-and-functions-consumers.md)

[^root-pubspec]: The workspace root's pubspec
[^admin-pubspec]: `firebase_admin_sdk`'s pubspec
[^firestore-pubspec]: `google_cloud_firestore`'s pubspec and its `analyzer` comment
[^lint-job]: The `lint` job in `build.yml`
