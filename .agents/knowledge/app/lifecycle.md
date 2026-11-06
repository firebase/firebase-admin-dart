---
type: Decision
title: Node-style app lifecycle and registry
description: Apps are created with `FirebaseApp.initializeApp({options, name})` into a named registry with Node's semantics and error codes, exposed as static members and closed with `app.close()`.
tags: [app, lifecycle, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/**
sources:
  - id: initialize-app
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: static FirebaseApp initializeApp(
    title: "`FirebaseApp.initializeApp`, with only optional arguments"
  - id: delete-app
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: static Future<void> deleteApp(
    title: "`FirebaseApp.deleteApp`, which closes the app"
  - id: app-close
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: Future<void> close() async
    title: "`app.close()`, which deletes the services in a `try`/`finally`"
  - id: firebase-config
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/app_registry.dart
    symbol: env['FIREBASE_CONFIG']
    title: The registry reads `FIREBASE_CONFIG` as inline JSON or a file path
  - id: node-lifecycle
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/app/lifecycle.ts
    symbol: export function initializeApp
    title: Node's app lifecycle
---

# Decision

The app API keeps Node's semantics and error codes, with a Dart surface of static members on `FirebaseApp`:[^initialize-app][^node-lifecycle]

| Node | Dart |
| --- | --- |
| `initializeApp(options?, appName?)` | `FirebaseApp.initializeApp({AppOptions? options, String? name})` |
| `getApp(name?)` | `FirebaseApp.getApp([name])`, and `FirebaseApp.instance` for the default app |
| `getApps()` | `FirebaseApp.apps` (a getter) |
| `deleteApp(app)` | `FirebaseApp.deleteApp(app)`[^delete-app] |
| `FirebaseApp.delete()` (internal) | `app.close()` |

Semantics shared with Node:

- Every argument is optional. With no options, the app is configured from `FIREBASE_CONFIG`, read as inline JSON or as a file path, as Node does.[^firebase-config]
- Apps live in a named registry. Re-initializing with equal options returns the existing app. Different options throw `app/duplicate-app`. Mixing an auto-initialized app (from `FIREBASE_CONFIG`) with an explicit one throws `app/invalid-app-options`.
- One exception: re-initializing with a different credential or `httpClient` silently returns the existing app.
- `app.close()` deletes every service of the app and removes it from the registry.[^app-close] Its cleanup runs in a `finally` block, so a service that fails to close doesn't leave the app half-closed.

This API replaced `FirebaseAdminApp.initializeApp(projectId, credential)` and its required positional arguments.

# Why

The maintainers' stated reason: align the app API with Node, so that, for example, `FirebaseApp.getApp('myApp')` works as in Node.js. The redesign closed specific gaps: no registry, services not cached, a project ID set by hand, no cleanup, manual emulator setup and no named apps.

The likely reason (not recorded) for static members and `close()`: Dart conventions. The public API has no free functions, and `close()` matches `http.Client.close`.

# Rules for agents

- **Must:** keep Dart's surface (static members, `app.close()`) and match Node for the semantics and error codes.
- **Must not:** reintroduce required positional project-ID or credential arguments.
- **Must not:** create services outside the app registry.
- **Must not:** let an app stay half-closed when a service fails to close.

# Related

- [Re-initializing an app ignores a different credential](/app/reinit-ignores-credential.md)
- [Services only through app methods, no public constructors](/app/service-access.md)
- [Who closes which HTTP client, and lazy client creation](/app/http-client-ownership.md)

[^initialize-app]: `FirebaseApp.initializeApp`
[^node-lifecycle]: Node's `lifecycle.ts`
[^firebase-config]: `FIREBASE_CONFIG` parsing
[^delete-app]: `FirebaseApp.deleteApp`
[^app-close]: `app.close()`
