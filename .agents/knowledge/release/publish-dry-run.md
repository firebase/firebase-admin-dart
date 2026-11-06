---
type: Constraint
title: The publish dry run must pass for both packages
description: CI's `publish` job runs `dart pub publish --dry-run` for both packages, which fails on fake keys not listed in `false_secrets`, bad descriptions, stale checked-in files and dependency overrides.
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
  - id: golden-pubignore
    resource: ../../../packages/google_cloud_firestore/tool/pipeline_golden/.pubignore
    title: Excludes the Node fixture generator from the package
  - id: admin-pubignore
    resource: ../../../packages/firebase_admin_sdk/.pubignore
    title: The admin package's `.pubignore`
---

# Constraint

`dart pub publish --dry-run` must pass in both packages. The `publish` job of `.github/workflows/build.yml` runs it after the other jobs of that workflow pass; a skipped `test-wif` counts as passing.[^publish-job]

The dry run fails on:

- a fake private key in a test file that isn't listed under `false_secrets` in the package pubspec;[^admin-false-secrets][^firestore-false-secrets]
- a pubspec `description` outside 50–180 characters;
- a modified checked-in file, such as a stale `version.g.dart`;
- dependency overrides;
- other pub validator warnings.

`.pubignore` files shape what is published.[^admin-pubignore] `tool/pipeline_golden/.pubignore` excludes that tool entirely.[^golden-pubignore]

# Why

The maintainers' stated reasons: `false_secrets` lists the fixtures so the publish check doesn't flag the mock RSA test key; pub requires a description between 50 and 180 characters; and `tool/pipeline_golden/.pubignore` says "The Node.js fixture generator is a development tool, not part of the package."

The likely reason each of these blocks CI (not recorded): the dry run exits non-zero on warnings.

# Enforced by

The `publish` job in `.github/workflows/build.yml`, and the `false_secrets` lists in both package pubspecs.

# Rules for agents

- **Must:** when you add a test fixture with a key or token that looks real, add its path to that package's `false_secrets`.
- **Must:** keep each pubspec `description` within 50–180 characters.
- **Must:** run `dart pub publish --dry-run` in both packages after a pubspec or file-layout change.
- **Must not:** drop `--dry-run`.

# Related

- [version.g.dart](/generated/version-g-dart.md)
- [No committed lockfiles or overrides](/dependencies/no-lockfiles-or-overrides.md)
- [Release process](/release/release-process.md)

[^publish-job]: The `publish` job
[^admin-false-secrets]: The admin package's `false_secrets`
[^firestore-false-secrets]: The Firestore package's `false_secrets`
[^admin-pubignore]: The admin package's `.pubignore`
[^golden-pubignore]: `tool/pipeline_golden/.pubignore`
