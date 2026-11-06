---
type: Divergence
title: No public Credential.getAccessToken()
description: Node's public `Credential.getAccessToken()` has no Dart equivalent; the closest is `Credential.createClient(scopes)`.
tags: [app, credentials, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/credential.dart
sources:
  - id: create-client
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/credential.dart
    symbol: Future<googleapis_auth.AuthClient> createClient(
    title: "`Credential.createClient`, the closest Dart equivalent"
  - id: node-get-access-token
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/app/credential.ts
    symbol: getAccessToken
    title: Node's public `Credential.getAccessToken()`
---

# Node.js

`Credential.getAccessToken(): Promise<GoogleOAuthAccessToken>` is public.[^node-get-access-token]

# Dart

`Credential` has no `getAccessToken()`. The closest is `createClient(scopes)`, which returns an authenticated client.[^create-client]

A `getAccessToken()` was added once and removed before any release, when the local `googleapis_auth_utils` package was dropped. The removal gives no reason.

# Why

The reason isn't recorded. Ask a maintainer before changing it.

# Rules for agents

- **Ask first:** before adding a public `getAccessToken()`, for Node parity or otherwise. Whether dropping it was deliberate isn't recorded.

# Related

- [Credential is a sealed class with factories](/app/credential-sealed-hierarchy.md)
- [Generic Google-auth features live upstream, not in this repo](/architecture/upstream-generic-auth-features.md)

[^node-get-access-token]: Node's `getAccessToken`
[^create-client]: `Credential.createClient`
