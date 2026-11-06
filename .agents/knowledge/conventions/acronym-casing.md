---
type: Divergence
title: Mixed acronym casing (URL vs Url)
description: Most public members keep Node's `URL` casing, but `UserRecord.photoUrl` and `UserInfo.photoUrl` use Dart casing while their JSON keys stay Node's.
tags: [conventions, naming, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/auth/user.dart
  - packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
  - packages/firebase_admin_sdk/lib/src/app/app_options.dart
sources:
  - id: user-photo-url
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/user.dart
    symbol: final String? photoUrl;
    title: "`UserRecord.photoUrl` and `UserInfo.photoUrl`, with `photoURL` JSON keys"
  - id: request-photo-url
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
    symbol: photoURL
    title: "`CreateRequest` and `UpdateRequest.photoURL`, `ssoURL` and `callbackURL`"
  - id: database-url
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/app_options.dart
    symbol: final String? databaseURL;
    title: "`AppOptions.databaseURL`"
  - id: node-photo-url
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/user-record.ts
    symbol: photoURL
    title: Node's `photoURL`
---

# Node.js

Node uses `photoURL`,[^node-photo-url] `databaseURL`, `ssoURL`, `callbackURL` and `getDownloadURL`, but `imageUrl` in messaging.

# Dart

Dart is mixed:

- It keeps Node's casing in `AppOptions.databaseURL`,[^database-url] `CreateRequest.photoURL` and `UpdateRequest.photoURL`, `UserImportRecord.photoURL`, the SAML and OIDC `ssoURL` and `callbackURL`,[^request-photo-url] and `Storage.getDownloadURL`.
- `UserRecord.photoUrl` and `UserInfo.photoUrl` use Dart casing, while their `toJson()` still emits the key `photoURL`, to encode JSON like Node.[^user-photo-url]

# Why

The reason isn't recorded. Ask a maintainer before changing it. Which casing new public members should use, Node's `URL` or Effective Dart's `Url`, is an open question for the maintainers.

# Rules for agents

- **Ask first:** before choosing the acronym casing of a new public member, or changing an existing one.
- **Must:** keep JSON keys as Node's.
- **Must not:** rename existing public members to satisfy a lint. It's a breaking change.

# Related

- [Auth records encode JSON like Node's toJSON()](/auth/user-record-tojson.md)
- [Dart core-library names replace Node member names](/conventions/dart-member-names.md)

[^node-photo-url]: Node's `UserRecord.photoURL`
[^database-url]: `AppOptions.databaseURL`
[^request-photo-url]: `photoURL`, `ssoURL` and `callbackURL` in `auth_config.dart`
[^user-photo-url]: `photoUrl` in `user.dart`
