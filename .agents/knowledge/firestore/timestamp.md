---
type: Divergence
title: Timestamp shape and its Node JSON keys
description: Dart's `Timestamp` uses named parameters and `DateTime`, but `toJson()` keeps Node's `_seconds` and `_nanoseconds` keys on purpose.
tags: [firestore, timestamp, json, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/timestamp.dart
sources:
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

# Node.js

`new Timestamp(seconds, nanoseconds)` takes positional arguments. It has `fromDate(Date)`, `fromMillis`, `toDate(): Date`, `toMillis`, `isEqual` and `valueOf()`, which makes `<` and `>` work.[^node-value-of]

Its private `_seconds` and `_nanoseconds` fields make `JSON.stringify` emit `{"_seconds": …, "_nanoseconds": …}`.

# Dart

- `Timestamp({required seconds, required nanoseconds})` takes named parameters. It has `fromDate(DateTime)`, `fromMillis`, and a Dart-only `fromMicros`.[^from-micros]
- `toDate()` returns a UTC `DateTime` with millisecond precision.
- It has `==` and `hashCode`, but no `isEqual`, `valueOf` or `Comparable`. It is a `final class`.
- `toJson()` returns `{'_seconds': …, '_nanoseconds': …}`, Node's keys.[^json-keys]

# Why

- **JSON keys.** The stated reason, from the contributor's request this implements: a `Timestamp` returned from a Cloud Function, through `Response.ok` or `CallableResult`, must serialize to a map of seconds and nanoseconds, as it does in Node, instead of throwing.
- **Bundles.** A maintainer stated that `toJson()` must not be used for bundle serialization, which needs `seconds` and `nanos` keys.
- **Constructor and conversions.** The likely reason (not recorded): Dart idioms.

# Rules for agents

- **Must:** match Node for the JSON keys, `_seconds` and `_nanoseconds`.
- **Must:** keep Dart's shape for the constructor and the conversion methods.
- **Must not:** "clean up" the underscored JSON keys.
- **Must not:** use `Timestamp.toJson()` for bundle serialization, which needs `seconds` and `nanos` keys.
- **Ask first:** before adding `Comparable` or a `fromJson`.

# Related

- [Firestore value types use Dart types and named parameters](/firestore/value-types.md)
- [Dart core-library names replace Node member names](/conventions/dart-member-names.md)
- [Firestore reference classes are mockable interfaces](/firestore/mockable-references.md)

[^node-value-of]: Node's `Timestamp`
[^from-micros]: `Timestamp.fromMicros`
[^json-keys]: `Timestamp.toJson()`
