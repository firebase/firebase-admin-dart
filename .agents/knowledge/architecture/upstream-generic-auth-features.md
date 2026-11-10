---
type: Decision
title: Generic Google-auth features live upstream, not in this repo
description: Generic Google-auth features such as signing, impersonation and project-ID discovery belong in Google's `googleapis_auth` and `google_cloud` packages, not in a local package.
tags: [architecture, dependencies, credentials]
agents_md: when-touching
governs:
  - pubspec.yaml
  - packages/*/pubspec.yaml
  - packages/firebase_admin_sdk/lib/src/utils/**
sources:
  - id: googleapis-auth-dependency
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "googleapis_auth:"
    title: The `googleapis_auth` dependency
  - id: google-cloud-dependency
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "google_cloud:"
    title: The `google_cloud` dependency
  - id: app-sign
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/app_extension.dart
    symbol: Future<String> sign(
    title: "`app.sign()`, built on `googleapis_auth`'s `sign()`"
---

# Where it lives

- Enforced by: nothing; review only.
- The upstream packages: `googleapis_auth` and `google_cloud` in the admin `pubspec.yaml`.[^googleapis-auth-dependency][^google-cloud-dependency]
- Signing on top of `googleapis_auth`'s `sign()`: `app.sign()` in `app_extension.dart`.[^app-sign]

# Decision

Generic Google-auth features belong in Google's `googleapis_auth` and `google_cloud` packages, not in a package in this repo. They include:

- access to the credential behind an `AuthClient`;
- local or IAM signing;
- impersonation;
- project-ID discovery.

A local `googleapis_auth_utils` package held these features and was deleted. The APIs it added were filed and landed upstream instead.

# Why

The maintainers' stated reason, in part: the local package was only an extension of `googleapis_auth` and `google_cloud` that added missing APIs, so those APIs belong upstream. A maintainer has tentatively proposed applying the same reasoning to JWT verification, by moving it into Google's cloud packages.

Not everything goes upstream: a proposal to move a project-ID fix into `google_cloud` was declined, because `google_cloud` already handles project-ID discovery and the bug was in `google_cloud_firestore`.

The likely reason (not recorded): Google maintains those packages, so the features are reusable outside Firebase.

# Rules for agents

- **Must not:** add a new local auth or utilities package.
- **Must not:** make the internal JWT/JWKS helpers public before maintainers agree where shared JWT/JWKS verification lives. Ask a maintainer.

# Related

- [Sign locally with the key, else through IAM signBlob](/app/signing.md)
- [Verifying ID tokens, session cookies and App Check tokens](/auth/jwt-verification.md)
- [Keep the dependency set small](/dependencies/minimal-dependencies.md)
- [Credential is a sealed class with factories](/app/credential-sealed-hierarchy.md)

[^googleapis-auth-dependency]: The `googleapis_auth` dependency
[^google-cloud-dependency]: The `google_cloud` dependency
[^app-sign]: `app.sign()`
