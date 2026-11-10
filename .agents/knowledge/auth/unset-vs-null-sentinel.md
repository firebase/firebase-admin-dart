---
type: Divergence
title: Unset versus null in Auth updates (sentinel and _Box)
description: "`_BaseUpdateRequest` encodes Node's three states for `displayName`, `photoURL` and `phoneNumber` with a `_sentinel` default and `_Box` (omitted leaves a field unchanged, a value sets it, `null` clears it), so every public constructor must keep that default reachable."
tags: [auth, node-parity, api-design]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
  - packages/firebase_admin_sdk/lib/src/auth/auth_request_handler.dart
  - packages/firebase_admin_sdk/lib/src/auth/base_auth.dart
  - packages/firebase_admin_sdk/test/unit/auth/update_request_test.dart
sources:
  - id: update-request-test
    resource: ../../../packages/firebase_admin_sdk/test/unit/auth/update_request_test.dart
    symbol: UpdateRequest(disabled: true) deletes nothing
    title: The tests that an omitted field sends no delete
  - id: update-request-factory
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
    symbol: factory UpdateRequest({
    title: The public `UpdateRequest`, a redirecting factory, and the comment that explains why
  - id: base-update-request
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
    symbol: Object? displayName = _sentinel
    title: "`_BaseUpdateRequest`, whose parameters default to `_sentinel`"
  - id: box
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
    symbol: class _Box<T>
    title: "`_Box`, which tells \"no value\" from \"a null value\""
  - id: box-rewrap
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
    symbol: static Object? rewrap(
    title: "`_Box.rewrap`, which passes a box back to a constructor"
  - id: dart-delete-attribute
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_request_handler.dart
    symbol: deleteAttribute
    title: Emits `deleteAttribute` and `deleteProvider` for cleared fields
  - id: set-custom-user-claims
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/base_auth.dart
    symbol: Future<void> setCustomUserClaims(
    title: "`setCustomUserClaims`, where `null` clears the claims"
  - id: node-delete-attribute
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/auth-api-request.ts
    symbol: deleteAttribute
    title: Node's `deleteAttribute` and `deleteProvider` handling
---

# Where it lives

- Enforced by: `update_request_test.dart`, which checks that an omitted field sends no `deleteAttribute` or `deleteProvider`.[^update-request-test]
- The three states and how they are stored: `_BaseUpdateRequest`, whose parameters default to `_sentinel`, and the `_Box` dartdoc, in `auth_config.dart`.[^base-update-request][^box]
- Why the public constructor is a redirecting factory: the comment on `factory UpdateRequest` in `auth_config.dart`.[^update-request-factory]
- Passing a box back to a constructor (`copyWith`): `_Box.rewrap` in `auth_config.dart`.[^box-rewrap]
- How a cleared field is sent: `deleteAttribute` and `deleteProvider` in `auth_request_handler.dart`.[^dart-delete-attribute]

# Node.js

In `UpdateRequest`, `displayName`, `photoURL` and `phoneNumber` are `string | null`. `undefined` leaves the field unchanged; `null` deletes it, through `deleteAttribute` for the display name and photo URL and `deleteProvider: ['phone']` for the phone number.[^node-delete-attribute] `setCustomUserClaims(uid, null)` clears the custom claims.

# Dart

The semantics are Node's, encoded with a `_sentinel` default and `_Box`. `setCustomUserClaims(uid, customUserClaims: null)` clears the claims, as in Node.[^set-custom-user-claims]

**The pitfall.** An omitted field reaches `_BaseUpdateRequest` as "omitted" only if the `_sentinel` default is reachable from the public constructor. A typed super-parameter such as `String? super.displayName` drops it: Dart doesn't inherit a default whose type (`_Sentinel`) isn't assignable to the declared type, so the parameter defaults to `null`, and an omitted field becomes `_Box(null)` and is sent as a delete. That is why the public `UpdateRequest` is a redirecting factory with typed `String?` parameters: it redirects to a constructor that keeps the default.[^update-request-factory]

# Why

The maintainers' stated reason is in the doc comment on `_Box`: "An object used to differentiate "no value" from "a null value"", to enable `update(displayName: null)`.[^box]

# Rules for agents

- **Must:** match Node's semantics: an omitted field is left unchanged, and `null` clears it.
- **Must:** keep the sentinel and `_Box` mechanism.
- **Must:** keep the `_sentinel` default reachable for every clearable field on every public constructor. Don't declare these parameters as typed super-parameters (`String? super.displayName`), which drop the default and turn an omitted field into a clear.
- **Must:** extend `update_request_test.dart` when you add a clearable field or a constructor.
- **Must not:** simplify these fields to plain nullable fields.
- **Ask first:** before changing how the public `UpdateRequest` constructor exposes the three states. It's an API decision for the maintainers.

# Related

- [URL casing; JSON keys stay Node's](/conventions/acronym-casing.md)

[^update-request-test]: `update_request_test.dart`
[^node-delete-attribute]: Node's `deleteAttribute` and `deleteProvider` handling
[^base-update-request]: `_BaseUpdateRequest` and its `_sentinel` defaults
[^box]: `_Box` and its doc comment
[^box-rewrap]: `_Box.rewrap`
[^dart-delete-attribute]: `deleteAttribute` and `deleteProvider` in the request handler
[^set-custom-user-claims]: `setCustomUserClaims`
[^update-request-factory]: The redirecting `UpdateRequest` factory and its comment
