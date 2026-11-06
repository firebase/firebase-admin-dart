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
sources:
  - id: update-request
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
    symbol: class UpdateRequest extends _BaseUpdateRequest
    title: The public `UpdateRequest`
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

# Node.js

In `UpdateRequest`, `displayName`, `photoURL` and `phoneNumber` are `string | null`. `undefined` leaves the field unchanged; `null` deletes it, through `deleteAttribute` for the display name and photo URL and `deleteProvider: ['phone']` for the phone number.[^node-delete-attribute] `setCustomUserClaims(uid, null)` clears the custom claims.

# Dart

The intended semantics are Node's. `_BaseUpdateRequest` provides the three states:

| Caller passes | Field stored | Effect |
| --- | --- | --- |
| nothing | `null` | left unchanged |
| a value | `_Box(value)` | set |
| `null` | `_Box(null)` | cleared |

Its constructor declares these parameters as `Object? displayName = _sentinel` (and the same for `photoURL` and `phoneNumber`).[^base-update-request] `_Box.unwrap` stores a parameter that still holds `_sentinel` as `null`, and any value the caller passed, `null` included, as `_Box(value)`.[^box] The request handler turns a `_Box(null)` into `deleteAttribute` (`PHOTO_URL`, `DISPLAY_NAME`) or `deleteProvider: ['phone']`.[^dart-delete-attribute] `setCustomUserClaims(uid, customUserClaims: null)` clears the claims, as in Node.[^set-custom-user-claims]

**The pitfall.** The public `UpdateRequest` builds on `_BaseUpdateRequest`.[^update-request] An omitted field only reaches the base class as "omitted" if the `_sentinel` default is still reachable from the public constructor. A typed super-parameter such as `String? super.displayName` drops it: Dart doesn't inherit a default whose type (`_Sentinel`) isn't assignable to the declared type, so the parameter defaults to `null`. An omitted field then becomes `_Box(null)` and is sent as a delete. An untyped `super.displayName` keeps the default, and so does a redirecting factory whose target constructor keeps it.

# Why

The maintainers' stated reason is in the doc comment on `_Box`: "An object used to differentiate "no value" from "a null value"", to enable `update(displayName: null)`.[^box]

# Rules for agents

- **Must:** match Node's semantics: an omitted field is left unchanged, and `null` clears it.
- **Must:** keep the sentinel and `_Box` mechanism.
- **Must:** keep the `_sentinel` default reachable for every clearable field on every public constructor. Don't declare these parameters as typed super-parameters (`String? super.displayName`), which drop the default and turn an omitted field into a clear.
- **Must:** test that an omitted field sends no delete: no `deleteAttribute` entry and no `deleteProvider: ['phone']` for a field the caller didn't pass.
- **Must not:** simplify these fields to plain nullable fields.
- **Ask first:** before changing how the public `UpdateRequest` constructor exposes the three states. Its shape is an API decision for the maintainers.

# Related

- [Auth records encode JSON like Node's toJSON()](/auth/user-record-tojson.md)

[^node-delete-attribute]: Node's `deleteAttribute` and `deleteProvider` handling
[^base-update-request]: `_BaseUpdateRequest` and its `_sentinel` defaults
[^box]: `_Box` and its doc comment
[^dart-delete-attribute]: `deleteAttribute` and `deleteProvider` in the request handler
[^set-custom-user-claims]: `setCustomUserClaims`
[^update-request]: The public `UpdateRequest`
