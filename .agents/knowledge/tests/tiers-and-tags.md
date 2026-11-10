---
type: Constraint
title: Test tiers and tags, and the prod and WIF runs
description: "Every feature and fix needs tests, split into unit, emulator, prod and WIF tiers by `dart_test.yaml` tags, never by environment variables; `-P prod` and `-P wif` need real credentials and run only on request, the coverage scripts add `-P prod` whenever `GOOGLE_APPLICATION_CREDENTIALS` is set, and the Pipeline E2E suite is the only prod suite CI runs."
tags: [tests, tags, credentials, ci]
agents_md: always
governs:
  - packages/*/test/**
  - packages/*/dart_test.yaml
  - packages/*/test/**/*_prod_test.dart
  - .github/workflows/build.yml
  - scripts/*coverage.sh
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
  - id: contributing-integration
    resource: ../../../CONTRIBUTING.md
    symbol: files named `*_integration_test.dart`
    title: CONTRIBUTING's integration-test naming, which matches no file
  - id: contributing-layout
    resource: ../../../CONTRIBUTING.md
    symbol: "# Auth unit & integration tests"
    title: CONTRIBUTING's repository tree, with an out-of-date test layout
  - id: admin-coverage-prod
    resource: ../../../scripts/coverage.sh
    symbol: dart test --concurrency=1 -P prod
    title: "`scripts/coverage.sh` runs `-P prod` when `GOOGLE_APPLICATION_CREDENTIALS` is set"
  - id: firestore-coverage-prod
    resource: ../../../scripts/firestore-coverage.sh
    symbol: dart test --concurrency=1 -P prod
    title: "`scripts/firestore-coverage.sh` does the same"
  - id: test-wif-job
    resource: ../../../.github/workflows/build.yml
    symbol: "test-wif:"
    title: The `test-wif` job, its authentication and its fork and Dependabot skip
  - id: admin-tags
    resource: ../../../packages/firebase_admin_sdk/dart_test.yaml
    symbol: Tests that hit real Firebase production APIs.
    title: The `prod` and `wif` tags and what credentials they need
  - id: contributing-prod
    resource: ../../../CONTRIBUTING.md
    symbol: "#### Production tests (opt-in)"
    title: CONTRIBUTING's prod and WIF sections
  - id: refresh-token-tests
    resource: ../../../packages/firebase_admin_sdk/test/integration/app/firebase_app_prod_test.dart
    symbol: FIREBASE_REFRESH_TOKEN_CREDENTIALS
    title: The prod and WIF test file, with the refresh-token tests
  - id: root-gitignore
    resource: ../../../.gitignore
    symbol: service-account.json
    title: The root `.gitignore` ignores `service-account.json`
  - id: package-gitignore
    resource: ../../../packages/firebase_admin_sdk/.gitignore
    symbol: service-account-key.json
    title: A package `.gitignore` ignores `service-account-key.json`
---

# Where it lives

- Enforced by (tiers and tags): the default `exclude_tags` and the presets in each `dart_test.yaml`, `exclude_tags: firebase-emulator || prod || wif` in `packages/firebase_admin_sdk/dart_test.yaml`[^admin-default-run] and `exclude_tags: firebase-emulator || prod` in `packages/google_cloud_firestore/dart_test.yaml`.[^firestore-default-run] Each tag's description says what it needs.
- Enforced by (prod and WIF runs): the `prod` and `wif` tags, kept out of the default run (see "Tiers and tags" below). In CI, only the `test-wif` job, `test-wif:` in `.github/workflows/build.yml`, runs admin credential tests.[^test-wif-job]
- The presets as a table: `### Running Tests` in `CONTRIBUTING.md`.[^contributing-running-tests]
- The testing requirements, with two out-of-date lines: `## Testing Requirements` in `CONTRIBUTING.md`, at `*_integration_test.dart` and `RUN_PROD_TESTS`.[^contributing-integration][^contributing-testing]
- An out-of-date test layout: the `test/` tree under `### Repo Organization` in `CONTRIBUTING.md`.[^contributing-layout]
- The coverage scripts' prod run: `dart test --concurrency=1 -P prod` in `scripts/coverage.sh`[^admin-coverage-prod] and `scripts/firestore-coverage.sh`.[^firestore-coverage-prod]
- What credentials each tier needs: the tag descriptions in `packages/firebase_admin_sdk/dart_test.yaml`,[^admin-tags] and `#### Production tests (opt-in)` in `CONTRIBUTING.md`.[^contributing-prod]
- The refresh-token tests: `FIREBASE_REFRESH_TOKEN_CREDENTIALS` in `test/integration/app/firebase_app_prod_test.dart`.[^refresh-token-tests]
- The key files git ignores: `service-account.json` in the root `.gitignore`,[^root-gitignore] and `service-account-key.json` in the packages' `.gitignore` files, such as `packages/firebase_admin_sdk/.gitignore`.[^package-gitignore]

# Constraint

## Tiers and tags

Tests are split into tiers by `dart_test` tags, never by environment variables.

- **Trap:** an untagged test that needs an emulator lands in the default run, and fails for everyone without emulators.
- CONTRIBUTING.md's Testing Requirements are out of date in two lines: there are no `*_integration_test.dart` files, since integration tests live in `test/integration/` and are tagged; and prod tests are gated by the `prod` tag, not `RUN_PROD_TESTS`.
- CONTRIBUTING.md's Repo Organization tree is out of date: admin tests live under `test/unit/<product>/` (plus `test/unit/utils_test.dart`) and `test/integration/<product>/`, and the shared helpers in `test/fixtures/`. Firestore's tests are flat `test/*.dart` files, with the live Pipeline suite in `test/e2e/`.

## Prod and WIF runs

**`-P prod`** runs tests against real Google Cloud APIs.

- In `firebase_admin_sdk`, the two refresh-token tests also need `FIREBASE_REFRESH_TOKEN_CREDENTIALS`. Without it, they fail rather than skip.
- **Trap:** `scripts/coverage.sh` and `scripts/firestore-coverage.sh` run `-P prod` after the emulator run whenever `GOOGLE_APPLICATION_CREDENTIALS` is set. A credential exported in the shell for other work turns a coverage run into a prod run.
- CI never runs `-P prod` for `firebase_admin_sdk`: the `test` job runs the coverage scripts without credentials. The Firestore Pipeline E2E suite is the only prod suite CI runs (see [Pipelines parity with Node](/firestore/pipelines/node-parity.md)).

**`-P wif`** (admin only) runs a single file, in the `test-wif` job in CI.

**Trap: the ignore rules miss some key files.** A `service-account-key.json` at the repo root isn't git-ignored, and in `firebase_admin_sdk` pub doesn't honour the package's ignore (see [the publish dry run](/release/publish-dry-run.md)).

# Why

## Tiers and tags

The maintainers' stated reasons: reviewers ask for tests before merging, and CONTRIBUTING.md makes them mandatory. Why production tests are an explicit opt-in is under "Prod and WIF runs" below. An earlier `RUN_PROD_TESTS`/`hasProdEnv` environment-variable guard was dropped in favour of tags.

## Prod and WIF runs

The maintainers' stated reasons: CI authenticates with Workload Identity Federation instead of a stored service-account key, and prod tests are quota-heavy and meant to run only locally.

# Rules for agents

- **Must:** include tests with every fix or feature.
- **Must:** tag every new test that needs an emulator or credentials.
- **Must:** put test files in the existing layout.
- **Must not:** write a test that reaches production without the `prod` tag.
- **Must not:** merge untested contributions.
- **Must not:** gate tests on custom environment variables, such as `RUN_PROD_TESTS`. Use tags.
- **Must not:** run `-P prod` or `-P wif` unless the user asks and supplies credentials.
- **Must:** before running `scripts/coverage.sh` or `scripts/firestore-coverage.sh`, which you do only when the user asks, check whether `GOOGLE_APPLICATION_CREDENTIALS` is set, without printing it. If it is and the user didn't ask for prod tests, run the script with the variable unset (`env -u GOOGLE_APPLICATION_CREDENTIALS …`).
- **Must not:** write credentials into the repo, print them, or put them in test fixtures. Don't rely on the ignore rules: they cover only the key files above.
- **Must not:** add `firebase_admin_sdk` prod tests to CI (`build.yml`). The Firestore Pipeline E2E suite is the one exception.

# Related

- [Inject test doubles and use the guarded emulator helpers](/tests/helpers-and-injection.md)
- [Pipelines parity with Node](/firestore/pipelines/node-parity.md), for the tag check on the live E2E suite
- [CI workflows: what runs, what gates merging, hardening](/ci/workflows.md)
- [The publish dry run must pass for both packages](/release/publish-dry-run.md)

[^admin-default-run]: The admin package's `dart_test.yaml`
[^firestore-default-run]: The Firestore package's `dart_test.yaml`
[^contributing-running-tests]: CONTRIBUTING's presets table
[^contributing-integration]: CONTRIBUTING's integration-test naming
[^contributing-testing]: CONTRIBUTING's testing requirements
[^contributing-layout]: CONTRIBUTING's repository tree
[^admin-coverage-prod]: The prod run in `scripts/coverage.sh`
[^firestore-coverage-prod]: The prod run in `scripts/firestore-coverage.sh`
[^test-wif-job]: The `test-wif` job
[^admin-tags]: The admin package's tag descriptions
[^contributing-prod]: CONTRIBUTING's prod and WIF sections
[^refresh-token-tests]: The prod and WIF test file
[^root-gitignore]: The root `.gitignore`
[^package-gitignore]: `packages/firebase_admin_sdk/.gitignore`
