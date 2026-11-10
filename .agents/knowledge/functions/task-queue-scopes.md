---
type: Divergence
title: "Task Queue scopes: no extension self-targeting, private Kit"
description: The Task Queue scope port never reads `EXT_INSTANCE_ID`, so it drops Node's own-extension handling, keeps the Kit scope private and prints warnings with `print()`.
tags: [functions, task-queue, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/functions/**
sources:
  - id: kit-scope
    resource: ../../../packages/firebase_admin_sdk/lib/src/functions/functions_api.dart
    symbol: class _KitFunctionScope
    title: The private Kit scope
  - id: kit-instance-env
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/environment.dart
    symbol: FIREBASE_KIT_INSTANCE_ID
    title: "`Environment.getKitInstanceId()`"
  - id: node-ext-instance
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/functions/functions.ts
    symbol: EXT_INSTANCE_ID
    title: Node's extension and kit self-targeting
  - id: node-current-scope
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/functions/functions-api-client-internal.ts
    symbol: private resolveResourceId(
    title: Node's `current` scope, which prefixes the queue inside an extension or kit
---

# Where it lives

- Enforced by: nothing; review only.
- The public scopes and the private Kit scope: `FunctionScope` and `_KitFunctionScope` in `functions_api.dart`.[^kit-scope]
- The Kit variable: `FIREBASE_KIT_INSTANCE_ID` in `app/environment.dart`. Nothing reads `EXT_INSTANCE_ID`.[^kit-instance-env]

# Node.js

`taskQueue(name, extensionId)` checks `EXT_INSTANCE_ID` and `FIREBASE_KIT_INSTANCE_ID`. When a function targets its own extension or kit, Node rewrites the scope and logs a warning.[^node-ext-instance]

The `current()` scope also reads both variables: it prefixes the queue with `ext-<EXT_INSTANCE_ID>-` inside an extension, or `kit-<FIREBASE_KIT_INSTANCE_ID>-` inside a kit.[^node-current-scope]

# Dart

Dart ports Node's scope logic, with three cuts:

- It never reads `EXT_INSTANCE_ID`. It drops both Node branches that use it: the `taskQueue` rewrite for a function targeting its own extension, and the `ext-<EXT_INSTANCE_ID>-` queue prefix that Node's `current` scope adds inside an extension. It keeps the `FIREBASE_KIT_INSTANCE_ID` checks.
- The Kit scope is private. There is no public `FunctionScope.kit`.
- The self-targeting warning is printed with `print()`.

These are deliberate omissions.

# Why

The maintainers' stated reasons:

- The own-extension cases are left out because Firebase Extensions don't use the Dart runtime.
- Kit is not a public feature, or a public name, so it stays out of the public contract. Annotating a public `FunctionScope.kit` with `@internal` was the other option offered; a private class was chosen.
- The SDK uses no logging package, and prints warnings with plain `print()` statements.

The port also flattens Node's error-handling flows, for readability.

# Rules for agents

- **Must:** keep Dart's way.
- **Must not:** export the Kit scope before Firebase announces it.
- **Must not:** add a logging dependency for a one-off warning.

# Related

- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md)

[^node-ext-instance]: Node's `taskQueue` self-targeting
[^node-current-scope]: Node's `current` scope
[^kit-instance-env]: `FIREBASE_KIT_INSTANCE_ID`
[^kit-scope]: `_KitFunctionScope`
