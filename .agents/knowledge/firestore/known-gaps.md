---
type: Divergence
title: "Firestore gaps: ignoreUndefinedProperties, update() pairs"
description: "Dart declares Node's `Settings.ignoreUndefinedProperties`, but nothing reads it and `null` is always written as `nullValue`; Node's alternating `update(field, value, ...)` varargs form has no Dart equivalent, and Dart has only the map form."
tags: [firestore, settings, node-parity, writes]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/firestore.dart
  - packages/google_cloud_firestore/lib/src/serializer.dart
  - packages/google_cloud_firestore/lib/src/write_batch.dart
  - packages/google_cloud_firestore/lib/src/reference/document_reference.dart
  - packages/google_cloud_firestore/lib/src/transaction.dart
sources:
  - id: dart-setting
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore.dart
    symbol: final bool ignoreUndefinedProperties
    title: The Dart `Settings.ignoreUndefinedProperties` field
  - id: null-encoding
    resource: ../../../packages/google_cloud_firestore/lib/src/serializer.dart
    symbol: "firestore_v1.Value(nullValue: protobuf_v1.NullValue.nullValue)"
    title: "`null` always encoded as `nullValue`"
  - id: node-setting
    resource: https://github.com/googleapis/google-cloud-node/blob/main/handwritten/firestore/types/firestore.d.ts
    symbol: "ignoreUndefinedProperties?: boolean"
    title: Node's `ignoreUndefinedProperties` setting
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
- The declared, unread setting: `Settings.ignoreUndefinedProperties` in `firestore.dart`.[^dart-setting]
- `null` encoded as `nullValue`: the `case null` branch of the serializer in `serializer.dart`.[^null-encoding]
- The map-only `update`: `DocumentReference.update` in `document_reference.dart`.[^update-dartdoc]
- The intended shape: the `TODO` in `write_batch.dart`.[^write-batch-todo]

# Node.js

## Settings.ignoreUndefinedProperties is never read

In Node, a field set to `undefined` throws an error that suggests enabling `ignoreUndefinedProperties`. With the setting on, the field is skipped.[^node-setting] `null` is always written as `nullValue`.

## No field-value-pairs form of update()

`update(field, value, ...moreFieldsAndValues, precondition?)` takes field paths and values as alternating varargs, next to `update(map)`.[^node-update]

# Dart

## Settings.ignoreUndefinedProperties is never read

Dart declares `Settings.ignoreUndefinedProperties`, and its dartdoc describes it as being about `null`. Nothing reads it: it appears only in the constructor, `copyWith`, `==` and `hashCode`.[^dart-setting]

`null` is always encoded as `nullValue`, whatever the setting says.[^null-encoding]

## No field-value-pairs form of update()

Dart has only the map form. **Trap:** the `DocumentReference.update` dartdoc describes Node's varargs form, which Dart doesn't have.[^update-dartdoc]

# Why

## Settings.ignoreUndefinedProperties is never read

The reason isn't recorded. Ask a maintainer before changing it.

The likely reason (not recorded): the field was ported from Node's `Settings` one for one, and Dart has no `undefined` for it to act on.

## No field-value-pairs form of update()

The intended shape is stated in a `TODO` in `WriteBatch`: "support update(ref, List<(FieldPath, value)>)", a list of records.[^write-batch-todo] The field-value-pairs form is a gap.

# Rules for agents

- **Ask first:** before giving this setting a behaviour or removing it.
- **Must not:** make `null` throw or be skipped. That would break Firestore's null semantics and diverge from Node, which writes `null`.
- **Ask first:** before adding a field-value-pairs form. If you add one, take a `List<(FieldPath, Object?)>`, as the `TODO` suggests, rather than emulating varargs.

# Related

- [One cached Firestore per database, settings fixed](/firestore/multi-database.md), where a later change to this setting is ignored
- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md), which maps Node's overloads and rest parameters

[^node-setting]: Node's `ignoreUndefinedProperties`
[^dart-setting]: Dart's `Settings.ignoreUndefinedProperties`
[^null-encoding]: The serializer's `null` case
[^update-dartdoc]: `DocumentReference.update` and its dartdoc
[^write-batch-todo]: The `WriteBatch` TODO
[^node-update]: Node's varargs `update()`
