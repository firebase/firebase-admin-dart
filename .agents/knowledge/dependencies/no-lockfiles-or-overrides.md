---
type: Constraint
title: No committed lockfiles or dependency overrides
description: "`pubspec.lock` and `pubspec_overrides.yaml` are git-ignored and merged PRs carry no `dependency_overrides`, so CI always resolves the newest allowed versions; committed Node lockfiles are the exception."
tags: [dependencies, ci, lockfiles]
agents_md: when-touching
governs:
  - pubspec.yaml
  - packages/*/pubspec.yaml
  - .gitignore
  - "**/package-lock.json"
sources:
  - id: gitignore-lock
    resource: ../../../.gitignore
    symbol: pubspec.lock
    title: "`pubspec.lock` is git-ignored"
  - id: gitignore-overrides
    resource: ../../../.gitignore
    symbol: pubspec_overrides.yaml
    title: "`pubspec_overrides.yaml` is git-ignored"
  - id: golden-lockfile
    resource: ../../../packages/google_cloud_firestore/tool/pipeline_golden/package-lock.json
    title: A committed Node tool lockfile
  - id: fixture-lockfile
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/task_queue_functions/package-lock.json
    title: The task queue fixture's committed lockfile
  - id: fixture-npm-install
    resource: ../../../scripts/coverage.sh
    symbol: cd test/fixtures/task_queue_functions
    title: "`scripts/coverage.sh` runs `npm install` in the fixture"
---

# Constraint

- `pubspec.lock` and `**/pubspec_overrides.yaml` are git-ignored.[^gitignore-lock][^gitignore-overrides]
- The root `pubspec.yaml` must not carry `dependency_overrides` when a PR is merged.
- So CI always resolves the newest allowed versions, and the daily scheduled run of the Build workflow catches upstream breakage.
- Node lockfiles (`package-lock.json`) are the exception. They are committed for the two `google_cloud_firestore` tools, `tool/pipeline_golden/` and `tool/pipeline_api_parity/`, and for the admin test fixture `test/fixtures/task_queue_functions/`.[^golden-lockfile][^fixture-lockfile]
- The tools' READMEs and workflows install with `npm ci`. The fixture is installed with `npm install`, by CONTRIBUTING's emulator setup and by `scripts/coverage.sh`, which CI's `test` job runs.[^fixture-npm-install]

# Why

- The maintainers state the rule itself: lock files aren't checked in, which is also why Dependabot doesn't check Dart dependencies.
- On overrides, the maintainers' stated reason: a release must not ship with an override in place, so a PR that needs one stays a draft until the dependency is released. The publish dry run doesn't catch an override (see below).
- The likely reason for the daily run (not recorded): it is the early warning for new upstream releases.

# Enforced by

- `.gitignore`, for the lock and override files.
- Overrides: not enforced. The `publish` job's dry run passes with `dependency_overrides` in place and only prints a hint; reviewers must catch them.

# Rules for agents

- **Must:** use `npm ci`, not `npm install`, in `tool/*`, so their committed lockfiles stay as they are. The exception is bumping the pinned Node SDK, which the tool READMEs do with `npm install`, committing the updated lockfile. This rule doesn't cover `test/fixtures/task_queue_functions`, which CONTRIBUTING and `scripts/coverage.sh` install with `npm install`.
- **Must not:** commit `pubspec.lock` or `pubspec_overrides.yaml`.
- **Must not:** leave `dependency_overrides` in a PR meant to merge. If one is needed temporarily, keep the PR as a draft.

# Related

- [dart pub publish --dry-run must pass for both packages](/release/publish-dry-run.md)
- [Dependabot updates GitHub Actions only](/dependencies/dependabot.md)

[^gitignore-lock]: `.gitignore`: `pubspec.lock`
[^gitignore-overrides]: `.gitignore`: `pubspec_overrides.yaml`
[^golden-lockfile]: `tool/pipeline_golden/package-lock.json`
[^fixture-lockfile]: `test/fixtures/task_queue_functions/package-lock.json`
[^fixture-npm-install]: `scripts/coverage.sh`
