---
type: Divergence
title: Dart core-library names replace Node member names
description: Where Dart has a core-library equivalent (`toJson`, `==`, `close`, `String` method names), it replaces Node's member name, and Pipeline renames are recorded in the parity table.
tags: [conventions, naming, node-parity]
agents_md: reference
sources:
  - id: field-value-consts
    resource: ../../../packages/google_cloud_firestore/lib/src/field_value.dart
    symbol: static const FieldValue serverTimestamp
    title: "`FieldValue.delete` and `FieldValue.serverTimestamp` as const fields"
  - id: field-path-document-id
    resource: ../../../packages/google_cloud_firestore/lib/src/path.dart
    symbol: static final documentId
    title: "`FieldPath.documentId` as a static field"
  - id: pipeline-to-lower-case
    resource: ../../../packages/google_cloud_firestore/lib/src/pipeline.dart
    symbol: PipelineExpression toLowerCase()
    title: "`toLowerCase()`, with its rename note"
  - id: parity-renames
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: const _renames
    title: The Pipeline parity test's `_renames` table
---

# Node.js

- `toJSON()` and `isEqual(other)`;
- `deleteApp(app)`;
- `FieldValue.delete()` and `FieldValue.serverTimestamp()` as static methods, and `FieldPath.documentId()`;
- Pipeline `toLower()` and `toUpper()`;
- `Firestore.settings({...})` as a mutator.

# Dart

- `toJson()`, so `jsonEncode` works, and `operator ==` with `hashCode`;
- `app.close()`;
- `FieldValue.delete` and `FieldValue.serverTimestamp` as const fields,[^field-value-consts] and `FieldPath.documentId` as a static field;[^field-path-document-id]
- Pipeline `toLowerCase()` and `toUpperCase()`; the backend function is still `to_lower`;[^pipeline-to-lower-case]
- immutable `Settings`, passed to the constructor.

# Why

- Pipeline names: the stated reason is that `toLowerCase()` and `toUpperCase()` deliberately keep Dart's `String` names. The doc comment says it is "Named for Dart's `String.toLowerCase()` rather than the Node SDK's `toLower`; the backend function is still `to_lower`."[^pipeline-to-lower-case] The parity test's `_renames` table records every Pipeline member rename and enforces it;[^parity-renames] class and enum names are mapped in its `_classes` and `_enums` tables.
- The others: the likely reasons (not recorded) are that `jsonEncode` calls `toJson()`, and Dart's equality protocol is `operator ==` with `hashCode`.

# Rules for agents

- **Must:** keep Dart's way. Where Dart has a core-library equivalent (`String` methods, `==`, `toJson`, `close`), use the Dart name, and record the rename in the parity test if it is a Pipeline API: in `_renames` for a member, in `_classes` or `_enums` for a type.

# Related

- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md)
- [Pipeline API mirrors Node with recorded exceptions](/firestore/pipelines/dart-surface.md)
- [Mixed acronym casing (URL vs Url)](/conventions/acronym-casing.md)

[^field-value-consts]: `FieldValue` const fields
[^field-path-document-id]: `FieldPath.documentId`
[^pipeline-to-lower-case]: `PipelineExpression.toLowerCase()`
[^parity-renames]: The `_renames` table
