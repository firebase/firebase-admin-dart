---
type: Divergence
title: Credential is a sealed class with factories
description: "`Credential` is a sealed class with service-account, ADC and refresh-token subtypes built through factories, where Node has top-level `cert()`, `applicationDefault()` and `refreshToken()`."
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
    title: The sealed `Credential` and its factories
  - id: adc-factory
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/credential.dart
    symbol: factory Credential.fromApplicationDefaultCredentials(
    title: The ADC factory, with its optional `serviceAccountId`
  - id: refresh-token-subtype
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/credential.dart
    symbol: final class RefreshTokenCredential extends Credential
    title: The refresh-token subtype
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
---

# Node.js

Top-level factories `cert(pathOrObject, httpAgent?)`, `applicationDefault(httpAgent?)` and `refreshToken(pathOrObject, httpAgent?)` return a `Credential` interface. `applicationDefault()` is memoised in a single global, and `cert()` and `refreshToken()` are memoised globally by their JSON. With no credential, `FirebaseApp` uses `getApplicationDefault()`.[^node-factories]

# Dart

`Credential` is a sealed class with three subtypes, built through factories:[^sealed-credential][^refresh-token-subtype]

| Factories | Subtype |
| --- | --- |
| `Credential.fromServiceAccount(File)`, `Credential.fromServiceAccountParams(...)` | `ServiceAccountCredential` |
| `Credential.fromApplicationDefaultCredentials({serviceAccountId})` | `ApplicationDefaultCredential` |
| `Credential.fromRefreshToken(File)`, `Credential.fromRefreshTokenParams(...)` | `RefreshTokenCredential` |

- The subtypes are hidden from the barrel.[^barrel-hide]
- A `File` or named parameters replace Node's string-or-object union.
- `serviceAccountId` on the ADC factory exists for Workload Identity Federation: WIF credential files have no `client_email` field, as the README explains.[^adc-factory]
- `Credential.createClient(scopes)` is public.
- With no credential, `GOOGLE_APPLICATION_CREDENTIALS` is first tried as a service-account file, then ADC.
- `app.firestore()` maps the credential onto Firestore's own `Credential`, and throws for subtypes Firestore doesn't accept.[^firestore-mapping]

# Why

The maintainers' stated reason: `Credential` was reworked into a sealed class, where a credential is one of a known set of types, and its type is used to detect the project ID. The refresh-token subtype covers cases where the default ADC file location isn't enough. The README explains `serviceAccountId` for WIF.

The likely reason (not recorded) for a `File` or parameters instead of a union: Dart has no union types.

A `GoogleCredential` from a short-lived local `googleapis_auth_utils` package was dropped together with that package.

# Rules for agents

- **Must:** keep Dart's way. A new credential source is a new factory and a new sealed subtype, and every `switch` over `Credential` must stay exhaustive.
- **Must:** when you add a subtype, update every exhaustive switch and the Firestore credential mapping in `app.firestore()`.
- **Must not:** assume `serviceAccountCredentials` is non-null. It is null for ADC, WIF and refresh-token credentials.

# Related

- [Credential discovery when none is passed](/app/credential-autodiscovery.md)
- [Firestore is a standalone package](/firestore/standalone-package.md)
- [Sign locally with the key, else through IAM signBlob](/app/signing.md)
- [TypeScript object unions become sealed classes](/conventions/unions-to-sealed-classes.md)

[^node-factories]: Node's credential factories
[^sealed-credential]: The sealed `Credential`
[^refresh-token-subtype]: `RefreshTokenCredential`
[^barrel-hide]: The barrel's `hide` list
[^adc-factory]: The ADC factory
[^firestore-mapping]: `app.firestore()` credential mapping
