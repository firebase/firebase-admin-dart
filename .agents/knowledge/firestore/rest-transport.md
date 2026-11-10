---
type: Divergence
title: Firestore runs over REST, with buffered streaming
description: Node's Firestore uses gRPC by default, while Dart's uses only REST through the generated `google_cloud_firestore_v1` client, which has no bidirectional RPC and buffers every server-streaming response, so Node's `Readable` APIs aren't ported.
tags: [firestore, transport, async, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/**
  - packages/google_cloud_firestore/pubspec.yaml
  - packages/firebase_admin_sdk/lib/src/app/app_options.dart
sources:
  - id: v1-dependency
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "google_cloud_firestore_v1:"
    title: The generated REST client dependency
  - id: generated-api
    resource: https://github.com/googleapis/google-cloud-dart/blob/main/generated/google_cloud_firestore_v1/lib/src/api.g.dart
    symbol: "enableSse: false"
    title: The generated client's server-streaming calls, made without SSE
  - id: firestore-http-client
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_http_client.dart
    symbol: Plain HTTP/1.1, matching nodejs-firestore's REST mode
    title: The emulator transport, matching Node's REST mode
  - id: service-exception
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_exception.dart
    symbol: exception is ServiceException
    title: "`handleFirestoreException` handling `google_cloud_rpc`'s `ServiceException`"
  - id: query-stream-todo
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: // TODO stream
    title: The `query.stream()` TODO on `Query`
  - id: parity-pipeline-stream
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: "'Pipeline.stream'"
    title: "`Pipeline.stream` listed as missing in the parity test"
  - id: node-prefer-rest
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/types/firestore.d.ts
    symbol: "preferRest?: boolean"
    title: Node's `preferRest` setting
  - id: node-pipeline-stream
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/pipelines/pipelines.ts
    symbol: "stream(): NodeJS.ReadableStream"
    title: Node's `pipeline.stream()`
---

# Where it lives

- Enforced by: nothing; review only.
- The generated client, and `google_cloud_rpc`, which sends its protobuf messages as JSON over HTTP: `google_cloud_firestore_v1:` in `pubspec.yaml`.[^v1-dependency]
- Buffered server streaming: the `postStreaming(…, enableSse: false)` calls in `google_cloud_firestore_v1`'s generated `api.g.dart`.[^generated-api]
- The emulator transport: the `Plain HTTP/1.1, matching nodejs-firestore's REST mode` comment in `firestore_http_client.dart`.[^firestore-http-client]
- The unported streaming APIs: `// TODO stream` in `query.dart`,[^query-stream-todo] and `'Pipeline.stream'` in `_pendingFixes` in `pipeline_api_parity_test.dart`.[^parity-pipeline-stream]

# Node.js

Node's Firestore uses gRPC by default. With `Settings.preferRest` it uses HTTP/1.1 REST until a call needs gRPC, and the only call that does is a snapshot listener.[^node-prefer-rest] Its `Readable` APIs, `query.stream()`, `explainStream()` and `pipeline.stream()`, yield results as they arrive.[^node-pipeline-stream]

# Dart

Dart's Firestore uses REST only, through Google's generated `google_cloud_firestore_v1` client rather than the `googleapis` discovery client. It doesn't depend on `grpc`.[^v1-dependency]

- **No bidirectional RPC.** The generated client has no `Listen` or `Write`.
- **Buffered streaming.** The server-streaming RPCs (`runQuery`, `batchGetDocuments`, `runAggregationQuery`, `executePipeline`) return a Dart `Stream`, but the generated client requests them with `enableSse: false`. The response is one JSON array, and `google_cloud_rpc` reads the whole body before it yields the first element.[^generated-api] Nothing streams incrementally.
- **No `Readable` APIs.** `query.stream()`, `explainStream()` and `pipeline.stream()` aren't ported. This is a gap.[^query-stream-todo][^parity-pipeline-stream] Whether Firestore's REST endpoint accepts SSE (`alt=sse`) for these RPCs is unverified.
- **Generated types stay internal.** Public results are hand-written wrappers, such as `ExplainStats`.
- **Errors** arrive as `google_cloud_rpc`'s `ServiceException`, whose shape has changed between `google_cloud_rpc` versions.[^service-exception]
- **No special-double interceptor.** An HTTP interceptor that rewrote Infinity, -Infinity and NaN for the `googleapis` client was dropped: the protobuf types carry those values, and int64, natively.
- **Firestore ignores `AppOptions.httpClient`.** It builds its own client from `Settings.credential`; [the test helpers concept](/tests/helpers-and-injection.md) owns what that means for tests.

# Why

- **REST only.** Why the SDK uses REST rather than gRPC isn't recorded; ask a maintainer. A maintainer stated a related limit of the earlier `googleapis` client: the way the library talked to Google's API clients didn't support streaming APIs, and adding that support depended on Google. That explains the missing streaming APIs, not the choice of REST.
- **The generated client.** The maintainers' stated intent: switching to it must not change the public API. The motive for the switch isn't recorded. One benefit was stated in review: protobuf supports int64, Infinity, -Infinity and NaN natively, so special doubles need no workaround. Likely context (not recorded as the reason): Google intends to take over the design of the Google API client dependencies.
- **`Readable` as `Stream`.** Inferred from the existing mapping of Node's async iterables to `Stream`; no maintainer has decided it.

# Rules for agents

- **Ask first:** before moving existing RPCs off REST. Everything Node's `preferRest` mode can do is in scope.
- **Must:** treat anything that needs a bidirectional RPC as needing a new transport, as listeners do ([No realtime listeners](/firestore/no-realtime-listeners.md)).
- **Must not:** present a buffered `runQuery` or `executePipeline` result as an incremental stream.
- **Ask first:** before porting `query.stream()`, `explainStream()` or `pipeline.stream()`, and before porting any of them as callbacks rather than a `Stream`. An incremental port needs SSE (unverified for Firestore REST) or gRPC.
- **Should:** port them as Dart `Stream`s. This is inferred; no maintainer has decided it.
- **Must:** keep `handleFirestoreException` working with the shape of `google_cloud_rpc`'s `ServiceException`.
- **Must not:** expose `firestore_v1` types in the public API.
- **Must not:** bring back the special-double interceptor.

# Related

- [No realtime listeners](/firestore/no-realtime-listeners.md)
- [Pooled HTTP/2 by default](/architecture/http2-pooled-transport.md), which owns the HTTP/2 transport
- [Admin services use generated REST clients](/architecture/generated-rest-clients.md)
- [Firestore errors](/errors/firestore-exception.md)
- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md), which maps Promises to `Future` and async iterables to `Stream`
- [Pipelines parity with Node](/firestore/pipelines/node-parity.md)

[^v1-dependency]: The `google_cloud_firestore_v1` dependency
[^generated-api]: The generated client's `postStreaming` calls
[^firestore-http-client]: The emulator transport in `FirestoreHttpClient`
[^service-exception]: `handleFirestoreException` and `ServiceException`
[^query-stream-todo]: The `// TODO stream` on `Query`
[^parity-pipeline-stream]: `Pipeline.stream` in `_pendingFixes`
[^node-prefer-rest]: Node's `preferRest` setting
[^node-pipeline-stream]: Node's `pipeline.stream()`
