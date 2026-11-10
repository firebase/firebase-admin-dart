---
type: Constraint
title: What CI runs, the coverage gate, and what gates merging
description: The workflow files say what runs where; beyond them, docs-only PRs skip Build, a green PR doesn't mean prod, WIF or E2E tests ran, the coverage threshold is copied as text in two places, and merging is gated only by the `cla/google` status and an Alphabet zizmor scan.
tags: [ci, workflows, coverage]
agents_md: when-touching
governs:
  - .github/workflows/**
  - scripts/process_coverage.dart
  - scripts/*coverage.sh
sources:
  - id: coverage-step
    resource: ../../../.github/workflows/build.yml
    symbol: Process coverage and check threshold
    title: The coverage gate in the `test` job, on stable only
  - id: process-coverage
    resource: ../../../scripts/process_coverage.dart
    symbol: totalCov.pct
    title: Merges `packages/*/coverage.lcov` and holds the threshold
  - id: coverage-comment
    resource: ../../../.github/workflows/build.yml
    symbol: Minimum threshold
    title: The threshold repeated as text in the coverage PR comment
  - id: contributing-threshold
    resource: ../../../CONTRIBUTING.md
    symbol: threshold** enforced by CI
    title: The threshold repeated as text in CONTRIBUTING
  - id: build-dispatch
    resource: ../../../.github/workflows/build.yml
    symbol: "dart_version:"
    title: The Build workflow's triggers, including a dispatch input no job reads
  - id: knowledge
    resource: ../../../.github/workflows/knowledge.yml
    symbol: ./scripts/knowledge.sh check
    title: The knowledge-base check, with no path filter
  - id: e2e
    resource: ../../../.github/workflows/e2e_pipeline.yml
    symbol: Requires live-project secrets
    title: The live Pipeline E2E workflow and its fork and Dependabot skip
  - id: contributing-ci
    resource: ../../../CONTRIBUTING.md
    symbol: test-integration
    title: CONTRIBUTING's CI table, with out-of-date job names
---

# Where it lives

- Enforced by: the coverage gate, the `Process coverage and check threshold` step in `.github/workflows/build.yml`,[^coverage-step] which runs `scripts/process_coverage.dart`; the threshold is what `totalCov.pct` is compared with.[^process-coverage]
- Triggers, path filters and skip conditions, with their reasons in comments: each workflow's `on:` and `if:` in `.github/workflows/`, such as `build.yml`,[^build-dispatch] `knowledge.yml`[^knowledge] and `e2e_pipeline.yml`.[^e2e]
- The threshold repeated as text: `Minimum threshold` in `build.yml`'s coverage comment[^coverage-comment] and `threshold** enforced by CI` in `CONTRIBUTING.md`.[^contributing-threshold]
- A `workflow_dispatch` input that no job reads: `dart_version:` in `build.yml`.[^build-dispatch]
- CONTRIBUTING.md's out-of-date CI table: `test-integration` in `CONTRIBUTING.md`.[^contributing-ci]

# Constraint

**Merge gates live outside the repo.** Branch protection on `main` requires only the `cla/google` status. An Alphabet enterprise ruleset also requires the zizmor workflow, `github_actions_scan.yml`, which lives in another Google repository. No workflow in this repo gates merging.

**Docs-only PRs skip Build.** `build.yml` ignores Markdown, so a PR that only edits AGENTS.md or the knowledge bundle runs no Build. `knowledge.yml`, which has no path filter, is what checks it.

**A green PR doesn't mean everything ran.** Forks and Dependabot skip `test-wif` and the Pipeline E2E suite, the Firestore workflows run only on Firestore changes, and admin prod tests never run in CI (see [Prod and WIF test runs](/tests/prod-and-wif.md)).

**`dart_version` does nothing.** The `workflow_dispatch` input of `build.yml` is read by no job, so a manual run uses the same SDK matrix as any other run.

**The coverage gate** runs only in the stable `test` job. Codecov, which the same job uploads to, never blocks. The script holds the threshold; the PR-comment text and CONTRIBUTING.md repeat it, and neither reads it from the script.

**CONTRIBUTING.md's CI table is out of date.** It names the jobs `test-integration` and `build`; they are `test-wif` and `publish`.

# Why

- The reasons for the path filters and skips are in the workflow comments.
- Why the threshold has its value isn't recorded; when it was set, the plan was to raise it as coverage grew. Ask a maintainer before changing it.

# Rules for agents

- **Must:** expect a docs-only PR to skip Build.
- **Must not:** assume a green PR means the prod, WIF or E2E tests ran.
- **Must not:** treat CI as a merge gate it is not.
- **Must not:** lower the coverage threshold.
- **Must:** if a maintainer changes the threshold, update the PR-comment text in `build.yml` and CONTRIBUTING.md in the same PR.

# Related

- [Workflow security rules and Dependabot](/ci/workflow-hardening.md)
- [PR template, review, licence and CLA](/contributing/pr-template-and-review.md)
- [Prod and WIF test runs](/tests/prod-and-wif.md)
- [Pipelines parity with Node](/firestore/pipelines/node-parity.md)
- [The pub workspace, melos and local setup](/repo/workspace-and-melos.md), for the `coverage.lcov` every package needs

[^coverage-step]: The coverage step in `build.yml`
[^process-coverage]: `scripts/process_coverage.dart`
[^coverage-comment]: The coverage PR comment in `build.yml`
[^contributing-threshold]: CONTRIBUTING's testing requirements
[^build-dispatch]: `build.yml`
[^knowledge]: `knowledge.yml`
[^e2e]: `e2e_pipeline.yml`
[^contributing-ci]: CONTRIBUTING's CI table
