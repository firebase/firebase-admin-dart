---
type: Constraint
title: Coverage threshold in CI
description: CI merges both packages' coverage and fails the stable `test` job when total line coverage is below the threshold in `scripts/process_coverage.dart`.
tags: [tests, coverage, ci]
agents_md: when-touching
governs:
  - scripts/process_coverage.dart
  - scripts/*coverage.sh
  - pubspec.yaml
sources:
  - id: process-coverage
    resource: ../../../scripts/process_coverage.dart
    symbol: totalCov.pct
    title: Merges `packages/*/coverage.lcov` and checks the threshold
  - id: coverage-script
    resource: ../../../scripts/coverage.sh
    symbol: test_with_coverage
    title: Coverage collection inside the emulators
---

# Constraint

- `scripts/coverage.sh` and `scripts/firestore-coverage.sh` collect coverage inside the emulators with `dart run coverage:test_with_coverage -- --concurrency=1 -P ci`.[^coverage-script]
- `scripts/process_coverage.dart` merges every `packages/*/coverage.lcov` into the root `coverage.lcov`, and fails when total line coverage is below the threshold it defines. It also fails when any directory under `packages/` has no `coverage.lcov`.[^process-coverage]
- The check runs only in the `test` job on the stable SDK. That job also posts the result as a PR comment (non-fork PRs only) and uploads it to Codecov, which never blocks.

# Why

The maintainers' stated reason for `test_with_coverage`, in `scripts/coverage.sh`: "dart test --coverage doesn't work with resolution: workspace".

Why the threshold has its value isn't recorded; when it was set, the plan was to raise it as coverage grew. Ask a maintainer before changing it.

# Enforced by

`scripts/process_coverage.dart`, run by the `test` job of `.github/workflows/build.yml` on the stable SDK.

# Rules for agents

- **Must not:** lower the threshold.
- **Must not:** add a directory under `packages/` without wiring its coverage.
- **Must not:** commit `coverage/` or `coverage.lcov`. Both are git-ignored.

# Related

- [The pub workspace and melos](/repo/workspace-and-melos.md)
- [Test tiers and tags](/tests/tiers-and-tags.md)

[^coverage-script]: `scripts/coverage.sh`
[^process-coverage]: `scripts/process_coverage.dart`
