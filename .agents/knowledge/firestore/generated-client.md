---
type: Decision
title: Firestore uses generated google_cloud_firestore_v1
description: The Firestore package talks to Firestore through Google's generated `google_cloud_firestore_v1` client, not the `googleapis` `firestore/v1` client, and keeps the generated types out of its public API.
tags: [firestore, transport, dependencies]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/**
  - packages/google_cloud_firestore/pubspec.yaml
sources:
  - id: v1-dependency
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "google_cloud_firestore_v1:"
    title: The `google_cloud_firestore_v1` dependency
  - id: rpc-dependency
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "google_cloud_rpc:"
    title: The `google_cloud_rpc` dependency, which carries the requests
  - id: service-exception
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_exception.dart
    symbol: exception is ServiceException
    title: "`handleFirestoreException` handling `google_cloud_rpc`'s `ServiceException`"
---

# Decision

`google_cloud_firestore` calls Firestore through Google's generated `google_cloud_firestore_v1` client, not the `googleapis` `firestore/v1` discovery client.[^v1-dependency]

- Requests and responses are protobuf-typed messages (`google_cloud_protobuf` types).
- `google_cloud_rpc`'s `ServiceClient` sends them JSON-encoded over HTTP. There is no gRPC.[^rpc-dependency]
- The generated types stay internal. Public results are hand-written wrappers, such as `ExplainStats`.
- Errors from the generated client arrive as `google_cloud_rpc`'s `ServiceException`, which `handleFirestoreException` handles.[^service-exception]

An HTTP interceptor that rewrote special doubles (Infinity, -Infinity, NaN) for the `googleapis` client was dropped. The protobuf types carry those values, and int64, natively.

# Why

The maintainers' stated intent: the switch of client must not change the public API. The motive for the switch itself isn't recorded. One benefit was stated in review: protobuf supports int64, Infinity, -Infinity and NaN natively, unlike the JSON discovery client, so special doubles need no workaround.

Likely context (not recorded as the reason): Google intends to take over the design of the Google API client dependencies.

# Rules for agents

- **Must:** keep `handleFirestoreException` working with the shape of `google_cloud_rpc`'s `ServiceException`, which has changed between `google_cloud_rpc` versions.
- **Must not:** expose `firestore_v1` types in the public API.
- **Must not:** bring back the special-double interceptor.

# Related

- [Firestore runs over REST, not gRPC](/firestore/rest-transport.md)
- [Admin services use generated REST clients](/architecture/generated-rest-clients.md)
- [FirestoreException and its error codes](/errors/firestore-exception.md)

[^v1-dependency]: The `google_cloud_firestore_v1` dependency
[^rpc-dependency]: The `google_cloud_rpc` dependency
[^service-exception]: `handleFirestoreException` and `ServiceException`
