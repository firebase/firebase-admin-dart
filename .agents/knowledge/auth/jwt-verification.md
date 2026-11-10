---
type: Decision
title: Verifying ID tokens, session cookies and App Check tokens
description: Tokens are verified with `dart_jsonwebtoken` against Google's public keys, without the JWT `typ` header check, mapping errors from exception types (the emulator verifier also matches message text), accepting unsigned ID tokens and session cookies under the Auth emulator, and exposing custom claims as a map where Node has an index signature.
tags: [auth, app-check, jwt, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/utils/jwt.dart
  - packages/firebase_admin_sdk/lib/src/auth/token_verifier.dart
  - packages/firebase_admin_sdk/lib/src/app_check/token_verifier.dart
sources:
  - id: jwt-header-check
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/jwt.dart
    symbol: Firebase session cookies omit the
    title: "The `checkHeaderType: false` call and its comment, which is wrong about expiry"
  - id: url-key-fetcher
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/jwt.dart
    symbol: class UrlKeyFetcher
    title: "`UrlKeyFetcher`, which takes an optional `http.Client`"
  - id: emulator-verifier
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/jwt.dart
    symbol: class EmulatorSignatureVerifier
    title: The emulator verifier, which branches on exception messages
  - id: dart-extract-claims
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/token_verifier.dart
    symbol: _extractCustomClaims
    title: "`DecodedIdToken.claims`: every claim without a typed field"
  - id: app-check-token-verifier
    resource: ../../../packages/firebase_admin_sdk/lib/src/app_check/token_verifier.dart
    title: Verification of App Check tokens
  - id: jsonwebtoken-dependency
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "dart_jsonwebtoken:"
    title: The `dart_jsonwebtoken` dependency
  - id: node-decoded-id-token
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/token-verifier.ts
    symbol: DecodedIdToken
    title: Node's `DecodedIdToken`, with an index signature
---

# Where it lives

- Enforced by: nothing; review only.
- The shared JWT code (signature check, key fetching, the emulator verifier): `lib/src/utils/jwt.dart`, built on `dart_jsonwebtoken`, with `UrlKeyFetcher` and `EmulatorSignatureVerifier` in it.[^jsonwebtoken-dependency][^url-key-fetcher][^emulator-verifier]
- The `typ` check is off at `JWT.verify(..., checkHeaderType: false)`, with a comment giving the reason.[^jwt-header-check]
- The verifiers: `auth/token_verifier.dart`, whose `_extractCustomClaims` decides what goes into `claims`, and `app_check/token_verifier.dart`.[^dart-extract-claims][^app-check-token-verifier]

# Decision

Firebase ID tokens, session cookies and App Check tokens are verified with `dart_jsonwebtoken` against Google's public keys, without the `typ` header check. Errors are mapped from exception types and `JwtErrorCode` values; `EmulatorSignatureVerifier.verify` is the one place that branches on message text.

**Trap:** the comment at the `checkHeaderType: false` call says that expiry is validated separately. It isn't: `JWT.verify` checks expiry, and the catch around that call maps every failure, an expired token included, to an invalid-signature error.

**Custom claims, unlike Node.** Node's `DecodedIdToken` has an index signature, `[key: string]: any`, so a custom claim is read as `decoded.isAdmin`.[^node-decoded-id-token] Dart's has typed fields for the standard claims plus a `claims` map of every other claim, read as `decoded.claims['isAdmin']`. Token claims without a typed field, such as `name` and `user_id`, stay in that map beside the custom claims, though the `_extractCustomClaims` dartdoc says it holds only custom claims.[^dart-extract-claims]

# Why

- `typ` check: the maintainers' stated reason is that Firebase session cookies omit the `typ` header claim.
- Error mapping: the maintainers' stated reason is that the code must not depend on the English message text.
- Injectable client: the maintainers' stated reason is that the real token-verification tests in the `firebase_functions` SDK need it.
- Custom claims: the likely reason (not recorded) is that Dart has no index signatures.
- A proposal to expose the raw token payload was closed. The likely reason (not recorded): custom claims are exposed through the `claims` map instead.

Consolidating the key fetchers and clock-skew handling into one shared verifier is proposed but not decided. Ask a maintainer before doing it.

# Rules for agents

- **Must:** keep `UrlKeyFetcher`'s `http.Client` injectable, because `firebase_functions` tests depend on it.
- **Must not:** re-enable `checkHeaderType`.
- **Must not:** add branching on exception message strings. `EmulatorSignatureVerifier.verify` is the existing exception; don't extend it or copy it.
- **Must:** keep typed fields for the standard claims, and custom claims in the `claims` map.

# Related

- [Generic Google-auth features live upstream](/architecture/upstream-generic-auth-features.md)
- [Dependency constraints: bounds, consumers and the SDK floor](/dependencies/constraints.md)

[^jsonwebtoken-dependency]: The `dart_jsonwebtoken` dependency
[^url-key-fetcher]: `UrlKeyFetcher` and its optional `http.Client`
[^emulator-verifier]: `EmulatorSignatureVerifier`
[^jwt-header-check]: The `checkHeaderType: false` call and its comment
[^dart-extract-claims]: `_extractCustomClaims`
[^app-check-token-verifier]: Verification of App Check tokens
[^node-decoded-id-token]: Node's `DecodedIdToken`
