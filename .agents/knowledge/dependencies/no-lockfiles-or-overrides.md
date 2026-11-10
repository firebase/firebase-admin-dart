---
type: Constraint
title: No committed lockfiles or dependency overrides
description: "No `pubspec.lock`, `pubspec_overrides.yaml` or merged `dependency_overrides`, so CI always resolves the newest allowed versions; the committed Node lockfiles are the exception, installed with `npm ci` in the tools and `npm install` in the test fixture."
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
  - id: build-schedule
    resource: ../../../.github/workflows/build.yml
    symbol: "schedule:"
    title: The Build workflow's daily scheduled run
---

# Where it lives

- Enforced by: `.gitignore`, for `pubspec.lock` and `pubspec_overrides.yaml`.[^gitignore-lock][^gitignore-overrides] Nothing enforces the no-`dependency_overrides` rule; review only.
- The committed Node lockfiles: `package-lock.json` in each `tool/pipeline_*` directory of `google_cloud_firestore`, such as `tool/pipeline_golden/`,[^golden-lockfile] and in `test/fixtures/task_queue_functions/`.[^fixture-lockfile]
- The fixture's `npm install`: `cd test/fixtures/task_queue_functions` in `scripts/coverage.sh`.[^fixture-npm-install]
- The early warning for upstream breakage: `schedule:` in `.github/workflows/build.yml`.[^build-schedule]

# Constraint

- The root `pubspec.yaml` must not carry `dependency_overrides` when a PR is merged.
- So CI always resolves the newest allowed versions, and the daily scheduled run of the Build workflow catches upstream breakage.
- The publish dry run doesn't fail on an override; it only prints a hint. Nothing else catches one.
- The tool lockfiles are installed with `npm ci`, by the tools' READMEs and workflows. The fixture is installed with `npm install`, by CONTRIBUTING's emulator setup and by `scripts/coverage.sh`, which CI's `test` job runs.

# Why

- The maintainers state the rule itself: lock files aren't checked in, which is also why Dependabot doesn't check Dart dependencies.
- On overrides, the maintainers' stated reason: the package cannot be published with an override in place, so a PR that needs one stays a draft until the dependency is released.
- The likely reason for the daily run (not recorded): it is the early warning for new upstream releases.

# Rules for agents

- **Must:** use `npm ci`, not `npm install`, in `tool/*`, so their committed lockfiles stay as they are. The exception is bumping the pinned Node SDK, which the tool READMEs do with `npm install`, committing the updated lockfile. This rule doesn't cover `test/fixtures/task_queue_functions`, which CONTRIBUTING and `scripts/coverage.sh` install with `npm install`.
- **Must not:** commit `pubspec.lock` or `pubspec_overrides.yaml`.
- **Must not:** leave `dependency_overrides` in a PR meant to merge. If one is needed temporarily, keep the PR as a draft.

# Related

- [The publish dry run must pass for both packages](/release/publish-dry-run.md)
- [Other generated, compiled or mirrored files](/generated/other-generated-files.md)
- [Workflow security rules and Dependabot](/ci/workflow-hardening.md)

[^gitignore-lock]: `.gitignore`: `pubspec.lock`
[^gitignore-overrides]: `.gitignore`: `pubspec_overrides.yaml`
[^golden-lockfile]: `tool/pipeline_golden/package-lock.json`
[^fixture-lockfile]: `test/fixtures/task_queue_functions/package-lock.json`
[^fixture-npm-install]: `scripts/coverage.sh`
[^build-schedule]: The `schedule:` trigger in `build.yml`
