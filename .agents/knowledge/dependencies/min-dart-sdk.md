---
type: Constraint
title: Minimum Dart SDK
description: The `environment.sdk` constraint is the SDK floor; code must analyze on it, although no tests run on it, and the floor is repeated as text in three places that must be kept in sync.
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
    title: "`google_cloud_firestore`'s `analyzer` range, chosen around the floor"
  - id: lint-job
    resource: ../../../.github/workflows/build.yml
    symbol: "name: Lint (Dart"
    title: The `lint` job, which analyzes on the SDK floor, stable and dev
  - id: contributing-floor
    resource: ../../../CONTRIBUTING.md
    symbol: "**Dart SDK**"
    title: CONTRIBUTING's prerequisites, which state the floor as text
  - id: readme-floor
    resource: ../../../packages/firebase_admin_sdk/README.md
    symbol: "**Dart SDK"
    title: The admin README, which states the floor as text
---

# Where it lives

- Enforced by: the `lint` job, `name: Lint (Dart` in `.github/workflows/build.yml`, whose matrix analyzes `firebase_admin_sdk` on the floor.[^lint-job] Nothing runs the tests on it.
- The floor: `environment:` `sdk:` in every pubspec, such as the root `pubspec.yaml` and `packages/firebase_admin_sdk/pubspec.yaml`.[^root-pubspec][^admin-pubspec]
- A dev-dependency range chosen around the floor: the `analyzer` comment, `Spans the releases that run on the minimum`, in `packages/google_cloud_firestore/pubspec.yaml`.[^firestore-pubspec]
- The floor as text: `**Dart SDK**` in `CONTRIBUTING.md`[^contributing-floor] and `**Dart SDK` in `packages/firebase_admin_sdk/README.md`,[^readme-floor] besides the lint matrix's first entry.

# Constraint

- Code must analyze on the floor, and run on the stable and beta SDKs. Tests run only on stable and beta.
- Library code uses null-aware elements (`'tenant_id': ?tenantId`), which need Dart 3.8, so the floor can't drop below 3.8 without code changes.
- CONTRIBUTING.md, the admin README and the `lint` matrix repeat the floor as text, not reading it from the pubspecs. A change to the floor updates all of them.

# Why

- The reason for the specific floor isn't recorded. Ask a maintainer before changing it.
- The likely reason it can't be much lower (not recorded): pub workspaces need Dart 3.6, and null-aware elements need 3.8.

# Rules for agents

- **Must:** when adding a dependency, check its newest version that still supports the SDK floor, as the `analyzer` range does.
- **Must not:** use language features or SDK APIs newer than the SDK floor. Dot shorthands, for example, need Dart 3.10.
- **Must not:** raise the SDK floor without maintainer agreement.

# Related

- [Lints, analysis and formatting](/ci/lint-and-format.md)
- [Resolvable in Flutter workspaces and for firebase_functions](/dependencies/flutter-and-functions-consumers.md)

[^root-pubspec]: The workspace root's pubspec
[^admin-pubspec]: `firebase_admin_sdk`'s pubspec
[^firestore-pubspec]: The `analyzer` comment in `google_cloud_firestore`'s pubspec
[^lint-job]: The `lint` job in `build.yml`
[^contributing-floor]: CONTRIBUTING's prerequisites
[^readme-floor]: The admin README's requirements
