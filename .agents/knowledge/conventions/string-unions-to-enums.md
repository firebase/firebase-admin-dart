---
type: Divergence
title: String unions become enums mapped to the wire string
description: Node's string-literal unions become Dart enums that map to the wire string, with a few existing exceptions that take plain strings.
tags: [conventions, api-design, node-parity]
agents_md: reference
sources:
  - id: where-filter
    resource: ../../../packages/google_cloud_firestore/lib/src/filter.dart
    symbol: enum WhereFilter
    title: "`WhereFilter`, mapped through a proto getter"
  - id: aps-interruption-level
    resource: ../../../packages/firebase_admin_sdk/lib/src/messaging/messaging_api.dart
    symbol: enum ApsInterruptionLevel
    title: "`ApsInterruptionLevel`, serialised as `\"time-sensitive\"` and so on"
  - id: auth-factor-type
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_config_tenant.dart
    symbol: typedef AuthFactorType = String;
    title: "`AuthFactorType`, a plain-string exception"
  - id: parity-string-union
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: A Node string union maps onto
    title: The parity test's string-union rule and its plain-string exceptions
---

# Node.js

Node uses string-literal unions: `WhereFilterOp` (`'<'`, `'=='`, `'array-contains'`, …), `OrderByDirection`, the APNs `'time-sensitive'` interruption level, the Pipeline `Type`, and the Android priority strings.

# Dart

Dart uses enums that map to the wire string:

- `WhereFilter.lessThan`, `WhereFilter.isIn` and so on;[^where-filter]
- `ApsInterruptionLevel.timeSensitive`, serialised as `"time-sensitive"`;[^aps-interruption-level]
- `PipelineValueType`, compared by its `value`;
- `AndroidConfigPriority` and `MultiFactorConfigState`.

Existing enums map in different ways: `WhereFilter` through a proto getter, `ApsInterruptionLevel` through a switch, and `AndroidConfigPriority` through `toString()`.

A few APIs are exceptions and take plain strings: `typedef AuthFactorType = String`,[^auth-factor-type] and the Pipeline `TimeUnit`, `TimePart` and `TimeGranularity`.[^parity-string-union] Why `AuthFactorType` is a string isn't recorded; ask a maintainer.

# Why

The stated rule, in the Pipeline parity test: "A Node string union maps onto the `value`s of a Dart enum"; the exceptions are listed there as "Dart takes these as plain strings (Object?)".[^parity-string-union] The enum for the APNs `interruption-level` was also a stated choice. For Pipelines, the parity test enforces the rule.

# Rules for agents

- **Must:** keep Dart's way. Use an enum that maps to the wire string.
- **Ask first:** where an existing API takes a raw string, before converting it to an enum. That's a breaking change.

# Related

- [TypeScript object unions become sealed classes](/conventions/unions-to-sealed-classes.md)
- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md)

[^where-filter]: `WhereFilter`
[^aps-interruption-level]: `ApsInterruptionLevel`
[^auth-factor-type]: `AuthFactorType`
[^parity-string-union]: The parity test's string-union rule
