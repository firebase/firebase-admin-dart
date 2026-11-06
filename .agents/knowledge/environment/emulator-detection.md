---
type: Decision
title: Emulators found only through standard environment variables
description: Emulators are found only through the standard Admin SDK `*_EMULATOR_HOST` variables, as in Node, with no `useEmulator()` API and `Bearer owner` on Auth, Firestore and Cloud Tasks emulator requests.
tags: [environment, emulators, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/environment.dart
  - packages/firebase_admin_sdk/lib/src/app/emulator_client.dart
  - packages/firebase_admin_sdk/lib/src/*/*_http_client.dart
  - packages/google_cloud_firestore/lib/src/environment.dart
  - packages/google_cloud_firestore/lib/src/firestore_http_client.dart
sources:
  - id: admin-env
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/environment.dart
    symbol: "'FIREBASE_AUTH_EMULATOR_HOST'"
    title: The admin package's emulator variables and lookups
  - id: firestore-env
    resource: ../../../packages/google_cloud_firestore/lib/src/environment.dart
    symbol: "'FIRESTORE_EMULATOR_HOST'"
    title: Firestore's emulator lookup
  - id: bearer-owner
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/emulator_client.dart
    symbol: "'Bearer owner'"
    title: The `owner` bearer token on emulator requests
  - id: check-revoked
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/base_auth.dart
    symbol: if (checkRevoked || isEmulator)
    title: Revocation is always checked under the Auth emulator
  - id: node-auth-env
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/auth-api-request.ts
    symbol: FIREBASE_AUTH_EMULATOR_HOST
    title: Node reads the Auth emulator host from the environment
  - id: node-check-revoked
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/base-auth.ts
    symbol: if (checkRevoked || isEmulator)
    title: Node always checks revocation under the Auth emulator
  - id: node-storage
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/storage/storage.ts
    symbol: STORAGE_EMULATOR_HOST
    title: Node's Storage emulator wiring
---

# Decision

Emulators are found only through the standard Admin SDK environment variables:[^admin-env][^firestore-env]

- `FIREBASE_AUTH_EMULATOR_HOST`
- `FIRESTORE_EMULATOR_HOST`
- `FIREBASE_STORAGE_EMULATOR_HOST`
- `CLOUD_TASKS_EMULATOR_HOST`

There is no `useEmulator(host, port)` API. Auth, Firestore and Cloud Tasks emulator requests carry `Authorization: Bearer owner`,[^bearer-owner] except that Auth and Functions use `AppOptions.httpClient` as is when it is set. Storage emulator requests go through `google_cloud_storage`'s own unauthenticated client, and `getDownloadURL` uses `app.client`. App Check has no emulator.

This matches Node in which variables are read. When they are read varies, in both SDKs: `AuthHttpClient` and `FunctionsHttpClient` pick the emulator client once per instance, `Storage` decides in its constructor, and `verifyIdToken` checks for the Auth emulator on each call. In the emulator, `verifyIdToken` always checks revocation (`checkRevoked || isEmulator`), as in Node.[^check-revoked][^node-check-revoked][^node-auth-env]

Both SDKs reject a `FIREBASE_STORAGE_EMULATOR_HOST` that contains `http://` or `https://`, with the same pattern and message. The error differs:[^node-storage]

- Dart: the `Storage` constructor throws a `FirebaseAppException` with `app/failed-precondition`. It runs the check whenever `FIREBASE_STORAGE_EMULATOR_HOST` is set.
- Node: it throws a `FirebaseStorageError` with `storage/invalid-emulator-host`. It runs the check only when `STORAGE_EMULATOR_HOST` is unset.

Dart adds two mechanisms:

1. Every lookup first consults a zone-injected environment (`Zone.current[envSymbol]`). Firestore also accepts `Settings.environmentOverride`, which its dartdoc describes as being for testing.
2. Storage writes `STORAGE_EMULATOR_HOST` into the native process environment through FFI (`setenv` and `unsetenv`, or `SetEnvironmentVariableW` on Windows), and unsets it when not emulating.

Storage differs from Node there. Node sets `STORAGE_EMULATOR_HOST` to `http://` plus the host only when `STORAGE_EMULATOR_HOST` is unset, and never clears it.[^node-storage] Dart writes the bare host, always overwrites the variable, and unsets a user-supplied value whenever `FIREBASE_STORAGE_EMULATOR_HOST` is absent.

# Why

The maintainers' stated reason: follow standard practice and the same process as the other Admin SDKs, which read the emulator host from an environment variable instead of setting host and port like the client SDKs do. Auto-detection from `FIREBASE_*_EMULATOR_HOST` replaced a manual `app.useEmulator()` call. Storage uses environment variables to match the JavaScript approach, and so that `Storage` instances created in other isolates use the emulator too.

Rejected alternatives: host and port parameters, reading `firebase.json`, and hard-coded ports.

# Rules for agents

- **Must:** match Node for which variables are read.
- **Ask first:** before changing when a service reads them, which already differs between the two SDKs.
- **Must:** keep the zone and FFI mechanisms, and the `owner` bearer token.
- **Must not:** replace them with `Platform.environment`-only reads or a `useEmulator` API.
- **Must not:** add a host/port emulator API or read `firebase.json`.
- **Must not:** send real credentials to an emulator. `getDownloadURL` does, since it uses `app.client` under the Storage emulator too; don't copy it.
- **Ask first:** before changing the Storage protocol error's type or code, for example to a `FirebaseStorageAdminException` with Node's `invalid-emulator-host`. Callers may catch the type that's thrown, and the Storage unit tests expect `FirebaseAppException`.

# Related

- [Environment reads go through a zone override first](/environment/zone-injected-environment.md)
- [Storage emulator host set in the native process environment](/environment/storage-emulator-native-env.md)
- [What emulator tests need](/tests/emulator-requirements.md)

[^admin-env]: The admin package's `Environment`
[^firestore-env]: Firestore's `Environment`
[^bearer-owner]: `EmulatorClient`
[^check-revoked]: Revocation check under the emulator
[^node-auth-env]: Node's Auth emulator host
[^node-check-revoked]: Node's revocation check under the emulator
[^node-storage]: Node's `STORAGE_EMULATOR_HOST`
