---
type: Divergence
title: Firestore runs over REST, not gRPC
description: Node's Firestore uses gRPC by default, while Dart's uses only REST through the generated `google_cloud_firestore_v1` client, which has no bidirectional `Listen` or `Write` RPC.
tags: [firestore, transport, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/firestore_http_client.dart
  - packages/google_cloud_firestore/pubspec.yaml
  - packages/firebase_admin_sdk/lib/src/app/app_options.dart
sources:
  - id: firestore-http-client
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_http_client.dart
    symbol: class FirestoreHttpClient
    title: The Firestore HTTP client (pooled HTTP/2, plain HTTP/1.1 for the emulator)
  - id: v1-dependency
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "google_cloud_firestore_v1:"
    title: The generated REST client dependency
  - id: rpc-dependency
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "google_cloud_rpc:"
    title: "`google_cloud_rpc`, which sends the requests as JSON over HTTP"
  - id: node-prefer-rest
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/types/firestore.d.ts
    symbol: "preferRest?: boolean"
    title: Node's `preferRest` setting
---

# Node.js

Node's Firestore uses gRPC by default. With `Settings.preferRest` it uses HTTP/1.1 REST until a call needs gRPC, and the only call that needs gRPC is a snapshot listener.[^node-prefer-rest] It connects to `FIRESTORE_EMULATOR_HOST` with `ssl: false`.

# Dart

Dart's Firestore uses REST only, through the generated `google_cloud_firestore_v1` client.[^v1-dependency] The messages are protobuf types, sent JSON-encoded over HTTP by `google_cloud_rpc`. The package doesn't depend on `grpc`.[^rpc-dependency]

- The generated client has no bidirectional `Listen` or `Write` RPC.
- Server-streaming RPCs such as `runQuery`, `batchGetDocuments` and `executePipeline` are requested without SSE. The response comes back as one JSON array, and it is buffered: nothing is yielded until the whole body has been read.
- `FirestoreHttpClient` pools HTTP/2 connections and falls back to HTTP/1.1 for plain-HTTP endpoints. Emulator requests use plain HTTP/1.1 and send `Authorization: Bearer owner`.[^firestore-http-client]
- Firestore ignores `AppOptions.httpClient`. It builds its own client from `Settings.credential`.

# Why

- **REST only.** Why the SDK uses REST rather than gRPC isn't recorded; ask a maintainer. A maintainer stated a related limit, said of the earlier `googleapis` client: the way the library talked to Google's API clients didn't support streaming APIs, and adding that support depended on Google. That explains the missing streaming APIs, not the choice of REST.
- **The emulator path.** The maintainers' stated reason: "Plain HTTP/1.1, matching nodejs-firestore's REST mode for the emulator" (a comment in `FirestoreHttpClient`).
- **HTTP/2 pooling.** The maintainers' stated reason: the package CHANGELOG records that it fixes slow and failing requests under high concurrency.

# Rules for agents

- **Ask first:** before moving existing RPCs off REST. Everything Node's `preferRest` mode can do is in scope.
- **Must:** treat anything that needs a bidirectional RPC as needing a new transport, as listeners do ([No realtime listeners](/firestore/no-realtime-listeners.md)). Incremental server streaming needs SSE or gRPC ([Promises become Futures, async iterables become Streams](/conventions/futures-and-streams.md)).

# Related

- [No realtime listeners](/firestore/no-realtime-listeners.md)
- [Pooled HTTP/2 by default](/architecture/http2-pooled-transport.md)
- [Firestore uses generated google_cloud_firestore_v1](/firestore/generated-client.md)

[^node-prefer-rest]: Node's `preferRest` setting
[^v1-dependency]: The generated REST client dependency
[^rpc-dependency]: The `google_cloud_rpc` dependency
[^firestore-http-client]: `FirestoreHttpClient`
