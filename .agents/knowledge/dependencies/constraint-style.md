---
type: Constraint
title: Dependency constraint style
description: Caret constraints are the default, explicit `'>=a <b'` ranges are used where a range was widened across breaking releases (several `google_cloud_*` packages and `googleapis`), ranges are widened without raising minimums, and dependencies are sorted.
tags: [dependencies, pubspec, versioning]
agents_md: when-touching
governs:
  - packages/*/pubspec.yaml
  - pubspec.yaml
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
---

# Constraint

- **Caret by default.** Most dependencies use caret constraints, including some 0.x Google Cloud packages (`google_cloud_protobuf`, `google_cloud_type`).[^firestore-protobuf-caret]
- **Explicit ranges where widened.** `'>=a <b'` ranges are used where a range was widened across breaking releases: `google_cloud`, `google_cloud_firestore`, `google_cloud_storage`, `google_cloud_firestore_v1`, `google_cloud_rpc` and `googleapis`.[^admin-firestore-range][^firestore-rpc-range] The `analyzer` dev dependency of `google_cloud_firestore` also uses a range, chosen around the SDK floor (see [minimum Dart SDK](/dependencies/min-dart-sdk.md)). These packages ship breaking releases often: 0.x minors of `google_cloud_*`, and majors of `googleapis`.
- **Bounds.** Lower bounds are tightened to versions known to work. Upper bounds are widened without raising the minimums.
- **Order.** Dependencies are sorted alphabetically.

# Why

The maintainers' stated reasons:

- Minimum versions were tightened (with `dart pub upgrade --tighten`) to versions that work on the supported SDK.
- Upper bounds are widened without bumping minimum versions, so downstream applications can resolve the newer releases.
- A range can span two breaking lines at once, as `google_cloud` does.
- Sorting comes from the `sort_pub_dependencies` lint in `dart_flutter_team_lints`.

# Enforced by

- `sort_pub_dependencies`, through `dart analyze`. CI analyzes only `packages/firebase_admin_sdk/` (see [lints and analysis](/ci/lint-and-format.md)).
- Lower bounds aren't tested: there is no `dart pub downgrade` job. The analyze job on the SDK floor resolves older versions only where newer ones need a newer SDK.

# Rules for agents

- **Must:** widen a range, and add a CHANGELOG line, rather than force users onto a new minor.
- **Must:** keep pubspec dependencies alphabetical.
- **Must:** when widening `googleapis`, check that every generated API the package imports still exists in the new major. A generated client has left `googleapis` before: `firebaseremoteconfig`, which is why `googleapis` has no Remote Config client (see [unsupported services](/scope/unsupported-services.md)).
- **Must not:** raise a lower bound unless the code needs the newer version.
- **Must not:** rewrite existing caret constraints into ranges, or the reverse, just to match a pattern.

# Related

- [Resolvable in Flutter workspaces and for firebase_functions](/dependencies/flutter-and-functions-consumers.md)
- [Storage is a thin wrapper over google_cloud_storage](/storage/google-cloud-storage-wrapper.md)
- [Releases are manual and done by Google maintainers](/release/release-process.md)

[^firestore-rpc-range]: `google_cloud_firestore`'s pubspec
[^firestore-protobuf-caret]: The `google_cloud_protobuf` caret in `google_cloud_firestore`'s pubspec
[^admin-firestore-range]: `firebase_admin_sdk`'s pubspec
