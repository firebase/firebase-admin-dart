---
type: Decision
title: "App HTTP client: public access, ownership and lazy creation"
description: "`FirebaseApp.client`, `AppOptions.httpClient`, `AppOptions.additionalScopes` and `Credential.createClient` let users call Google APIs the SDK does not wrap, which Node does not offer; `FirebaseApp` closes only the client it created, a service must close only clients it built (Auth and Functions also close a user-supplied client under their emulators), and authenticated clients are created on first use."
tags: [app, transport, credentials, lifecycle]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/**
  - packages/firebase_admin_sdk/lib/src/*/*_http_client.dart
  - packages/firebase_admin_sdk/lib/src/storage/storage.dart
  - packages/firebase_admin_sdk/lib/src/firestore/firestore.dart
  - packages/google_cloud_firestore/lib/src/firestore_http_client.dart
sources:
  - id: app-client
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: "**Lifecycle:** The client is closed automatically"
    title: The `FirebaseApp.client` dartdoc (scopes, lifecycle, the `googleapis` use case)
  - id: http-client-option
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/app_options.dart
    symbol: final googleapis_auth.AuthClient? httpClient;
    title: "`AppOptions.httpClient`"
  - id: additional-scopes
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/app_options.dart
    symbol: final List<String> additionalScopes;
    title: "`AppOptions.additionalScopes`"
  - id: create-client
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/credential.dart
    symbol: Future<googleapis_auth.AuthClient> createClient(
    title: "`Credential.createClient`"
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
  - id: node-http-agent
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/app/core.ts
    symbol: "httpAgent?: Agent"
    title: Node's `AppOptions.httpAgent`
---

# Where it lives

- Enforced by: nothing; review only.
- The public client, its default scopes, its lifecycle and the `googleapis` use case: the dartdoc of `FirebaseApp.client` in `firebase_app.dart`.[^app-client]
- The transport options: `AppOptions.httpClient` and `AppOptions.additionalScopes` in `app_options.dart`.[^http-client-option][^additional-scopes]
- A client for any scopes: `Credential.createClient` in `credential.dart`.[^create-client]
- What `FirebaseApp.close()` closes, and that a second call throws `app/app-deleted` as in Node: the `close()` dartdoc and `_checkDestroyed` in `firebase_app.dart`.[^app-close]
- Lazy, idempotent service clients: the `_delegate` getter and `delete()` in `storage.dart`, and `FirestoreHttpClient.close` in `firestore_http_client.dart`.[^storage-lazy][^storage-delete][^firestore-close]
- The emulator path that reaches a user-supplied client: `AuthHttpClient._createClient`, `Auth.delete` and `Functions.delete`.[^auth-create-client][^auth-delete][^functions-delete]

# Decision

## A public authenticated client (divergence from Node)

`FirebaseApp.client` is public, and `AppOptions.httpClient`, `AppOptions.additionalScopes` and `Credential.createClient(scopes)` add transport options. Through `FirebaseApp.client`, users can call Google APIs the SDK doesn't wrap while sharing the app's token lifecycle.

The default transport is pooled HTTP/2; see [Pooled HTTP/2 by default](/architecture/http2-pooled-transport.md).

## Ownership and lazy creation

`FirebaseApp` owns the default client it creates. A service's `delete()` is meant to close only clients that service built (emulator clients), and to be idempotent; Auth and Functions break the first half (see the trap below). Authenticated clients are created on first use, never in constructors.

**Trap: Auth and Functions close a user-supplied client under their emulators.**

- `AuthHttpClient._createClient()` and `FunctionsHttpClient._createClient()` return `app.client` whenever `app.options.httpClient` is set, even under an emulator.
- `Auth.delete()` closes its request handler's client whenever `FIREBASE_AUTH_EMULATOR_HOST` is set, and `Functions.delete()` whenever `CLOUD_TASKS_EMULATOR_HOST` is set. Both decide from the variable alone.
- So with a user-supplied client and one of those variables set, `app.close()` closes the user's client if the app has an Auth or Functions instance. `delete()` creates the client first if no request has, so a request isn't needed.

# Node.js

Node's `AppOptions.httpAgent` takes a Node `http.Agent`. There is no public authenticated client.[^node-http-agent]

# Why

Public client:

- The stated reason, from the feature request this implements: some wrapped products, such as Storage, have a trimmed-down API that isn't enough for every use case, for example multi-GB uploads or range reads.
- The maintainers' stated reason: while `client` was `@internal`, users who needed an authenticated client for `googleapis` APIs the SDK doesn't cover had to silence the warning and use the internal API, or re-implement the credential setup themselves.

Ownership and lazy creation, the maintainers' stated reasons:

- `FirebaseApp` promises in its dartdoc that a user-provided `options.httpClient` is not closed automatically. A change that made `Storage.delete()` close `app.client` was blocked for that reason.
- Building a client eagerly starts a credential lookup; the Storage delegate's dartdoc gives the example.
- Closing an unused Firestore must not resolve credentials: without credentials, closing the app failed.
- A double close is a bug; the idempotency guards prevent it.

Eager construction is the rejected alternative: when ADC was missing, it raised unhandled async errors with no user frames in the stack.

# Rules for agents

- **Must:** keep Dart's way: a public authenticated client and these transport options.
- **Must not:** make `client` internal again.
- **Must:** keep each service's `delete()` and `FirestoreHttpClient.close()` idempotent. `FirebaseApp.close()` deliberately throws `app/app-deleted` on a second call, as Node does.
- **Must not:** close `app.client` or a user-supplied `AppOptions.httpClient` from a service.
- **Must:** in a new or changed `delete()`, close a client only when the service built it, not on the emulator variable alone. `Auth.delete()` and `Functions.delete()` decide from the variable, which is how they reach a user-supplied client.
- **Must not:** start credential lookups in constructors or in `close()`.

# Related

- [Pooled HTTP/2 by default, HTTP/1.1 for plain-HTTP endpoints](/architecture/http2-pooled-transport.md)
- [Storage is a thin wrapper over google_cloud_storage](/storage/google-cloud-storage-wrapper.md)
- [Emulators found only through standard environment variables](/environment/emulator-detection.md)

[^node-http-agent]: Node's `httpAgent`
[^app-client]: The `FirebaseApp.client` dartdoc
[^http-client-option]: `AppOptions.httpClient`
[^additional-scopes]: `AppOptions.additionalScopes`
[^create-client]: `Credential.createClient`
[^app-close]: The `FirebaseApp.close()` dartdoc
[^storage-lazy]: Storage's lazy `_delegate`
[^storage-delete]: `Storage.delete()`
[^firestore-close]: `FirestoreHttpClient.close()`
[^auth-create-client]: `AuthHttpClient._createClient()`
[^auth-delete]: `Auth.delete()`
[^functions-delete]: `Functions.delete()`
