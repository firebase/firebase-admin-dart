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
    symbol: Future<void> close() async
    title: "`FirebaseApp.close()` and which client it closes"
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

# Decision

- `FirebaseApp` owns the default client it creates and closes it in `close()`. `FirebaseApp.close()` itself never closes a client the user passes in `AppOptions.httpClient`.[^app-close]
- A service's `delete()` is meant to close only clients that service created (emulator clients), and is idempotent. In production, Storage's delegate holds `app.client`, whose lifecycle belongs to the app.[^storage-delete]
- Auth and Functions close a user-supplied client in one path:
  - `AuthHttpClient._createClient()` and `FunctionsHttpClient._createClient()` return `app.client` whenever `app.options.httpClient` is set, even under an emulator.[^auth-create-client]
  - `Auth.delete()` closes its request handler's client whenever `FIREBASE_AUTH_EMULATOR_HOST` is set, and `Functions.delete()` whenever `CLOUD_TASKS_EMULATOR_HOST` is set.[^auth-delete][^functions-delete] Both decide from the variable alone.
  - So with a user-supplied client and one of those variables set, `app.close()` closes the user's client if the app has an Auth or Functions instance. `delete()` creates the client first if no request has, so a request isn't needed.
- `FirestoreHttpClient.close()` is idempotent, and closing a Firestore that never created its client does no credential lookup.[^firestore-close]
- `FirebaseApp.close()` throws `app/app-deleted` on a second call, as Node does.
- Authenticated clients are created on first use, never in constructors.

# Why

The maintainers' stated reasons:

- `FirebaseApp` promises in its dartdoc that a user-provided `options.httpClient` is not closed automatically. A change that made `Storage.delete()` close `app.client` was blocked for that reason.
- `gcs.Storage` starts resolving credentials as soon as it is built, so building it eagerly "would make `app.storage()` alone perform an auth handshake" (code comment in `storage.dart`).[^storage-delete]
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

[^app-close]: `FirebaseApp.close()`
[^storage-delete]: `Storage.delete()` and the lazy delegate
[^firestore-close]: `FirestoreHttpClient.close()`
[^auth-create-client]: `AuthHttpClient._createClient()`
[^auth-delete]: `Auth.delete()`
[^functions-delete]: `Functions.delete()`
