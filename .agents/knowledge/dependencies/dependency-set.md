---
type: Constraint
title: Small dependency set, no lockfiles or overrides
description: "Dependencies that are unmaintained, trivially inlined or thin wrappers have been removed, library code is written by hand without code generators, and adding a runtime dependency or a generator needs agreement; no `pubspec.lock`, `pubspec_overrides.yaml` or merged `dependency_overrides` is committed, so CI always resolves the newest allowed versions, and the committed Node lockfiles are the exception."
tags: [dependencies, supply-chain, codegen, ci, lockfiles]
agents_md: when-touching
governs:
  - packages/*/pubspec.yaml
  - pubspec.yaml
  - "**/*.g.dart"
  - .gitignore
  - "**/package-lock.json"
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
  - id: gitignore-lock
    resource: ../../../.gitignore
    symbol: pubspec.lock
    title: "`pubspec.lock` is git-ignored"
  - id: gitignore-overrides
    resource: ../../../.gitignore
    symbol: pubspec_overrides.yaml
    title: "`pubspec_overrides.yaml` is git-ignored"
  - id: golden-lockfile
    resource: ../../../packages/google_cloud_firestore/tool/pipeline_golden/package-lock.json
    title: A committed Node tool lockfile
  - id: fixture-lockfile
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/task_queue_functions/package-lock.json
    title: The task queue fixture's committed lockfile
  - id: fixture-npm-install
    resource: ../../../scripts/coverage.sh
    symbol: cd test/fixtures/task_queue_functions
    title: "`scripts/coverage.sh` runs `npm install` in the fixture"
  - id: build-schedule
    resource: ../../../.github/workflows/build.yml
    symbol: "schedule:"
    title: The Build workflow's daily scheduled run
---

# Where it lives

- Enforced by (small dependency set, no code generation): nothing; review only.
- Enforced by (no lockfiles or overrides): `.gitignore`, for `pubspec.lock` and `pubspec_overrides.yaml`.[^gitignore-lock][^gitignore-overrides] Nothing enforces the no-`dependency_overrides` rule; review only.
- The dependency lists: `dependencies:` in each package's `pubspec.yaml`.[^admin-dependencies][^firestore-dependencies]
- A runtime dependency nothing uses: `asn1lib:` in `packages/firebase_admin_sdk/pubspec.yaml`.[^asn1lib]
- A dev dependency nothing uses: `build_runner:` in both packages' `dev_dependencies`, such as `packages/google_cloud_firestore/pubspec.yaml`.[^build-runner]
- The committed Node lockfiles: `package-lock.json` in each `tool/pipeline_*` directory of `google_cloud_firestore`, such as `tool/pipeline_golden/`,[^golden-lockfile] and in `test/fixtures/task_queue_functions/`.[^fixture-lockfile]
- The fixture's `npm install`: `cd test/fixtures/task_queue_functions` in `scripts/coverage.sh`.[^fixture-npm-install]
- The early warning for upstream breakage: `schedule:` in `.github/workflows/build.yml`.[^build-schedule]

# Constraint

## Small dependency set, no code generation

Keep the dependency set of both packages small. Dependencies that are unmaintained, trivial to inline or thin wrappers are removed, and adding one needs a reason.

These have been removed:

- `equatable`, replaced by a trivial in-repo equivalent;
- `googleapis_beta`, unmaintained and trivial to inline;
- `jose`: JWT handling uses `dart_jsonwebtoken` alone;
- `freezed`, once used for Firestore's settings, replaced by manual implementations;
- `googleapis_auth_utils` (see [Generic Google-auth features live upstream](/architecture/upstream-generic-auth-features.md)).

**No code generation.** Library code in both packages is written by hand. No library type uses `freezed`, `json_serializable` or another generator. `version.g.dart` is the one generated file, and a shell script writes it, not a builder (see [version.g.dart](/release/releases-and-versioning.md)).

**Traps.** `asn1lib` is declared, but nothing under `lib/` imports it. `build_runner` is a dev dependency of both packages, with no builder to run.

A dependency bump that users need ships with a CHANGELOG entry in each package it affects.

## No lockfiles or overrides

- The root `pubspec.yaml` must not carry `dependency_overrides` when a PR is merged.
- So CI always resolves the newest allowed versions, and the daily scheduled run of the Build workflow catches upstream breakage.
- The publish dry run doesn't fail on an override; it only prints a hint. Nothing else catches one.
- The tool lockfiles are installed with `npm ci`, by the tools' READMEs and workflows. The fixture is installed with `npm install`, by CONTRIBUTING's emulator setup and by `scripts/coverage.sh`, which CI's `test` job runs.

# Why

## Small dependency set, no code generation

- The maintainers' stated reasons: drop a package that hasn't been updated in years when it's trivial to inline (`googleapis_beta`), and drop one with a trivial replacement (`equatable`). No reason is recorded for dropping `jose`; the change consolidated JWT handling on `dart_jsonwebtoken`.
- On code generation, the maintainers recorded only the fact: `freezed` was removed in favour of manual implementations. Whether "no code generation" is a firm rule, or a side effect of splitting Firestore into its own package, isn't recorded.
- The likely reason (not recorded): fewer dependencies mean fewer resolution conflicts for users (see [Flutter workspaces](/dependencies/constraints.md)), less supply-chain surface, and no `build_runner` step for consumers or releases.

## No lockfiles or overrides

- The maintainers state the rule itself: lock files aren't checked in, which is also why Dependabot doesn't check Dart dependencies.
- On overrides, the maintainers' stated reason: the package cannot be published with an override in place, so a PR that needs one stays a draft until the dependency is released.
- The likely reason for the daily run (not recorded): it is the early warning for new upstream releases.

# Rules for agents

- **Must not:** add a runtime dependency to either package's `lib/` without the user's explicit agreement. Prefer a small in-repo helper.
- **Must not:** add a dependency for something a few lines can do.
- **Must not:** re-add `equatable`, `googleapis_beta`, `freezed` or `jose`, or use `json_serializable` for library types.
- **Must not:** add a dependency that is unmaintained, or that pins Flutter-pinned packages high.
- **Must not:** read the `build_runner` dev dependency as a sign that code generation is in use.
- **Ask first:** before adding any code generator.
- **Must:** use `npm ci`, not `npm install`, in `tool/*`, so their committed lockfiles stay as they are. The exception is bumping the pinned Node SDK, which the tool READMEs do with `npm install`, committing the updated lockfile. This rule doesn't cover `test/fixtures/task_queue_functions`, which CONTRIBUTING and `scripts/coverage.sh` install with `npm install`.
- **Must not:** commit `pubspec.lock` or `pubspec_overrides.yaml`.
- **Must not:** leave `dependency_overrides` in a PR meant to merge. If one is needed temporarily, keep the PR as a draft.

# Related

- [Generic Google-auth features live upstream](/architecture/upstream-generic-auth-features.md)
- [Releases, versioning, CHANGELOG and version.g.dart](/release/releases-and-versioning.md)
- [Sign locally with the key, else through IAM](/app/signing.md)
- [The publish dry run must pass for both packages](/release/publish-dry-run.md)
- [Other generated, compiled or mirrored files](/generated/other-generated-files.md)
- [CI workflows: what runs, what gates merging, hardening](/ci/workflows.md)

[^admin-dependencies]: `firebase_admin_sdk`'s pubspec
[^firestore-dependencies]: `google_cloud_firestore`'s pubspec
[^asn1lib]: `asn1lib` in `firebase_admin_sdk`'s pubspec
[^build-runner]: `build_runner` in `google_cloud_firestore`'s pubspec
[^gitignore-lock]: `.gitignore`: `pubspec.lock`
[^gitignore-overrides]: `.gitignore`: `pubspec_overrides.yaml`
[^golden-lockfile]: `tool/pipeline_golden/package-lock.json`
[^fixture-lockfile]: `test/fixtures/task_queue_functions/package-lock.json`
[^fixture-npm-install]: `scripts/coverage.sh`
[^build-schedule]: The `schedule:` trigger in `build.yml`
