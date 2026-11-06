---
type: Divergence
title: No general retry layer for admin REST calls
description: Node's admin HTTP client retries 503s and connection resets, but `firebase_admin_sdk` has no general retry layer for its REST calls.
tags: [architecture, transport, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/**/*_http_client.dart
sources:
  - id: admin-pubspec
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "googleapis:"
    title: The generated `googleapis` clients the admin services call
  - id: node-retry
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/utils/api-request.ts
    symbol: defaultRetryConfig
    title: Node's default retry policy for admin HTTP calls
---

# Node.js

Node's admin services share a hand-written `HttpClient` with a default retry policy, `defaultRetryConfig`: up to 4 retries on HTTP 503 and on `ECONNRESET` or `ETIMEDOUT`, with exponential backoff capped at 60 seconds.[^node-retry]

# Dart

Admin services call generated `package:googleapis` clients (identitytoolkit, fcm, cloudtasks, firebaseappcheck and firebaserules) through the app's `AuthClient`.[^admin-pubspec] `firebase_admin_sdk` has no general retry layer, so a transient failure reaches the caller.

Firestore is different: `google_cloud_firestore` has its own retries, for `WriteBatch.commit`, `getAll` and connection errors.

# Why

The reason isn't recorded. Ask a maintainer before changing it.

# Rules for agents

- **Ask first:** before adding a retry layer to admin REST calls. Whether they should retry like Node's `defaultRetryConfig` is undecided.

# Related

- [Firestore retries transient errors like Node](/firestore/retries.md)
- [Admin services use generated REST clients from googleapis](/architecture/generated-rest-clients.md)

[^node-retry]: Node's `defaultRetryConfig`
[^admin-pubspec]: The admin package's `googleapis` dependency
