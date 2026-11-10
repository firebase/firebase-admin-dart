---
type: Decision
title: Firestore retries transient errors like Node
description: A standalone `WriteBatch.commit()` retries Node's commit codes, transactions retry as a whole, and reads retry a dropped connection only before any partial result and outside a transaction, all with `package:retry`.
tags: [firestore, retries, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/write_batch.dart
  - packages/google_cloud_firestore/lib/src/transaction.dart
  - packages/google_cloud_firestore/lib/src/firestore_http_client.dart
  - packages/google_cloud_firestore/lib/src/firestore_exception.dart
  - packages/google_cloud_firestore/lib/src/document_reader.dart
  - packages/google_cloud_firestore/lib/src/reference/**
sources:
  - id: write-batch-tests
    resource: ../../../packages/google_cloud_firestore/test/write_batch_test.dart
    symbol: group('WriteBatch retry'
    title: The commit retry tests
  - id: transaction-read-test
    resource: ../../../packages/google_cloud_firestore/test/transaction_aggregation_test.dart
    symbol: does not retry a read within an active transaction
    title: The test that a read inside a transaction isn't retried
  - id: write-batch-retry
    resource: ../../../packages/google_cloud_firestore/lib/src/write_batch.dart
    symbol: StatusCode.resourceExhaustedAbortedUnavailable
    title: "`WriteBatch.commit()` retry codes, and the transaction branch that skips them"
  - id: resource-exhausted-backoff
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_exception.dart
    symbol: Future<void> backOffHardOnResourceExhausted(
    title: The extra wait on RESOURCE_EXHAUSTED
  - id: read-retry
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_exception.dart
    symbol: Future<T> retryOnConnectionError<T>(
    title: "`retryOnConnectionError` and the conditions in its dartdoc"
  - id: document-reader
    resource: ../../../packages/google_cloud_firestore/lib/src/document_reader.dart
    symbol: StatusCode.batchGetRetryCodes
    title: "`getAll()` retries only after progress, like Node's `document-reader.ts`"
  - id: transaction-runner
    resource: ../../../packages/google_cloud_firestore/lib/src/transaction.dart
    symbol: _runTransaction
    title: The transaction runner, which owns retries inside a transaction
  - id: retry-dependency
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "retry:"
    title: The `package:retry` dependency
  - id: node-retry-codes
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/write-batch.ts
    symbol: retryCodes
    title: Node's commit retry codes
---

# Where it lives

- Enforced by: the `WriteBatch retry` group in `write_batch_test.dart`[^write-batch-tests] and `does not retry a read within an active transaction` in `transaction_aggregation_test.dart`.[^transaction-read-test]
- Commit retry codes, and the transaction branch that skips them: `StatusCode.resourceExhaustedAbortedUnavailable` in `WriteBatch._commit`, `write_batch.dart`.[^write-batch-retry] The extra wait on RESOURCE_EXHAUSTED: `backOffHardOnResourceExhausted` in `firestore_exception.dart`.[^resource-exhausted-backoff]
- When a read may retry: the dartdoc of `retryOnConnectionError` in `firestore_exception.dart`.[^read-retry]
- `getAll()`'s codes and attempts: `StatusCode.batchGetRetryCodes` in `document_reader.dart`.[^document-reader]
- Retries inside a transaction: `_runTransaction` in `transaction.dart`.[^transaction-runner]

# Decision

- **Writes.** A standalone `WriteBatch.commit()` retries Node's commit codes.[^write-batch-retry][^node-retry-codes]
- **Transactions.** A commit inside a transaction isn't retried by the batch. The transaction runner retries the whole transaction.[^transaction-runner]
- **Reads.** Queries, aggregations and pipelines retry a dropped connection, but only before any partial result has arrived and only outside a transaction.[^read-retry] `getAll()` follows Node's `document-reader.ts` instead, retrying only after progress.[^document-reader]

`package:retry` replaced a hand-rolled retry loop.[^retry-dependency]

# Why

- The stated reason, in the contribution the maintainers merged: the commit retry codes follow Node's `write-batch.ts`, and transaction commits are left out because the transaction layer already retries them.
- The maintainers' stated reason for reads: the connection-closed error is a known keep-alive race in `dart:io`'s `HttpClient`, with no client-side fix except retrying.
- The maintainers' stated reason for `package:retry`: it does real exponential backoff.

# Rules for agents

- **Must not:** retry inside an active transaction. `Transaction._runTransaction` owns retries there.
- **Must not:** retry a query, aggregation or pipeline once it has delivered partial results.
- **Must not:** hand-roll backoff loops.

# Related

- [Admin services use generated REST clients](/architecture/generated-rest-clients.md), which records that the admin services have no retry layer
- [Pooled HTTP/2 by default](/architecture/http2-pooled-transport.md)

[^write-batch-tests]: The `WriteBatch retry` tests
[^transaction-read-test]: The transaction read test
[^write-batch-retry]: `WriteBatch.commit()` retry codes
[^resource-exhausted-backoff]: `backOffHardOnResourceExhausted`
[^read-retry]: `retryOnConnectionError`
[^document-reader]: `getAll()` retries in `document_reader.dart`
[^transaction-runner]: The transaction runner
[^retry-dependency]: The `package:retry` dependency
[^node-retry-codes]: Node's commit retry codes
