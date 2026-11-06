---
type: Decision
title: Dart idioms win where Node's shape does not fit
description: Where a Node API shape does not fit Dart, the Dart idiom is used and the difference is written down.
tags: [architecture, node-parity, api-design]
agents_md: always
governs:
  - packages/*/lib/**
sources:
  - id: sealed-credential
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/credential.dart
    symbol: sealed class Credential
    title: "`Credential`, a sealed class where Node has a union of factories"
  - id: auth-provider-config
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_config.dart
    symbol: sealed class AuthProviderConfig
    title: "`AuthProviderConfig`, a sealed class"
  - id: aps-sound
    resource: ../../../packages/firebase_admin_sdk/lib/src/messaging/messaging_api.dart
    symbol: sealed class ApsSound
    title: "`ApsSound`, a sealed class for Node's `string | CriticalSound`"
  - id: function-scope
    resource: ../../../packages/firebase_admin_sdk/lib/src/functions/functions_api.dart
    symbol: sealed class FunctionScope
    title: "`FunctionScope`, a sealed class"
  - id: pipeline-to-lower-case
    resource: ../../../packages/google_cloud_firestore/lib/src/pipeline.dart
    symbol: PipelineExpression toLowerCase()
    title: Pipeline's `toLowerCase()`, named after Dart's `String` method
---

# Decision

Node's source is the reference (see the Node port), but where its shape doesn't fit Dart, the Dart idiom wins and the difference is written down:

- TypeScript unions become sealed classes: `Credential`, `AuthProviderConfig`, `ApsSound` and `FunctionScope`.[^sealed-credential][^auth-provider-config][^aps-sound][^function-scope]
- Untyped option maps become typed options or named parameters. Pipeline execution options are typed; `rawOptions` sits beside them as a deliberate escape hatch.
- Docs say `Future` and `null`, not Promise and `undefined`.
- Dart `String` method names are kept where Node uses other names, such as Pipeline's `toLowerCase()` and `toUpperCase()`.[^pipeline-to-lower-case]
- Only the Node Admin SDK is the reference. Web-SDK-style synonyms such as `equalValue` are not added, because the Node Admin SDK has none of them.

A literal transliteration, with untyped maps and Node names, is the alternative this rejects.

# Why

The maintainers' stated reasons, case by case:

- `ApsSound` is a sealed type to match the Node Admin SDK's `string | CriticalSound` union.
- `toLowerCase()` and `toUpperCase()` deliberately keep Dart's `String` names.
- Pipeline execution options became typed because a wrong key failed silently. `rawOptions` was added on purpose alongside them.
- The docs were changed to use Dart terms instead of Node's.

The general rule isn't stated anywhere; it is inferred from these cases.

# Rules for agents

- **Must not:** add untyped `Map` option bags where Node has an options object. A deliberate escape hatch alongside typed options, such as the Pipeline `rawOptions`, is not this.
- **Must not:** copy names from the JS Web SDK. Only the Node Admin SDK is the reference.
- **Must not:** add a divergence to a Firestore Pipeline API without an entry and a reason in the parity tables.
- **Ask first:** outside Pipelines there is no table. Record the difference in the dartdoc and the CHANGELOG, and ask before adding a divergence that no idiom or divergence concept already covers.

# Related

- [Port of the Node.js Admin SDK](/architecture/node-port.md)
- [Pipelines parity with Node is checked by machine](/firestore/pipelines/node-parity.md)
- [Pipeline API mirrors Node with recorded exceptions](/firestore/pipelines/dart-surface.md)
- [Optional positionals and Pipeline options become named parameters](/conventions/named-parameters-for-options.md)
- [Node overloads become separate methods; rest parameters become lists](/conventions/no-overloads-or-rest-params.md)
- [TypeScript string unions become enums](/conventions/string-unions-to-enums.md)
- [TypeScript object unions become sealed classes](/conventions/unions-to-sealed-classes.md)
- [Dart core-library names replace Node member names](/conventions/dart-member-names.md)
- [Promises become Futures, async iterables become Streams](/conventions/futures-and-streams.md)

[^sealed-credential]: Sealed `Credential`
[^auth-provider-config]: Sealed `AuthProviderConfig`
[^aps-sound]: Sealed `ApsSound`
[^function-scope]: Sealed `FunctionScope`
[^pipeline-to-lower-case]: Pipeline `toLowerCase()`
