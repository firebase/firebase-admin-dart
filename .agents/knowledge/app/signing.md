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
  - id: node-crypto-signer
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/utils/crypto-signer.ts
    symbol: export function cryptoSignerFromApp
    title: "Node's `cryptoSignerFromApp`: `ServiceAccountSigner`, else `IAMSigner`"
  - id: node-app-check
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/app-check/app-check.ts
    symbol: new AppCheckTokenGenerator(cryptoSignerFromApp(app))
    title: Node's App Check token generator, which always signs
---

# Decision

Auth custom tokens and App Check custom tokens are signed through `app.sign()`.[^auth-token-generator][^app-check-token-generator] They are its only callers; the SDK has no signed-URL code.

`app.sign()` picks a signer:[^app-sign]

1. When the Auth emulator is enabled, it returns an empty signature, so tokens are unsigned. The check is only `isAuthEmulatorEnabled()`, for App Check tokens too.[^emulator-short-circuit] Node differs for App Check: its App Check token generator always signs through `cryptoSignerFromApp`, and only Auth custom tokens use an unsigned `EmulatedSigner` under the Auth emulator.[^node-app-check]
2. When the credential has a service-account private key, it signs locally.
3. Otherwise it calls IAM Credentials `signBlob`, through `googleapis_auth`'s `sign()`, as `credential.serviceAccountId`.

ADC and WIF credentials have no private key, so they sign through IAM.

# Why

The maintainers' stated reason: match the Node.js Admin SDK's `GoogleAuth.sign()` behaviour, which signs locally when service-account credentials with private keys are available and falls back to IAM signing otherwise. In Node's Admin SDK that choice is `cryptoSignerFromApp` (`ServiceAccountSigner` or `IAMSigner`).[^node-crypto-signer]

Several signers were tried and replaced:

- an HMAC-SHA256 signer keyed with the private key, whose custom tokens Firebase rejected, then a hand-written ASN.1 RSA signer that replaced it;
- `package:jose`, dropped when JWT handling was consolidated on `dart_jsonwebtoken`;
- fixes to a hand-written `_IAMSigner`, handled instead by using `googleapis` for IAM;
- a local `signBlob` extension, replaced by `googleapis_auth`'s `sign()`.

# Rules for agents

- **Must not:** require `serviceAccountCredentials` to sign. ADC and WIF sign through IAM.
- **Must not:** reintroduce `jose` or a custom ASN.1 parser. JWT handling is consolidated on `dart_jsonwebtoken`.
- **Must not:** sign Auth custom tokens when the Auth emulator is enabled, as in Node.
- **Ask first:** before changing whether App Check custom tokens are signed under the Auth emulator. Node signs them; why Dart doesn't isn't recorded.

# Related

- [Generic Google-auth features live upstream, not in this repo](/architecture/upstream-generic-auth-features.md)
- [Credential is a sealed class with factories](/app/credential-sealed-hierarchy.md)
- [How ID tokens, session cookies and App Check tokens are verified](/auth/jwt-verification.md)
- [Keep the dependency set small](/dependencies/minimal-dependencies.md)

[^auth-token-generator]: Auth's token generator
[^app-check-token-generator]: App Check's token generator
[^app-sign]: `app.sign()`
[^emulator-short-circuit]: Emulator short-circuit
[^node-app-check]: Node's App Check token generator
[^node-crypto-signer]: Node's `cryptoSignerFromApp`
