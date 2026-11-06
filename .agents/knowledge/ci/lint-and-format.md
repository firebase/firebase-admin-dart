---
type: Constraint
title: Lints, analysis and formatting
description: One root `analysis_options.yaml` builds on `dart_flutter_team_lints` with strict modes; CI analyzes and format-checks only `packages/firebase_admin_sdk/`, with `--fatal-infos` and the format check on the dev SDK only, so format only the files you change and check ignores against every analysis SDK.
tags: [ci, lints, formatting]
agents_md: always
governs:
  - analysis_options.yaml
  - .github/workflows/build.yml
sources:
  - id: analysis-options
    resource: ../../../analysis_options.yaml
    symbol: dart_flutter_team_lints
    title: The root analysis options
  - id: unnecessary-ignore
    resource: ../../../analysis_options.yaml
    symbol: unnecessary_ignore
    title: The `unnecessary_ignore` lint
  - id: fatal-infos
    resource: ../../../.github/workflows/build.yml
    symbol: dart analyze --fatal-infos
    title: "`--fatal-infos` in the `lint` job, on dev only"
  - id: format-check
    resource: ../../../.github/workflows/build.yml
    symbol: dart format --set-exit-if-changed
    title: The format check in the `lint` job, on dev only
  - id: messaging-ignore
    resource: ../../../packages/firebase_admin_sdk/test/unit/messaging/messaging_test.dart
    symbol: "ignore_for_file: deprecated_member_use"
    title: A blanket ignore whose need depends on the resolved `googleapis`
  - id: firestore-ignore
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_http_client.dart
    symbol: "ignore_for_file: experimental_member_use"
    title: A blanket ignore in the Firestore HTTP client
---

# Constraint

**Configuration.** One root `analysis_options.yaml` includes `package:dart_flutter_team_lints/analysis_options.yaml`, turns on `strict-casts`, `strict-inference` and `strict-raw-types`, adds the `unnecessary_ignore` lint, ignores `lines_longer_than_80_chars`, and excludes `example_server_app/**`.[^analysis-options][^unnecessary-ignore] The lint set enforces rules CONTRIBUTING.md doesn't list, among them `omit_local_variable_types`, `directives_ordering`, `sort_pub_dependencies`, `comment_references`, `avoid_dynamic_calls`, `unawaited_futures`, `type_annotate_public_apis` and `only_throw_errors`.

**What CI checks.** The `lint` job runs only inside `packages/firebase_admin_sdk/`, which takes in its `example/` by path for both checks, and its `example_server_app/` for the format check only, since analysis excludes it:

- `dart analyze` on the SDK floor and stable;
- `dart analyze --fatal-infos` and `dart format --set-exit-if-changed .` on dev only.[^fatal-infos][^format-check]

CI neither analyzes nor format-checks `packages/google_cloud_firestore/` or `scripts/`.

**Blanket ignores.** `// ignore_for_file: experimental_member_use` sits in `google_cloud_firestore/lib/src/firestore_http_client.dart` and `firebase_admin_sdk/lib/src/app/http2_client.dart`, and `// ignore_for_file: deprecated_member_use` in `firebase_admin_sdk/test/unit/messaging/messaging_test.dart`.[^firestore-ignore][^messaging-ignore]

**Formatter skew.** Formatter output differs between SDK versions, and CI checks formatting on dev only. A contributor on stable can produce diffs CI rejects, or rewrite files CI accepts.

**Ignore skew.** `unnecessary_ignore` is on, analysis runs on three SDKs, and dependencies aren't locked. An `// ignore:` needed with one SDK or dependency version can be flagged as unnecessary with another, which is fatal on dev because of `--fatal-infos`.

# Why

Why the project uses this lint setup isn't recorded. The change that introduced it states only what it did: adopt `dart_flutter_team_lints`, centralize `analysis_options.yaml` at the workspace root, remove the per-package copies and un-ignore lints. Both skews have broken CI: formatting had to be reverted to match the dev formatter, and the `deprecated_member_use` ignore in `messaging_test.dart` was removed as unnecessary, then restored to satisfy `--fatal-infos`. The likely reason that ignore comes and goes (not recorded): whether it is needed depends on which `googleapis` resolves.

Why the format and `--fatal-infos` checks run only on dev, and why `example_server_app` is excluded, isn't recorded. Ask a maintainer before changing either. The likely reason Firestore isn't linted (not recorded): the `lint` job was never extended when Firestore became its own package.

# Enforced by

`analysis_options.yaml` and the `lint` job of `.github/workflows/build.yml`.

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

[^analysis-options]: The root analysis options
[^unnecessary-ignore]: The `unnecessary_ignore` lint
[^fatal-infos]: `--fatal-infos` in the `lint` job
[^format-check]: The format check in the `lint` job
[^firestore-ignore]: The Firestore HTTP client's blanket ignore
[^messaging-ignore]: The messaging test's blanket ignore
