---
type: Decision
title: Verifying ID tokens, session cookies and App Check tokens
description: Tokens are verified with `dart_jsonwebtoken` against Google's public keys, without the JWT `typ` header check, mapping errors from exception types (the emulator verifier also matches message text) and accepting unsigned tokens in emulator mode.
tags: [auth, app-check, jwt]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/utils/jwt.dart
  - packages/firebase_admin_sdk/lib/src/auth/token_verifier.dart
  - packages/firebase_admin_sdk/lib/src/app_check/token_verifier.dart
sources:
  - id: jwt-header-check
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/jwt.dart
    symbol: "checkHeaderType: false"
    title: Signature verification with the `typ` header check turned off
  - id: url-key-fetcher
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/jwt.dart
    symbol: class UrlKeyFetcher
    title: "`UrlKeyFetcher`, which takes an optional `http.Client`"
  - id: emulator-verifier
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/jwt.dart
    symbol: class EmulatorSignatureVerifier
    title: The emulator verifier, which branches on exception messages
  - id: auth-token-verifier
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/token_verifier.dart
    title: Verification of ID tokens and session cookies
  - id: app-check-token-verifier
    resource: ../../../packages/firebase_admin_sdk/lib/src/app_check/token_verifier.dart
    title: Verification of App Check tokens
  - id: jsonwebtoken-dependency
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "dart_jsonwebtoken:"
    title: The `dart_jsonwebtoken` dependency
---

# Decision

Firebase ID tokens, session cookies and App Check tokens are verified with `dart_jsonwebtoken` against Google's public keys.[^jsonwebtoken-dependency] The shared JWT code is in `lib/src/utils/jwt.dart`; the Auth verifier[^auth-token-verifier] and the App Check verifier[^app-check-token-verifier] build on it.

- **No `typ` header check.** Signatures are verified with `checkHeaderType: false`.[^jwt-header-check]
- **Emulator tokens.** In emulator mode, unsigned emulator tokens are accepted.[^emulator-verifier]
- **Errors.** Verification errors are mapped from exception types and `JwtErrorCode` values. `EmulatorSignatureVerifier.verify` is the one place that branches on message text: it accepts a token when the `JWTInvalidException` it catches has the message `'unknown algorithm'` or `'invalid signature'`.[^emulator-verifier]
- **Custom claims.** `DecodedIdToken.claims` is an unmodifiable map that excludes the standard and reserved claims (see [custom claims](/auth/claims-map.md)).
- **Key fetching.** `UrlKeyFetcher` takes an optional `http.Client`, so callers can inject one.[^url-key-fetcher]

# Why

- `typ` check: the maintainers' stated reason, also given in the code comment at the call, is that Firebase session cookies omit the `typ` header claim, and signature, issuer, audience and expiry are all validated separately.[^jwt-header-check]
- Error mapping: the maintainers' stated reason is that the code must not depend on the English message text.
- Injectable client: the maintainers' stated reason is that the real token-verification tests in the `firebase_functions` SDK need it.
- A proposal to expose the raw token payload was closed. The likely reason (not recorded): custom claims are exposed through the `claims` map instead.

Consolidating the key fetchers and clock-skew handling into one shared verifier is proposed but not decided. Ask a maintainer before doing it.

# Rules for agents

- **Must:** keep `UrlKeyFetcher`'s `http.Client` injectable, because `firebase_functions` tests depend on it.
- **Must not:** re-enable `checkHeaderType`.
- **Must not:** add branching on exception message strings. `EmulatorSignatureVerifier.verify` is the existing exception; don't extend it or copy it.

# Related

- [Custom claims as a map](/auth/claims-map.md)
- [Generic Google-auth features live upstream](/architecture/upstream-generic-auth-features.md)
- [Resolvable in Flutter workspaces and for firebase_functions](/dependencies/flutter-and-functions-consumers.md)

[^jsonwebtoken-dependency]: The `dart_jsonwebtoken` dependency
[^auth-token-verifier]: Verification of ID tokens and session cookies
[^app-check-token-verifier]: Verification of App Check tokens
[^jwt-header-check]: Signature verification with the `typ` header check turned off
[^url-key-fetcher]: `UrlKeyFetcher` and its optional `http.Client`
[^emulator-verifier]: `EmulatorSignatureVerifier`
