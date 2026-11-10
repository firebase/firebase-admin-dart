---
type: Divergence
title: Re-initializing an app ignores a different credential
description: A second `initializeApp` with a different credential or `httpClient` silently returns the existing app, where Node throws `invalid-app-options`.
tags: [app, lifecycle, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/app_options.dart
  - packages/firebase_admin_sdk/lib/src/app/app_registry.dart
sources:
  - id: app-options-equality
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/app_options.dart
    symbol: bool operator ==(Object other)
    title: "`AppOptions.==`, which ignores the credential and `httpClient`"
  - id: registry-initialize
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/app_registry.dart
    symbol: FirebaseApp initializeApp({AppOptions? options, String? name})
    title: The registry's re-initialization path
  - id: node-deep-equals
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/app/lifecycle.ts
    symbol: validateAppOptionsSupportDeepEquals
    title: Node rejects re-initialization with a credential or `httpAgent`
---

# Where it lives

- Enforced by: nothing; review only.
- What re-initialization compares: `AppOptions.==` in `app_options.dart`, which leaves out the credential and `httpClient`.[^app-options-equality]
- Where the registry uses it: `AppRegistry.initializeApp` in `app_registry.dart`.[^registry-initialize]

# Node.js

If an app with the given name exists and the new `initializeApp` call passes a `credential` or `httpAgent`, Node throws `invalid-app-options`, because the SDK cannot confirm that two `Credential` objects are equal.[^node-deep-equals]

# Dart

The registry decides whether a second `initializeApp` matches the first with `AppOptions.==`, which compares neither the credential nor `httpClient`. So a second `initializeApp` with a different credential or `httpClient` silently returns the existing app, which keeps the first call's credential and client.

# Why

The reason isn't recorded. Ask a maintainer before changing it.

# Rules for agents

- **Ask first:** before changing this behaviour, for example to throw `app/invalid-app-options` as Node does. Whether it is intended isn't recorded.

# Related

- [Node-style app lifecycle and registry](/app/lifecycle.md)

[^node-deep-equals]: Node's `validateAppOptionsSupportDeepEquals`
[^app-options-equality]: `AppOptions.==`
[^registry-initialize]: `AppRegistry.initializeApp`
