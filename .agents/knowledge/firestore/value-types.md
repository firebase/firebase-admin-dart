---
type: Divergence
title: Firestore value types use Dart types and named parameters
description: Firestore value types such as `GeoPoint`, dates, big integers, bytes and `FieldValue` use Dart types (`DateTime`, `BigInt`, `Uint8List`) and named or const constructors instead of Node's shapes.
tags: [firestore, value-types, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/geo_point.dart
  - packages/google_cloud_firestore/lib/src/serializer.dart
  - packages/google_cloud_firestore/lib/src/field_value.dart
sources:
  - id: geo-point
    resource: ../../../packages/google_cloud_firestore/lib/src/geo_point.dart
    symbol: "GeoPoint({required this.latitude, required this.longitude})"
    title: "`GeoPoint`'s named constructor"
  - id: serializer
    resource: ../../../packages/google_cloud_firestore/lib/src/serializer.dart
    symbol: case BigInt()
    title: Encoding of `DateTime`, `BigInt` and `Uint8List`
  - id: field-value
    resource: ../../../packages/google_cloud_firestore/lib/src/field_value.dart
    symbol: const factory FieldValue.increment
    title: "`FieldValue`'s const factories"
  - id: node-geo-point
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/geo-point.ts
    symbol: class GeoPoint
    title: Node's `GeoPoint`
---

# Node.js

- `new GeoPoint(lat, lng)` takes positional arguments.[^node-geo-point]
- A JS `Date` is accepted and stored as a timestamp, and `bigint` is accepted.
- Integers decode as 53-bit numbers, unless `useBigInt` decodes them as `BigInt`.

# Dart

- `GeoPoint({required latitude, required longitude})` takes named parameters.[^geo-point]
- `DateTime` and `BigInt` are accepted as input. Timestamps decode to `Timestamp`.[^serializer]
- `Settings.useBigInt` decodes integers as `BigInt`. Dart's `int` is already 64-bit on the VM, so the default loses no precision.
- Bytes are `Uint8List`.
- `FieldValue` uses const factories, such as `FieldValue.increment(num)` and `FieldValue.arrayUnion(List)`.[^field-value]
- Firestore value and reference classes are `@immutable`.

# Why

The likely reason (not recorded): these are the Dart idioms for the same values.

# Rules for agents

- **Must:** keep Dart's shapes. Use named parameters for value types with several fields.
- **Must:** make new value classes `@immutable`, with `==` and `hashCode`.

# Related

- [Timestamp shape and its Node JSON keys](/firestore/timestamp.md)
- [Optional positionals and Pipeline options become named parameters](/conventions/named-parameters-for-options.md)

[^node-geo-point]: Node's `GeoPoint`
[^geo-point]: `GeoPoint`'s named constructor
[^serializer]: The value serializer
[^field-value]: `FieldValue`'s const factories
