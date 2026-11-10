---
type: Divergence
title: No field-value-pairs form of update()
description: Node's alternating `update(field, value, ...)` varargs form has no Dart equivalent; Dart has only the map form.
tags: [firestore, writes, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/write_batch.dart
  - packages/google_cloud_firestore/lib/src/reference/document_reference.dart
  - packages/google_cloud_firestore/lib/src/transaction.dart
sources:
  - id: update-dartdoc
    resource: ../../../packages/google_cloud_firestore/lib/src/reference/document_reference.dart
    symbol: or a variable number of arguments
    title: "`DocumentReference.update`, map form only, with a dartdoc that describes Node's varargs form"
  - id: write-batch-todo
    resource: ../../../packages/google_cloud_firestore/lib/src/write_batch.dart
    symbol: // TODO support update(ref, List<(FieldPath, value)>)
    title: The TODO naming the intended list-of-records shape
  - id: node-update
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/dev/src/reference/document-reference.ts
    symbol: preconditionOrValues
    title: Node's varargs `update()`
---

# Where it lives

- Enforced by: nothing; review only.
- The map-only `update`: `DocumentReference.update` in `document_reference.dart`.[^update-dartdoc]
- The intended shape: the `TODO` in `write_batch.dart`.[^write-batch-todo]

# Node.js

`update(field, value, ...moreFieldsAndValues, precondition?)` takes field paths and values as alternating varargs, next to `update(map)`.[^node-update]

# Dart

Dart has only the map form. **Trap:** the `DocumentReference.update` dartdoc still describes Node's varargs form, which Dart doesn't have.[^update-dartdoc]

# Why

The intended shape is stated in a `TODO` in `WriteBatch`: "support update(ref, List<(FieldPath, value)>)", a list of records.[^write-batch-todo] The field-value-pairs form is a gap.

# Rules for agents

- **Ask first:** before adding a field-value-pairs form. If you add one, take a `List<(FieldPath, Object?)>`, as the `TODO` suggests, rather than emulating varargs.

# Related

- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md), which maps Node's overloads and rest parameters

[^update-dartdoc]: `DocumentReference.update` and its dartdoc
[^write-batch-todo]: The `WriteBatch` TODO
[^node-update]: Node's varargs `update()`
