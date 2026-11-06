---
type: Divergence
title: One type parameter and a function-pair withConverter
description: Dart typed references have a single type parameter and `withConverter` takes a pair of functions, where Node has two model type parameters and a converter object.
tags: [firestore, converters, api-shape, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/reference/**
  - packages/google_cloud_firestore/lib/src/types.dart
  - packages/google_cloud_firestore/lib/src/transaction.dart
  - packages/google_cloud_firestore/lib/src/write_batch.dart
sources:
  - id: query-with-converter
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: Query<U> withConverter<U>(
    title: "`Query.withConverter`, including its reset to `DocumentData`"
  - id: converter-types
    resource: ../../../packages/google_cloud_firestore/lib/src/types.dart
    symbol: typedef FromFirestore<T>
    title: The converter function types and the internal converter record
  - id: node-with-converter
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/reference/query.ts
    symbol: withConverter<
    title: Node's `Query.withConverter`
---

# Node.js

References have two type parameters, `AppModelType` and `DbModelType`. `withConverter(converter)` takes a `FirestoreDataConverter` object, or `null` to reset the reference.[^node-with-converter] The converter has `toFirestore(model, options?)`, with a partial or merge overload, and `fromFirestore(snapshot)`.

# Dart

- References have a single type parameter `T`: `DocumentReference<T>`, `Query<T>`.
- `withConverter<U>({FromFirestore<U>? fromFirestore, ToFirestore<U>? toFirestore})` takes two functions. They are stored internally as a record, `({fromFirestore, toFirestore})`.[^query-with-converter][^converter-types]
- Omitting either function resets the reference to `DocumentData`.
- `toFirestore` doesn't take `SetOptions`.
- `Transaction` and `WriteBatch` `update` and `delete` accept `DocumentReference<Object?>`, so typed references work there.

# Why

- **Reset.** The maintainers' stated reason: `withConverter()` takes nullable parameters so that a typed reference can be reset to `DocumentData`.
- **One type parameter and a function pair.** The likely reason (not recorded): it matches FlutterFire's `cloud_firestore`. That conflicts with the decision that Firestore follows Node, not FlutterFire; whether FlutterFire is a reference is an open question for the maintainers.

# Rules for agents

- **Must:** keep Dart's shape.
- **Ask first:** before adding a second model type parameter or a converter interface class.

# Related

- [Firestore follows Node, not FlutterFire](/firestore/node-not-flutterfire.md)
- [Positional aggregate fields with auto-aliases](/firestore/aggregate-api.md)

[^node-with-converter]: Node's `Query.withConverter`
[^query-with-converter]: `Query.withConverter`
[^converter-types]: The converter types
