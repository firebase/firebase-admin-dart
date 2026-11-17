---
type: Constraint
title: "Dependency constraints: bounds, consumers and the SDK floor"
description: "Upper bounds are widened without raising minimums and lower bounds are untested, so they are raised only when the code needs it; `firebase_admin_sdk` must keep resolving for `firebase_functions` and, with `google_cloud_firestore`, in pub workspaces that contain a stable Flutter app, so Flutter-pinned packages such as `meta` keep low lower bounds; the `environment.sdk` floor must analyze, although no tests run on it, and is repeated as text in three places that must be kept in sync."
tags: [dependencies, pubspec, versioning, flutter, downstream, dart-sdk, ci]
agents_md: always
governs:
  - packages/*/pubspec.yaml
  - pubspec.yaml
  - "**/pubspec.yaml"
  - .github/workflows/build.yml
sources:
  - id: admin-firestore-range
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "google_cloud_firestore: '>="
    title: An explicit range in `firebase_admin_sdk`'s pubspec
  - id: firestore-rpc-range
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "google_cloud_rpc: '>="
    title: An explicit range in `google_cloud_firestore`'s pubspec
  - id: firestore-protobuf-caret
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "google_cloud_protobuf: ^"
    title: A caret constraint on a 0.x Google Cloud package in `google_cloud_firestore`'s pubspec
  - id: admin-meta
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "meta:"
    title: "`firebase_admin_sdk`'s `meta` constraint"
  - id: firestore-meta
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "meta:"
    title: "`google_cloud_firestore`'s `meta` constraint"
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

- Enforced by (constraint style): nothing; review only. No CI job runs `dart pub downgrade`, so lower bounds are untested.
- Enforced by (flutter workspaces and firebase_functions): nothing; review only. No CI job resolves the packages together with Flutter.
- Enforced by (minimum Dart SDK): the `lint` job, `name: Lint (Dart` in `.github/workflows/build.yml`, whose matrix analyzes `firebase_admin_sdk` on the floor.[^lint-job] Nothing runs the tests on it.
- Ranges widened across breaking releases: `'>=a <b'` constraints such as `google_cloud_firestore: '>=` in `packages/firebase_admin_sdk/pubspec.yaml`[^admin-firestore-range] and `google_cloud_rpc: '>=` in `packages/google_cloud_firestore/pubspec.yaml`.[^firestore-rpc-range]
- Caret constraints, the default, also on some 0.x Google Cloud packages: `google_cloud_protobuf: ^` in `packages/google_cloud_firestore/pubspec.yaml`.[^firestore-protobuf-caret]
- The `meta` lower bound held at what Flutter stable pins: `meta:` in `packages/firebase_admin_sdk/pubspec.yaml`[^admin-meta] and `packages/google_cloud_firestore/pubspec.yaml`.[^firestore-meta]
- The floor: `environment:` `sdk:` in every pubspec, such as the root `pubspec.yaml` and `packages/firebase_admin_sdk/pubspec.yaml`.[^root-pubspec][^admin-pubspec]
- A dev-dependency range chosen around the floor: the `analyzer` comment, `Spans the releases that run on the minimum`, in `packages/google_cloud_firestore/pubspec.yaml`.[^firestore-pubspec]
- The floor as text: `**Dart SDK**` in `CONTRIBUTING.md`[^contributing-floor] and `**Dart SDK` in `packages/firebase_admin_sdk/README.md`,[^readme-floor] besides the lint matrix's first entry.

# Constraint

## Constraint style

- Upper bounds are widened without raising the minimums. A range can span two breaking lines at once, as `google_cloud` does. The `google_cloud_*` packages ship breaking 0.x minors often, and `googleapis` ships breaking majors.
- Lower bounds were tightened to versions known to work on the supported SDK.
- Lower bounds are untested. The analyze job on the SDK floor resolves older versions only where newer ones need a newer SDK, and CI analyzes only `firebase_admin_sdk` (see [lints and analysis](/ci/lint-and-format.md)).

## Flutter workspaces and firebase_functions

`firebase_admin_sdk` is a dependency of `firebase_functions` (firebase/firebase-functions-dart), and both published packages must resolve in a pub workspace that also contains a stable Flutter app.

- The Flutter SDK pins some packages to exact versions: `meta`, `collection` and, through `flutter_localizations`, `intl`. The regular `dependencies` of both packages must not raise their lower bounds above what Flutter stable ships. The `meta` lower bound was lowered for this reason.
- APIs that downstream SDKs need stay public or injectable, for example `UrlKeyFetcher`'s client (see [How tokens are verified](/auth/jwt-verification.md)).
- Dev dependencies aren't affected: consumers don't resolve them.

## Minimum Dart SDK

- Code must analyze on the floor, and run on the stable and beta SDKs. Tests run only on stable and beta.
- Library code uses null-aware elements (`'tenant_id': ?tenantId`), which need Dart 3.8, so the floor can't drop below 3.8 without code changes.
- CONTRIBUTING.md, the admin README and the `lint` matrix repeat the floor as text, not reading it from the pubspecs. A change to the floor updates all of them.

# Why

## Constraint style

The maintainers' stated reasons:

- Minimum versions were tightened (with `dart pub upgrade --tighten`) to versions that work on the supported SDK.
- Upper bounds are widened without bumping minimum versions, so downstream applications can resolve the newer releases.

## Flutter workspaces and firebase_functions

- The maintainers' stated reason, recorded in both packages' CHANGELOGs: the `meta` constraint was lowered to allow workspaces with stable Flutter. The likely reason (not recorded) it matters here: `firebase_functions` depends on the admin package, so it must resolve in those workspaces too.
- The likely mechanism (not recorded): the Flutter SDK pins `meta` and friends to exact versions, so a dependency demanding a newer one makes the shared workspace unsolvable.
- The likely use case (not recorded): Dart Cloud Functions or shared model packages living in the same workspace as a Flutter app. Users do share models between Flutter and `google_cloud_firestore`.

## Minimum Dart SDK

- The reason for the specific floor isn't recorded. Ask a maintainer before changing it.
- The likely reason it can't be much lower (not recorded): pub workspaces need Dart 3.6, and null-aware elements need 3.8.

# Rules for agents

- **Must:** widen a range, and add a CHANGELOG line, rather than force users onto a new minor.
- **Must:** when widening `googleapis`, check that every generated API the package imports still exists in the new major. A generated client has left `googleapis` before: `firebaseremoteconfig` (see [unsupported services](/scope/unsupported-services.md)).
- **Must not:** raise a lower bound unless the code needs the newer version.
- **Must not:** rewrite existing caret constraints into ranges, or the reverse, just to match a pattern.
- **Must not:** raise the lower bound of `meta`, `collection` or `intl` (for example with `dart pub upgrade --tighten`) without checking the versions Flutter stable pins, and never above them.
- **Must not:** break APIs that `firebase_functions` uses without coordinating with that SDK.
- **Must:** when adding a dependency, check its newest version that still supports the SDK floor, as the `analyzer` range does.
- **Must not:** use language features or SDK APIs newer than the SDK floor. Dot shorthands, for example, need Dart 3.10.
- **Must not:** raise the SDK floor without maintainer agreement.

# Related

- [Storage is a thin wrapper over google_cloud_storage](/storage/google-cloud-storage-wrapper.md)
- [Releases, versioning, CHANGELOG and version.g.dart](/release/releases-and-versioning.md)
- [Small dependency set, no lockfiles or overrides](/dependencies/dependency-set.md)
- [Verifying ID tokens, session cookies and App Check tokens](/auth/jwt-verification.md)
- [Credential: sealed class, factories and discovery](/app/credentials.md)
- [Lints, analysis and formatting](/ci/lint-and-format.md)

[^admin-firestore-range]: `firebase_admin_sdk`'s pubspec
[^firestore-rpc-range]: `google_cloud_firestore`'s pubspec
[^firestore-protobuf-caret]: The `google_cloud_protobuf` caret in `google_cloud_firestore`'s pubspec
[^admin-meta]: `meta` in `firebase_admin_sdk`'s pubspec
[^firestore-meta]: `meta` in `google_cloud_firestore`'s pubspec
[^root-pubspec]: The workspace root's pubspec
[^admin-pubspec]: `firebase_admin_sdk`'s pubspec
[^firestore-pubspec]: The `analyzer` comment in `google_cloud_firestore`'s pubspec
[^lint-job]: The `lint` job in `build.yml`
[^contributing-floor]: CONTRIBUTING's prerequisites
[^readme-floor]: The admin README's requirements
