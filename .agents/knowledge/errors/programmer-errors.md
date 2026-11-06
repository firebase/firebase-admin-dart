---
type: Divergence
title: Firestore misuse throws ArgumentError and StateError
description: In `google_cloud_firestore`, most misuse throws Dart `ArgumentError` or `StateError` where Node throws a plain `Error`, while the admin package throws typed exceptions with `invalid-*` codes.
tags: [errors, firestore, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/**
sources:
  - id: argument-error
    resource: ../../../packages/google_cloud_firestore/lib/src/validate.dart
    symbol: throw ArgumentError.value(
    title: Argument validation throws `ArgumentError`
  - id: state-error
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_http_client.dart
    symbol: throw StateError('FirestoreHttpClient has already been closed.')
    title: A request after `terminate()` throws `StateError`
  - id: geo-point
    resource: ../../../packages/google_cloud_firestore/lib/src/geo_point.dart
    symbol: Value for argument "latitude" is not a valid number
    title: A validation message copied verbatim from Node
  - id: transaction-misuse
    resource: ../../../packages/google_cloud_firestore/lib/src/transaction.dart
    symbol: FirestoreClientErrorCode.failedPrecondition
    title: Transaction misuse throws `FirestoreException`
  - id: node-validate
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/validate.ts
    symbol: invalidArgumentMessage
    title: Node Firestore's validation, which throws a plain `Error`
---

# Node.js

Node Firestore's validation throws a plain `Error`: `throw new Error(invalidArgumentMessage(...))`.[^node-validate]

# Dart

`google_cloud_firestore` throws Dart `Error`s for most misuse, not `Exception`s:

- `ArgumentError` for invalid arguments;[^argument-error]
- `StateError` for invalid state, such as any request after `terminate()`.[^state-error]

Transaction misuse (a read after a write, a write in a read-only transaction) and an invalid `desiredPartitionCount` throw `FirestoreException` instead (`FirestoreClientErrorCode.failedPrecondition` and `.invalidArgument`, codes `failed_precondition` and `invalid_argument`), where Node throws a plain `Error`.[^transaction-misuse]

Validation messages are often Node's text verbatim, such as `Value for argument "latitude" is not a valid number`.[^geo-point] Backend failures are `FirestoreException`s.

The admin package differs: it throws `FirebaseXAdminException` with `invalid-*` codes, mirroring the Node Admin SDK.

# Why

The behaviour is stated in the Firestore CHANGELOG: requests made after `terminate()` throw a `StateError`, an `Error` and not an `Exception`.

The likely reason (not recorded): Effective Dart's convention that an `Error` signals a programmer error.

# Rules for agents

- **Must:** keep each package's convention. In `google_cloud_firestore`, use `ArgumentError`/`StateError` for misuse in new code, and `FirestoreException` for backend failures. In `firebase_admin_sdk`, follow Node's codes.
- **Ask first:** before changing an existing misuse throw from `FirestoreException`. Callers may catch it.

# Related

- [FirestoreException is separate and maps HTTP to gRPC codes](/errors/firestore-exception.md)
- [Typed per-service admin exceptions with Node's error codes](/errors/admin-exceptions.md)

[^node-validate]: Node Firestore's `validate.ts`
[^argument-error]: `ArgumentError` in `validate.dart`
[^state-error]: `StateError` after `terminate()`
[^geo-point]: `GeoPoint` validation message
[^transaction-misuse]: Transaction misuse in `transaction.dart`
