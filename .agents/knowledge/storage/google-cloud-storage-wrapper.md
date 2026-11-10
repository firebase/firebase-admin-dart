---
type: Decision
title: Storage is a thin wrapper over google_cloud_storage
description: "`app.storage()` is a thin wrapper over Google's `package:google_cloud_storage`, adding only Firebase helpers such as the default bucket and `getDownloadURL`, and returning that package's types."
tags: [storage, dependencies, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/storage/**
  - packages/firebase_admin_sdk/pubspec.yaml
sources:
  - id: get-download-url
    resource: ../../../packages/firebase_admin_sdk/lib/src/storage/storage.dart
    symbol: Future<String> getDownloadURL(
    title: "`Storage.getDownloadURL(bucket, objectName)`"
  - id: bucket
    resource: ../../../packages/firebase_admin_sdk/lib/src/storage/storage.dart
    symbol: gcs.Bucket bucket([String? name])
    title: "`Storage.bucket()`, which falls back to `AppOptions.storageBucket`"
  - id: gcs-dependency
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "google_cloud_storage:"
    title: The `google_cloud_storage` version range
  - id: node-get-download-url
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/storage/index.ts
    symbol: getDownloadURL
    title: Node's top-level `getDownloadURL(file)`
---

# Where it lives

- Enforced by: nothing; review only.
- The Firebase helpers: `bucket()`, which falls back to `AppOptions.storageBucket` (in its body), and `getDownloadURL` (its dartdoc), in `storage.dart`.[^bucket][^get-download-url]
- The `google_cloud_storage` version range: the admin `pubspec.yaml`.[^gcs-dependency]

# Decision

`app.storage()` is a thin `FirebaseService` over Google's `package:google_cloud_storage`, adding only Firebase-specific helpers. Object operations belong to `google_cloud_storage`. The delegate is created lazily; see [Who closes which HTTP client](/app/http-client-ownership.md).

This repo has no GCS client of its own. An in-repo port of Node's `@google-cloud/storage` (with V2/V4 signed URLs and POST policies) was dropped in favour of Google's package. Users who need more, such as ranged or streamed downloads, use `FirebaseApp.client` with `googleapis`.

In Node, `getStorage().bucket()` returns a `@google-cloud/storage` `Bucket`, and `getDownloadURL(file)` is a top-level function that takes a `File`.[^node-get-download-url]

# Why

- The maintainers' stated position: use Google's `google_cloud_storage` instead of their own port. The version range was widened because the wrapper then relied on only three things: a no-argument `Storage` constructor, emulator settings from the environment, and `Storage.bucket(name)`; using more of the API might call for pinning the major version.
- The wrapper also passes `projectId:` and `client:` to the `Storage` constructor, so it relies on more than those three. Both parameters exist in every published version in the range. Whether to pin the range is undecided; ask a maintainer.
- The likely reason (not recorded): Google's Dart team owns `google_cloud_storage`, so a second GCS client in this repo would duplicate it.
- The likely reason `getDownloadURL` takes a bucket and an object name (not recorded): the Dart GCS package has no `File` object.

# Rules for agents

- **Must:** keep Dart's way. The object API belongs to `google_cloud_storage`, not this repo.
- **Must not:** vendor or re-port a GCS client.
- **Ask first:** before widening the `google_cloud_storage` range or relying on more of its API.

# Related

- [Storage emulator host set in the native process environment](/environment/storage-emulator-native-env.md)
- [Public authenticated app client and transport options](/app/app-client-and-transport-options.md)
- [Dependency constraint style](/dependencies/constraint-style.md)
- [Who closes which HTTP client](/app/http-client-ownership.md)

[^bucket]: `Storage.bucket()`
[^get-download-url]: `Storage.getDownloadURL`
[^node-get-download-url]: Node's `getDownloadURL`
[^gcs-dependency]: The `google_cloud_storage` range in the admin pubspec
