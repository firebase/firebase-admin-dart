---
type: Constraint
title: Live Pipeline E2E suite
description: The Firestore Pipeline E2E suite runs against a live Enterprise database in its own workflow, and every public Pipeline API member must have a live case there or a credential-free guard fails.
tags: [tests, firestore, pipelines, ci]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/test/e2e/**
  - packages/google_cloud_firestore/lib/src/pipeline.dart
  - .github/workflows/e2e_pipeline.yml
sources:
  - id: e2e-readme
    resource: ../../../packages/google_cloud_firestore/test/e2e/README.md
    title: The suite's rules and their reasons
  - id: e2e-workflow
    resource: ../../../.github/workflows/e2e_pipeline.yml
    symbol: PIPELINE_E2E_SERVICE_ACCOUNT
    title: The E2E workflow, its secrets and its skip checks
  - id: coverage-guard
    resource: ../../../packages/google_cloud_firestore/test/pipeline_e2e_coverage_test.dart
    title: The credential-free coverage guard
---

# Constraint

`packages/google_cloud_firestore/test/e2e/pipeline/` runs against a live Enterprise-edition database, `firestore-pipeline-test`, which it shares with FlutterFire.

- It runs in `.github/workflows/e2e_pipeline.yml` with a long-lived service-account key (the `PIPELINE_E2E_SERVICE_ACCOUNT` secret) and the `PIPELINE_E2E_PROJECT_ID` secret.[^e2e-workflow]
- It needs the `pipeline_e2e_books` vector index, created once out of band, and `--concurrency=1`.
- Each file is tagged `prod`, imports only the public barrel, `package:test` and the harness, and wraps its tests in `pipelineE2E(...)`.[^e2e-readme]
- Every public Pipeline API member, optional parameter and value position must be exercised there. Otherwise `test/pipeline_e2e_coverage_test.dart`, an ordinary unit test that needs no credentials, fails.[^coverage-guard]

# Why

Stated in `test/e2e/README.md`:

- No `(default)` database fallback, because it "would let an ambient `GOOGLE_CLOUD_PROJECT` silently point the suite somewhere it cannot pass".
- Skip detection, because "`dart test` exits `0` when every test is *skipped*".
- Barrel-only imports, "so a public API missing from the barrel fails to compile here".
- "Adding a public Pipeline function therefore means adding a live case for it here; the guard fails until you do."

# Enforced by

- `.github/workflows/e2e_pipeline.yml`: a concurrency group per ref, early failures on empty secrets and on "All tests skipped", and the key written to `$RUNNER_TEMP` and removed afterwards.
- `test/pipeline_e2e_coverage_test.dart`, in the unit run.

# Rules for agents

- **Must:** when you add a public Pipeline API member, add live cases for it in the right family file.
- **Must not:** point the suite at another database, or add a `(default)` fallback.
- **Must not:** weaken the skip guards.

# Related

- [Pipelines parity with Node](/firestore/pipelines/node-parity.md)
- [Prod and WIF test runs](/tests/prod-and-wif.md)
- [What CI runs where](/ci/trigger-matrix.md)

[^e2e-workflow]: The E2E workflow
[^e2e-readme]: The suite's README
[^coverage-guard]: The coverage guard
