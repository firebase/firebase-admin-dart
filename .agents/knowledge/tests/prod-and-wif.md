---
type: Constraint
title: Prod and WIF test runs
description: "`-P prod` and `-P wif` need real credentials and run only on request; the coverage scripts add `-P prod` whenever `GOOGLE_APPLICATION_CREDENTIALS` is set, and CI never runs admin prod tests, so the Pipeline E2E suite is the only prod suite CI runs."
tags: [tests, credentials, ci]
agents_md: always
governs:
  - packages/*/test/**/*_prod_test.dart
  - .github/workflows/build.yml
  - scripts/*coverage.sh
sources:
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

- Enforced by: the `prod` and `wif` tags, kept out of the default run (see [test tiers](/tests/tiers-and-tags.md)). In CI, only the `test-wif` job, `test-wif:` in `.github/workflows/build.yml`, runs admin credential tests.[^test-wif-job]
- The coverage scripts' prod run: `dart test --concurrency=1 -P prod` in `scripts/coverage.sh`[^admin-coverage-prod] and `scripts/firestore-coverage.sh`.[^firestore-coverage-prod]
- What credentials each tier needs: the tag descriptions in `packages/firebase_admin_sdk/dart_test.yaml`,[^admin-tags] and `#### Production tests (opt-in)` in `CONTRIBUTING.md`.[^contributing-prod]
- The refresh-token tests: `FIREBASE_REFRESH_TOKEN_CREDENTIALS` in `test/integration/app/firebase_app_prod_test.dart`.[^refresh-token-tests]
- The key files git ignores: `service-account.json` in the root `.gitignore`,[^root-gitignore] and `service-account-key.json` in the packages' `.gitignore` files, such as `packages/firebase_admin_sdk/.gitignore`.[^package-gitignore]

# Constraint

**`-P prod`** runs tests against real Google Cloud APIs.

- In `firebase_admin_sdk`, the two refresh-token tests also need `FIREBASE_REFRESH_TOKEN_CREDENTIALS`. Without it, they fail rather than skip.
- **Trap:** `scripts/coverage.sh` and `scripts/firestore-coverage.sh` run `-P prod` after the emulator run whenever `GOOGLE_APPLICATION_CREDENTIALS` is set. A credential exported in the shell for other work turns a coverage run into a prod run.
- CI never runs `-P prod` for `firebase_admin_sdk`: the `test` job runs the coverage scripts without credentials. The Firestore Pipeline E2E suite is the only prod suite CI runs (see [Pipelines parity with Node](/firestore/pipelines/node-parity.md)).

**`-P wif`** (admin only) runs a single file, in the `test-wif` job in CI.

**Trap: the ignore rules miss some key files.** A `service-account-key.json` at the repo root isn't git-ignored, and in `firebase_admin_sdk` pub doesn't honour the package's ignore (see [the publish dry run](/release/publish-dry-run.md)).

# Why

The maintainers' stated reasons: CI authenticates with Workload Identity Federation instead of a stored service-account key, and prod tests are quota-heavy and meant to run only locally.

# Rules for agents

- **Must not:** run `-P prod` or `-P wif` unless the user asks and supplies credentials.
- **Must:** before running `scripts/coverage.sh` or `scripts/firestore-coverage.sh`, which you do only when the user asks, check whether `GOOGLE_APPLICATION_CREDENTIALS` is set, without printing it. If it is and the user didn't ask for prod tests, run the script with the variable unset (`env -u GOOGLE_APPLICATION_CREDENTIALS …`).
- **Must not:** write credentials into the repo, print them, or put them in test fixtures. Don't rely on the ignore rules: they cover only the key files above.
- **Must not:** add `firebase_admin_sdk` prod tests to CI (`build.yml`). The Firestore Pipeline E2E suite is the one exception.

# Related

- [Every change needs tests, in tiers selected by tags](/tests/tiers-and-tags.md)
- [Pipelines parity with Node](/firestore/pipelines/node-parity.md)
- [What CI runs, the coverage gate, and what gates merging](/ci/trigger-matrix.md)
- [The publish dry run must pass for both packages](/release/publish-dry-run.md)

[^admin-coverage-prod]: The prod run in `scripts/coverage.sh`
[^firestore-coverage-prod]: The prod run in `scripts/firestore-coverage.sh`
[^test-wif-job]: The `test-wif` job
[^admin-tags]: The admin package's tag descriptions
[^contributing-prod]: CONTRIBUTING's prod and WIF sections
[^refresh-token-tests]: The prod and WIF test file
[^root-gitignore]: The root `.gitignore`
[^package-gitignore]: `packages/firebase_admin_sdk/.gitignore`
