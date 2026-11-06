---
type: Divergence
title: Pipeline API mirrors Node with recorded exceptions
description: The Dart Pipeline API mirrors Node's `FirebaseFirestore.Pipelines` namespace, and every rename, type mapping, alias, Dart-only member and known difference is recorded in the parity tables.
tags: [firestore, pipelines, api-shape, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/pipeline.dart
  - packages/google_cloud_firestore/lib/google_cloud_firestore.dart
  - packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
sources:
  - id: renames
    resource: ../../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: const _renames
    title: "`_renames`: Node members Dart spells differently"
  - id: dart-only
    resource: ../../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: const _dartOnly
    title: "`_dartOnly`: public Dart members with no Node counterpart"
  - id: flutterfire-aliases
    resource: ../../../../packages/google_cloud_firestore/lib/src/pipeline.dart
    symbol: FlutterFire-style entry points
    title: The FlutterFire-style entry points and aliases
  - id: node-expression
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/pipelines/expression.ts
    symbol: export abstract class Expression
    title: Node's `Expression` class hierarchy
---

# Node.js

Node's `FirebaseFirestore.Pipelines` namespace has top-level functions, an `Expression` class hierarchy (`Constant`, `FunctionExpression`, `Field`, …) and option objects.[^node-expression]

# Dart

Dart mirrors that namespace. Every exception is an entry in a table in `pipeline_api_parity_test.dart`.[^renames][^dart-only] `_dartOnly`, `_knownDifferences` and `_pendingFixes` give a reason for every entry; `_renames` and `_classes` give one only where a comment does.

The tables are the full list relative to the pinned Node release (`_nodeVersion` in the same file). APIs added in later Node releases, such as the `insert` and `upsert` stages, appear only when the pin is bumped.

| Table | What it records | Example |
| --- | --- | --- |
| `_renames` | Node members that Dart spells differently | `Transaction.execute` is `executePipeline` |
| `_classes` | The Dart type that stands for each Node class | Node's implementation classes are private in Dart |
| `_enums` | The Dart enum that stands for each Node string union | `Type` is `PipelineValueType` |
| `_optionTypes` | Dart types that Node models as option objects or inline string unions | `PipelineExplainOptions`, used by `PipelineExecuteOptions.explainOptions` |
| `_dartOnly` | Public Dart members with no Node counterpart | the `raw` escape hatches |
| `_knownDifferences` | Deliberate signature differences | `count()` with no argument |

Node APIs that Dart lacks are in `_pendingFixes`; see [Pipeline APIs Node has that Dart lacks](/firestore/pipelines/missing-node-apis.md).

`pipeline.dart` also has "FlutterFire-style" entry points and aliases, such as `Expression`, `BooleanExpression` and `Ordering`.[^flutterfire-aliases]

Names that exist only in the JS Web SDK, such as `equalValue` and `eqValue`, are not part of the API.

# Why

The maintainers' stated reasons are in the tables, where an entry has one. For the Web SDK names, the stated reason is that they come from the JS Web SDK and the Node Admin SDK has none of them. The reference is the Node Admin SDK, not the Web SDK.

# Rules for agents

- **Must:** match Node by default. A deliberate difference needs an entry in the right table, with its reason.

# Related

- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md)
- [Dart core-library names replace Node member names](/conventions/dart-member-names.md)
- [Pipeline API snapshot extracted from Node's typings](/generated/pipeline-api-snapshot.md)
- [Firestore follows Node, not FlutterFire](/firestore/node-not-flutterfire.md)

[^node-expression]: Node's `Expression` class hierarchy
[^renames]: `_renames`
[^dart-only]: `_dartOnly`
[^flutterfire-aliases]: The FlutterFire-style entry points and aliases
