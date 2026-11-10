---
type: Constraint
title: Resolvable in Flutter workspaces and for firebase_functions
description: "`firebase_admin_sdk` must keep resolving for `firebase_functions` and, with `google_cloud_firestore`, in pub workspaces that contain a stable Flutter app, so Flutter-pinned packages such as `meta` keep low lower bounds."
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
---

# Where it lives

- Enforced by: nothing; review only. No CI job resolves the packages together with Flutter.
- The `meta` lower bound held at what Flutter stable pins: `meta:` in `packages/firebase_admin_sdk/pubspec.yaml`[^admin-meta] and `packages/google_cloud_firestore/pubspec.yaml`.[^firestore-meta]

# Constraint

`firebase_admin_sdk` is a dependency of `firebase_functions` (firebase/firebase-functions-dart), and both published packages must resolve in a pub workspace that also contains a stable Flutter app.

- The Flutter SDK pins some packages to exact versions: `meta`, `collection` and, through `flutter_localizations`, `intl`. The regular `dependencies` of both packages must not raise their lower bounds above what Flutter stable ships. The `meta` lower bound was lowered for this reason.
- APIs that downstream SDKs need stay public or injectable, for example `UrlKeyFetcher`'s client (see [How tokens are verified](/auth/jwt-verification.md)).
- Dev dependencies aren't affected: consumers don't resolve them.

# Why

- The maintainers' stated reason, recorded in both packages' CHANGELOGs: the `meta` constraint was lowered to allow workspaces with stable Flutter. The likely reason (not recorded) it matters here: `firebase_functions` depends on the admin package, so it must resolve in those workspaces too.
- The likely mechanism (not recorded): the Flutter SDK pins `meta` and friends to exact versions, so a dependency demanding a newer one makes the shared workspace unsolvable.
- The likely use case (not recorded): Dart Cloud Functions or shared model packages living in the same workspace as a Flutter app. Users do share models between Flutter and `google_cloud_firestore`.

# Rules for agents

- **Must not:** raise the lower bound of `meta`, `collection` or `intl` (for example with `dart pub upgrade --tighten`) without checking the versions Flutter stable pins, and never above them.
- **Must not:** break APIs that `firebase_functions` uses without coordinating with that SDK.

# Related

- [Dependency constraint style](/dependencies/constraint-style.md)
- [Keep the dependency set small](/dependencies/minimal-dependencies.md)
- [Verifying ID tokens, session cookies and App Check tokens](/auth/jwt-verification.md)
- [Credential discovery when none is passed](/app/credential-autodiscovery.md)

[^admin-meta]: `meta` in `firebase_admin_sdk`'s pubspec
[^firestore-meta]: `meta` in `google_cloud_firestore`'s pubspec
