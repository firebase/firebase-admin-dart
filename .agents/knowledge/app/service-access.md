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
    title: "`getOrInitService`, the per-app service cache keyed by a string"
  - id: service-type
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_service.dart
    symbol: enum FirebaseServiceType
    title: The `FirebaseServiceType` enum, whose names the services register under
  - id: dartdoc-example
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_service.dart
    symbol: "'my-service',"
    title: The `FirebaseService` dartdoc example, which registers a raw string through a public factory
  - id: auth-internal
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth.dart
    symbol: factory Auth.internal(
    title: Auth's `@internal` cached factory and its sub-manager getters
  - id: node-get-auth
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/index.ts
    symbol: export function getAuth
    title: Node's top-level `getAuth(app?)`
  - id: node-tenant-manager
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/auth.ts
    symbol: "tenantManager(): TenantManager"
    title: Node's `tenantManager()` method
---

# Where it lives

- Enforced by: nothing; review only.
- The `app.x()` methods and the per-app cache: `getOrInitService` in `firebase_app.dart`.[^get-or-init]
- The names services register under: `FirebaseServiceType` in `firebase_service.dart`.[^service-type]
- The `@internal` factory and getter pattern: `Auth.internal` and the `tenantManager` getter in `auth.dart`.[^auth-internal]

# Node.js

Node has modular top-level accessors: `getAuth(app?)`, `getFirestore(app?|databaseId)` and so on. With no argument they use the default app. Each caches its service through `FirebaseApp.getOrInitService`, and the service constructors are `@internal`.[^node-get-auth] Sub-managers are methods: `auth.tenantManager()` and `auth.projectConfigManager()`.[^node-tenant-manager]

# Dart

Services are instance methods on `FirebaseApp`, backed by `@internal` cached factories. There are no public service constructors and no top-level `getAuth()`. Sub-managers are getters. A new service follows the checklist in [Product libraries, parts and barrel exports](/conventions/product-libraries-and-barrels.md).

**Trap:** `getOrInitService` accepts any string, and the `FirebaseService` dartdoc example registers `'my-service'` through a public factory.[^dartdoc-example] Every SDK service registers under its `FirebaseServiceType` name instead.

# Why

The maintainers' stated reason, in part: each app returns the same service instance instead of creating a new one on every call, and `FirebaseServiceType` replaces magic strings as service names.

The change that removed the public constructors and turned the service getters into methods gave no reason. The likely reasons (not recorded): one access path per service, and Node parity, since Node's service constructors are `@internal` too. Caching didn't require removing the constructors, since before their removal they were factories that went through `getOrInitService`.

Why Dart uses methods on the app instead of Node's top-level functions isn't recorded. Ask a maintainer before changing it.

# Rules for agents

- **Ask first:** before adding public service constructors. They were removed on purpose; the likely reason (not recorded) is Node parity, where the service constructors are `@internal`.
- **Must not:** register services with string names outside `FirebaseServiceType`. Don't copy the `FirebaseService` dartdoc example.
- **Ask first:** before adding Node-style top-level `getX()` functions. Why Dart chose methods isn't recorded.

# Related

- [Node-style app lifecycle and registry](/app/lifecycle.md)
- [Product libraries, parts and barrel exports](/conventions/product-libraries-and-barrels.md)
- [Firebase services Node has and Dart does not](/scope/unsupported-services.md)

[^node-get-auth]: Node's `getAuth`
[^node-tenant-manager]: Node's `tenantManager()`
[^get-or-init]: `getOrInitService`
[^service-type]: `FirebaseServiceType`
[^dartdoc-example]: The `FirebaseService` dartdoc example
[^auth-internal]: `Auth.internal`
