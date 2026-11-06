---
type: Decision
title: Firestore retries transient errors like Node
description: A standalone `WriteBatch.commit()` retries ABORTED, UNAVAILABLE and RESOURCE_EXHAUSTED as Node does, and reads retry connection-closed errors only before any partial result and outside a transaction.
tags: [firestore, retries, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/write_batch.dart
  - packages/google_cloud_firestore/lib/src/transaction.dart
  - packages/google_cloud_firestore/lib/src/firestore_http_client.dart
  - packages/google_cloud_firestore/lib/src/reference/**
sources:
  - id: write-batch-retry
    resource: ../../../packages/google_cloud_firestore/lib/src/write_batch.dart
    symbol: StatusCode.resourceExhaustedAbortedUnavailable
    title: "`WriteBatch.commit()` retry codes and `RetryOptions`"
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

# Decision

- **Writes.** A standalone `WriteBatch.commit()` retries Node's commit codes, ABORTED, UNAVAILABLE and RESOURCE_EXHAUSTED, with `package:retry`.[^write-batch-retry][^node-retry-codes][^retry-dependency] On RESOURCE_EXHAUSTED it also waits the maximum backoff delay before the next attempt.
- **Transactions.** A commit inside a transaction isn't retried by the batch. The transaction runner retries the whole transaction.[^transaction-runner]
- **Reads.** Queries, aggregations and pipelines retry `http.ClientException` connection-closed errors with `package:retry`, but only before any partial result has arrived and only outside a transaction. `getAll()` retries a bounded number of times.

`package:retry` replaced a hand-rolled retry loop.

# Why

The maintainers' stated reasons:

- The commit retry codes follow Node's `write-batch.ts`. Transaction commits are left out because the transaction layer already retries them.
- The connection-closed error is a known keep-alive race in `dart:io`'s `HttpClient`, with no client-side fix except retrying.
- `package:retry` is used because it does real exponential backoff.

# Rules for agents

- **Must not:** retry inside an active transaction. `Transaction._runTransaction` owns retries there.
- **Must not:** retry a read once it has delivered partial results.
- **Must not:** hand-roll backoff loops.

# Related

- [No general retry layer for admin REST calls](/architecture/admin-http-retries.md)
- [Pooled HTTP/2 by default](/architecture/http2-pooled-transport.md)

[^write-batch-retry]: `WriteBatch.commit()` retry
[^node-retry-codes]: Node's commit retry codes
[^retry-dependency]: The `package:retry` dependency
[^transaction-runner]: The transaction runner
