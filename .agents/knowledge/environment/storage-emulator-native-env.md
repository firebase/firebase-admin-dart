---
type: Decision
title: Storage emulator host set in the native process environment
description: The Storage emulator host reaches `google_cloud_storage` through `STORAGE_EMULATOR_HOST`, written with FFI `setenv` and removed with `unsetenv` in production mode.
tags: [environment, emulators, storage]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/storage/**
  - packages/firebase_admin_sdk/lib/src/utils/native_environment.dart
sources:
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
- The FFI calls: `setenv` and `unsetenv`, with `SetEnvironmentVariableW` on Windows, in `native_environment.dart`.[^setenv][^unsetenv]
- When they run: the `Storage` constructor in `storage.dart`.[^storage-unset]

# Decision

The Storage emulator host reaches `google_cloud_storage` through the process environment variable `STORAGE_EMULATOR_HOST`. It is not passed as an argument.

When `FIREBASE_STORAGE_EMULATOR_HOST` is set, `Storage` writes its value into `STORAGE_EMULATOR_HOST` through FFI. In production mode, it removes the variable.

This differs from Node, which sets `STORAGE_EMULATOR_HOST` to `http://` plus the host only when it is unset, and never clears it.[^node-storage] Dart writes the bare host, always overwrites the variable, and unsets a user-supplied value whenever `FIREBASE_STORAGE_EMULATOR_HOST` is absent.

# Why

The maintainers' stated reason: match the approach the JavaScript SDK uses, and make sure the emulator is used by `Storage` instances created in other isolates. `Platform.environment` is immutable and cached, so the variable is read and written directly through FFI. The `unsetenv` in production mode stops the value leaking into later production `Storage` instances in the same process.

An integration that configured the emulator in Dart code was superseded by this one.

Whether changing the whole process environment through FFI is acceptable long term, or `google_cloud_storage` should accept emulator settings directly, is undecided; ask a maintainer.

# Rules for agents

- **Must not:** replace this with `Platform.environment` or zone overrides. `google_cloud_storage` reads the variable natively and bypasses zones.
- **Must not:** remove the `unsetenv` call in the production branch of the `Storage` constructor.

# Related

- [Emulators found only through standard environment variables](/environment/emulator-detection.md)
- [Storage is a thin wrapper over google_cloud_storage](/storage/google-cloud-storage-wrapper.md)
- [Server only: no web, no mobile](/scope/server-only.md)

[^setenv]: FFI `setenv`
[^unsetenv]: FFI `unsetenv`
[^storage-unset]: The `Storage` constructor
[^node-storage]: Node's `STORAGE_EMULATOR_HOST`
