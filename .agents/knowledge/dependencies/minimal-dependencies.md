---
type: Constraint
title: Keep the dependency set small, with no code generation
description: Dependencies that are unmaintained, trivially inlined or thin wrappers have been removed, library code is written by hand without code generators, and adding a runtime dependency or a generator needs agreement.
tags: [dependencies, supply-chain, codegen]
agents_md: when-touching
governs:
  - packages/*/pubspec.yaml
  - pubspec.yaml
  - "**/*.g.dart"
sources:
  - id: admin-dependencies
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "dependencies:"
    title: "`firebase_admin_sdk`'s dependencies"
  - id: firestore-dependencies
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "dependencies:"
    title: "`google_cloud_firestore`'s dependencies"
  - id: asn1lib
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "asn1lib:"
    title: "`asn1lib`, declared but imported by nothing under `lib/`"
  - id: build-runner
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "build_runner:"
    title: "`build_runner`, a dev dependency with no builder to run"
---

# Where it lives

- Enforced by: nothing; review only.
- The dependency lists: `dependencies:` in each package's `pubspec.yaml`.[^admin-dependencies][^firestore-dependencies]
- A runtime dependency nothing uses: `asn1lib:` in `packages/firebase_admin_sdk/pubspec.yaml`.[^asn1lib]
- A dev dependency nothing uses: `build_runner:` in both packages' `dev_dependencies`, such as `packages/google_cloud_firestore/pubspec.yaml`.[^build-runner]

# Constraint

Keep the dependency set of both packages small. Dependencies that are unmaintained, trivial to inline or thin wrappers are removed, and adding one needs a reason.

These have been removed:

- `equatable`, replaced by a trivial in-repo equivalent;
- `googleapis_beta`, unmaintained and trivial to inline;
- `jose`: JWT handling uses `dart_jsonwebtoken` alone;
- `freezed`, once used for Firestore's settings, replaced by manual implementations;
- `googleapis_auth_utils` (see [Generic Google-auth features live upstream](/architecture/upstream-generic-auth-features.md)).

**No code generation.** Library code in both packages is written by hand. No library type uses `freezed`, `json_serializable` or another generator. `version.g.dart` is the one generated file, and a shell script writes it, not a builder (see [version.g.dart](/generated/version-g-dart.md)).

**Traps.** `asn1lib` is declared, but nothing under `lib/` imports it. `build_runner` is still a dev dependency of both packages, although there is no builder for it to run.

A dependency bump that users need ships with a CHANGELOG entry in each package it affects.

# Why

- The maintainers' stated reasons: drop a package that hasn't been updated in years when it's trivial to inline (`googleapis_beta`), and drop one with a trivial replacement (`equatable`). No reason is recorded for dropping `jose`; the change consolidated JWT handling on `dart_jsonwebtoken`.
- On code generation, the maintainers recorded only the fact: `freezed` was removed in favour of manual implementations. Whether "no code generation" is a firm rule, or a side effect of splitting Firestore into its own package, isn't recorded.
- The likely reason (not recorded): fewer dependencies mean fewer resolution conflicts for users (see [Flutter workspaces](/dependencies/flutter-and-functions-consumers.md)), less supply-chain surface, and no `build_runner` step for consumers or releases.

# Rules for agents

- **Must not:** add a runtime dependency to either package's `lib/` without the user's explicit agreement. Prefer a small in-repo helper.
- **Must not:** add a dependency for something a few lines can do.
- **Must not:** re-add `equatable`, `googleapis_beta`, `freezed` or `jose`, or use `json_serializable` for library types.
- **Must not:** add a dependency that is unmaintained, or that pins Flutter-pinned packages high.
- **Must not:** read the `build_runner` dev dependency as a sign that code generation is in use.
- **Ask first:** before adding any code generator.

# Related

- [Generic Google-auth features live upstream](/architecture/upstream-generic-auth-features.md)
- [version.g.dart is generated from the pubspec](/generated/version-g-dart.md)
- [Sign locally with the key, else through IAM](/app/signing.md)

[^admin-dependencies]: `firebase_admin_sdk`'s pubspec
[^firestore-dependencies]: `google_cloud_firestore`'s pubspec
[^asn1lib]: `asn1lib` in `firebase_admin_sdk`'s pubspec
[^build-runner]: `build_runner` in `google_cloud_firestore`'s pubspec
