---
type: Constraint
title: "CI workflows: what runs, what gates merging, hardening"
description: "A green PR does not mean every suite ran, the coverage threshold is copied as text in two places, and merging is gated only by the `cla/google` status and an Alphabet zizmor scan; CI tests the admin examples but not the Firestore one; workflow edits must pass the zizmor scan and the org Actions allow-list, and Dependabot updates only GitHub Actions."
tags: [ci, workflows, coverage, tests, examples, security, dependencies]
agents_md: when-touching
governs:
  - .github/workflows/**
  - scripts/process_coverage.dart
  - scripts/*coverage.sh
  - packages/firebase_admin_sdk/example/**
  - packages/firebase_admin_sdk/example_server_app/**
  - packages/google_cloud_firestore/example/**
  - .github/dependabot.yaml
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
  - id: ci-example-tests
    resource: ../../../.github/workflows/build.yml
    symbol: example_server_app
    title: The example test steps in the `test` job
  - id: admin-example
    resource: ../../../packages/firebase_admin_sdk/example
    symbol: "publish_to: none"
    title: The admin example package, unpublished
  - id: server-example
    resource: ../../../packages/firebase_admin_sdk/example_server_app
    symbol: "publish_to: none"
    title: The example server app, unpublished
  - id: dependabot-cooldown
    resource: ../../../.github/dependabot.yaml
    symbol: "cooldown:"
    title: The Dependabot config, with the reasons for its cooldown, grouping and codecov ignore
  - id: codecov-pin
    resource: ../../../.github/workflows/build.yml
    symbol: codecov/codecov-action@
    title: The `codecov/codecov-action` pin, at v4
  - id: knowledge-checkout
    resource: ../../../.github/workflows/knowledge.yml
    symbol: "persist-credentials: false"
    title: Read-only permissions and a credential-free checkout
---

# Where it lives

- Enforced by (what runs and what gates merging): the coverage gate, the `Process coverage and check threshold` step in `.github/workflows/build.yml`,[^coverage-step] which runs `scripts/process_coverage.dart`; the threshold is what `totalCov.pct` is compared with.[^process-coverage]
- Enforced by (example tests): the example test steps in the `test` job, which name `example_server_app` in `.github/workflows/build.yml`.[^ci-example-tests] Nothing covers the Firestore example.
- Enforced by (workflow hardening and Dependabot): the Alphabet zizmor scan and the org Actions allow-list, both configured outside the repo (see "What runs and what gates merging" below). The rest is review only.
- Triggers, path filters and skip conditions, with their reasons in comments: each workflow's `on:` and `if:` in `.github/workflows/`, such as `build.yml`,[^build-dispatch] `knowledge.yml`[^knowledge] and `e2e_pipeline.yml`.[^e2e]
- The threshold repeated as text: `Minimum threshold` in `build.yml`'s coverage comment[^coverage-comment] and `threshold** enforced by CI` in `CONTRIBUTING.md`.[^contributing-threshold]
- A `workflow_dispatch` input that no job reads: `dart_version:` in `build.yml`.[^build-dispatch]
- CONTRIBUTING.md's out-of-date CI table: `test-integration` in `CONTRIBUTING.md`.[^contributing-ci]
- The admin examples, unpublished workspace members: `packages/firebase_admin_sdk/example/`[^admin-example] and `packages/firebase_admin_sdk/example_server_app/`.[^server-example]
- Dependabot's scope, cooldown, grouping and codecov ignore, with their reasons in comments: `cooldown:` in `.github/dependabot.yaml`.[^dependabot-cooldown]
- The one action held at an old major: `codecov/codecov-action@` in `.github/workflows/build.yml`.[^codecov-pin]
- The practice to copy, with read-only `permissions` and a checkout without credentials: `persist-credentials: false` in `.github/workflows/knowledge.yml`.[^knowledge-checkout]

# Constraint

## What runs and what gates merging

**Merge gates live outside the repo.** Branch protection on `main` requires only the `cla/google` status. An Alphabet enterprise ruleset also requires the zizmor workflow, `github_actions_scan.yml`, which lives in another Google repository. No workflow in this repo gates merging.

**The coverage gate** runs only in the stable `test` job. The script holds the threshold; the PR-comment text and CONTRIBUTING.md repeat it, and neither reads it from the script.

**CONTRIBUTING.md's CI table is out of date.** It names the jobs `test-integration` and `build`; they are `test-wif` and `publish`.

## Example tests

`packages/google_cloud_firestore/example/` holds plain Dart files inside the Firestore package. It isn't a workspace member, and CI neither analyzes it, since CI analyzes only `firebase_admin_sdk`, nor runs it.

## Workflow hardening and Dependabot

**The zizmor scan** enforces:

- every action pinned to a full commit SHA;
- no `${{ }}` interpolation of secrets or untrusted values inside `run:` or `script:` blocks; pass them through `env:`;
- a Dependabot `cooldown`.

**The org Actions allow-list** permits only allow-listed actions. The codecov ignore in `dependabot.yaml` says which `codecov/codecov-action` major it allows.

**Not enforced:** read-only top-level `permissions`, escalated per job, and `persist-credentials: false` on checkouts are repo practice. Whether the scan requires them isn't stated, and `build.yml`'s checkouts pass without the latter.

# Why

## What runs and what gates merging

- The reasons for the path filters and skips are in the workflow comments.
- Why the threshold has its value isn't recorded; when it was set, the plan was to raise it as coverage grew. Ask a maintainer before changing it.

## Example tests

The maintainers' stated reason for testing the admin examples: the example server's test assertions went stale after its routes changed, because CI ran only the SDK and Firestore unit tests.

## Workflow hardening and Dependabot

- The maintainers' stated reasons: the SHA pins and the template-injection fix were made to unblock the mandatory zizmor check, and the Dependabot cooldown was added because the scan flags a config without one. The other Dependabot reasons are in its comments.
- The maintainers' stated reason Dependabot skips Dart: no lock files are checked in (see [no lockfiles](/dependencies/dependency-set.md)).

# Rules for agents

- **Must:** expect a docs-only PR to skip Build.
- **Must not:** assume a green PR means the prod, WIF or E2E tests ran. Which suites CI never runs is in [Prod and WIF test runs](/tests/tiers-and-tags.md).
- **Must not:** treat CI as a merge gate it is not.
- **Must not:** lower the coverage threshold.
- **Must:** if a maintainer changes the threshold, update the PR-comment text in `build.yml` and CONTRIBUTING.md in the same PR.
- **Must:** when you change or remove a public API that an example uses, update that example. Run the tests of the admin `example/` and `example_server_app/`, and check that `google_cloud_firestore/example/` still analyzes; it has no tests.
- **Must:** pin any new or updated action to a full commit SHA. The zizmor scan enforces it.
- **Must:** use only actions already used here or confirmed to be allow-listed.
- **Must:** keep secrets in `env:`.
- **Must not:** bump `codecov/codecov-action` past v4.
- **Must not:** remove the Dependabot cooldown.
- **Ask first:** before adding a `pub` or `npm` ecosystem to Dependabot.
- **Should:** add a `# vX` comment naming the version after the SHA, as on the `codecov/codecov-action` pin.
- **Should:** add `persist-credentials: false` to checkouts that don't push.
- **Should:** keep `permissions` read-only by default, and don't loosen existing ones.

# Related

- [Pull requests: titles, template, review and CLA](/contributing/pull-requests.md)
- [Test tiers and tags, and the prod and WIF runs](/tests/tiers-and-tags.md)
- [Pipelines parity with Node](/firestore/pipelines/node-parity.md)
- [The pub workspace, melos and local setup](/repo/workspace-and-melos.md), for the `coverage.lcov` every package needs
- [Lints, analysis and formatting](/ci/lint-and-format.md)
- [Small dependency set, no lockfiles or overrides](/dependencies/dependency-set.md)

[^coverage-step]: The coverage step in `build.yml`
[^process-coverage]: `scripts/process_coverage.dart`
[^coverage-comment]: The coverage PR comment in `build.yml`
[^contributing-threshold]: CONTRIBUTING's testing requirements
[^build-dispatch]: `build.yml`
[^knowledge]: `knowledge.yml`
[^e2e]: `e2e_pipeline.yml`
[^contributing-ci]: CONTRIBUTING's CI table
[^ci-example-tests]: The example test steps in CI
[^admin-example]: The admin example package
[^server-example]: The example server app
[^dependabot-cooldown]: `.github/dependabot.yaml`
[^codecov-pin]: The codecov pin in `build.yml`
[^knowledge-checkout]: `knowledge.yml` permissions and checkout
