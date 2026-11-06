---
type: Divergence
title: Custom claims as a map, not an index signature
description: Node's `DecodedIdToken` exposes custom claims through an index signature, while Dart has typed fields plus a `claims` map holding only the non-reserved claims.
tags: [auth, jwt, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/auth/token_verifier.dart
sources:
  - id: dart-claims-field
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/token_verifier.dart
    symbol: final Map<String, Object?> claims;
    title: "`DecodedIdToken.claims`, the map of custom claims"
  - id: dart-extract-claims
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/token_verifier.dart
    symbol: _extractCustomClaims
    title: Drops the standard and reserved claims from the payload
  - id: node-decoded-id-token
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/auth/token-verifier.ts
    symbol: DecodedIdToken
    title: Node's `DecodedIdToken`, with an index signature
---

# Node.js

`DecodedIdToken` has an index signature, `[key: string]: any`, so a custom claim is read as a property: `decoded.isAdmin`.[^node-decoded-id-token]

# Dart

`DecodedIdToken` has typed fields for the standard claims plus `final Map<String, Object?> claims`.[^dart-claims-field] The map holds only the non-reserved claims: the standard OpenID Connect claims and Firebase's reserved claims are removed from it.[^dart-extract-claims] A custom claim is read as `decoded.claims['isAdmin']`.

`TokenProvider`, the type of the `firebase` claim, keeps Node's index signature only as a `// TODO allow any key` comment.

# Why

The likely reason (not recorded): Dart has no index signatures.

# Rules for agents

- **Must:** keep Dart's way: typed fields for the standard claims, and custom claims in the `claims` map.

# Related

- [How tokens are verified](/auth/jwt-verification.md)

[^node-decoded-id-token]: Node's `DecodedIdToken`
[^dart-claims-field]: `DecodedIdToken.claims`
[^dart-extract-claims]: `_extractCustomClaims`
