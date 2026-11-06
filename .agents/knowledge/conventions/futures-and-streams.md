---
type: Divergence
title: Promises become Futures, async iterables become Streams
description: Node Promises become `Future`s and AsyncIterables become `Stream`s; Node's `Readable`-based APIs (`query.stream()`, `explainStream()`, `pipeline.stream()`) are not ported, and an incremental port needs a transport that streams (SSE or gRPC), because the server-streaming responses are buffered.
tags: [conventions, async, firestore]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/reference/query.dart
  - packages/google_cloud_firestore/lib/src/pipeline.dart
sources:
  - id: get-partitions
    resource: ../../../packages/google_cloud_firestore/lib/src/collection_group.dart
    symbol: Stream<QueryPartition<T>> getPartitions
    title: "`getPartitions` returns a `Stream`"
  - id: list-documents-pages
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/collection_reference.dart
    symbol: listDocumentsPages({
    title: "`listDocumentsPages` returns a `Stream`"
  - id: node-get-partitions
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/collection-group.ts
    symbol: getPartitions
    title: Node's `async *getPartitions`
  - id: parity-pipeline-stream
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: "'Pipeline.stream'"
    title: "`Pipeline.stream` listed as missing in the parity table"
---

# Node.js

Node uses Promises; `AsyncIterable`s, such as `async *getPartitions`;[^node-get-partitions] Node `Readable` streams (`query.stream()`, `explainStream()`, `pipeline.stream()`); `.on('data')` events; and BulkWriter callbacks.

# Dart

- A Promise becomes a `Future`.
- An async sequence becomes a `Stream`: `getPartitions` returns a `Stream<QueryPartition>`,[^get-partitions] and `listDocumentsPages` a `Stream<DocumentReferencePage>`.[^list-documents-pages]
- BulkWriter callbacks are kept.
- Dartdoc ported from Node is written in Dart terms: "[Future]" instead of "promise", and `[name]` instead of `@param`.

None of Node's `Readable`-based APIs are ported. This is a gap: `query.stream()` has a `// TODO stream` in `query.dart`, and `Pipeline.stream` is listed as missing in the parity table.[^parity-pipeline-stream]

The server-streaming RPCs behind them are exposed as `Stream`s, but the generated client buffers the response (`enableSse: false`), so they don't stream incrementally (see [no realtime listeners](/firestore/no-realtime-listeners.md)). A `Readable` equivalent that streams incrementally needs server-sent events (`alt=sse`, `enableSse: true`) or another transport, such as gRPC. Whether Firestore's REST endpoint accepts SSE for these RPCs is unverified.

# Why

- Dart terms in docs: the stated reason is a cleanup of doc comments to use Dart terms, for example "Returns a [Future] that completes with" instead of "Returns a promise that resolves with".
- `Stream` for `AsyncIterable`: the likely reason (not recorded) is that it is Dart's equivalent.
- `Readable` APIs as `Stream`s: inferred from the existing `AsyncIterable` to `Stream` mapping; no maintainer has decided it.

# Rules for agents

- **Must:** keep Dart's way. Map `AsyncIterable` to `Stream` and Promise to `Future`, and write docs in Dart terms.
- **Should:** port Node's `Readable` APIs as Dart `Stream`s. This is inferred; no maintainer has decided it.
- **Ask first:** before porting `query.stream()`, `explainStream()` or `pipeline.stream()`. An incremental port needs SSE (unverified for Firestore REST) or gRPC.
- **Must not:** port Node `Readable` APIs as callbacks.
- **Must not:** present a buffered `runQuery` or `executePipeline` result as an incremental stream.

# Related

- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md)
- [No realtime listeners](/firestore/no-realtime-listeners.md)
- [Pipeline APIs Node has that Dart lacks](/firestore/pipelines/missing-node-apis.md)

[^node-get-partitions]: Node's `getPartitions`
[^get-partitions]: `CollectionGroup.getPartitions`
[^list-documents-pages]: `CollectionReference.listDocumentsPages`
[^parity-pipeline-stream]: `Pipeline.stream` in the parity table
