---
type: Divergence
title: URL casing; JSON keys stay Node's
description: Most public members keep Node's `URL` casing but `photoUrl` uses Dart casing, and every `toJson()` encodes like Node's `toJSON()`, with Node's keys and dates as strings.
tags: [conventions, naming, json, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/auth/user.dart
  - packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
  - packages/firebase_admin_sdk/lib/src/app/app_options.dart
sources:
  - id: user-photo-url
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/user.dart
    symbol: "'photoURL': ?photoUrl"
    title: "`photoUrl` fields encoded under Node's `photoURL` key"
  - id: dart-format-date
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/user.dart
    symbol: String? _formatDate(DateTime? dateTime)
    title: Dates are encoded as strings
  - id: request-photo-url
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
    symbol: photoURL
    title: The request and SAML config members that keep Node's `URL` casing
  - id: node-photo-url
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/user-record.ts
    symbol: photoURL
    title: Node's `photoURL`
  - id: node-to-json
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/user-record.ts
    symbol: "public toJSON(): object"
    title: Node's `UserRecord.toJSON()`
---

# Where it lives

- Enforced by: nothing; review only.
- Which members use `URL` and which `Url`: grep the public API, for example `auth_config.dart` and `user.dart`.[^request-photo-url][^user-photo-url]
- Node's keys in `toJson()`: the `toJson()` methods in `user.dart`, such as `'photoURL': ?photoUrl`.[^user-photo-url]
- Dates as strings: `_formatDate` in `user.dart`.[^dart-format-date]

# Node.js

Node mostly uses `URL` casing, such as `photoURL`,[^node-photo-url] `databaseURL` and `getDownloadURL`, but `imageUrl` in messaging. `UserRecord.toJSON()` and its parts define the JSON encoding.[^node-to-json]

# Dart

- **Casing is mixed.** Most public members keep Node's `URL`, but `UserRecord.photoUrl` and `UserInfo.photoUrl` use Dart casing.
- **JSON stays Node's.** Auth records and config classes have a public `toJson()` that encodes like Node's `toJSON()`: Node's keys, so `photoURL` even where the field is `photoUrl`, and dates as strings, never `DateTime` objects.

# Why

The maintainers' stated reasons for `toJson()`: to expose public JSON methods for `UserRecord` and the config classes, and to encode JSON consistently with the Node version. `jsonEncode` can't encode a `DateTime`; an earlier `toJson()` emitted `DateTime` values and failed for that reason.

Why `photoUrl` differs isn't recorded. Which casing new public members should use, Node's `URL` or Effective Dart's `Url`, is an open question for the maintainers.

# Rules for agents

- **Ask first:** before choosing the acronym casing of a new public member, or changing an existing one.
- **Must:** keep JSON keys and value formats as Node's `toJSON()` has them.
- **Must not:** emit `DateTime` objects from `toJson()`.
- **Must not:** rename existing public members to satisfy a lint. It's a breaking change.

# Related

- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md)
- [Timestamp shape and its Node JSON keys](/firestore/timestamp.md)

[^node-photo-url]: Node's `UserRecord.photoURL`
[^node-to-json]: Node's `UserRecord.toJSON()`
[^request-photo-url]: `photoURL`, `ssoURL` and `callbackURL` in `auth_config.dart`
[^user-photo-url]: `toJson()` in `user.dart`
[^dart-format-date]: `_formatDate`
