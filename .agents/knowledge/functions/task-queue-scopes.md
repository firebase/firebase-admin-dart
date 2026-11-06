---
type: Divergence
title: "Task Queue scopes: no extension self-targeting, private Kit"
description: The Task Queue scope port drops Node's own-extension self-targeting, keeps the Kit scope private and prints warnings with `print()`.
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
---

# Node.js

`taskQueue(name, extensionId)` checks `EXT_INSTANCE_ID` and `FIREBASE_KIT_INSTANCE_ID`. When a function targets its own extension or kit, Node rewrites the scope and logs a warning.[^node-ext-instance]

# Dart

Dart ports Node's scope logic, with three cuts:

- It checks `FIREBASE_KIT_INSTANCE_ID`, but drops the `EXT_INSTANCE_ID` branch for a function targeting its own extension.[^kit-instance-env]
- The Kit scope is private (`_KitFunctionScope`). There is no public `FunctionScope.kit`; the public factories are `current()`, `global()` and `extension(id)`.[^kit-scope]
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

- [TypeScript object unions become sealed classes](/conventions/unions-to-sealed-classes.md)
- [Overloads become separate methods; rest params become lists](/conventions/no-overloads-or-rest-params.md)

[^node-ext-instance]: Node's `taskQueue` self-targeting
[^kit-instance-env]: `FIREBASE_KIT_INSTANCE_ID`
[^kit-scope]: `_KitFunctionScope`
