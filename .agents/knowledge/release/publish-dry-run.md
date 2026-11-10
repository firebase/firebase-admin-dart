---
type: Constraint
title: The publish dry run must pass for both packages
description: CI runs `dart pub publish --dry-run` for both packages, which fails on fake keys not listed in `false_secrets`, modified checked-in files and other pub validator warnings, but not on a bad description length or dependency overrides.
tags: [release, publishing, ci]
agents_md: when-touching
governs:
  - packages/*/pubspec.yaml
  - "**/.pubignore"
  - packages/*/test/fixtures/**
sources:
  - id: publish-job
    resource: ../../../.github/workflows/build.yml
    symbol: publish --dry-run
    title: The `publish` job
  - id: admin-false-secrets
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "false_secrets:"
    title: The admin package's `false_secrets`
  - id: firestore-false-secrets
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "false_secrets:"
    title: The Firestore package's `false_secrets`
  - id: admin-pubignore
    resource: ../../../packages/firebase_admin_sdk/.pubignore
    symbol: test/credential_test.dart
    title: The admin package's `.pubignore`, which names a file that doesn't exist
  - id: golden-pubignore
    resource: ../../../packages/google_cloud_firestore/tool/pipeline_golden/.pubignore
    title: Excludes the Node fixture generator from the package
---

# Where it lives

- Enforced by: the `publish` job, `publish --dry-run` in `.github/workflows/build.yml`, after the workflow's other jobs pass.[^publish-job]
- The fake keys the dry run must ignore: `false_secrets:` in each package's `pubspec.yaml`.[^admin-false-secrets][^firestore-false-secrets]
- What each package leaves out: its `.pubignore` files, such as `packages/firebase_admin_sdk/.pubignore`[^admin-pubignore] and `tool/pipeline_golden/.pubignore`.[^golden-pubignore]

# Constraint

`dart pub publish --dry-run` must pass in both packages. It fails on:

- a fake private key in a test file that isn't listed under `false_secrets` in the package pubspec;
- a modified checked-in file, such as a stale `version.g.dart`;
- other pub validator warnings.

Not caught by the dry run: a description outside 50–180 characters (pub.dev's scoring asks for that length) and dependency overrides (only a hint).

**Traps:**

- The admin `.pubignore` names `test/credential_test.dart`, a path that doesn't exist. The fake keys are covered by `false_secrets`, not by `.pubignore`.
- Because that `.pubignore` exists, pub skips `packages/firebase_admin_sdk/.gitignore`. A git-ignored `service-account-key.json` anywhere in the package, subdirectories included, is listed for publishing; only `example/` and `example_server_app/` are covered, by their own `.gitignore`. The dry run lists the file, and pub's leak detector fails the dry run when the file holds a private key.
- In `google_cloud_firestore`, only `tool/pipeline_golden/` has a `.pubignore`. `tool/pipeline_api_parity/`, with its `package.json` and lockfile, ships in the published `google_cloud_firestore`.

# Why

The maintainers' stated reasons: `false_secrets` lists the fixtures so the publish check doesn't flag the mock RSA test key, and pub.dev asks for a description between 50 and 180 characters.

The likely reason the listed failures block CI (not recorded): the dry run exits non-zero on warnings.

# Rules for agents

- **Must:** when you add a test fixture with a key or token that looks real, add its path to that package's `false_secrets`.
- **Must:** keep each pubspec `description` within 50–180 characters.
- **Must:** run `dart pub publish --dry-run` in both packages after a pubspec or file-layout change.
- **Must not:** drop `--dry-run`.

# Related

- [version.g.dart is generated from the pubspec](/generated/version-g-dart.md)
- [No committed lockfiles or dependency overrides](/dependencies/no-lockfiles-or-overrides.md)
- [Releases are manual and done by Google maintainers](/release/release-process.md)
- [Inject test doubles and use the guarded emulator helpers](/tests/helpers-and-injection.md)

[^publish-job]: The `publish` job
[^admin-false-secrets]: The admin package's `false_secrets`
[^firestore-false-secrets]: The Firestore package's `false_secrets`
[^admin-pubignore]: The admin package's `.pubignore`
[^golden-pubignore]: `tool/pipeline_golden/.pubignore`
