---
type: Decision
title: Firestore follows Node, not FlutterFire
description: The Firestore API follows Node rather than FlutterFire's `cloud_firestore`, and matching FlutterFire signatures to share code with Flutter clients was declined.
tags: [firestore, api-shape, flutterfire, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/**
sources:
  - id: flutterfire-aliases
    resource: ../../../packages/google_cloud_firestore/lib/src/pipeline.dart
    symbol: FlutterFire-style entry points
    title: The Pipeline API's "FlutterFire-style" entry points and aliases, which pull the other way
  - id: query-where
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: Query<T> where(Object path, WhereFilter op, Object? value)
    title: "`Query.where(path, op, value)`, shaped like Node's `where(fieldPath, opStr, value)`"
---

# Decision

The Firestore API follows Node's Firestore, not FlutterFire's `cloud_firestore`; `Query.where` takes Node's path, operator and value.[^query-where] Changing `where()` and other signatures to match `cloud_firestore`, so that code could be shared with Flutter clients, was declined.

Sharing value types such as `Timestamp` and `GeoPoint` with FlutterFire through a common package has been raised and isn't decided.

Some parts of the API do resemble FlutterFire's. The Pipeline API has entry points and aliases its code calls "FlutterFire-style".[^flutterfire-aliases] The aggregate helpers and the single-type-parameter `withConverter` also look like `cloud_firestore`'s, though no source says they were modelled on it. Whether FlutterFire is a reference at all is an open question for the maintainers.

# Why

The maintainers' stated reason: the goal of sharing code with Flutter clients doesn't justify the change, since the SDK looks like the official JS SDK.

# Rules for agents

- **Must not:** change Firestore signatures to match `cloud_firestore` without a maintainer decision on sharing value types with FlutterFire. Ask a maintainer.

# Related

- [Port of the Node.js Admin SDK](/architecture/node-port.md)
- [Positional aggregate fields with auto-aliases](/firestore/aggregate-api.md)
- [One type parameter and a function-pair withConverter](/firestore/typed-references.md)

[^flutterfire-aliases]: The Pipeline API's "FlutterFire-style" entry points
[^query-where]: `Query.where`
