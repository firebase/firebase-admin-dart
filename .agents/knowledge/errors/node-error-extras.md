---
type: Divergence
title: Node's error extras are not ported
description: Node's `FirebaseError` has `httpResponse`, `cause`, `hasCode()` and a richer `toJSON()`, while Dart's `FirebaseAdminException` has none of them and its `toJson()` returns only `code` and `message`.
tags: [errors, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/exception.dart
sources:
  - id: admin-to-json
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/exception.dart
    symbol: Map<String, dynamic> toJson()
    title: "`FirebaseAdminException.toJson()`, with only `code` and `message`"
  - id: node-error
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/utils/error.ts
    symbol: hasCode
    title: Node's `FirebaseError` with `httpResponse`, `cause` and `hasCode()`
---

# Node.js

Node's `FirebaseError` has:[^node-error]

- `httpResponse`;
- `cause`;
- `hasCode(code)`, which accepts the code with or without the service prefix;
- a richer `toJSON()`.

# Dart

`FirebaseAdminException` has none of these. `toJson()` returns only `{code, message}`.[^admin-to-json]

This is a gap: nothing records a decision to leave them out.

# Why

The reason isn't recorded. Ask a maintainer before changing it.

# Rules for agents

- **Ask first:** before adding them. If they are added, follow Node's semantics with Dart names: `hasCode`, and `cause` as an `Object?`, possibly with a `StackTrace`.

# Related

- [Typed per-service admin exceptions with Node's error codes](/errors/admin-exceptions.md)

[^node-error]: Node's `FirebaseError`
[^admin-to-json]: `FirebaseAdminException.toJson()`
