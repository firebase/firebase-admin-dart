---
type: Divergence
title: "Firestore errors: FirestoreException, and Errors for misuse"
description: "`google_cloud_firestore` throws its own `FirestoreException`, not a `FirebaseAdminException`, mapping HTTP statuses onto gRPC-style codes, and throws `ArgumentError` or `StateError` for most misuse where Node throws a plain `Error`."
tags: [errors, firestore, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/firestore_exception.dart
  - packages/google_cloud_firestore/lib/src/status_code.dart
  - packages/google_cloud_firestore/lib/src/**
sources:
  - id: firestore-exception
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_exception.dart
    symbol: class FirestoreException implements Exception
    title: "`FirestoreException` and `FirestoreClientErrorCode`, outside the admin hierarchy"
  - id: handle-exception
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_exception.dart
    symbol: Never handleFirestoreException(
    title: The mapping from REST and HTTP errors to gRPC-style codes
  - id: code-strings
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_exception.dart
    symbol: "code: 'deadline_exceeded'"
    title: "`FirestoreClientErrorCode` code strings, in mixed styles"
  - id: argument-error
    resource: ../../../packages/google_cloud_firestore/lib/src/validate.dart
    symbol: throw ArgumentError.value(
    title: Argument validation throws `ArgumentError`
  - id: state-error
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_http_client.dart
    symbol: throw StateError('FirestoreHttpClient has already been closed.')
    title: A request after `terminate()` throws `StateError`
  - id: transaction-misuse
    resource: ../../../packages/google_cloud_firestore/lib/src/transaction.dart
    symbol: FirestoreClientErrorCode.failedPrecondition
    title: Transaction misuse throws `FirestoreException`
  - id: node-status-code
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/status-code.ts
    symbol: StatusCode
    title: Node Firestore's internal copy of the gRPC status codes
  - id: node-validate
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/validate.ts
    symbol: invalidArgumentMessage
    title: Node Firestore's validation, which throws a plain `Error`
---

# Where it lives

- Enforced by: nothing; review only.
- The exception, its fields and its error codes: `FirestoreException` and `FirestoreClientErrorCode` in `firestore_exception.dart`.[^firestore-exception]
- How REST and HTTP errors become gRPC-style codes: `handleFirestoreException` in the same file.[^handle-exception]
- Misuse: `ArgumentError` in `validate.dart`, `StateError` after `terminate()` in `firestore_http_client.dart`, and `FirestoreException` for transaction misuse in `transaction.dart`.[^argument-error][^state-error][^transaction-misuse]

# Node.js

Node Firestore's server errors are google-gax `GoogleError`s, with the numeric gRPC `code` that google-gax sets. Node Firestore keeps its own copy of the status codes, in `status-code.ts`, to compare those codes against.[^node-status-code]

Node Firestore's validation throws a plain `Error`: `throw new Error(invalidArgumentMessage(...))`.[^node-validate]

# Dart

`google_cloud_firestore` throws `FirestoreException`, which is not a `FirebaseAdminException`. The transport is REST, so it maps HTTP statuses onto gRPC-style codes.

The code strings mix styles: `already-exists` and `data-loss` are kebab-case, while most others, such as `deadline_exceeded`, use underscores.[^code-strings] Whether that is intended, and which form is canonical, is undecided; ask a maintainer.

**Misuse throws a Dart `Error`, not an `Exception`:** `ArgumentError` for invalid arguments and `StateError` for invalid state. Two cases throw `FirestoreException` instead, where Node throws a plain `Error`: transaction misuse (a read after a write, a write in a read-only transaction) and an invalid `desiredPartitionCount`. Validation messages are often Node's text verbatim.

The admin package differs: it throws its typed exceptions with `invalid-*` codes, mirroring the Node Admin SDK.

# Why

The likely reason (not recorded) for staying out of the admin hierarchy: `google_cloud_firestore` stands alone and never imports the admin package.

The likely reason (not recorded) for the HTTP-to-gRPC mapping: over REST, errors arrive as HTTP statuses.

The Firestore CHANGELOG states that requests made after `terminate()` throw a `StateError`, an `Error` and not an `Exception`. The likely reason (not recorded) for `Error`s on misuse: Effective Dart's convention that an `Error` signals a programmer error.

# Rules for agents

- **Must not:** make `FirestoreException` extend `FirebaseAdminException`. That would make `google_cloud_firestore` depend on the admin package.
- **Must:** keep each package's convention. In `google_cloud_firestore`, use `ArgumentError`/`StateError` for misuse in new code, and `FirestoreException` for backend failures. In `firebase_admin_sdk`, follow Node's codes.
- **Ask first:** before changing an existing misuse throw from `FirestoreException`. Callers may catch it.

# Related

- [Typed per-service admin exceptions with Node's error codes](/errors/admin-exceptions.md)
- [Firestore is a standalone package](/firestore/standalone-package.md)
- [Firestore runs over REST, with buffered streaming](/firestore/rest-transport.md)

[^node-status-code]: Node Firestore's `status-code.ts`
[^node-validate]: Node Firestore's `validate.ts`
[^firestore-exception]: `FirestoreException`
[^handle-exception]: `handleFirestoreException`
[^code-strings]: `FirestoreClientErrorCode` code strings
[^argument-error]: `ArgumentError` in `validate.dart`
[^state-error]: `StateError` after `terminate()`
[^transaction-misuse]: Transaction misuse in `transaction.dart`
