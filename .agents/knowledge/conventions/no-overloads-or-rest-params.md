---
type: Divergence
title: Overloads become separate methods; rest params become lists
description: Node overloads become separately named Dart methods and rest parameters become a trailing `List` or `Iterable`, not one `Object` parameter with runtime type checks.
tags: [conventions, api-design, node-parity]
agents_md: reference
sources:
  - id: parity-no-overloads
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: since Dart has no overloads
    title: The parity test on overloads and rest parameters
  - id: start-at-document
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: Query<T> startAtDocument(
    title: "`startAt(List)` and `startAtDocument(snapshot)`"
  - id: where-filter
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/query.dart
    symbol: Query<T> whereFilter(
    title: "`where`, `whereFieldPath` and `whereFilter`"
  - id: transaction-get-query
    resource: ../../../packages/google_cloud_firestore/lib/src/transaction.dart
    symbol: getQuery<T>(
    title: "`Transaction.get`, `getQuery`, `getAggregateQuery` and `getAll`"
---

# Node.js

Node uses overloads and rest parameters: `where(path, op, value) | where(Filter)`, `startAt(...valuesOrSnapshot)`, `select(...fields)`, `getAll(...refs, readOptions?)`, `transaction.get(ref | query | aggregateQuery)`, `taskQueue(name, extensionId | FunctionScope)`, `new FieldPath(...segments)`, `update(field, value, ...more)` and `and(a, b, ...more)`.

# Dart

Dart splits overloads into separate methods, and turns rest parameters into a trailing `List` or `Iterable`:

- `where`, `whereFieldPath` and `whereFilter`;[^where-filter]
- `startAt(List)` and `startAtDocument(snapshot)`, and likewise for `startAfter`, `endBefore` and `endAt`;[^start-at-document]
- `select([List<FieldPath>])` and `getAll(List, [ReadOptions])`;
- `Transaction.get`, `getQuery`, `getAggregateQuery` and `getAll`;[^transaction-get-query]
- `taskQueue(name, {@Deprecated extensionId, scope})`;
- `FieldPath(List<String>)`;
- in Pipelines, `and(Iterable)`, `add(second, [others])`, and `collection(path)` next to `collectionReference(ref)`.

Some older APIs take an `Object` path, for example `where(Object path, ...)`, which accepts a `String` or a `FieldPath`.

# Why

The stated rule, in the Pipeline parity test: a `PipelineSource.collection` "Takes a path; a CollectionReference goes to collectionReference(), since Dart has no overloads", and "A Node rest parameter matches a trailing Dart `Iterable`".[^parity-no-overloads] For Pipelines, that test enforces it.

# Rules for agents

- **Must:** keep Dart's way. Port a Node overload as named variants, not as one `Object` parameter with runtime type checks.
- **Must not:** spread the older `Object`-path pattern to new APIs.

# Related

- [Named parameters for optional arguments and Pipeline options](/conventions/named-parameters-for-options.md)
- [No field-value-pairs form of update()](/firestore/update-field-value-pairs.md)
- [TypeScript object unions become sealed classes](/conventions/unions-to-sealed-classes.md)

[^where-filter]: `Query.whereFilter`
[^start-at-document]: `Query.startAtDocument`
[^transaction-get-query]: `Transaction.getQuery`
[^parity-no-overloads]: The parity test
