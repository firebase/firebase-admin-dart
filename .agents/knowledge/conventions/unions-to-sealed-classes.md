---
type: Divergence
title: TypeScript object unions become sealed classes
description: Node's object unions, intersections and runtime type tags become sealed class hierarchies used with pattern matching.
tags: [conventions, api-design, node-parity]
agents_md: reference
sources:
  - id: sealed-message
    resource: ../../../packages/firebase_admin_sdk/lib/src/messaging/messaging_api.dart
    symbol: sealed class Message
    title: "`sealed class Message`"
  - id: sealed-aps-sound
    resource: ../../../packages/firebase_admin_sdk/lib/src/messaging/messaging_api.dart
    symbol: sealed class ApsSound
    title: "`sealed class ApsSound`, Node's `string | CriticalSound`"
  - id: sealed-functions
    resource: ../../../packages/firebase_admin_sdk/lib/src/functions/functions_api.dart
    symbol: sealed class DeliverySchedule
    title: "`DeliverySchedule` and `FunctionScope`, with the exhaustiveness comment"
  - id: sealed-set-options
    resource: ../../../packages/google_cloud_firestore/lib/src/set_options.dart
    symbol: sealed class SetOptions
    title: "`sealed class SetOptions`"
  - id: parity-type-tags
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: sealed classes and `is`
    title: The parity test on dropped type tags
---

# Node.js

Node uses TypeScript object unions and intersections, plus runtime type tags:

- `Message = FidMessage | TokenMessage | TopicMessage | ConditionMessage`;
- `sound: string | CriticalSound`;
- `DeliverySchedule = DelayDelivery | AbsoluteDelivery`, and `TaskOptions = DeliverySchedule & ...`;
- transaction options `ReadWrite | ReadOnly`, and `SetOptions {merge | mergeFields}`;
- tags such as `expr.expressionType === 'Field'`.

# Dart

Dart uses sealed hierarchies:

- `sealed class Message` (`TokenMessage`, `TopicMessage`, `ConditionMessage`);[^sealed-message]
- `sealed class ApsSound` (`ApsSoundName`, `CriticalSound`);[^sealed-aps-sound]
- `sealed class DeliverySchedule`, inside `TaskOptions(schedule: …)`, and `sealed class FunctionScope`, with the factories `.current()`, `.global()` and `.extension(id)`;[^sealed-functions]
- `TransactionOptions`, `SetOptions`, `Filter`, `FieldMask`, `Credential` and `PipelineExpression`.[^sealed-set-options]

Type tags are dropped in favour of `is` and pattern matching. Subtypes are built with their own constructors, such as `TokenMessage(...)`, or with named factories.

# Why

The stated reasons:

- `ApsSound` is a sealed base type to match the Node.js Admin SDK's `string | CriticalSound` union.
- The parity test says Node properties that only exist for TypeScript runtime type tests are dropped, because Dart uses "its type system (sealed classes and `is`) instead".[^parity-type-tags]
- The comment on `DeliverySchedule` says it is a "sealed class, ensuring compile-time exhaustiveness checking".[^sealed-functions]

# Rules for agents

- **Must:** keep Dart's way. Model every new TypeScript union as a sealed class.
- **Must not:** add `type` or `expressionType` string tags.

# Related

- [Credential is a sealed class with factories](/app/credential-sealed-hierarchy.md)
- [String unions become enums mapped to the wire string](/conventions/string-unions-to-enums.md)
- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md)

[^sealed-message]: `sealed class Message`
[^sealed-aps-sound]: `sealed class ApsSound`
[^sealed-functions]: `DeliverySchedule` and `FunctionScope`
[^sealed-set-options]: `sealed class SetOptions`
[^parity-type-tags]: The parity test on type tags
