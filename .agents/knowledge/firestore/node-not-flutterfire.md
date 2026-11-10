---
type: Decision
title: Firestore follows Node, with a few FlutterFire look-alikes
description: The Firestore API follows Node rather than FlutterFire's `cloud_firestore`, and matching FlutterFire to share code with Flutter clients was declined, yet the aggregate API, `withConverter` and some Pipeline aliases look like FlutterFire's.
tags: [firestore, api-shape, flutterfire, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/**
sources:
  - id: query-where
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: Query<T> where(Object path, WhereFilter op, Object? value)
    title: "`Query.where(path, op, value)`, shaped like Node's `where(fieldPath, opStr, value)`"
  - id: query-aggregate
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: AggregateQuery aggregate(
    title: "`Query.aggregate`, `sum` and `average`"
  - id: query-with-converter
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: Query<U> withConverter<U>(
    title: "`Query.withConverter`, including its reset to `DocumentData`"
  - id: converter-types
    resource: ../../../packages/google_cloud_firestore/lib/src/types.dart
    symbol: typedef FromFirestore<T>
    title: The converter function types
  - id: flutterfire-aliases
    resource: ../../../packages/google_cloud_firestore/lib/src/pipeline.dart
    symbol: FlutterFire-style entry points
    title: The Pipeline API's "FlutterFire-style" entry points and aliases
  - id: node-aggregate
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/reference/query.ts
    symbol: aggregate<
    title: Node's `count()` and `aggregate()`
  - id: node-with-converter
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/reference/query.ts
    symbol: withConverter<
    title: Node's `Query.withConverter`
---

# Where it lives

- Enforced by: nothing; review only.
- Node's query shape: `Query.where(path, op, value)` in `query.dart`.[^query-where]
- The aggregate API, its automatic aliases and the `sum` and `average` shortcuts: `Query.aggregate` in `query.dart`.[^query-aggregate]
- `withConverter` and its reset: `Query.withConverter` in `query.dart`,[^query-with-converter] with the function types in `types.dart`.[^converter-types]
- The Pipeline API's FlutterFire-style entry points and aliases: `pipeline.dart`.[^flutterfire-aliases]

# Decision

The Firestore API follows Node's Firestore, not FlutterFire's `cloud_firestore`.[^query-where] Changing `where()` and other signatures to match `cloud_firestore`, so that code could be shared with Flutter clients, was declined.

Sharing value types such as `Timestamp` and `GeoPoint` with FlutterFire through a common package has been raised and isn't decided.

A few parts look like FlutterFire instead. Only the Pipeline aliases are called "FlutterFire-style" in the code;[^flutterfire-aliases] no source says the others were modelled on it:

- **Aggregates.** `aggregate()` takes up to three positional fields and names the results itself, and Dart adds `sum()` and `average()`.[^query-aggregate]
- **Converters.** References have one type parameter, and `withConverter` takes a pair of functions. Omitting either resets the reference to `DocumentData`.[^query-with-converter]

Whether FlutterFire is a reference at all is an open question for the maintainers.

# Node.js

- `query.aggregate({alias: AggregateField.sum('x'), …})` takes a map of aliases the user picks, and results are read by alias.[^node-aggregate]
- References have two type parameters, `AppModelType` and `DbModelType`. `withConverter` takes a `FirestoreDataConverter` object, or `null` to reset the reference.[^node-with-converter]

# Why

- **Following Node.** The maintainers' stated reason: the goal of sharing code with Flutter clients doesn't justify the change, since the SDK looks like the official JS SDK.
- **`withConverter`'s nullable parameters.** The maintainers' stated reason: so a typed reference can be reset to `DocumentData`.
- **The aggregate shape, one type parameter and the function pair.** The reason isn't recorded. The likely reason (not recorded): they match `cloud_firestore`, which conflicts with the decision above.

# Rules for agents

- **Must not:** change Firestore signatures to match `cloud_firestore` without a maintainer decision on sharing value types with FlutterFire. Ask a maintainer.
- **Ask first:** before changing the shape of the aggregate API.
- **Must:** keep the single type parameter and the function-pair `withConverter`.
- **Ask first:** before adding a second model type parameter or a converter interface class.

# Related

- [Port of the Node.js Admin SDK](/architecture/node-port.md)
- [Pipelines parity with Node](/firestore/pipelines/node-parity.md)

[^query-where]: `Query.where`
[^query-aggregate]: `Query.aggregate`
[^query-with-converter]: `Query.withConverter`
[^converter-types]: The converter types
[^flutterfire-aliases]: The Pipeline API's "FlutterFire-style" entry points
[^node-aggregate]: Node's `count()` and `aggregate()`
[^node-with-converter]: Node's `Query.withConverter`
