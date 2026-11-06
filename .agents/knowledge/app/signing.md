---
type: Decision
title: Sign locally with the key, else through IAM signBlob
description: Custom tokens and App Check custom tokens are signed with the service-account key when present, otherwise through IAM `signBlob`, and left unsigned when the Auth emulator is enabled.
tags: [app, credentials, tokens]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/utils/app_extension.dart
  - packages/firebase_admin_sdk/lib/src/auth/token_generator.dart
  - packages/firebase_admin_sdk/lib/src/app_check/token_generator.dart
sources:
  - id: app-sign
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/app_extension.dart
    symbol: Future<String> sign(
    title: "`app.sign()`: local key, else IAM through `googleapis_auth`"
  - id: emulator-short-circuit
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/app_extension.dart
    symbol: if (Environment.isAuthEmulatorEnabled()) return '';
    title: The emulator short-circuit
  - id: auth-token-generator
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/token_generator.dart
    symbol: _app.sign(utf8.encode(token))
    title: Auth custom tokens are signed through `app.sign()`
  - id: app-check-token-generator
    resource: ../../../packages/firebase_admin_sdk/lib/src/app_check/token_generator.dart
    symbol: app.sign(utf8.encode(token))
    title: App Check custom tokens are signed through `app.sign()`
---

# Decision

Auth custom tokens and App Check custom tokens are signed through `app.sign()`.[^auth-token-generator][^app-check-token-generator] They are its only callers; the SDK has no signed-URL code.

`app.sign()` picks a signer:[^app-sign]

1. When the Auth emulator is enabled, it returns an empty signature, so tokens are unsigned. The check is only `isAuthEmulatorEnabled()`, for App Check tokens too.[^emulator-short-circuit]
2. When the credential has a service-account private key, it signs locally.
3. Otherwise it calls IAM Credentials `signBlob`, through `googleapis_auth`'s `sign()`, as `credential.serviceAccountId`.

ADC and WIF credentials have no private key, so they sign through IAM.

# Why

The maintainers' stated reason: match the Node.js Admin SDK's `GoogleAuth.sign()` behaviour, which signs locally when service-account credentials with private keys are available and falls back to IAM signing otherwise.

Several signers were tried and replaced:

- a hand-written ASN.1 RSA signer, whose custom tokens Firebase rejected;
- `package:jose`, which was dropped (the reason isn't recorded);
- fixes to a hand-written `_IAMSigner`, handled instead by using `googleapis` for IAM;
- a local `signBlob` extension, replaced by `googleapis_auth`'s `sign()`.

# Rules for agents

- **Must not:** require `serviceAccountCredentials` to sign. ADC and WIF sign through IAM.
- **Must not:** reintroduce `jose` (the reason it was removed isn't recorded) or a custom ASN.1 parser.
- **Must not:** sign in emulator mode.

# Related

- [Generic Google-auth features live upstream, not in this repo](/architecture/upstream-generic-auth-features.md)
- [Credential is a sealed class with factories](/app/credential-sealed-hierarchy.md)
- [How ID tokens, session cookies and App Check tokens are verified](/auth/jwt-verification.md)
- [Keep the dependency set small](/dependencies/minimal-dependencies.md)

[^auth-token-generator]: Auth's token generator
[^app-check-token-generator]: App Check's token generator
[^app-sign]: `app.sign()`
[^emulator-short-circuit]: Emulator short-circuit
