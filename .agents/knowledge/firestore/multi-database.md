---
type: Decision
title: One cached Firestore per database, settings fixed
description: The admin `app.firestore()` caches one `Firestore` per database ID; asking for it again with settings whose project, database, host, SSL flag or credential differ throws, and other setting changes are silently ignored.
tags: [firestore, multi-database, app]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/firestore/**
sources:
  - id: per-db-cache
    resource: ../../../packages/firebase_admin_sdk/lib/src/firestore/firestore.dart
    symbol: has already been called with different settings for database
    title: The per-database cache and its re-initialization error
  - id: settings-compare
    resource: ../../../packages/firebase_admin_sdk/lib/src/firestore/firestore.dart
    symbol: bool _areSettingsEqual(
    title: "`_areSettingsEqual`, which compares five settings fields"
  - id: settings-equality
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore.dart
    symbol: "bool operator ==(Object other) =>"
    title: "`Settings.==`, which the cache check doesn't use"
  - id: node-failed-precondition
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/firestore/firestore-internal.ts
    symbol: failed-precondition
    title: Node's `failed-precondition` on re-initialization
---

# Decision

`app.firestore(databaseId:, settings:)` keeps one `Firestore` per database ID, built with the settings of the call that created it.[^per-db-cache] A later call for the same database never changes those settings:

- Without `settings`, it returns the cached instance.
- With `settings`, it compares them with the first call's settings through `_areSettingsEqual`, which checks only `projectId`, `databaseId`, `host`, `ssl` and `credential`.[^settings-compare] If any of these differ, it throws a `FirebaseAppException` with `app/failed-precondition`.
- If only `useBigInt`, `headers`, `environmentOverride` or `ignoreUndefinedProperties` differ, it returns the cached instance and silently ignores the new values.
- `credential` is compared by identity, because `Credential` doesn't override `==`. Two credentials built separately from the same values count as different.
- If the first call passed no settings, any later call with settings throws, because the stored settings are `null`.

`Settings.==` compares every field except `environmentOverride`, but `_areSettingsEqual` doesn't use it.[^settings-equality]

Throwing on re-initialization matches Node.[^node-failed-precondition] Two things differ: Node's error is `firestore/failed-precondition`, Dart's carries the `app/` prefix; and Node's check compares only `preferRest`.

# Why

The maintainers' stated reason: an app can use several databases, as in the Node.js Admin SDK, and re-initializing a database with different settings is prevented.

Why `_areSettingsEqual` compares only those five fields isn't recorded. Ask a maintainer before changing it.

# Rules for agents

- **Must not:** silently replace the settings of a cached database.
- **Must not:** rely on a second `app.firestore()` call to apply `useBigInt`, `headers`, `environmentOverride` or `ignoreUndefinedProperties`. Pass them on the first call for that database.
- **Ask first:** before changing which fields `_areSettingsEqual` compares, including for a new `Settings` field, or switching it to `Settings.==`. Comparing more fields turns calls that return the cached instance into errors.

# Related

- [Firestore is a standalone package](/firestore/standalone-package.md)

[^per-db-cache]: The per-database cache and its error
[^settings-compare]: `_areSettingsEqual`
[^settings-equality]: `Settings.==`
[^node-failed-precondition]: Node's `failed-precondition` on re-initialization
