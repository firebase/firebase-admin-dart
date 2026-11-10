---
type: Divergence
title: Timestamp shape and its Node JSON keys
description: Dart's `Timestamp` uses named parameters and `DateTime` and adds `fromMicros`, but `toJson()` keeps Node's `_seconds` and `_nanoseconds` keys on purpose.
tags: [firestore, timestamp, json, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/timestamp.dart
sources:
  - id: json-test
    resource: ../../../packages/google_cloud_firestore/test/timestamp_test.dart
    symbol: toJson() returns correct JSON representation
    title: The test that pins `toJson()`'s keys
  - id: timestamp-class
    resource: ../../../packages/google_cloud_firestore/lib/src/timestamp.dart
    symbol: final class Timestamp
    title: The Dart `Timestamp` class
  - id: json-keys
    resource: ../../../packages/google_cloud_firestore/lib/src/timestamp.dart
    symbol: "'_seconds': seconds"
    title: "`Timestamp.toJson()` with Node's keys"
  - id: from-micros
    resource: ../../../packages/google_cloud_firestore/lib/src/timestamp.dart
    symbol: factory Timestamp.fromMicros
    title: The Dart-only `Timestamp.fromMicros`
  - id: node-value-of
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/timestamp.ts
    symbol: "valueOf(): string"
    title: Node's `Timestamp`, including `valueOf()`
---

# Where it lives

- Enforced by: the `toJson() returns correct JSON representation` test in `timestamp_test.dart`, for the JSON keys only.[^json-test]
- The constructor, the conversions and `==`: `final class Timestamp` in `timestamp.dart`.[^timestamp-class]
- The JSON keys: `toJson()` in `timestamp.dart`.[^json-keys]
- The Dart-only `fromMicros`: `factory Timestamp.fromMicros` in `timestamp.dart`.[^from-micros]

# Node.js

`new Timestamp(seconds, nanoseconds)` takes positional arguments. It has `isEqual` and `valueOf()`, which makes `<` and `>` work, and no `fromMicros`.[^node-value-of]

Its private `_seconds` and `_nanoseconds` fields make `JSON.stringify` emit `{"_seconds": …, "_nanoseconds": …}`.

# Dart

`Timestamp` takes named parameters and converts to and from `DateTime`.[^timestamp-class] It has `==` and `hashCode`, but no `isEqual`, `valueOf` or `Comparable`. It adds `fromMicros`, which Node lacks.[^from-micros]

`toJson()` returns Node's keys, `_seconds` and `_nanoseconds`.[^json-keys]

# Why

- **JSON keys.** The stated reason, from the contributor's request this implements: a `Timestamp` returned from a Cloud Function, through `Response.ok` or `CallableResult`, must serialize to a map of seconds and nanoseconds, as it does in Node, instead of throwing.
- **Bundles.** A maintainer stated that `toJson()` must not be used for bundle serialization, which needs `seconds` and `nanos` keys.
- **`fromMicros`.** The stated reason, in the contribution the maintainers accepted: to keep microsecond precision.
- **Constructor and conversions.** The likely reason (not recorded): Dart idioms.

# Rules for agents

- **Must:** match Node for the JSON keys, `_seconds` and `_nanoseconds`.
- **Must:** keep Dart's shape for the constructor and the conversion methods.
- **Must not:** "clean up" the underscored JSON keys.
- **Must not:** use `Timestamp.toJson()` for bundle serialization, which needs `seconds` and `nanos` keys.
- **Ask first:** before adding `Comparable` or a `fromJson`.

# Related

- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md)
- [Firestore reference classes are mockable interfaces](/firestore/mockable-references.md)

[^json-test]: The `toJson()` test
[^timestamp-class]: The Dart `Timestamp`
[^json-keys]: `Timestamp.toJson()`
[^from-micros]: `Timestamp.fromMicros`
[^node-value-of]: Node's `Timestamp`
