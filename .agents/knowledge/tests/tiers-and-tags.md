---
type: Constraint
title: Every change needs tests, in tiers selected by tags
description: Every feature and fix needs tests, and tests are split into unit, emulator, prod and WIF tiers by `dart_test.yaml` tags, not by environment variables.
tags: [tests, tags]
agents_md: always
governs:
  - packages/*/test/**
  - packages/*/dart_test.yaml
sources:
  - id: admin-default-run
    resource: ../../../packages/firebase_admin_sdk/dart_test.yaml
    symbol: "exclude_tags: firebase-emulator || prod || wif"
    title: The admin package's default exclusions and presets
  - id: admin-wif-preset
    resource: ../../../packages/firebase_admin_sdk/dart_test.yaml
    symbol: "include_tags: wif"
    title: The admin-only `wif` preset
  - id: firestore-default-run
    resource: ../../../packages/google_cloud_firestore/dart_test.yaml
    symbol: "exclude_tags: firebase-emulator || prod"
    title: The Firestore package's default exclusions and presets
---

# Constraint

Every feature and every bug fix comes with tests. CONTRIBUTING.md: "All new features and bug fixes must include tests."

Tests are split into tiers by `dart_test` tags, never by environment variables. Each package's `dart_test.yaml` defines the default run and the presets:[^admin-default-run][^firestore-default-run]

| Command | What runs |
| --- | --- |
| `dart test` | Unit tests only. The admin package excludes `firebase-emulator`, `prod` and `wif`; Firestore excludes `firebase-emulator` and `prod`. |
| `dart test -P firebase-emulator` | Tests that need the emulators. |
| `dart test -P prod` | Tests against real Google Cloud APIs. |
| `dart test -P wif` | Workload Identity Federation tests, in `firebase_admin_sdk` only.[^admin-wif-preset] |
| `dart test -P ci` | Everything except `prod` and `wif`, so the emulators must be running. |

Tag a whole file with a library-level `@Tags([...])`, or a group or a single test with `tags:`.

Layout:

- `firebase_admin_sdk`: `test/unit/<product>/`, `test/integration/<product>/` (prod tests are named `*_prod_test.dart`), and shared helpers in `test/fixtures/`.
- `google_cloud_firestore`: flat `test/*.dart`, with the live Pipeline suite in `test/e2e/pipeline/`.

# Why

The maintainers' stated reasons: reviewers ask for tests before merging, and CONTRIBUTING.md makes them mandatory. Production tests are quota-heavy and not required in CI, so they are an explicit opt-in. An earlier `RUN_PROD_TESTS`/`hasProdEnv` environment-variable guard was dropped in favour of tags, and each tag's description in `dart_test.yaml` says what it needs. CONTRIBUTING.md's testing section says to gate prod tests behind `RUN_PROD_TESTS`; that line is out of date, so use the `prod` tag.

# Enforced by

- The default `exclude_tags` and the presets in `packages/firebase_admin_sdk/dart_test.yaml` and `packages/google_cloud_firestore/dart_test.yaml`.
- For the live E2E suite, `test/pipeline_e2e_coverage_test.dart` fails any `*_test.dart` file under `test/e2e/pipeline/` that lacks `@Tags(['prod'])`.

# Rules for agents

- **Must:** include tests with every fix or feature.
- **Must:** tag every new test that needs an emulator or credentials. An untagged emulator test lands in the default unit run and fails for everyone.
- **Must:** put test files in the existing layout.
- **Must not:** write a test that reaches production without the `prod` tag.
- **Must not:** merge untested contributions.
- **Must not:** gate tests on custom environment variables, such as `RUN_PROD_TESTS`. Use tags.

# Related

- [What emulator tests need](/tests/emulator-requirements.md)
- [Prod and WIF test runs](/tests/prod-and-wif.md)
- [Live Pipeline E2E suite](/tests/pipeline-e2e-live.md)
- [Coverage threshold in CI](/tests/coverage-threshold.md)

[^admin-default-run]: The admin package's default exclusions and presets
[^firestore-default-run]: The Firestore package's default exclusions and presets
[^admin-wif-preset]: The admin-only `wif` preset
