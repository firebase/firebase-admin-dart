---
type: Decision
title: "Storage wraps google_cloud_storage; emulator via native env"
description: "`app.storage()` is a thin wrapper over Google's `package:google_cloud_storage`, adding only Firebase helpers such as the default bucket and `getDownloadURL`, and returning that package's types; the Storage emulator host reaches it through `STORAGE_EMULATOR_HOST`, written with FFI `setenv` and removed with `unsetenv` in production mode."
tags: [storage, dependencies, node-parity, environment, emulators]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/storage/**
  - packages/firebase_admin_sdk/pubspec.yaml
  - packages/firebase_admin_sdk/lib/src/utils/native_environment.dart
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
  - id: setenv
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/native_environment.dart
    symbol: "'setenv'"
    title: FFI `setenv`, with `SetEnvironmentVariableW` on Windows
  - id: unsetenv
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/native_environment.dart
    symbol: "'unsetenv'"
    title: FFI `unsetenv`
  - id: storage-unset
    resource: ../../../packages/firebase_admin_sdk/lib/src/storage/storage.dart
    symbol: unsetNativeEnvironmentVariable('STORAGE_EMULATOR_HOST')
    title: "`Storage` sets the variable when emulating and unsets it otherwise"
  - id: node-storage
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/storage/storage.ts
    symbol: STORAGE_EMULATOR_HOST
    title: Node's Storage emulator wiring
---

# Where it lives

- Enforced by: nothing; review only.
- The Firebase helpers: `bucket()`, which falls back to `app.options.storageBucket` (in its body), and `getDownloadURL` (its dartdoc), in `storage.dart`.[^bucket][^get-download-url]
- The `google_cloud_storage` version range: the admin `pubspec.yaml`.[^gcs-dependency]
- The FFI calls: `setenv` and `unsetenv`, with `SetEnvironmentVariableW` on Windows, in `native_environment.dart`.[^setenv][^unsetenv]
- When they run: the `Storage` constructor in `storage.dart`.[^storage-unset]

# Decision

## Thin wrapper over google_cloud_storage

`app.storage()` is a thin `FirebaseService` over Google's `package:google_cloud_storage`, adding only Firebase-specific helpers. Object operations belong to `google_cloud_storage`. The delegate is created lazily; see [Who closes which HTTP client](/app/http-clients.md).

This repo has no GCS client of its own. An in-repo port of Node's `@google-cloud/storage` (with V2/V4 signed URLs and POST policies) was dropped in favour of Google's package. Users who need more, such as ranged or streamed downloads, use `FirebaseApp.client` with `googleapis`.

In Node, `getStorage().bucket()` returns a `@google-cloud/storage` `Bucket`, and `getDownloadURL(file)` is a top-level function that takes a `File`.[^node-get-download-url]

## Emulator host in the native process environment

The Storage emulator host reaches `google_cloud_storage` through the process environment variable `STORAGE_EMULATOR_HOST`. It is not passed as an argument.

When `FIREBASE_STORAGE_EMULATOR_HOST` is set, `Storage` writes its value into `STORAGE_EMULATOR_HOST` through FFI. In production mode, it removes the variable.

This differs from Node, which sets `STORAGE_EMULATOR_HOST` to `http://` plus the host only when it is unset, and never clears it.[^node-storage] Dart writes the bare host, always overwrites the variable, and unsets a user-supplied value whenever `FIREBASE_STORAGE_EMULATOR_HOST` is absent.

# Why

## Thin wrapper over google_cloud_storage

- The maintainers' stated position: use Google's `google_cloud_storage` instead of their own port. The version range was widened because the wrapper then relied on only three things: a no-argument `Storage` constructor, emulator settings from the environment, and `Storage.bucket(name)`; using more of the API might call for pinning the major version.
- The wrapper also passes `projectId:` and `client:` to the `Storage` constructor, so it relies on more than those three. Both parameters exist in every published version in the range. Whether to pin the range is undecided; ask a maintainer.
- The likely reason (not recorded): Google's Dart team owns `google_cloud_storage`, so a second GCS client in this repo would duplicate it.
- The likely reason `getDownloadURL` takes a bucket and an object name (not recorded): the Dart GCS package has no `File` object.

## Emulator host in the native process environment

The maintainers' stated reason: match the approach the JavaScript SDK uses, and make sure the emulator is used by `Storage` instances created in other isolates. `Platform.environment` is immutable and cached, so the variable is read and written directly through FFI. The `unsetenv` in production mode stops the value leaking into later production `Storage` instances in the same process.

An integration that configured the emulator in Dart code was superseded by this one.

Whether changing the whole process environment through FFI is acceptable long term, or `google_cloud_storage` should accept emulator settings directly, is undecided; ask a maintainer.

# Rules for agents

- **Must:** keep Dart's way. The object API belongs to `google_cloud_storage`, not this repo.
- **Must not:** vendor or re-port a GCS client.
- **Ask first:** before widening the `google_cloud_storage` range or relying on more of its API.
- **Must not:** replace this with `Platform.environment` or zone overrides. `google_cloud_storage` reads the variable natively and bypasses zones.
- **Must not:** remove the `unsetenv` call in the production branch of the `Storage` constructor.

# Related

- [App HTTP client: public access, ownership and lazy creation](/app/http-clients.md)
- [Dependency constraints: bounds, consumers and the SDK floor](/dependencies/constraints.md)
- [Emulators found only through standard environment variables](/environment/emulator-detection.md)
- [Server only: no web, no mobile](/scope/server-only.md)

[^bucket]: `Storage.bucket()`
[^get-download-url]: `Storage.getDownloadURL`
[^node-get-download-url]: Node's `getDownloadURL`
[^gcs-dependency]: The `google_cloud_storage` range in the admin pubspec
[^setenv]: FFI `setenv`
[^unsetenv]: FFI `unsetenv`
[^storage-unset]: The `Storage` constructor
[^node-storage]: Node's `STORAGE_EMULATOR_HOST`
