---
type: Decision
title: Who closes which HTTP client, and lazy client creation
description: "`FirebaseApp` closes only the client it created, a service must close only clients it built (Auth and Functions also close a user-supplied client under their emulators), and authenticated clients are created on first use."
tags: [app, transport, lifecycle]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
  - packages/firebase_admin_sdk/lib/src/app/credential.dart
  - packages/firebase_admin_sdk/lib/src/*/*_http_client.dart
  - packages/firebase_admin_sdk/lib/src/storage/storage.dart
  - packages/firebase_admin_sdk/lib/src/firestore/firestore.dart
  - packages/google_cloud_firestore/lib/src/firestore_http_client.dart
sources:
  - id: app-close
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: be closed automatically. You are responsible
    title: The `FirebaseApp.close()` dartdoc, which never closes a user-supplied client
  - id: storage-lazy
    resource: ../../../packages/firebase_admin_sdk/lib/src/storage/storage.dart
    symbol: perform an auth handshake
    title: Storage builds its `google_cloud_storage` delegate on first use, and why
  - id: storage-delete
    resource: ../../../packages/firebase_admin_sdk/lib/src/storage/storage.dart
    symbol: if (_isDeleted) return;
    title: "`Storage.delete()`, idempotent and closing only its emulator client"
  - id: firestore-close
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_http_client.dart
    symbol: _closeFuture ??= _close()
    title: "`FirestoreHttpClient.close()`, idempotent"
  - id: auth-create-client
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_http_client.dart
    symbol: if (app.options.httpClient != null) {
    title: "`AuthHttpClient._createClient()` returns `app.client` whenever the user supplied one"
  - id: auth-delete
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth.dart
    symbol: final client = await _authRequestHandler.httpClient.client;
    title: "`Auth.delete()` closes its client whenever the Auth emulator variable is set"
  - id: functions-delete
    resource: ../../../packages/firebase_admin_sdk/lib/src/functions/functions.dart
    symbol: final client = await _requestHandler.httpClient.client;
    title: "`Functions.delete()` closes its client whenever the Cloud Tasks emulator variable is set"
---

# Where it lives

- Enforced by: nothing; review only.
- What `FirebaseApp.close()` closes, and that a second call throws `app/app-deleted` as in Node: the `close()` dartdoc and `_checkDestroyed` in `firebase_app.dart`.[^app-close]
- Lazy, idempotent service clients: the `_delegate` getter and `delete()` in `storage.dart`, and `FirestoreHttpClient.close` in `firestore_http_client.dart`.[^storage-lazy][^storage-delete][^firestore-close]
- The emulator path that reaches a user-supplied client: `AuthHttpClient._createClient`, `Auth.delete` and `Functions.delete`.[^auth-create-client][^auth-delete][^functions-delete]

# Decision

`FirebaseApp` owns the default client it creates. A service's `delete()` is meant to close only clients that service built (emulator clients), and to be idempotent; Auth and Functions break the first half (see the trap below). Authenticated clients are created on first use, never in constructors.

**Trap: Auth and Functions close a user-supplied client under their emulators.**

- `AuthHttpClient._createClient()` and `FunctionsHttpClient._createClient()` return `app.client` whenever `app.options.httpClient` is set, even under an emulator.
- `Auth.delete()` closes its request handler's client whenever `FIREBASE_AUTH_EMULATOR_HOST` is set, and `Functions.delete()` whenever `CLOUD_TASKS_EMULATOR_HOST` is set. Both decide from the variable alone.
- So with a user-supplied client and one of those variables set, `app.close()` closes the user's client if the app has an Auth or Functions instance. `delete()` creates the client first if no request has, so a request isn't needed.

# Why

The maintainers' stated reasons:

- `FirebaseApp` promises in its dartdoc that a user-provided `options.httpClient` is not closed automatically. A change that made `Storage.delete()` close `app.client` was blocked for that reason.
- Building a client eagerly starts a credential lookup; the Storage delegate's dartdoc gives the example.
- Closing an unused Firestore must not resolve credentials: without credentials, closing the app failed.
- A double close is a bug; the idempotency guards prevent it.

Eager construction is the rejected alternative: when ADC was missing, it raised unhandled async errors with no user frames in the stack.

# Rules for agents

- **Must:** keep each service's `delete()` and `FirestoreHttpClient.close()` idempotent. `FirebaseApp.close()` deliberately throws `app/app-deleted` on a second call, as Node does.
- **Must not:** close `app.client` or a user-supplied `AppOptions.httpClient` from a service.
- **Must:** in a new or changed `delete()`, close a client only when the service built it, not on the emulator variable alone. `Auth.delete()` and `Functions.delete()` decide from the variable, which is how they reach a user-supplied client.
- **Must not:** start credential lookups in constructors or in `close()`.

# Related

- [Public authenticated app client and transport options](/app/app-client-and-transport-options.md)
- [Storage is a thin wrapper over google_cloud_storage](/storage/google-cloud-storage-wrapper.md)
- [Emulators found only through standard environment variables](/environment/emulator-detection.md)

[^app-close]: The `FirebaseApp.close()` dartdoc
[^storage-lazy]: Storage's lazy `_delegate`
[^storage-delete]: `Storage.delete()`
[^firestore-close]: `FirestoreHttpClient.close()`
[^auth-create-client]: `AuthHttpClient._createClient()`
[^auth-delete]: `Auth.delete()`
[^functions-delete]: `Functions.delete()`
