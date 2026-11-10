---
type: Decision
title: Firestore reference classes are mockable interfaces
description: The Firestore reference classes `Query`, `CollectionReference`, `DocumentReference` and `CollectionGroup` are `interface class`es so users can mock them, while value types stay `final`.
tags: [firestore, testing, api-shape]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/reference/**
  - packages/google_cloud_firestore/lib/src/collection_group.dart
sources:
  - id: example-mocks
    resource: ../../../packages/firebase_admin_sdk/example/test/examples_test.dart
    symbol: class MockQuery<T> extends Mock implements Query<T>
    title: The example tests' `mocktail` mocks of `Query`, `CollectionReference` and `DocumentReference`
  - id: query
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: interface class Query
    title: "`Query` is an `interface class`"
  - id: collection-reference
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/collection_reference.dart
    symbol: interface class CollectionReference
    title: "`CollectionReference` is an `interface class`"
  - id: document-reference
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/document_reference.dart
    symbol: interface class DocumentReference
    title: "`DocumentReference` is an `interface class`"
  - id: collection-group
    resource: ../../../packages/google_cloud_firestore/lib/src/collection_group.dart
    symbol: interface class CollectionGroup
    title: "`CollectionGroup` is an `interface class`"
  - id: timestamp
    resource: ../../../packages/google_cloud_firestore/lib/src/timestamp.dart
    symbol: final class Timestamp
    title: "`Timestamp`, a value type, stays `final`"
---

# Where it lives

- Enforced by: the `mocktail` mocks in `example/test/examples_test.dart`, which stop compiling if `Query`, `CollectionReference` or `DocumentReference` becomes `final` or `base`. Nothing mocks `CollectionGroup`.[^example-mocks]
- The `interface class` declarations: `query.dart`, `collection_reference.dart`, `document_reference.dart` and `collection_group.dart`.[^query][^collection-reference][^document-reference][^collection-group]
- A value type that stays `final`: `final class Timestamp` in `timestamp.dart`.[^timestamp]

# Decision

`Query`, `CollectionReference`, `DocumentReference` and `CollectionGroup` are `interface class`es, so users can mock them with `package:mocktail` or `package:mockito`.[^query][^collection-reference][^document-reference][^collection-group]

`Timestamp` and `GeoPoint` stay `final`.[^timestamp]

# Why

The maintainers' stated reason: as `final` or `base` classes, the references stopped users from mocking them with `package:mocktail` or `package:mockito`, and users asked for that.

They were once `final` (`Query` was `base`), for a reason that isn't recorded. Shipping fakes instead was also raised.

# Rules for agents

- **Must not:** mark these classes `final` or `base` again.

# Related

- [Timestamp shape and its Node JSON keys](/firestore/timestamp.md)

[^example-mocks]: The example tests' mocks
[^query]: `Query`
[^collection-reference]: `CollectionReference`
[^document-reference]: `DocumentReference`
[^collection-group]: `CollectionGroup`
[^timestamp]: `Timestamp`
