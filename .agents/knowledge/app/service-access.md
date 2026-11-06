---
type: Divergence
title: Services only through app methods, no public constructors
description: Services are reached through instance methods such as `app.auth()` backed by `@internal` cached factories, with no public constructors and no Node-style top-level `getAuth()`.
tags: [app, services, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
  - packages/firebase_admin_sdk/lib/src/app/firebase_service.dart
  - packages/firebase_admin_sdk/lib/src/auth.dart
  - packages/firebase_admin_sdk/lib/src/app_check/app_check.dart
  - packages/firebase_admin_sdk/lib/src/functions/functions.dart
  - packages/firebase_admin_sdk/lib/src/messaging/messaging.dart
  - packages/firebase_admin_sdk/lib/src/security_rules/security_rules.dart
  - packages/firebase_admin_sdk/lib/src/storage/storage.dart
  - packages/firebase_admin_sdk/lib/src/firestore/firestore.dart
sources:
  - id: get-or-init
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: T getOrInitService<T extends FirebaseService>(
    title: "`getOrInitService`, the per-app service cache"
  - id: service-type
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_service.dart
    symbol: enum FirebaseServiceType
    title: The `FirebaseServiceType` enum, whose names the services register under
  - id: auth-internal
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth.dart
    symbol: factory Auth.internal(
    title: Auth's `@internal` cached factory
  - id: tenant-manager
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth.dart
    symbol: TenantManager get tenantManager
    title: The `tenantManager` getter
  - id: node-get-auth
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/index.ts
    symbol: export function getAuth
    title: Node's top-level `getAuth(app?)`
  - id: node-tenant-manager
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/auth.ts
    symbol: "tenantManager(): TenantManager"
    title: Node's `tenantManager()` method
---

# Node.js

Node has modular top-level accessors: `getAuth(app?)`, `getFirestore(app?|databaseId)` and so on. With no argument they use the default app. Each caches its service through `FirebaseApp.getOrInitService`, and the service constructors are `@internal`.[^node-get-auth] Sub-managers are methods: `auth.tenantManager()` and `auth.projectConfigManager()`.[^node-tenant-manager]

# Dart

Services are instance methods on `FirebaseApp`: `app.auth()`, `app.firestore({settings, databaseId})`, `app.messaging()` and so on. The default app is `FirebaseApp.instance`. There are no public service constructors and no top-level `getAuth()`.

Each method calls an `@internal factory X.internal(app)`, which caches one instance per app through `getOrInitService(String name, …)`.[^get-or-init][^auth-internal] The cache is keyed by that string, and `getOrInitService` accepts any string. Every SDK service registers under its `FirebaseServiceType` name, such as `FirebaseServiceType.auth.name`.[^service-type] The `FirebaseService` dartdoc example doesn't: it registers `'my-service'` through a public factory.

Sub-managers are getters: `auth.tenantManager` and `auth.projectConfigManager`.[^tenant-manager]

# Why

The maintainers' stated reason, in part: each app returns the same service instance instead of creating a new one on every call, and `FirebaseServiceType` replaces magic strings as service names.

The change that removed the public constructors and turned the service getters into methods gave no reason. The likely reasons (not recorded): one access path per service, and Node parity, since Node's service constructors are `@internal` too. Caching didn't require removing the constructors, since before their removal they were factories that went through `getOrInitService`.

Why Dart uses methods on the app instead of Node's top-level functions isn't recorded. Ask a maintainer before changing it.

# Rules for agents

- **Must:** give a new service an `X app.x()` method plus an `@internal factory X.internal(FirebaseApp)` that goes through `getOrInitService` with a new `FirebaseServiceType` value's `name`.
- **Ask first:** before adding public service constructors. They were removed on purpose; the likely reason (not recorded) is Node parity, where the service constructors are `@internal`.
- **Must not:** register services with string names outside `FirebaseServiceType`. Don't copy the `FirebaseService` dartdoc example, which uses `'my-service'` and a public factory.
- **Ask first:** before adding Node-style top-level `getX()` functions. Why Dart chose methods isn't recorded.

# Related

- [Node-style app lifecycle and registry](/app/lifecycle.md)
- [Firebase services Node has and Dart does not](/scope/unsupported-services.md)

[^node-get-auth]: Node's `getAuth`
[^node-tenant-manager]: Node's `tenantManager()`
[^get-or-init]: `getOrInitService`
[^service-type]: `FirebaseServiceType`
[^auth-internal]: `Auth.internal`
[^tenant-manager]: The `tenantManager` getter
