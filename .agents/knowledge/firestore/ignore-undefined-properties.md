---
type: Divergence
title: Settings.ignoreUndefinedProperties is never read
description: Dart declares Node's `Settings.ignoreUndefinedProperties`, but nothing reads it and `null` is always written as `nullValue`.
tags: [firestore, settings, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/firestore.dart
  - packages/google_cloud_firestore/lib/src/serializer.dart
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
---

# Where it lives

- Enforced by: nothing; review only.
- The declared, unread setting: `Settings.ignoreUndefinedProperties` in `firestore.dart`.[^dart-setting]
- `null` encoded as `nullValue`: the `case null` branch of the serializer in `serializer.dart`.[^null-encoding]

# Node.js

In Node, a field set to `undefined` throws an error that suggests enabling `ignoreUndefinedProperties`. With the setting on, the field is skipped.[^node-setting] `null` is always written as `nullValue`.

# Dart

Dart declares `Settings.ignoreUndefinedProperties`, and its dartdoc describes it as being about `null`. Nothing reads it: it appears only in the constructor, `copyWith`, `==` and `hashCode`.[^dart-setting]

`null` is always encoded as `nullValue`, whatever the setting says.[^null-encoding]

# Why

The reason isn't recorded. Ask a maintainer before changing it.

The likely reason (not recorded): the field was ported from Node's `Settings` one for one, and Dart has no `undefined` for it to act on.

# Rules for agents

- **Ask first:** before giving this setting a behaviour or removing it.
- **Must not:** make `null` throw or be skipped. That would break Firestore's null semantics and diverge from Node, which writes `null`.

# Related

- [One cached Firestore per database, settings fixed](/firestore/multi-database.md), where a later change to this setting is ignored

[^node-setting]: Node's `ignoreUndefinedProperties`
[^dart-setting]: Dart's `Settings.ignoreUndefinedProperties`
[^null-encoding]: The serializer's `null` case
