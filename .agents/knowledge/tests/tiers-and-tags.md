---
type: Constraint
title: Every change needs tests, in tiers selected by tags
description: Every feature and fix needs tests, and tests are split into unit, emulator, prod and WIF tiers by `dart_test.yaml` tags, never by environment variables; CONTRIBUTING.md's lines that say otherwise are out of date.
tags: [tests, tags]
agents_md: always
governs:
  - packages/*/test/**
  - packages/*/dart_test.yaml
sources:
  - id: admin-default-run
    resource: ../../../packages/firebase_admin_sdk/dart_test.yaml
    symbol: "exclude_tags: firebase-emulator || prod || wif"
    title: The admin package's default exclusions, presets and tag descriptions
  - id: firestore-default-run
    resource: ../../../packages/google_cloud_firestore/dart_test.yaml
    symbol: "exclude_tags: firebase-emulator || prod"
    title: The Firestore package's default exclusions, presets and tag descriptions
  - id: contributing-running-tests
    resource: ../../../CONTRIBUTING.md
    symbol: "### Running Tests"
    title: CONTRIBUTING's table of presets
  - id: contributing-testing
    resource: ../../../CONTRIBUTING.md
    symbol: RUN_PROD_TESTS
    title: CONTRIBUTING's testing requirements, with two out-of-date lines
  - id: contributing-layout
    resource: ../../../CONTRIBUTING.md
    symbol: "### Repo Organization"
    title: CONTRIBUTING's repository tree, with an out-of-date test layout
---

# Where it lives

- Enforced by: the default `exclude_tags` and the presets in each `dart_test.yaml`, `exclude_tags: firebase-emulator || prod || wif` in `packages/firebase_admin_sdk/dart_test.yaml`[^admin-default-run] and `exclude_tags: firebase-emulator || prod` in `packages/google_cloud_firestore/dart_test.yaml`.[^firestore-default-run] Each tag's description says what it needs.
- The presets as a table: `### Running Tests` in `CONTRIBUTING.md`.[^contributing-running-tests]
- The testing requirements, with two out-of-date lines: `## Testing Requirements` in `CONTRIBUTING.md`, at `RUN_PROD_TESTS`.[^contributing-testing]
- An out-of-date test layout: `### Repo Organization` in `CONTRIBUTING.md`.[^contributing-layout]

# Constraint

Tests are split into tiers by `dart_test` tags, never by environment variables. The default `dart test` runs unit tests only.

- **Trap:** an untagged test that needs an emulator lands in the default run, and fails for everyone without emulators.
- CONTRIBUTING.md's Testing Requirements are out of date in two lines: there are no `*_integration_test.dart` files, since integration tests live in `test/integration/` and are tagged; and prod tests are gated by the `prod` tag, not `RUN_PROD_TESTS`.
- CONTRIBUTING.md's Repo Organization tree is out of date: admin tests live under `test/unit/<product>/` and `test/integration/<product>/`, and the shared helpers in `test/fixtures/`. Firestore's tests are flat `test/*.dart` files, with the live Pipeline suite in `test/e2e/`.

# Why

The maintainers' stated reasons: reviewers ask for tests before merging, and CONTRIBUTING.md makes them mandatory. Production tests are quota-heavy and not required in CI, so they are an explicit opt-in. An earlier `RUN_PROD_TESTS`/`hasProdEnv` environment-variable guard was dropped in favour of tags.

# Rules for agents

- **Must:** include tests with every fix or feature.
- **Must:** tag every new test that needs an emulator or credentials.
- **Must:** put test files in the existing layout.
- **Must not:** write a test that reaches production without the `prod` tag.
- **Must not:** merge untested contributions.
- **Must not:** gate tests on custom environment variables, such as `RUN_PROD_TESTS`. Use tags.

# Related

- [Inject test doubles and use the guarded emulator helpers](/tests/helpers-and-injection.md)
- [Prod and WIF test runs](/tests/prod-and-wif.md)
- [Pipelines parity with Node](/firestore/pipelines/node-parity.md), for the tag check on the live E2E suite
- [What CI runs, the coverage gate, and what gates merging](/ci/trigger-matrix.md)

[^admin-default-run]: The admin package's `dart_test.yaml`
[^firestore-default-run]: The Firestore package's `dart_test.yaml`
[^contributing-running-tests]: CONTRIBUTING's presets table
[^contributing-testing]: CONTRIBUTING's testing requirements
[^contributing-layout]: CONTRIBUTING's repository tree
