---
type: Decision
title: Node-style app lifecycle and registry
description: Apps are created with `FirebaseApp.initializeApp({options, name})` into a named registry with Node's semantics and error codes, exposed as static members and closed with `app.close()`; unlike Node, re-initializing with a different credential or `httpClient` silently returns the existing app.
tags: [app, lifecycle, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/**
sources:
  - id: initialize-app
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: static FirebaseApp initializeApp(
    title: The static members of `FirebaseApp`, with their dartdoc
  - id: app-close
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: Future<void> close() async
    title: "`app.close()`, which deletes the services in a `try`/`finally`"
  - id: registry-initialize
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/app_registry.dart
    symbol: "Throws `FirebaseAppException` if:"
    title: The registry's re-initialization rules, in the `AppRegistry.initializeApp` dartdoc
  - id: firebase-config
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/app_registry.dart
    symbol: Loads app options from the FIREBASE_CONFIG environment variable.
    title: "`fetchOptionsFromEnvironment`: `FIREBASE_CONFIG` as inline JSON or a file path"
  - id: app-options-equality
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/app_options.dart
    symbol: bool operator ==(Object other)
    title: "`AppOptions.==`, which ignores the credential and `httpClient`"
  - id: registry-reinit
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/app_registry.dart
    symbol: FirebaseApp initializeApp({AppOptions? options, String? name})
    title: The registry's re-initialization path
  - id: node-deep-equals
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/app/lifecycle.ts
    symbol: validateAppOptionsSupportDeepEquals
    title: Node rejects re-initialization with a credential or `httpAgent`
  - id: node-lifecycle
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/app/lifecycle.ts
    symbol: export function initializeApp
    title: Node's app lifecycle
---

# Where it lives

- Enforced by: nothing; review only.
- The Dart surface: the static members of `FirebaseApp` in `firebase_app.dart`.[^initialize-app]
- Registry semantics: the dartdoc of `AppRegistry.initializeApp` in `app_registry.dart`; their codes, `app/duplicate-app` for different options and `app/invalid-app-options` for mixing a `FIREBASE_CONFIG` app with an explicit one: the throws in its body.[^registry-initialize]
- How `FIREBASE_CONFIG` is read: `fetchOptionsFromEnvironment` in `app_registry.dart`.[^firebase-config]
- Cleanup that survives a failing service: the `finally` block in `FirebaseApp.close`.[^app-close]
- What re-initialization compares: `AppOptions.==` in `app_options.dart`, which leaves out the credential and `httpClient`; the registry uses it in `AppRegistry.initializeApp` in `app_registry.dart`.[^app-options-equality][^registry-reinit]

# Decision

The app API keeps Node's semantics and error codes, with a Dart surface of static members on `FirebaseApp` and `app.close()` in place of Node's top-level functions and internal `delete()`.[^node-lifecycle]

One code differs: a `FIREBASE_CONFIG` that can't be read or parsed throws `app/invalid-argument` in Dart, where Node throws `app/invalid-app-options`. Re-initializing with a different credential also differs; see below.

This API replaced `FirebaseAdminApp.initializeApp(projectId, credential)` and its required positional arguments.

## Divergence: re-initializing ignores a different credential

- **Node.js:** if an app with the given name exists and the new `initializeApp` call passes a `credential` or `httpAgent`, Node throws `invalid-app-options`, because the SDK cannot confirm that two `Credential` objects are equal.[^node-deep-equals]
- **Dart:** the registry decides whether a second `initializeApp` matches the first with `AppOptions.==`, which compares neither the credential nor `httpClient`. So a second `initializeApp` with a different credential or `httpClient` silently returns the existing app, which keeps the first call's credential and client.

# Why

The maintainers' stated reason: align the app API with Node, so that, for example, `FirebaseApp.getApp('myApp')` works as in Node.js. The redesign closed specific gaps: no registry, services not cached, a project ID set by hand, no cleanup, manual emulator setup and no named apps.

The likely reason (not recorded) for static members and `close()`: Dart conventions. The public API has no free functions, and `close()` matches `http.Client.close`.

Why re-initialization ignores the credential isn't recorded. Ask a maintainer before changing it.

# Rules for agents

- **Must:** keep Dart's surface (static members, `app.close()`) and match Node for the semantics and error codes.
- **Must not:** reintroduce required positional project-ID or credential arguments.
- **Must not:** create services outside the app registry.
- **Must not:** let an app stay half-closed when a service fails to close.
- **Ask first:** before changing what re-initialization does with a different credential, for example to throw `app/invalid-app-options` as Node does. Whether it is intended isn't recorded.

# Related

- [Services only through app methods, no public constructors](/app/service-access.md)
- [App HTTP client: public access, ownership and lazy creation](/app/http-clients.md)

[^initialize-app]: `FirebaseApp`'s static members
[^node-lifecycle]: Node's `lifecycle.ts`
[^registry-initialize]: `AppRegistry.initializeApp`
[^firebase-config]: `fetchOptionsFromEnvironment`
[^app-close]: `app.close()`
[^app-options-equality]: `AppOptions.==`
[^registry-reinit]: `AppRegistry.initializeApp`
[^node-deep-equals]: Node's `validateAppOptionsSupportDeepEquals`
