---
type: Divergence
title: Public authenticated app client and transport options
description: "`FirebaseApp.client`, `AppOptions.httpClient`, `AppOptions.additionalScopes` and `Credential.createClient` let users call Google APIs the SDK does not wrap, which Node does not offer."
tags: [app, transport, credentials]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/**
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

# Node.js

Node's `AppOptions.httpAgent` takes a Node `http.Agent`. There is no public authenticated client.[^node-http-agent]

# Dart

`FirebaseApp.client` is public, and `AppOptions.httpClient`, `AppOptions.additionalScopes` and `Credential.createClient(scopes)` add transport options. Users can call Google APIs the SDK doesn't wrap while sharing the app's token lifecycle.

The default transport is pooled HTTP/2; see [Pooled HTTP/2 by default](/architecture/http2-pooled-transport.md). Who closes a supplied client is in [Who closes which HTTP client](/app/http-client-ownership.md).

# Why

The stated reason, from the feature request this implements: some wrapped products, such as Storage, have a trimmed-down API that isn't enough for every use case, for example multi-GB uploads or range reads.

The maintainers' stated reason: while `client` was `@internal`, users who needed an authenticated client for `googleapis` APIs the SDK doesn't cover had to silence the warning and use the internal API, or re-implement the credential setup themselves.

# Rules for agents

- **Must:** keep Dart's way: a public authenticated client and these transport options.
- **Must not:** make `client` internal again.

# Related

- [Pooled HTTP/2 by default, HTTP/1.1 for plain-HTTP endpoints](/architecture/http2-pooled-transport.md)
- [Who closes which HTTP client, and lazy client creation](/app/http-client-ownership.md)
- [Storage is a thin wrapper over google_cloud_storage](/storage/google-cloud-storage-wrapper.md)

[^node-http-agent]: Node's `httpAgent`
[^app-client]: The `FirebaseApp.client` dartdoc
[^http-client-option]: `AppOptions.httpClient`
[^additional-scopes]: `AppOptions.additionalScopes`
[^create-client]: `Credential.createClient`
