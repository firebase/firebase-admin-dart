---
type: Constraint
title: Keep the dependency set small
description: Dependencies that are unmaintained, trivially inlined or thin wrappers have been removed, and adding a runtime dependency needs a reason and agreement.
tags: [dependencies, supply-chain]
agents_md: when-touching
governs:
  - packages/*/pubspec.yaml
  - pubspec.yaml
sources:
  - id: admin-dependencies
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "dependencies:"
    title: "`firebase_admin_sdk`'s dependencies"
  - id: firestore-dependencies
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "dependencies:"
    title: "`google_cloud_firestore`'s dependencies"
---

# Constraint

Keep the dependency set of both packages small.[^admin-dependencies][^firestore-dependencies] Dependencies that are unmaintained, trivial to inline or thin wrappers are removed, and adding one needs a reason.

These have been removed:

- `equatable`, replaced by a trivial in-repo equivalent;
- `googleapis_beta`, unmaintained and trivial to inline;
- `freezed` (see [no code generation](/conventions/no-codegen.md));
- `jose`: JWT handling uses `dart_jsonwebtoken` alone;
- `googleapis_auth_utils`, whose generic features moved upstream into `googleapis_auth`.

`asn1lib` is declared in `firebase_admin_sdk`'s pubspec, but nothing under `lib/` imports it.

A dependency bump that users need ships with a CHANGELOG entry in each package it affects.

# Why

- The maintainers' stated reasons: drop a package that hasn't been updated in years when it's trivial to inline (`googleapis_beta`), and drop one with a trivial replacement (`equatable`). No reason is recorded for dropping `jose`; the change consolidated JWT handling on `dart_jsonwebtoken`.
- The likely reason (not recorded): fewer dependencies mean fewer resolution conflicts for users (see [Flutter workspaces](/dependencies/flutter-and-functions-consumers.md)) and less supply-chain surface.

# Enforced by

Not enforced; a convention, applied in review.

# Rules for agents

- **Must not:** add a runtime dependency to either package's `lib/` without the user's explicit agreement. Prefer a small in-repo helper.
- **Must not:** add a dependency for something a few lines can do.
- **Must not:** re-add `equatable`, `googleapis_beta`, `freezed` or `jose`.
- **Must not:** add a dependency that is unmaintained, or that pins Flutter-pinned packages high.
- **Must:** keep `dev_dependencies` in `sort_pub_dependencies` order. Adding a dev dependency is lower risk, but still needs that order.

# Related

- [Library code is written by hand](/conventions/no-codegen.md)
- [Generic Google-auth features live upstream](/architecture/upstream-generic-auth-features.md)
- [Sign locally with the key, else through IAM](/app/signing.md)

[^admin-dependencies]: `firebase_admin_sdk`'s pubspec
[^firestore-dependencies]: `google_cloud_firestore`'s pubspec
