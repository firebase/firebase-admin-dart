---
type: Divergence
title: Positional aggregate fields with auto-aliases
description: Dart's `query.aggregate()` takes up to three positional fields with automatic aliases and adds `sum()` and `average()` shortcuts, where Node takes a map of user-chosen aliases.
tags: [firestore, aggregation, api-shape, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/aggregate.dart
  - packages/google_cloud_firestore/lib/src/reference/**
sources:
  - id: query-aggregate
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: AggregateQuery aggregate(
    title: "`Query.aggregate`, `sum` and `average`"
  - id: lowercase-helpers
    resource: ../../../packages/google_cloud_firestore/lib/src/aggregate.dart
    symbol: class count extends AggregateField
    title: "`AggregateField` and the lower-case `count`, `sum` and `average` classes"
  - id: snapshot-getters
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/aggregate_query_snapshot.dart
    symbol: num? getSum(String field)
    title: "`getSum`, `getAverage` and `getField` on the snapshot"
  - id: node-aggregate
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/reference/query.ts
    symbol: aggregate<
    title: Node's `count()` and `aggregate()`
---

# Node.js

`query.count()`, and `query.aggregate({alias: AggregateField.sum('x'), …})` with aliases the user picks. Results are read by alias, from `snapshot.data().alias`.[^node-aggregate]

# Dart

- `query.aggregate(AggregateField f1, [f2, f3])` is positional and takes at most three fields.[^query-aggregate]
- Aliases are automatic: `count`, `sum_<field>` and `avg_<field>`.
- The snapshot reads results with `getSum('x')`, `getAverage('x')` and `getField(alias)`.[^snapshot-getters]
- Dart-only shortcuts: `query.sum(field)` and `query.average(field)`, and the lower-case classes `count()`, `sum(f)` and `average(f)`, which carry `// ignore: camel_case_types`.[^lowercase-helpers]

# Why

The reason isn't recorded. Ask a maintainer before changing it.

The likely reason (not recorded): it mirrors the aggregate API of FlutterFire's `cloud_firestore`, with lower-case `count`, `sum` and `average` and the `getSum` and `getAverage` helpers. That conflicts with the decision that Firestore follows Node, not FlutterFire; whether FlutterFire is a reference is an open question for the maintainers.

# Rules for agents

- **Ask first:** before changing the shape of the aggregate API.

# Related

- [Firestore follows Node, not FlutterFire](/firestore/node-not-flutterfire.md)
- [Conveniences Dart adds on top of Node](/scope/dart-only-conveniences.md)

[^node-aggregate]: Node's `count()` and `aggregate()`
[^query-aggregate]: `Query.aggregate`
[^snapshot-getters]: The aggregate snapshot getters
[^lowercase-helpers]: The lower-case aggregate classes
