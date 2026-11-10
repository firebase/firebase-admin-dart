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
    title: The `owner` bearer token on Auth and Cloud Tasks emulator requests
  - id: firestore-bearer-owner
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_http_client.dart
    symbol: "'Bearer owner'"
    title: The `owner` bearer token on Firestore emulator requests
  - id: storage-protocol-check
    resource: ../../../packages/firebase_admin_sdk/lib/src/storage/storage.dart
    symbol: FIREBASE_STORAGE_EMULATOR_HOST should not contain a protocol
    title: The `Storage` constructor's protocol check and its `FirebaseAppException`
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

# Where it lives

- Enforced by: nothing; review only.
- The variables and their lookups: `environment.dart` in each package.[^admin-env][^firestore-env]
- The `owner` bearer token on Auth, Firestore and Cloud Tasks emulator requests: `EmulatorClient` and `CloudTasksEmulatorClient` in the admin `emulator_client.dart`, and `google_cloud_firestore`'s own `EmulatorClient` in `firestore_http_client.dart`.[^bearer-owner][^firestore-bearer-owner]
- Revocation always checked under the emulator, as in Node: `checkRevoked || isEmulator` in `base_auth.dart`.[^check-revoked][^node-check-revoked]
- The Storage host's protocol check: the `Storage` constructor in `storage.dart`.[^storage-protocol-check]

# Decision

Emulators are found only through the standard Admin SDK environment variables, the same ones Node reads.[^node-auth-env] There is no `useEmulator(host, port)` API. App Check has no emulator.

When the variables are read differs, in both SDKs: `AuthHttpClient` and `FunctionsHttpClient` pick the emulator client once per instance, `Storage` decides in its constructor, and `verifyIdToken` checks for the Auth emulator on each call. How Auth and Functions treat a user-supplied `AppOptions.httpClient` under their emulators is in [Who closes which HTTP client](/app/http-clients.md).

**The Storage protocol error differs from Node's.** Both SDKs reject a host that contains `http://` or `https://`, with the same pattern and message.[^node-storage] Dart throws a `FirebaseAppException` with `app/failed-precondition`, whenever `FIREBASE_STORAGE_EMULATOR_HOST` is set. Node throws a `FirebaseStorageError` with `storage/invalid-emulator-host`, only when `STORAGE_EMULATOR_HOST` is unset.

**Trap:** `getDownloadURL` uses `app.client` under the Storage emulator too, so it sends real credentials to the emulator.

How the Storage emulator host reaches `google_cloud_storage`, and how that differs from Node, is in [Storage emulator host set in the native process environment](/storage/google-cloud-storage-wrapper.md). How tests override the variables is in [Environment reads go through a zone override first](/environment/zone-injected-environment.md).

# Why

The maintainers' stated reason: follow standard practice and the same process as the other Admin SDKs, which read the emulator host from an environment variable instead of setting host and port like the client SDKs do. Auto-detection from `FIREBASE_*_EMULATOR_HOST` replaced a manual `app.useEmulator()` call.

Rejected alternatives: host and port parameters, reading `firebase.json`, and hard-coded ports.

# Rules for agents

- **Must:** match Node for which variables are read.
- **Ask first:** before changing when a service reads them, which already differs between the two SDKs.
- **Must:** keep the zone and FFI mechanisms, and the `owner` bearer token.
- **Must not:** replace them with `Platform.environment`-only reads or a `useEmulator` API.
- **Must not:** add a host/port emulator API or read `firebase.json`.
- **Must not:** send real credentials to an emulator. Don't copy `getDownloadURL`.
- **Ask first:** before changing the Storage protocol error's type or code, for example to a `FirebaseStorageAdminException` with Node's `invalid-emulator-host`. Callers may catch the type that's thrown, and the Storage unit tests expect `FirebaseAppException`.

# Related

- [Environment reads go through a zone override first](/environment/zone-injected-environment.md)
- [Storage wraps google_cloud_storage; emulator via native env](/storage/google-cloud-storage-wrapper.md)
- [App HTTP client: public access, ownership and lazy creation](/app/http-clients.md)
- [Inject test doubles and use the guarded emulator helpers](/tests/helpers-and-injection.md)

[^admin-env]: The admin package's `Environment`
[^firestore-env]: Firestore's `Environment`
[^bearer-owner]: The admin `EmulatorClient` and `CloudTasksEmulatorClient`
[^firestore-bearer-owner]: Firestore's `EmulatorClient`
[^check-revoked]: Revocation check under the emulator
[^node-check-revoked]: Node's revocation check under the emulator
[^storage-protocol-check]: The `Storage` constructor's protocol check
[^node-auth-env]: Node's Auth emulator host
[^node-storage]: Node's `STORAGE_EMULATOR_HOST`
