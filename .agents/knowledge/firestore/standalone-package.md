---
type: Decision
title: Firestore is a standalone package
description: Firestore ships as `google_cloud_firestore`, which works without the Admin SDK and never imports it; `firebase_admin_sdk` wraps it through `app.firestore()`.
tags: [firestore, packaging, credentials]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/**
  - packages/firebase_admin_sdk/lib/src/firestore/**
  - packages/firebase_admin_sdk/lib/firestore.dart
sources:
  - id: firestore-readme
    resource: ../../../packages/google_cloud_firestore/README.md
    symbol: standalone
    title: The package README on standalone use
  - id: firestore-credential
    resource: ../../../packages/google_cloud_firestore/lib/src/credential.dart
    symbol: sealed class Credential
    title: Firestore's own sealed `Credential`
  - id: firestore-settings
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore.dart
    symbol: environmentOverride
    title: Firestore's own `Settings`, including its environment override
  - id: admin-wrapper
    resource: ../../../packages/firebase_admin_sdk/lib/src/firestore/firestore.dart
    symbol: AppErrorCode.invalidCredential
    title: "`app.firestore()`: maps the app's credential and rejects unsupported ones"
  - id: admin-barrel
    resource: ../../../packages/firebase_admin_sdk/lib/firestore.dart
    symbol: export 'src/firestore/firestore.dart';
    title: The admin Firestore barrel, which exports only the wrapper
  - id: node-firestore
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/firestore/index.ts
    symbol: getFirestore
    title: Node's `firebase-admin/firestore`, which re-exports a fixed list of `@google-cloud/firestore`'s names
---

# Where it lives

- Enforced by: nothing; review only.
- Standalone use: the package README.[^firestore-readme]
- What Firestore keeps its own copy of: `sealed class Credential` in `credential.dart`[^firestore-credential] and `Settings` (with `environmentOverride`) in `firestore.dart`.[^firestore-settings]
- How the admin SDK hands over its credential, and which credentials it rejects: `_buildSettings` and its `AppErrorCode.invalidCredential` throw, in the admin `lib/src/firestore/firestore.dart`.[^admin-wrapper]
- What the admin barrel exports: `lib/firestore.dart` in `firebase_admin_sdk`.[^admin-barrel]

# Decision

Firestore is its own published package, `google_cloud_firestore`. It can be used without the Admin SDK, and it never imports `firebase_admin_sdk`.[^firestore-readme] Anything it needs that the Admin SDK also has is duplicated or passed in through its `Settings`.[^firestore-credential][^firestore-settings] `firebase_admin_sdk` wraps it through `app.firestore()`.[^admin-wrapper]

# Node.js

Firestore is the separate `@google-cloud/firestore` package, and `firebase-admin/firestore` builds on it, as here.[^node-firestore] One difference is a trap: Node's `firebase-admin/firestore` re-exports most of `@google-cloud/firestore`'s public names, while `package:firebase_admin_sdk/firestore.dart` doesn't re-export `google_cloud_firestore`. It exports the admin wrapper class, also named `Firestore`, so code that imports both packages has two `Firestore` classes and needs a prefix or a `show` or `hide`.[^admin-barrel]

# Why

The maintainers' stated reason is to align with the Node.js Admin SDK, where Firestore is maintained separately; `Credential` was duplicated for the same package independence. Why the admin barrel doesn't re-export the Firestore package isn't recorded.

# Rules for agents

- **Must not:** import `firebase_admin_sdk` from `google_cloud_firestore`.
- **Ask first:** before moving shared code into a dependency the Firestore package would have to take on, instead of duplicating it or passing it in through `Settings`. Sharing value types with FlutterFire is in [Firestore follows Node, with a few FlutterFire look-alikes](/firestore/node-not-flutterfire.md).
- **Ask first:** before re-exporting `google_cloud_firestore` from the admin package.

# Related

- [Credential: sealed class, factories and discovery](/app/credentials.md), which owns the rule to update `app.firestore()`'s mapping when the admin SDK gains a `Credential` subtype
- [Firestore runs over REST, with buffered streaming](/firestore/rest-transport.md)
- [Firestore errors](/errors/firestore-exception.md)
- [One cached Firestore per database, settings fixed](/firestore/multi-database.md)

[^firestore-readme]: The package README on standalone use
[^firestore-credential]: Firestore's own sealed `Credential`
[^firestore-settings]: Firestore's own `Settings`
[^admin-wrapper]: `app.firestore()` credential mapping
[^admin-barrel]: The admin Firestore barrel
[^node-firestore]: Node's `firebase-admin/firestore`
