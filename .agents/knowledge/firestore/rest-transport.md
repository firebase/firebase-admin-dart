---
type: Divergence
title: "Firestore runs over REST, with gRPC only for Listen"
description: "Node's Firestore uses gRPC by default, while Dart's uses REST through the generated `google_cloud_firestore_v1` client for every RPC except the bidirectional `Listen`, which goes over `package:grpc` to back the `snapshots()` streams; the REST client buffers every server-streaming response, so Node's `Readable` APIs are not ported, and `package:grpc`'s older `http2` major blocks publishing."
tags: [firestore, transport, async, node-parity, realtime, grpc]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/**
  - packages/google_cloud_firestore/pubspec.yaml
  - packages/firebase_admin_sdk/lib/src/app/app_options.dart
  - packages/google_cloud_firestore/lib/src/reference/**
  - packages/google_cloud_firestore/lib/src/firestore_http_client.dart
  - packages/google_cloud_firestore/lib/src/watch/**
  - packages/firebase_admin_sdk/pubspec.yaml
  - pubspec.yaml
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
  - id: grpc-dependency
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "grpc:"
    title: The `package:grpc` dependency, used only for `Listen`
  - id: listen-transport
    resource: ../../../packages/google_cloud_firestore/lib/src/watch/listen_transport.dart
    symbol: final class GrpcListenTransport implements ListenTransport
    title: "`GrpcListenTransport`, the `Listen` call over `package:grpc`"
  - id: proto3-json-bridge
    resource: ../../../packages/google_cloud_firestore/lib/src/watch/listen_transport.dart
    symbol: mergeFromProto3Json
    title: The proto3 JSON bridge between the protoc-generated messages and `google_cloud_firestore_v1`
  - id: compile-protos
    resource: ../../../packages/google_cloud_firestore/tool/compile_protos.dart
    symbol: const _outDir = 'lib/src/generated';
    title: The tool that generates the protobuf messages under `lib/src/generated/`
  - id: watch
    resource: ../../../packages/google_cloud_firestore/lib/src/watch/watch.dart
    symbol: final class Watch<T>
    title: The internal `Watch` state machine
  - id: document-snapshots
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/document_reference.dart
    symbol: Stream<DocumentSnapshot<T>> snapshots()
    title: "`DocumentReference.snapshots()`"
  - id: query-snapshots
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: Stream<QuerySnapshot<T>> snapshots()
    title: "`Query.snapshots()`"
  - id: terminate-listeners
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore.dart
    symbol: for (final listener in listeners) attempt(listener._stop)
    title: "`Firestore.terminate()` stopping every active listener"
  - id: http2-constraint
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "http2:"
    title: The `http2` major the HTTP/2 pool needs
  - id: http2-override
    resource: ../../../pubspec.yaml
    symbol: "dependency_overrides:"
    title: The workspace's `http2` override for `package:grpc`
  - id: node-prefer-rest
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/types/firestore.d.ts
    symbol: "preferRest?: boolean"
    title: Node's `preferRest` setting
  - id: node-pipeline-stream
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/pipelines/pipelines.ts
    symbol: "stream(): NodeJS.ReadableStream"
    title: Node's `pipeline.stream()`
  - id: node-on-snapshot
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/types/firestore.d.ts
    symbol: onSnapshot(
    title: Node's `onSnapshot()` declarations
  - id: node-terminate
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/index.ts
    symbol: registeredListenersCount
    title: Node's `terminate()`, which rejects while listeners are registered
  - id: admin-node-index
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/firestore/index.ts
    symbol: QuerySnapshot
    title: Node's Admin SDK re-exports `Query` and `QuerySnapshot` from `@google-cloud/firestore`
---

# Where it lives

- Enforced by: nothing; review only.
- The generated REST client, and `google_cloud_rpc`, which sends its protobuf messages as JSON over HTTP: `google_cloud_firestore_v1:` in `pubspec.yaml`.[^v1-dependency]
- Buffered server streaming: the `postStreaming(…, enableSse: false)` calls in `google_cloud_firestore_v1`'s generated `api.g.dart`.[^generated-api]
- The emulator's REST transport: the `Plain HTTP/1.1, matching nodejs-firestore's REST mode` comment in `firestore_http_client.dart`.[^firestore-http-client]
- The unported streaming APIs: `// TODO stream` in `query.dart`,[^query-stream-todo] and `'Pipeline.stream'` in `_pendingFixes` in `pipeline_api_parity_test.dart`.[^parity-pipeline-stream]
- The `Listen` transport: `grpc:` in `pubspec.yaml`,[^grpc-dependency] `GrpcListenTransport` in `listen_transport.dart`,[^listen-transport] its proto3 JSON bridge (`mergeFromProto3Json`),[^proto3-json-bridge] and the protobuf messages under `lib/src/generated/`, written by `compile_protos.dart`.[^compile-protos]
- The listeners: the internal `Watch` in `watch.dart`,[^watch] `DocumentReference.snapshots()` in `document_reference.dart`[^document-snapshots] and `Query.snapshots()` in `query.dart`,[^query-snapshots] stopped by `Firestore.terminate()` in `firestore.dart`.[^terminate-listeners]
- The release blocker: `http2:` in each package's `pubspec.yaml`,[^http2-constraint] and the `http2` entry under `dependency_overrides:` in the workspace root `pubspec.yaml`, which pub.dev consumers don't get.[^http2-override]

# Node.js

## REST transport and buffered streaming

Node's Firestore uses gRPC by default. With `Settings.preferRest` it uses HTTP/1.1 REST until a call needs gRPC, and the only call that does is a snapshot listener.[^node-prefer-rest] Its `Readable` APIs, `query.stream()`, `explainStream()` and `pipeline.stream()`, yield results as they arrive.[^node-pipeline-stream]

## Realtime listeners (onSnapshot)

Node's Admin SDK re-exports `@google-cloud/firestore`, so it has realtime listeners.[^admin-node-index] `DocumentReference`, `Query` and `CollectionReference` all have `onSnapshot`, which takes callbacks and returns an unsubscribe function.[^node-on-snapshot] Listeners run over the bidirectional gRPC `Listen` RPC, through the `Watch` class. `terminate()` rejects while any listener is still registered.[^node-terminate]

# Dart

## REST transport and buffered streaming

Dart's Firestore uses REST for every RPC except `Listen`, through Google's generated `google_cloud_firestore_v1` client rather than the `googleapis` discovery client.[^v1-dependency]

- **No bidirectional RPC over REST.** The generated client has no `Listen` or `Write`. `Listen` goes over gRPC (below); `Write` isn't used.
- **Buffered streaming.** The server-streaming RPCs (`runQuery`, `batchGetDocuments`, `runAggregationQuery`, `executePipeline`) return a Dart `Stream`, but the generated client requests them with `enableSse: false`. The response is one JSON array, and `google_cloud_rpc` reads the whole body before it yields the first element.[^generated-api] Nothing streams incrementally.
- **No `Readable` APIs.** `query.stream()`, `explainStream()` and `pipeline.stream()` aren't ported. This is a gap.[^query-stream-todo][^parity-pipeline-stream] Whether Firestore's REST endpoint accepts SSE (`alt=sse`) for these RPCs is unverified.
- **Generated types stay internal.** Public results are hand-written wrappers, such as `ExplainStats`.
- **Errors** arrive as `google_cloud_rpc`'s `ServiceException`, whose shape has changed between `google_cloud_rpc` versions.[^service-exception]
- **No special-double interceptor.** An HTTP interceptor that rewrote Infinity, -Infinity and NaN for the `googleapis` client was dropped: the protobuf types carry those values, and int64, natively.
- **Firestore ignores `AppOptions.httpClient`.** It builds its own client from `Settings.credential`; [the test helpers concept](/tests/helpers-and-injection.md) owns what that means for tests.

## Listen over gRPC

Only `Listen` uses gRPC, as in Node's `preferRest` mode.[^grpc-dependency]

- **One channel per `Firestore`.** `GrpcListenTransport` owns a `package:grpc` channel, created on the first listener and shared by all of them; each subscription opens its own `Listen` call on it.[^listen-transport] It authenticates from `Settings.credential` as REST does, and sends the emulator's `owner` token to the emulator.
- **Two message types, bridged at the transport.** `package:grpc` needs protoc-generated messages, which live under `lib/src/generated/`.[^compile-protos] The transport converts them to and from `google_cloud_firestore_v1` types through proto3 JSON, so the watch code above it sees the same types as the REST code.[^proto3-json-bridge]
- **`Watch`** is the internal state machine that turns `Listen` responses into snapshots, ported from Node's `Watch`.[^watch]

## Realtime listeners (snapshots)

`DocumentReference.snapshots()` and `Query.snapshots()`, and so `CollectionReference`, return a Dart `Stream` where Node has `onSnapshot`.[^document-snapshots][^query-snapshots]

- **One backend stream per subscription.** The stream starts nothing until listened to, can be listened to more than once, and cancelling a subscription closes its `Listen` call. The dartdoc owns the error, retry and pause behaviour.
- **`Firestore.terminate()` closes listeners.** Every active subscription ends with a done event and no error, then the transport closes. Node rejects `terminate()` instead.[^terminate-listeners][^node-terminate]

## Publishing is blocked

`package:grpc` requires an older major of `http2` than the SDK's HTTP/2 pool needs.[^http2-constraint] The workspace resolves only because the root `pubspec.yaml` overrides `http2`, and pub.dev consumers don't get that override,[^http2-override] so `google_cloud_firestore` can't be published until a `package:grpc` release allows the newer `http2`, or `Listen` gets its own gRPC framing over `package:http2`.

# Why

## REST transport and buffered streaming

- **REST for everything else.** Why the SDK uses REST rather than gRPC isn't recorded; ask a maintainer. A maintainer stated a related limit of the earlier `googleapis` client: the way the library talked to Google's API clients didn't support streaming APIs, and adding that support depended on Google. That explains the missing streaming APIs, not the choice of REST.
- **The generated client.** The maintainers' stated intent: switching to it must not change the public API. The motive for the switch isn't recorded. One benefit was stated in review: protobuf supports int64, Infinity, -Infinity and NaN natively, so special doubles need no workaround. Likely context (not recorded as the reason): Google intends to take over the design of the Google API client dependencies.
- **`Readable` as `Stream`.** Inferred from the existing mapping of Node's async iterables to `Stream`; no maintainer has decided it.

## Listen over gRPC

- **gRPC for `Listen`.** The likely reason (not recorded): the generated REST client has no bidirectional RPC, and Node's own REST mode also falls back to gRPC for listeners.
- **Proto3 JSON bridge.** The likely reason (not recorded): it keeps `google_cloud_firestore_v1` the one set of types above the transport, so the protoc-generated messages stay confined to it.

## Realtime listeners (snapshots)

- **`Stream`, not `onSnapshot`.** A maintainer decision: listeners are Dart `Stream`s, and cancelling the subscription replaces Node's unsubscribe function.
- **`terminate()` closes listeners.** A maintainer decision: `terminate()` ends active listeners with a done event rather than rejecting as Node does.

# Rules for agents

- **Ask first:** before moving any RPC other than `Listen` off REST. Everything Node's `preferRest` mode can do over REST stays on REST.
- **Should:** put any new bidirectional RPC on the `Listen` path: a gRPC transport behind an internal interface that converts to `google_cloud_firestore_v1` types at its boundary. Ask first before adding one.
- **Must not:** expose `firestore_v1` types, the protoc-generated messages or `package:grpc` types in the public API.
- **Must:** regenerate `lib/src/generated/` with its tool rather than editing it by hand.
- **Must not:** present a buffered `runQuery` or `executePipeline` result as an incremental stream.
- **Ask first:** before porting `query.stream()`, `explainStream()` or `pipeline.stream()`, and before porting any of them as callbacks rather than a `Stream`. An incremental port needs SSE (unverified for Firestore REST) or gRPC.
- **Should:** port them as Dart `Stream`s. This is inferred; no maintainer has decided it.
- **Must:** keep listeners as `snapshots()` `Stream`s. **Ask first:** before adding a Node-style `onSnapshot` callback API beside them.
- **Must:** keep `Firestore.terminate()` closing every active listener with a done event. **Must not:** make it reject while listeners are open, as Node does.
- **Must:** keep `handleFirestoreException` working with the shape of `google_cloud_rpc`'s `ServiceException`.
- **Must not:** bring back the special-double interceptor.
- **Must not:** publish anything that depends on `grpc` while it forces an older major of `http2` than the SDK's HTTP/2 pool needs ([Pooled HTTP/2 by default](/architecture/http2-pooled-transport.md)).

# Related

- [Pooled HTTP/2 by default](/architecture/http2-pooled-transport.md), which owns the HTTP/2 transport
- [Admin services use generated REST clients](/architecture/generated-rest-clients.md)
- [Firestore errors](/errors/firestore-exception.md)
- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md), which maps Promises to `Future`, async iterables and `onSnapshot` to `Stream`
- [Small dependency set, no lockfiles or overrides](/dependencies/dependency-set.md)
- [Pipelines parity with Node](/firestore/pipelines/node-parity.md)
- [Firebase services Node has and Dart does not](/scope/unsupported-services.md)

[^v1-dependency]: The `google_cloud_firestore_v1` dependency
[^generated-api]: The generated client's `postStreaming` calls
[^firestore-http-client]: The emulator transport in `FirestoreHttpClient`
[^service-exception]: `handleFirestoreException` and `ServiceException`
[^query-stream-todo]: The `// TODO stream` on `Query`
[^parity-pipeline-stream]: `Pipeline.stream` in `_pendingFixes`
[^grpc-dependency]: The `grpc` dependency
[^listen-transport]: `GrpcListenTransport`
[^proto3-json-bridge]: The proto3 JSON bridge in `listen_transport.dart`
[^compile-protos]: `tool/compile_protos.dart`
[^watch]: The internal `Watch`
[^document-snapshots]: `DocumentReference.snapshots()`
[^query-snapshots]: `Query.snapshots()`
[^terminate-listeners]: `Firestore.terminate()` stopping listeners
[^http2-constraint]: The `http2` constraint
[^http2-override]: The root `dependency_overrides`
[^node-prefer-rest]: Node's `preferRest` setting
[^node-pipeline-stream]: Node's `pipeline.stream()`
[^node-on-snapshot]: Node's `onSnapshot()` declarations
[^node-terminate]: Node's `terminate()`
[^admin-node-index]: Node's Admin SDK re-exports `@google-cloud/firestore`
