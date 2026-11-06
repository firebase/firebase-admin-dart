---
type: Divergence
title: FirestoreException is separate and maps HTTP to gRPC codes
description: "`google_cloud_firestore` throws its own `FirestoreException`, not a `FirebaseAdminException`, and maps REST and HTTP statuses onto gRPC-style codes."
tags: [errors, firestore, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/firestore_exception.dart
  - packages/google_cloud_firestore/lib/src/status_code.dart
sources:
  - id: firestore-exception
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_exception.dart
    symbol: class FirestoreException implements Exception
    title: "`FirestoreException`, outside the admin hierarchy"
  - id: handle-exception
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_exception.dart
    symbol: Never handleFirestoreException(
    title: The mapping from REST and HTTP errors to gRPC-style codes
  - id: code-strings
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_exception.dart
    symbol: "code: 'deadline_exceeded'"
    title: "`FirestoreClientErrorCode` code strings, in mixed styles"
  - id: status-code
    resource: ../../../packages/google_cloud_firestore/lib/src/status_code.dart
    symbol: enum StatusCode
    title: The gRPC status codes
  - id: node-status-code
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/status-code.ts
    symbol: StatusCode
    title: Node Firestore's internal copy of the gRPC status codes
---

# Node.js

Node Firestore's server errors are google-gax `GoogleError`s with a numeric gRPC `code`, taken from an internal copy of the status codes.[^node-status-code]

# Dart

`google_cloud_firestore` throws `FirestoreException implements Exception`, which is not a `FirebaseAdminException`.[^firestore-exception] It carries:

- `errorCode`, a `FirestoreClientErrorCode`, where each value maps to a `StatusCode` with its gRPC number;[^status-code]
- `code`, a string;
- `message`.

The transport is REST, so `handleFirestoreException` maps `ServiceException.status` or the HTTP status onto gRPC-style codes: 400 and 409 by the message text, then 412, 429, 499 and others by status.[^handle-exception]

The code strings mix styles. `already-exists` and `data-loss` are kebab-case, while `deadline_exceeded`, `failed_precondition`, `invalid_argument`, `not_found`, `out_of_range`, `permission_denied` and `resource_exhausted` use underscores.[^code-strings] Whether that is intended, and which form is canonical, is undecided; ask a maintainer.

# Why

The likely reason (not recorded) for staying out of the admin hierarchy: `google_cloud_firestore` stands alone and never imports the admin package.

The likely reason (not recorded) for the HTTP-to-gRPC mapping: over REST, errors arrive as HTTP statuses.

# Rules for agents

- **Must:** keep Dart's way.
- **Must not:** make `FirestoreException` extend `FirebaseAdminException`. That would make `google_cloud_firestore` depend on the admin package.

# Related

- [Typed per-service admin exceptions with Node's error codes](/errors/admin-exceptions.md)
- [Firestore is a standalone package](/firestore/standalone-package.md)
- [Firestore uses the generated google_cloud_firestore_v1 client](/firestore/generated-client.md)
- [Firestore runs over REST, not gRPC](/firestore/rest-transport.md)

[^node-status-code]: Node Firestore's `status-code.ts`
[^firestore-exception]: `FirestoreException`
[^status-code]: `StatusCode`
[^handle-exception]: `handleFirestoreException`
[^code-strings]: `FirestoreClientErrorCode` code strings
