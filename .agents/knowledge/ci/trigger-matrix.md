---
type: Constraint
title: What CI runs where, and what gates merging
description: Build runs on every non-docs PR, push to `main` and nightly, the knowledge-base check on every PR and push to `main`, the Firestore-only workflows on Firestore changes, admin prod tests never run in CI, and merging is gated by the `cla/google` status and an Alphabet-required zizmor scan, not by any workflow in this repo.
tags: [ci, workflows]
agents_md: when-touching
governs:
  - .github/workflows/**
sources:
  - id: build
    resource: ../../../.github/workflows/build.yml
    title: The main Build workflow
  - id: e2e
    resource: ../../../.github/workflows/e2e_pipeline.yml
    title: The live Pipeline E2E workflow
  - id: golden
    resource: ../../../.github/workflows/pipeline_golden.yml
    title: The Pipeline golden-fixture check
  - id: snapshot
    resource: ../../../.github/workflows/pipeline_api_snapshot.yml
    title: The Pipeline API snapshot check
  - id: knowledge
    resource: ../../../.github/workflows/knowledge.yml
    symbol: ./scripts/knowledge.sh check
    title: The knowledge-base check
---

# Constraint

**`build.yml`** runs on every PR that changes anything besides `**.md` and `**.mdx` files, on every push to `main`, nightly, and on manual dispatch:[^build]

- `check-license-header`;
- `lint`, on the SDK floor, stable and dev;
- `test`, on stable and beta: emulators and coverage for both packages, then the `example/` and `example_server_app/` tests. The coverage threshold and PR comment run on stable only;
- `test-wif`, skipped for forks and Dependabot;
- `publish`: the dry run of both packages, after the others pass.

Its `workflow_dispatch` input `dart_version` is read by no job.

**`knowledge.yml`** runs `./scripts/knowledge.sh check` on every PR, Markdown-only ones included, and on every push to `main`. It has no path filter.[^knowledge]

**PRs that touch `packages/google_cloud_firestore/**`** or the workflow file itself, and pushes to `main` that do, run:

- `pipeline_golden.yml` and `pipeline_api_snapshot.yml`;[^golden][^snapshot]
- `e2e_pipeline.yml`, against live Firestore, skipped for forks and Dependabot.[^e2e]

**Nightly**, only `build.yml` and `e2e_pipeline.yml` run. The golden and snapshot checks are not scheduled.

**Never in CI:** `-P prod` for `firebase_admin_sdk`, and for `google_cloud_firestore` outside `test/e2e/pipeline/`.

**Merging.** Branch protection on `main` requires only the `cla/google` status. An Alphabet enterprise ruleset also requires the zizmor workflow, `github_actions_scan.yml`, which lives in another Google repository. No workflow in this repo gates merging.

Because `build.yml` ignores `**.md`, a PR that only edits AGENTS.md or the knowledge bundle runs no Build; `knowledge.yml` is what checks it.

# Why

Stated in the workflow comments:

- The E2E tests "cost live Firestore quota, so they are not worth running for changes that cannot affect them".
- The snapshot check is a separate workflow "so that it only runs for google_cloud_firestore changes: build.yml cannot filter paths per job".
- `test-wif` is skipped for fork and Dependabot PRs because "repository secrets are not available".

# Enforced by

The workflow files in `.github/workflows/`. Merging is gated only by branch protection (`cla/google`) and the Alphabet ruleset (zizmor).

# Rules for agents

- **Must:** expect a docs-only PR to skip Build.
- **Must not:** assume a green PR means the prod, WIF or E2E tests ran. Forks and Dependabot skip them.
- **Must not:** treat CI as a merge gate it is not.

# Related

- [Workflow security rules](/ci/workflow-hardening.md)
- [Apache-2.0 licence and the Google CLA](/contributing/license-and-cla.md)
- [Live Pipeline E2E suite](/tests/pipeline-e2e-live.md)
- [Prod and WIF test runs](/tests/prod-and-wif.md)

[^build]: `build.yml`
[^golden]: `pipeline_golden.yml`
[^snapshot]: `pipeline_api_snapshot.yml`
[^e2e]: `e2e_pipeline.yml`
[^knowledge]: `knowledge.yml`
