---
type: Divergence
title: Credential is a sealed class with factories
description: "`Credential` is a sealed class with service-account, ADC and refresh-token subtypes built through factories, where Node has top-level `cert()`, `applicationDefault()` and `refreshToken()` and a public `getAccessToken()`."
tags: [app, credentials, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/credential.dart
  - packages/firebase_admin_sdk/lib/src/firestore/firestore.dart
  - packages/firebase_admin_sdk/lib/firebase_admin_sdk.dart
sources:
  - id: sealed-credential
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/credential.dart
    symbol: sealed class Credential
    title: The sealed `Credential`, its factories and subtypes
  - id: adc-factory
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/credential.dart
    symbol: factory Credential.fromApplicationDefaultCredentials(
    title: The ADC factory, with its optional `serviceAccountId`
  - id: create-client
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/credential.dart
    symbol: Future<googleapis_auth.AuthClient> createClient(
    title: "`Credential.createClient`, the closest Dart equivalent of `getAccessToken()`"
  - id: barrel-hide
    resource: ../../../packages/firebase_admin_sdk/lib/firebase_admin_sdk.dart
    symbol: RefreshTokenCredential,
    title: The subtypes are hidden from the barrel
  - id: firestore-mapping
    resource: ../../../packages/firebase_admin_sdk/lib/src/firestore/firestore.dart
    symbol: Firestore requires ServiceAccountCredential or
    title: "`app.firestore()` maps the credential and rejects other subtypes"
  - id: node-factories
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/app/credential-factory.ts
    symbol: export function applicationDefault
    title: Node's top-level credential factories
  - id: node-get-access-token
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/app/credential.ts
    symbol: getAccessToken
    title: Node's public `Credential.getAccessToken()`
---

# Where it lives

- Enforced by: the compiler, for every `switch` over the sealed class. The `app.firestore()` mapping is an `if` chain that throws for unknown subtypes, so nothing flags it.[^firestore-mapping]
- The factories and subtypes: `sealed class Credential` in `credential.dart`.[^sealed-credential]
- The subtypes are kept out of the public API by the `hide` list in `firebase_admin_sdk.dart`.[^barrel-hide]
- `serviceAccountId` for Workload Identity Federation: `Credential.fromApplicationDefaultCredentials` in `credential.dart`.[^adc-factory]
- A client for any scopes: `Credential.createClient` in `credential.dart`.[^create-client]

# Node.js

Top-level factories `cert(pathOrObject, httpAgent?)`, `applicationDefault(httpAgent?)` and `refreshToken(pathOrObject, httpAgent?)` return a `Credential` interface. `applicationDefault()` is memoised in a single global, and `cert()` and `refreshToken()` are memoised globally by their JSON.[^node-factories]

`Credential.getAccessToken(): Promise<GoogleOAuthAccessToken>` is public.[^node-get-access-token]

# Dart

`Credential` is a sealed class with one subtype per credential source, built through factories that take a `File` or named parameters instead of Node's string-or-object union. Nothing is memoised globally.

- `serviceAccountId` on the ADC factory exists because Workload Identity Federation credential files have no `client_email` field, as the README explains.
- **Node gap:** `Credential` has no `getAccessToken()`. The closest is `createClient(scopes)`, which returns an authenticated client. A `getAccessToken()` was added once and removed before any release, together with the local `googleapis_auth_utils` package, and the removal gives no reason.

# Why

The maintainers' stated reason: `Credential` was reworked into a sealed class, where a credential is one of a known set of types, and its type is used to detect the project ID. The refresh-token subtype covers cases where the default ADC file location isn't enough.

The likely reason (not recorded) for a `File` or parameters instead of a union: Dart has no union types.

A `GoogleCredential` from the same short-lived `googleapis_auth_utils` package was dropped with it; see [Generic Google-auth features live upstream](/architecture/upstream-generic-auth-features.md). Why `getAccessToken()` went too isn't recorded.

# Rules for agents

- **Must:** keep Dart's way. A new credential source is a new factory and a new sealed subtype, and every `switch` over `Credential` must stay exhaustive.
- **Must:** when you add a subtype, also update the Firestore credential mapping in `app.firestore()`, which the compiler doesn't check.
- **Must not:** assume `serviceAccountCredentials` is non-null. It is null for ADC, WIF and refresh-token credentials.
- **Ask first:** before adding a public `getAccessToken()`, for Node parity or otherwise. Whether dropping it was deliberate isn't recorded.

# Related

- [Credential discovery when none is passed](/app/credential-autodiscovery.md)
- [Firestore is a standalone package](/firestore/standalone-package.md)
- [Sign locally with the key, else through IAM signBlob](/app/signing.md)
- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md)
- [Generic Google-auth features live upstream, not in this repo](/architecture/upstream-generic-auth-features.md)

[^node-factories]: Node's credential factories
[^node-get-access-token]: Node's `getAccessToken`
[^sealed-credential]: The sealed `Credential`
[^barrel-hide]: The barrel's `hide` list
[^adc-factory]: The ADC factory
[^create-client]: `Credential.createClient`
[^firestore-mapping]: `app.firestore()` credential mapping
