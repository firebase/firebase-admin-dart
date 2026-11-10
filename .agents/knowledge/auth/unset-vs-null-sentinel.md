---
type: Divergence
title: Unset versus null in Auth updates (sentinel and _Box)
description: "`_BaseUpdateRequest` encodes Node's three states for `displayName`, `photoURL` and `phoneNumber` with a `_sentinel` default and `_Box` (omitted leaves a field unchanged, a value sets it, `null` clears it), so every public constructor must make that default reachable."
tags: [auth, node-parity, api-design]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
  - packages/firebase_admin_sdk/lib/src/auth/auth_request_handler.dart
  - packages/firebase_admin_sdk/lib/src/auth/base_auth.dart
sources:
  - id: update-request
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
    symbol: class UpdateRequest extends _BaseUpdateRequest
    title: The public `UpdateRequest`
  - id: update-request-typed
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
    symbol: String? super.displayName
    title: The public `UpdateRequest` constructor's typed super-parameters
  - id: base-update-request
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
    symbol: Object? displayName = _sentinel
    title: "`_BaseUpdateRequest`, whose parameters default to `_sentinel`"
  - id: box
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
    symbol: class _Box<T>
    title: "`_Box`, which tells \"no value\" from \"a null value\""
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

- Enforced by: nothing; review only. No test checks that an omitted field sends no delete.
- The three states and how they are stored: `_BaseUpdateRequest`, whose parameters default to `_sentinel`, and the `_Box` dartdoc, in `auth_config.dart`.[^base-update-request][^box]
- The public constructor whose typed super-parameters drop the default: `UpdateRequest` in `auth_config.dart`.[^update-request][^update-request-typed]
- How a cleared field is sent: `deleteAttribute` and `deleteProvider` in `auth_request_handler.dart`.[^dart-delete-attribute]

# Node.js

In `UpdateRequest`, `displayName`, `photoURL` and `phoneNumber` are `string | null`. `undefined` leaves the field unchanged; `null` deletes it, through `deleteAttribute` for the display name and photo URL and `deleteProvider: ['phone']` for the phone number.[^node-delete-attribute] `setCustomUserClaims(uid, null)` clears the custom claims.

# Dart

The intended semantics are Node's, encoded with a `_sentinel` default and `_Box`. `setCustomUserClaims(uid, customUserClaims: null)` clears the claims, as in Node.[^set-custom-user-claims]

**The pitfall.** An omitted field only reaches `_BaseUpdateRequest` as "omitted" if the `_sentinel` default is still reachable from the public constructor. A typed super-parameter such as `String? super.displayName` drops it: Dart doesn't inherit a default whose type (`_Sentinel`) isn't assignable to the declared type, so the parameter defaults to `null`. An omitted field then becomes `_Box(null)` and is sent as a delete. An untyped `super.displayName` keeps the default, and so does a redirecting factory whose target constructor keeps it. The public `UpdateRequest` constructor declares `String? super.displayName`, `String? super.phoneNumber` and `String? super.photoURL`, so through it an omitted field is sent as a delete.

# Why

The maintainers' stated reason is in the doc comment on `_Box`: "An object used to differentiate "no value" from "a null value"", to enable `update(displayName: null)`.[^box]

# Rules for agents

- **Must:** match Node's semantics: an omitted field is left unchanged, and `null` clears it.
- **Must:** keep the sentinel and `_Box` mechanism.
- **Must:** make the `_sentinel` default reachable for every clearable field on every public constructor. Don't declare these parameters as typed super-parameters (`String? super.displayName`), which drop the default and turn an omitted field into a clear.
- **Must:** test that an omitted field sends no delete: no `deleteAttribute` entry and no `deleteProvider: ['phone']` for a field the caller didn't pass.
- **Must not:** simplify these fields to plain nullable fields.
- **Ask first:** about the shape of the public `UpdateRequest` constructor when you fix or change it. The outcome above is required; how the constructor exposes the three states is an API decision for the maintainers.

# Related

- [URL casing; JSON keys stay Node's](/conventions/acronym-casing.md)

[^node-delete-attribute]: Node's `deleteAttribute` and `deleteProvider` handling
[^base-update-request]: `_BaseUpdateRequest` and its `_sentinel` defaults
[^box]: `_Box` and its doc comment
[^dart-delete-attribute]: `deleteAttribute` and `deleteProvider` in the request handler
[^set-custom-user-claims]: `setCustomUserClaims`
[^update-request]: The public `UpdateRequest`
[^update-request-typed]: The public `UpdateRequest` constructor
