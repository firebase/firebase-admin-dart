---
type: Decision
title: One cached Firestore per database, settings fixed
description: The admin `app.firestore()` caches one `Firestore` per database ID; asking for it again with settings that differ in a field `_areSettingsEqual` compares throws, and other setting changes are silently ignored.
tags: [firestore, multi-database, app]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/firestore/**
sources:
  - id: settings-tests
    resource: ../../../packages/firebase_admin_sdk/test/unit/firestore/firestore_test.dart
    symbol: group('settings comparison'
    title: The unit tests for the re-initialization check
  - id: per-db-cache
    resource: ../../../packages/firebase_admin_sdk/lib/src/firestore/firestore.dart
    symbol: has already been called with different settings for database
    title: The per-database cache and its re-initialization error
  - id: settings-compare
    resource: ../../../packages/firebase_admin_sdk/lib/src/firestore/firestore.dart
    symbol: bool _areSettingsEqual(
    title: "`_areSettingsEqual`, which decides which settings a later call may change"
  - id: node-failed-precondition
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/firestore/firestore-internal.ts
    symbol: failed-precondition
    title: Node's `failed-precondition` on re-initialization
---

# Where it lives

- Enforced by: the `settings comparison` group in `test/unit/firestore/firestore_test.dart`.[^settings-tests]
- The cache and its `app/failed-precondition` error: `initializeDatabase` in `lib/src/firestore/firestore.dart`.[^per-db-cache]
- The fields a later call is compared on: `_areSettingsEqual` in the same file.[^settings-compare]

# Decision

`app.firestore(databaseId:, settings:)` keeps one `Firestore` per database ID, built with the settings of the call that created it.[^per-db-cache] A later call for the same database never changes those settings. Without `settings` it returns the cached instance; with `settings` it throws if `_areSettingsEqual` finds a difference.[^settings-compare]

Traps:

- A difference only in a field `_areSettingsEqual` doesn't compare is silently ignored, and the cached instance is returned.
- `credential` is compared by identity, because Firestore's `Credential` doesn't override `==`. Two credentials built separately from the same values count as different.
- If the first call passed no settings, any later call with settings throws, because the stored settings are `null`.
- `Settings.==` exists, but the check doesn't use it.

# Node.js

Node also throws on re-initialization.[^node-failed-precondition] Two things differ: Node's error is `firestore/failed-precondition`, where Dart's carries the `app/` prefix; and Node's check compares only `preferRest`.

# Why

The maintainers' stated reason: an app can use several databases, as in the Node.js Admin SDK, and re-initializing a database with different settings is prevented.

Why `_areSettingsEqual` compares only the fields it does isn't recorded. Ask a maintainer before changing it.

# Rules for agents

- **Must not:** silently replace the settings of a cached database.
- **Must not:** rely on a second `app.firestore()` call to apply a setting that `_areSettingsEqual` doesn't compare. Pass every setting on the first call for that database.
- **Ask first:** before changing which fields `_areSettingsEqual` compares, including for a new `Settings` field, or switching it to `Settings.==`. Comparing more fields turns calls that return the cached instance into errors.

# Related

- [Firestore is a standalone package](/firestore/standalone-package.md)

[^settings-tests]: The `settings comparison` tests
[^per-db-cache]: The per-database cache and its error
[^settings-compare]: `_areSettingsEqual`
[^node-failed-precondition]: Node's `failed-precondition` on re-initialization
