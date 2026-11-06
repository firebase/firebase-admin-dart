---
type: Divergence
title: Pipeline APIs Node has that Dart lacks
description: Some Node Pipeline APIs, including `pipeline.stream()`, have no Dart implementation; each one in the pinned Node release is a pending entry in the parity tables, which fail when an entry goes stale.
tags: [firestore, pipelines, gaps, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/pipeline.dart
  - packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
  - packages/google_cloud_firestore/test/pipeline_golden_test.dart
sources:
  - id: pending-fixes
    resource: ../../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: const _pendingFixes
    title: "`_pendingFixes`: Node members and options Dart lacks, among other pending differences"
  - id: dart-api-gaps
    resource: ../../../../packages/google_cloud_firestore/test/pipeline_golden_test.dart
    symbol: const _dartApiGaps
    title: "`_dartApiGaps`: golden cases Dart can't express"
  - id: node-stream
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/pipelines/pipelines.ts
    symbol: "stream(): NodeJS.ReadableStream"
    title: Node's `pipeline.stream()`
---

# Node.js

Node's Pipelines include APIs Dart doesn't have, such as `subcollection()`, the `define`, `delete` and `update` stages, and `pipeline.stream()`, which returns a Node `Readable`.[^node-stream]

# Dart

Dart has none of these. Each API missing relative to the pinned Node release (`_nodeVersion` in `pipeline_api_parity_test.dart`) is an entry in a parity table:

- `_pendingFixes` in `pipeline_api_parity_test.dart`, for missing members and options;[^pending-fixes]
- `_dartApiGaps` in `pipeline_golden_test.dart`, for golden cases Dart can't express.[^dart-api-gaps]

Both tests fail when an entry goes stale, so implementing an API forces its entry out. APIs added in later Node releases, such as the `insert` and `upsert` stages, appear only when the pin is bumped.

`pipeline.stream()` is a gap. The `executePipeline` RPC under `execute()` returns a `Stream`, but its response is buffered: the generated client requests it with `enableSse: false`, and the whole JSON array is read before the first result is yielded. A `stream()` built on it would not be incremental; an incremental port needs SSE or gRPC.

# Why

The maintainers' stated reason is in the tables: these are Node APIs Dart doesn't implement. They are gaps, not deliberate omissions.

For `pipeline.stream()`, the likely shape (not recorded, and not decided by a maintainer): a Dart `Stream`, like other Node async sequences ported to Dart.

# Rules for agents

- **Must:** match Node. Implement to Node's signature and wire format, then delete the table entry; the test fails while it is stale.
- **Ask first:** before porting `pipeline.stream()`. An incremental port needs SSE or gRPC; see [Promises become Futures, async iterables become Streams](/conventions/futures-and-streams.md).
- **Must not:** present the buffered `executePipeline` response as an incremental stream, as that concept also says.

# Related

- [Pipelines parity with Node is checked by machine](/firestore/pipelines/node-parity.md)
- [Promises become Futures, async iterables become Streams](/conventions/futures-and-streams.md)

[^node-stream]: Node's `pipeline.stream()`
[^pending-fixes]: `_pendingFixes`
[^dart-api-gaps]: `_dartApiGaps`
