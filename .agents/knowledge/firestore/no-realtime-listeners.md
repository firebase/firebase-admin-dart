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
  - id: http2-constraint
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "http2:"
    title: The `http2` major the HTTP/2 pool needs
  - id: node-on-snapshot
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/types/firestore.d.ts
    symbol: onSnapshot(
    title: Node's `onSnapshot()` declarations
  - id: admin-node-index
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/firestore/index.ts
    symbol: QuerySnapshot
    title: Node's Admin SDK re-exports `Query` and `QuerySnapshot` from `@google-cloud/firestore`
---

# Where it lives

- Enforced by: nothing; review only.
- The missing listener APIs: `// TODO onSnapshot` in `query.dart`[^query-todo] and `// TODO snapshots` in `document_reference.dart`.[^document-todo]
- The `http2` major that rules out `package:grpc`: `http2:` in each package's `pubspec.yaml`.[^http2-constraint]

# Node.js

Node's Admin SDK re-exports `@google-cloud/firestore`, so it has realtime listeners.[^admin-node-index] `DocumentReference`, `Query` and `CollectionReference` all have `onSnapshot`.[^node-on-snapshot] Listeners run over the bidirectional gRPC `Listen` RPC, through the `Watch` class.

# Dart

Dart has no `onSnapshot` and no other listener API. The generated `google_cloud_firestore_v1` client has no `Listen` method and no bidirectional RPC at all, and no API Dart ships needs one. Server-streaming RPCs exist but are buffered; [Firestore runs over REST](/firestore/rest-transport.md) owns that, and Node's `query.stream()`-style APIs, which aren't listeners.

# Why

This is a transport limit and a gap, not a choice that admin SDKs don't need listeners.

- The maintainers' stated reason, about an earlier client library: it had no streaming API, and adding one was up to Google. The generated client has the same limit for the bidirectional `Listen` RPC.
- A gRPC transport for `Listen` (`package:grpc`) has been explored as the way to add listeners. It can't ship while `package:grpc` forces an older major of `http2` than the SDK's HTTP/2 pool needs.[^http2-constraint]

# Rules for agents

- **Must not:** publish anything that depends on `grpc` while it forces an older major of `http2` than the SDK's HTTP/2 pool needs ([Pooled HTTP/2 by default](/architecture/http2-pooled-transport.md)).
- **Must not:** document listeners as supported.
- **Ask first:** before emulating listeners by polling or by looping `runQuery`.
- **Must not:** call listeners out of scope.
- **Ask first:** before choosing the listener API's shape, a `snapshots()` `Stream` or a Node-style `onSnapshot` callback. It hasn't been decided; ask a maintainer.

# Related

- [Firestore runs over REST, with buffered streaming](/firestore/rest-transport.md)
- [Firebase services Node has and Dart does not](/scope/unsupported-services.md)
- [Pooled HTTP/2 by default](/architecture/http2-pooled-transport.md)

[^admin-node-index]: Node's Admin SDK re-exports `@google-cloud/firestore`
[^node-on-snapshot]: Node's `onSnapshot()` declarations
[^query-todo]: The `onSnapshot` TODO on `Query`
[^document-todo]: The snapshots TODO on `DocumentReference`
[^http2-constraint]: The `http2` constraint
