---
type: Constraint
title: Resolvable in Flutter workspaces and for firebase_functions
description: "`firebase_admin_sdk` must keep resolving in pub workspaces that contain a Flutter app and for `firebase_functions`, so Flutter-pinned packages such as `meta` keep low lower bounds and downstream-needed APIs stay public or injectable."
tags: [dependencies, flutter, downstream]
agents_md: always
governs:
  - packages/*/pubspec.yaml
sources:
  - id: admin-meta
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "meta:"
    title: "`firebase_admin_sdk`'s `meta` constraint"
  - id: firestore-meta
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "meta:"
    title: "`google_cloud_firestore`'s `meta` constraint"
  - id: url-key-fetcher
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/jwt.dart
    symbol: class UrlKeyFetcher
    title: "`UrlKeyFetcher`, whose `http.Client` is injectable for downstream tests"
---

# Constraint

`firebase_admin_sdk` is a dependency of `firebase_functions` (firebase/firebase-functions-dart), and both published packages must resolve in a pub workspace that also contains a Flutter (stable) app.

- **Flutter-pinned packages.** The Flutter SDK pins some packages to exact versions: `meta`, `collection` and, through `flutter_localizations`, `intl`. The regular `dependencies` of both packages must not raise their lower bounds above what Flutter stable ships. The `meta` lower bound in both pubspecs is held there for this reason.[^admin-meta][^firestore-meta]
- **Wide ranges.** Version ranges on most `google_cloud_*` dependencies are wide; `google_cloud_protobuf` and `google_cloud_type` use caret constraints.
- **Downstream APIs.** APIs that downstream SDKs need stay public or injectable, for example `UrlKeyFetcher`'s `http.Client`.[^url-key-fetcher]
- **Dev dependencies** aren't affected: consumers don't resolve them.

# Why

- The maintainers' stated reasons: the `meta` constraint was lowered to allow workspaces with stable Flutter, as both packages' CHANGELOGs record, towards making `firebase_functions` usable in Flutter workspaces. Making `UrlKeyFetcher`'s client injectable is a prerequisite for the real token-verification tests in the `firebase_functions` SDK. Credential auto-discovery was fixed for a `firebase_functions` issue, and the `google_cloud` range spans two minor lines at once.
- The likely mechanism (not recorded): the Flutter SDK pins `meta` and friends to exact versions, so a dependency demanding a newer one makes the shared workspace unsolvable.
- The likely use case (not recorded): Dart Cloud Functions or shared model packages living in the same workspace as a Flutter app. Users do share models between Flutter and `google_cloud_firestore`.

# Enforced by

Not enforced; a convention. No CI job resolves the packages together with Flutter.

# Rules for agents

- **Must not:** raise the lower bound of `meta`, `collection` or `intl` (for example with `dart pub upgrade --tighten`) without checking the versions Flutter stable pins, and never above them.
- **Must not:** break APIs that `firebase_functions` uses without coordinating with that SDK.

# Related

- [Dependency constraint style](/dependencies/constraint-style.md)
- [Keep the dependency set small](/dependencies/minimal-dependencies.md)
- [How tokens are verified](/auth/jwt-verification.md)
- [Credential discovery when none is passed](/app/credential-autodiscovery.md)

[^admin-meta]: `meta` in `firebase_admin_sdk`'s pubspec
[^firestore-meta]: `meta` in `google_cloud_firestore`'s pubspec
[^url-key-fetcher]: `UrlKeyFetcher`
