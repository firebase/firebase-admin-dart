---
type: Divergence
title: No realtime listeners (onSnapshot)
description: Node's Admin SDK supports Firestore realtime listeners through the bidirectional `Listen` RPC, which the generated REST client Dart uses doesn't have, so listeners are a transport limit and a gap, not out of scope.
tags: [firestore, realtime, transport, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/reference/**
  - packages/google_cloud_firestore/lib/src/firestore_http_client.dart
  - packages/google_cloud_firestore/pubspec.yaml
  - packages/firebase_admin_sdk/pubspec.yaml
sources:
  - id: query-todo
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: // TODO onSnapshot
    title: The `onSnapshot` TODO on `Query`
  - id: document-todo
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/document_reference.dart
    symbol: // TODO snapshots
    title: The snapshots TODO on `DocumentReference`
  - id: doc-changes
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query_snapshot.dart
    symbol: late final List<DocumentChange<T>> docChanges
    title: "`QuerySnapshot.docChanges`, filled with `added` changes only"
  - id: query-reader
    resource: ../../../packages/google_cloud_firestore/lib/src/query_reader.dart
    symbol: api.runQuery(request)
    title: "`runQuery` consumed as a `Stream`"
  - id: node-on-snapshot
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/types/firestore.d.ts
    symbol: onSnapshot(
    title: Node's `onSnapshot()` declarations
  - id: admin-node-index
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/firestore/index.ts
    symbol: QuerySnapshot
    title: Node's Admin SDK re-exports `Query` and `QuerySnapshot` from `@google-cloud/firestore`
---

# Node.js

Node's Admin SDK re-exports `@google-cloud/firestore`, so it has realtime listeners.[^admin-node-index] `DocumentReference`, `Query` and `CollectionReference` all have `onSnapshot`.[^node-on-snapshot] Listeners run over the bidirectional gRPC `Listen` RPC, through the `Watch` class.

# Dart

Dart has no `onSnapshot` and no other listener API. `Query` and `DocumentReference` carry `TODO` markers for them.[^query-todo][^document-todo]

- The generated `google_cloud_firestore_v1` client has no `Listen` method and no bidirectional RPC at all. No API Dart ships needs one.
- The server-streaming RPCs (`runQuery`, `batchGetDocuments`, `runAggregationQuery`, `executePipeline`) return a Dart `Stream`,[^query-reader] but the generated client calls them with `enableSse: false`. For a JSON response, `google_cloud_rpc` reads and decodes the whole body before it yields the first element. The response is buffered: nothing streams incrementally. Both behaviours live in dependencies, not in this repository: see the `postStreaming` calls in `google_cloud_firestore_v1` and `ServiceClient` in `google_cloud_rpc`.
- `QuerySnapshot.docChanges` exists, but `get()` fills it with `added` changes only, as Node's `get()` does.[^doc-changes]

Node's `query.stream()`, `explainStream()` and `pipeline.stream()` aren't listeners. They are covered in [Promises become Futures, async iterables become Streams](/conventions/futures-and-streams.md).

# Why

This is a transport limit and a gap, not a choice that admin SDKs don't need listeners.

- The maintainers' stated reason, about an earlier client library: it had no streaming API, and adding one was up to Google. The generated client has the same limit for the bidirectional `Listen` RPC.
- A gRPC transport for `Listen` (`package:grpc`) has been explored as the way to add listeners. It can't ship while `package:grpc` forces an older major of `http2` than the SDK's HTTP/2 pool needs.

# Rules for agents

- **Must not:** publish anything that depends on `grpc` while it forces an older major of `http2` than the SDK's HTTP/2 pool needs ([Pooled HTTP/2 by default](/architecture/http2-pooled-transport.md)).
- **Must not:** document listeners as supported.
- **Ask first:** before emulating listeners by polling or by looping `runQuery`.
- **Must not:** call listeners out of scope.
- **Ask first:** before choosing the listener API's shape, a `snapshots()` `Stream` or a Node-style `onSnapshot` callback. It hasn't been decided; ask a maintainer.

# Related

- [Firestore runs over REST, not gRPC](/firestore/rest-transport.md)
- [Promises become Futures, async iterables become Streams](/conventions/futures-and-streams.md)
- [Firebase services Node has and Dart does not](/scope/unsupported-services.md)
- [Pooled HTTP/2 by default](/architecture/http2-pooled-transport.md)

[^admin-node-index]: Node's Admin SDK re-exports `@google-cloud/firestore`
[^node-on-snapshot]: Node's `onSnapshot()` declarations
[^query-todo]: The `onSnapshot` TODO on `Query`
[^document-todo]: The snapshots TODO on `DocumentReference`
[^query-reader]: `runQuery` consumed as a `Stream`
[^doc-changes]: `QuerySnapshot.docChanges`
