---
type: Constraint
title: Prod and WIF test runs
description: "`-P prod` needs a service account for the Google-owned `dart-firebase-admin` project and never runs in CI for `firebase_admin_sdk`, while `-P wif` runs one test file in the `test-wif` job."
tags: [tests, credentials, ci]
agents_md: always
governs:
  - packages/*/test/**/*_prod_test.dart
  - .github/workflows/build.yml
  - scripts/*coverage.sh
sources:
  - id: test-wif-job
    resource: ../../../.github/workflows/build.yml
    symbol: "test-wif:"
    title: The `test-wif` job and its fork and Dependabot skip
  - id: wif-test
    resource: ../../../packages/firebase_admin_sdk/test/integration/app/firebase_app_prod_test.dart
    symbol: firebase-adminsdk-fbsvc
    title: The prod and WIF test file
  - id: prod-opt-in
    resource: ../../../scripts/coverage.sh
    symbol: GOOGLE_APPLICATION_CREDENTIALS
    title: The coverage script runs `-P prod` only when credentials are set
  - id: root-gitignore
    resource: ../../../.gitignore
    symbol: service-account.json
    title: The root `.gitignore` ignores `service-account.json`
  - id: package-gitignore
    resource: ../../../packages/firebase_admin_sdk/.gitignore
    symbol: service-account-key.json
    title: A package `.gitignore` ignores `service-account-key.json`
---

# Constraint

**`-P prod`** runs tests against real Google Cloud APIs.

- It needs `GOOGLE_APPLICATION_CREDENTIALS` pointing to a service account with access to the Google-owned `dart-firebase-admin` project. `scripts/coverage.sh` and `scripts/firestore-coverage.sh` run it only when that variable is set.[^prod-opt-in]
- In `firebase_admin_sdk`, it also needs `FIREBASE_REFRESH_TOKEN_CREDENTIALS`. Without it, the two refresh-token tests fail rather than skip.[^wif-test]
- CI never runs `-P prod` for `firebase_admin_sdk`. The one prod suite CI runs is the Firestore Pipeline E2E suite.

**`-P wif`** (admin only) runs a single file, `test/integration/app/firebase_app_prod_test.dart`, in the `test-wif` job of `.github/workflows/build.yml`.[^test-wif-job]

- The job authenticates through `google-github-actions/auth` with the `WORKLOAD_IDENTITY_PROVIDER` and `SERVICE_ACCOUNT` secrets.
- The test hardcodes the project's `firebase-adminsdk-fbsvc` service account.
- Fork and Dependabot PRs get no secrets, so the job is skipped for them.

# Why

The maintainers' stated reasons: CI authenticates with Workload Identity Federation instead of a stored service-account key, and prod tests are quota-heavy and meant to run only locally. The `test-wif` job skips forks and Dependabot because "repository secrets are not available" to them.

# Enforced by

The `prod` and `wif` presets in each `dart_test.yaml`, and the `test-wif` job in `.github/workflows/build.yml`.

# Rules for agents

- **Must not:** run `-P prod` or `-P wif` unless the user asks and supplies credentials.
- **Must not:** write credentials into the repo, print them, or put them in test fixtures. The ignore rules cover only some key files:
  - the root `.gitignore` ignores `service-account.json` in every directory;[^root-gitignore]
  - `service-account-key.json` is ignored only inside `packages/firebase_admin_sdk/` and `packages/google_cloud_firestore/`, by those packages' `.gitignore` files (the examples' `.gitignore` files list it too). Elsewhere, such as at the repo root, it isn't ignored.[^package-gitignore]
- **Must not:** add `firebase_admin_sdk` prod tests to CI (`build.yml`). The Firestore Pipeline E2E suite is the one exception.

# Related

- [Test tiers and tags](/tests/tiers-and-tags.md)
- [Live Pipeline E2E suite](/tests/pipeline-e2e-live.md)
- [What CI runs where](/ci/trigger-matrix.md)

[^prod-opt-in]: The coverage script's `-P prod` opt-in
[^wif-test]: The prod and WIF test file
[^test-wif-job]: The `test-wif` job
[^root-gitignore]: The root `.gitignore`
[^package-gitignore]: `packages/firebase_admin_sdk/.gitignore`
