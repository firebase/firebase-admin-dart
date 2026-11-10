---
type: Decision
title: One fixed project-ID resolution order
description: All services resolve the project ID in one fixed order through `FirebaseApp.resolveProjectIdSync()` and `getProjectId()`, with explicit configuration before ambient environment and async discovery last.
tags: [app, project-id, credentials]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/**
  - packages/firebase_admin_sdk/lib/src/*/*_http_client.dart
sources:
  - id: resolve-sync
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: Covers every source that can be read synchronously
    title: The `resolveProjectIdSync` dartdoc, with the order and Node's `getExplicitProjectId`
  - id: get-project-id
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: Future<String> getProjectId(
    title: The async resolver, which adds discovery
  - id: env-non-empty
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: if (value != null && value.isNotEmpty) return value;
    title: "`_projectIdFromEnvironment` skips empty variables"
  - id: stale-getter-doc
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: ProjectIdProvider.discoverProjectId()
    title: The `projectId` getter's dartdoc, which names the removed `ProjectIdProvider`
---

# Where it lives

- Enforced by: nothing; review only.
- The order, how an injected environment replaces the process environment, and the sync/async split: the dartdoc of `resolveProjectIdSync` in `firebase_app.dart`.[^resolve-sync]
- Async discovery last: `getProjectId` in `firebase_app.dart`, through `package:google_cloud`.[^get-project-id]
- Empty variables are skipped: `_projectIdFromEnvironment` in `firebase_app.dart`.[^env-non-empty]

# Decision

Every service resolves the project ID through `FirebaseApp.resolveProjectIdSync()` and `getProjectId()`. An explicit credential outranks the ambient environment.

Per-service discovery, such as an earlier `ProjectIdProvider`, was replaced by this shared resolver. The discovery sources themselves live upstream in `google_cloud`.

**Trap:** the dartdoc of the `projectId` getter still tells services to use `ProjectIdProvider.discoverProjectId()`, which no longer exists.[^stale-getter-doc] Use the resolver.

# Why

The maintainers' stated reason: apps configured with a service account for one project, while running on Google Cloud infrastructure in another, must resolve the service account's project instead of the host project. The shared resolver lets every service resolve a configured service account's project without a hop to the gcloud CLI or the metadata server.

# Rules for agents

- **Must not:** let ambient environment variables override an explicit credential's project.
- **Must not:** do async discovery on a synchronous construction path.
- **Must not:** add per-service discovery logic.

# Related

- [Environment reads go through a zone override first](/environment/zone-injected-environment.md)
- [Generic Google-auth features live upstream, not in this repo](/architecture/upstream-generic-auth-features.md)
- [Port of the Node.js Admin SDK](/architecture/node-port.md)

[^resolve-sync]: The `resolveProjectIdSync()` dartdoc
[^get-project-id]: `getProjectId()`
[^env-non-empty]: `_projectIdFromEnvironment`
[^stale-getter-doc]: The `projectId` getter's dartdoc
