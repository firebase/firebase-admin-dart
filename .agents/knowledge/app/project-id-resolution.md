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
    symbol: String? resolveProjectIdSync(
    title: The synchronous resolver, with the order in its dartdoc
  - id: get-project-id
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: Future<String> getProjectId(
    title: The async resolver, which adds discovery
---

# Decision

Every service resolves the project ID through `FirebaseApp.resolveProjectIdSync()` and `getProjectId()`, in one fixed order:[^resolve-sync][^get-project-id]

1. an `environment` argument or a zone-injected environment (tests);
2. a `projectIdOverride` argument;
3. `AppOptions.projectId`;
4. the credential's service-account project;
5. non-empty `GOOGLE_CLOUD_PROJECT`-style environment variables;
6. the credentials file;
7. async discovery through `package:google_cloud` (the gcloud CLI and the GCE metadata server).

An injected environment replaces the process environment instead of layering on it: when one is supplied, `resolveProjectIdSync()` skips steps 5 and 6 and returns null after step 4.

`resolveProjectIdSync()` stops before step 7 and returns null when only discovery could answer. `getProjectId()` falls back to step 7.

An explicit credential outranks the ambient environment, so a service account for one project resolves to that project even on Google Cloud infrastructure that belongs to another.

Per-service discovery, such as an earlier `ProjectIdProvider`, was replaced by this shared resolver. The discovery sources themselves live upstream in `google_cloud`.

# Why

The maintainers' stated reason: apps configured with a service account for one project, while running on Google Cloud infrastructure in another, must resolve the service account's project instead of the host project. The shared resolver lets every service resolve a configured service account's project without a hop to the gcloud CLI or the metadata server.

# Rules for agents

- **Must not:** let ambient environment variables override an explicit credential's project.
- **Must not:** do async discovery on a synchronous construction path.
- **Must not:** add per-service discovery logic.
- **Must not:** treat an empty environment variable as a project ID.

# Related

- [Environment reads go through a zone override first](/environment/zone-injected-environment.md)
- [Generic Google-auth features live upstream, not in this repo](/architecture/upstream-generic-auth-features.md)
- [Port of the Node.js Admin SDK](/architecture/node-port.md)

[^resolve-sync]: `resolveProjectIdSync()`
[^get-project-id]: `getProjectId()`
