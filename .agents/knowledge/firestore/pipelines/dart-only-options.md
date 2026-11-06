---
type: Divergence
title: Pipeline execution options Node lacks
description: Dart's Pipeline execution adds options and behaviours that Node lacks, each recorded with its reason, and keeps query-level options on `execute()` rather than on the Pipeline.
tags: [firestore, pipelines, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/pipeline.dart
  - packages/google_cloud_firestore/lib/src/transaction.dart
sources:
  - id: known-differences
    resource: ../../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: const _knownDifferences
    title: "`_knownDifferences`: the deliberate signature differences and their reasons"
  - id: transaction-execute
    resource: ../../../../packages/google_cloud_firestore/lib/src/transaction.dart
    symbol: Future<PipelineSnapshot> executePipeline(
    title: "`Transaction.executePipeline`, with the same options as `execute()`"
  - id: execute-read-time
    resource: ../../../../packages/google_cloud_firestore/lib/src/pipeline.dart
    symbol: Timestamp? readTime
    title: "`Pipeline.execute(readTime:)`"
  - id: node-execute
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/pipelines/pipelines.ts
    symbol: execute(
    title: Node's `pipeline.execute()`
---

# Node.js

Node's `pipeline.execute(options)` has no public `readTime`.[^node-execute] `transaction.execute(pipeline)` takes no options and drops explain stats. `findNearest` has no `distanceThreshold`. `PipelineResult` throws on non-document references nested in maps and arrays.

# Dart

Dart goes further than Node in a few places. For example:

- `Pipeline.execute(readTime:)` reads at a past time.[^execute-read-time]
- `Transaction.executePipeline` takes the same options as `Pipeline.execute` and keeps explain stats.[^transaction-execute]

The full list of signature differences, each with its reason, is `_knownDifferences` in `pipeline_api_parity_test.dart`.[^known-differences]

Two behaviours sit outside that table:

- A non-document reference nested in a map or array decodes to its resource-name `String`. "The Node SDK throws for such references instead" (a comment in `pipeline.dart`).
- Query-level options are passed to `execute()`, not built onto the Pipeline, "so a Pipeline value stays a pure description of what to fetch" (the package README).

# Why

The maintainers' stated reasons are recorded with each item: in `_knownDifferences`, in the package README, and in comments in `pipeline.dart` and `pipeline_test.dart`. For example, a test notes that explain stats survive the transaction path, which Node drops.

# Rules for agents

- **Must:** keep these Dart additions, and keep query-level options on `execute()`.

# Related

- [Pipeline API mirrors Node with recorded exceptions](/firestore/pipelines/dart-surface.md)

[^node-execute]: Node's `pipeline.execute()`
[^execute-read-time]: `Pipeline.execute(readTime:)`
[^transaction-execute]: `Transaction.executePipeline`
[^known-differences]: `_knownDifferences`
