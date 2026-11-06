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
    symbol: Future<googleapis_auth.AuthClient> get client
    title: The public `FirebaseApp.client`
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

# Node.js

Node's `AppOptions.httpAgent` takes a Node `http.Agent`. There is no public authenticated client.[^node-http-agent]

# Dart

Dart offers an authenticated client and more transport options:

- `FirebaseApp.client` is public. It is a `Future<AuthClient>`: the SDK's own authenticated client.[^app-client]
- `AppOptions.httpClient` takes a `googleapis_auth` `AuthClient`. The caller owns its lifecycle, except that `Auth` and `Functions` close it when their emulator variable is set; see [Who closes which HTTP client](/app/http-client-ownership.md).[^http-client-option]
- `AppOptions.additionalScopes` adds OAuth scopes to the default client.[^additional-scopes]
- `Credential.createClient(scopes)` builds an authenticated client for any scopes.[^create-client]

With these, users can call Google APIs the SDK doesn't wrap while sharing the app's token lifecycle. The default transport is pooled HTTP/2 with an HTTP/1.1 fallback.

# Why

The stated reason, from the feature request this implements: some wrapped products, such as Storage, have a trimmed-down API that isn't enough for every use case, for example multi-GB uploads or range reads.

The maintainers' stated reason: while `client` was `@internal`, users who needed an authenticated client for `googleapis` APIs the SDK doesn't cover had to silence the warning and use the internal API, or re-implement the credential setup themselves. The HTTP/2 pooling is stated in the package CHANGELOG.

# Rules for agents

- **Must:** keep Dart's way: a public authenticated client and these transport options.
- **Must not:** make `client` internal again.
- **Must not:** close a user-supplied `AppOptions.httpClient`.

# Related

- [Pooled HTTP/2 by default, HTTP/1.1 for plain-HTTP endpoints](/architecture/http2-pooled-transport.md)
- [Who closes which HTTP client, and lazy client creation](/app/http-client-ownership.md)
- [Storage is a thin wrapper over google_cloud_storage](/storage/google-cloud-storage-wrapper.md)
- [Conveniences Dart adds on top of Node](/scope/dart-only-conveniences.md)

[^node-http-agent]: Node's `httpAgent`
[^app-client]: `FirebaseApp.client`
[^http-client-option]: `AppOptions.httpClient`
[^additional-scopes]: `AppOptions.additionalScopes`
[^create-client]: `Credential.createClient`
