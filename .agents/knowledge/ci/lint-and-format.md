---
type: Constraint
title: Lints, analysis and formatting
description: One root `analysis_options.yaml` applies to every package, but CI analyzes and format-checks only `packages/firebase_admin_sdk/`, with `--fatal-infos` and the format check on the dev SDK only, so format only the files you change and check ignores against every analysis SDK.
tags: [ci, lints, formatting]
agents_md: always
governs:
  - analysis_options.yaml
  - .github/workflows/build.yml
sources:
  - id: lint-job
    resource: ../../../.github/workflows/build.yml
    symbol: "name: Lint (Dart"
    title: The `lint` job, run only in `packages/firebase_admin_sdk`
  - id: fatal-infos
    resource: ../../../.github/workflows/build.yml
    symbol: dart analyze --fatal-infos
    title: "`--fatal-infos` in the `lint` job, on dev only"
  - id: format-check
    resource: ../../../.github/workflows/build.yml
    symbol: dart format --set-exit-if-changed
    title: The format check in the `lint` job, on dev only
  - id: analysis-options
    resource: ../../../analysis_options.yaml
    symbol: dart_flutter_team_lints
    title: The root analysis options
  - id: unnecessary-ignore
    resource: ../../../analysis_options.yaml
    symbol: unnecessary_ignore
    title: The `unnecessary_ignore` lint
  - id: messaging-ignore
    resource: ../../../packages/firebase_admin_sdk/test/unit/messaging/messaging_test.dart
    symbol: "ignore_for_file: deprecated_member_use"
    title: A blanket ignore whose need depends on the resolved `googleapis`
  - id: contributing-format
    resource: ../../../CONTRIBUTING.md
    symbol: "### Code Formatting and Analysis"
    title: CONTRIBUTING's formatting advice, which runs `dart format .`
---

# Where it lives

- Enforced by: the `lint` job, `name: Lint (Dart` in `.github/workflows/build.yml`, which runs only in `packages/firebase_admin_sdk`.[^lint-job] `dart analyze --fatal-infos`[^fatal-infos] and `dart format --set-exit-if-changed`[^format-check] run there on dev only.
- The lint set, strict modes and analysis excludes: `dart_flutter_team_lints` and `unnecessary_ignore` in the root `analysis_options.yaml`.[^analysis-options][^unnecessary-ignore]
- An ignore whose need depends on the resolved `googleapis`: `ignore_for_file: deprecated_member_use` in `test/unit/messaging/messaging_test.dart`.[^messaging-ignore]
- CONTRIBUTING.md's out-of-date formatting advice: `### Code Formatting and Analysis`, and the Local Validation section after it.[^contributing-format]

# Constraint

**CI checks only the admin package.** The `lint` job takes in `firebase_admin_sdk`'s `example/` for both checks, and its `example_server_app/` for the format check only, since analysis excludes it. CI neither analyzes nor format-checks `packages/google_cloud_firestore/` or `scripts/`.

**Formatter skew.** Formatter output differs between SDK versions, and CI checks formatting on dev only. A contributor on stable can produce diffs CI rejects, or rewrite files CI accepts. CONTRIBUTING.md's `dart format .`, under Code Formatting and Analysis and Local Validation, is out of date: format only the files you change.

**Ignore skew.** `unnecessary_ignore` is on, analysis runs on three SDKs, and dependencies aren't locked. An `// ignore:` needed with one SDK or dependency version can be flagged as unnecessary with another, which is fatal on dev because of `--fatal-infos`.

# Why

Why the project uses this lint setup isn't recorded. Both skews have broken CI: formatting had to be reverted to match the dev formatter, and the `deprecated_member_use` ignore in `messaging_test.dart` was removed as unnecessary, then restored to satisfy `--fatal-infos`. The likely reason that ignore comes and goes (not recorded): whether it is needed depends on which `googleapis` resolves.

Why the format and `--fatal-infos` checks run only on dev, and why `example_server_app` is excluded, isn't recorded. Ask a maintainer before changing either. The likely reason Firestore isn't linted (not recorded): the `lint` job was never extended when Firestore became its own package.

# Rules for agents

- **Must:** run `dart analyze --fatal-infos` on every package you touched, including `google_cloud_firestore`, which CI doesn't analyze.
- **Must:** run `dart format` on the files you changed only. If the CI format step fails, compare with a dev-channel SDK before reformatting.
- **Should:** fix the cause, for example by migrating off a deprecated API, rather than add an ignore.
- **Must not:** add a per-package `analysis_options.yaml` or disable rules.
- **Must not:** add a new blanket ignore without a comment explaining why.
- **Must not:** run `dart format .` across the repo unless asked, or commit formatting-only diffs to untouched files.
- **Must not:** delete an `ignore` because your local analyzer calls it unnecessary, without checking the SDK-floor and dev jobs.

# Related

- [Minimum Dart SDK](/dependencies/min-dart-sdk.md)
- [Dependency constraint style](/dependencies/constraint-style.md)
- [No committed lockfiles or overrides](/dependencies/no-lockfiles-or-overrides.md)

[^lint-job]: The `lint` job in `build.yml`
[^fatal-infos]: `--fatal-infos` in the `lint` job
[^format-check]: The format check in the `lint` job
[^analysis-options]: The root analysis options
[^unnecessary-ignore]: The `unnecessary_ignore` lint
[^messaging-ignore]: The messaging test's blanket ignore
[^contributing-format]: CONTRIBUTING's formatting advice
