---
type: Decision
title: Auth records encode JSON like Node's toJSON()
description: Auth records expose a public `toJson()` that encodes like Node's `toJSON()`.
tags: [auth, json, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/auth/user.dart
  - packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
sources:
  - id: dart-to-json
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/user.dart
    symbol: Map<String, Object?> toJson()
    title: The `toJson()` methods of `UserRecord` and its parts
  - id: dart-format-date
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/user.dart
    symbol: String? _formatDate(DateTime? dateTime)
    title: Dates are encoded as strings
  - id: node-to-json
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/user-record.ts
    symbol: "public toJSON(): object"
    title: Node's `UserRecord.toJSON()`
---

# Decision

Auth records, such as `UserRecord`, `UserInfo`, `UserMetadata` and the multi-factor types, expose a public `toJson()` that encodes like Node's `toJSON()`.[^dart-to-json][^node-to-json] The keys are Node's (for example `photoURL`, even where the Dart field is `photoUrl`), and dates are encoded as strings, never as `DateTime` objects.[^dart-format-date] Config classes expose `toJson()` too.

# Why

The maintainers' stated reasons: to expose public JSON methods for `UserRecord` and the config classes, and to encode JSON consistently with the Node version.

`jsonEncode` can't encode a `DateTime`. An earlier `toJson()` emitted `DateTime` values and failed for that reason, which is why dates must be strings.

# Rules for agents

- **Must:** follow Node's encoding: the same keys and value formats as Node's `toJSON()`.
- **Must not:** emit `DateTime` objects from `toJson()`.

# Related

- [Mixed acronym casing (URL vs Url)](/conventions/acronym-casing.md)
- [Timestamp shape and its Node JSON keys](/firestore/timestamp.md)

[^dart-to-json]: The `toJson()` methods in `user.dart`
[^node-to-json]: Node's `UserRecord.toJSON()`
[^dart-format-date]: `_formatDate`
