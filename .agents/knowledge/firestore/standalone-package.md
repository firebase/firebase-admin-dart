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
  - id: firestore-credential
    resource: ../../../packages/google_cloud_firestore/lib/src/credential.dart
    symbol: sealed class Credential
    title: Firestore's own sealed `Credential` (service account and Application Default Credentials)
  - id: firestore-settings
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore.dart
    symbol: environmentOverride
    title: Firestore's own `Settings`, including its environment override
  - id: firestore-readme
    resource: ../../../packages/google_cloud_firestore/README.md
    symbol: standalone
    title: The package README on standalone use
  - id: admin-wrapper
    resource: ../../../packages/firebase_admin_sdk/lib/src/firestore/firestore.dart
    symbol: AppErrorCode.invalidCredential
    title: "`app.firestore()`: maps the app's credential and rejects unsupported ones"
  - id: node-firestore
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/firestore/index.ts
    symbol: getFirestore
    title: Node's `firebase-admin/firestore`, which re-exports `@google-cloud/firestore`
---

# Decision

Firestore is its own published package, `google_cloud_firestore`. It can be used without the Admin SDK (`Firestore(settings: ...)`), and it never imports `firebase_admin_sdk`.[^firestore-readme] Everything it needs that the Admin SDK also has is duplicated or passed in through its `Settings`: its own sealed `Credential`, `Settings`, environment lookup and exceptions.[^firestore-credential][^firestore-settings]

`firebase_admin_sdk` wraps it: `app.firestore()` maps the app's credential onto Firestore's `Credential` and throws `app/invalid-credential` for credential types Firestore doesn't accept, such as OAuth refresh tokens.[^admin-wrapper]

This mirrors Node.js, where Firestore is the separate `@google-cloud/firestore` package and `firebase-admin/firestore` builds on it.[^node-firestore] One difference: Node's `firebase-admin/firestore` re-exports every `@google-cloud/firestore` type, while `package:firebase_admin_sdk/firestore.dart` doesn't re-export `google_cloud_firestore`. That barrel exports the admin wrapper class, also named `Firestore`, so code that imports both packages has two `Firestore` classes and needs a prefix or a `show`/`hide`.

# Why

The maintainers' stated reason is to align with the Node.js Admin SDK, where Firestore is maintained separately; `Credential` was duplicated for the same package independence. Why the admin barrel doesn't re-export the Firestore package isn't recorded.

# Rules for agents

- **Must not:** import `firebase_admin_sdk` from `google_cloud_firestore`.
- **Must:** when you add a `Credential` subtype to the admin SDK, update the mapping in `app.firestore()`, which throws for types it doesn't know. Accept the same credentials for Firestore as Node does: a service account or Application Default Credentials.
- **Ask first:** before moving shared code into a dependency the Firestore package would have to take on, instead of duplicating it or passing it in through `Settings`. Sharing `Timestamp` and `GeoPoint` through a common package has been raised and isn't decided.
- **Ask first:** before re-exporting `google_cloud_firestore` from the admin package.

# Related

- [Firestore's generated client](/firestore/generated-client.md)
- [Firestore exceptions](/errors/firestore-exception.md)
- [The sealed `Credential` hierarchy](/app/credential-sealed-hierarchy.md)
- [Multi-database settings](/firestore/multi-database.md)

[^firestore-readme]: The package README on standalone use
[^firestore-credential]: Firestore's own sealed `Credential`
[^firestore-settings]: Firestore's own `Settings`
[^admin-wrapper]: `app.firestore()` credential mapping
[^node-firestore]: Node's `firebase-admin/firestore`
