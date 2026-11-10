---
type: Constraint
title: version.g.dart is generated from the pubspec
description: "`packages/firebase_admin_sdk/lib/src/version.g.dart` is written by `scripts/gen-version.sh` from the admin pubspec version and committed; nothing compares the two, but a stale file fails the publish dry run."
tags: [generated, versioning, release]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/version.g.dart
  - packages/firebase_admin_sdk/pubspec.yaml
  - scripts/gen-version.sh
sources:
  - id: version-file
    resource: ../../../packages/firebase_admin_sdk/lib/src/version.g.dart
    symbol: const String packageVersion
    title: The generated version constant
  - id: gen-version
    resource: ../../../scripts/gen-version.sh
    symbol: version.g.dart
    title: The generator script
  - id: melos-hooks
    resource: ../../../pubspec.yaml
    symbol: "post: ./scripts/gen-version.sh"
    title: The melos `bootstrap` and `version` hooks that run the script
  - id: publish-job
    resource: ../../../.github/workflows/build.yml
    symbol: publish --dry-run
    title: The publish dry run, which a stale file fails
---

# Where it lives

- Enforced by: nothing compares the file with the pubspec. A stale file fails the publish dry run, `publish --dry-run` in `.github/workflows/build.yml`.[^publish-job]
- The generated constant: `const String packageVersion` in `packages/firebase_admin_sdk/lib/src/version.g.dart`.[^version-file]
- The generator: `scripts/gen-version.sh`,[^gen-version] which melos runs after `bootstrap` and `version` (`post: ./scripts/gen-version.sh` in the root `pubspec.yaml`).[^melos-hooks]

# Constraint

The file is committed and must match the `version:` in `packages/firebase_admin_sdk/pubspec.yaml` exactly. Only the admin package has one; it feeds the [usage-tracking headers](/architecture/usage-tracking-headers.md).

# Why

The maintainers have stated that a stale file breaks CI: they updated it specifically to make the publish dry run pass.

The likely mechanism (not recorded): CI's `melos bootstrap` rewrites the file, and `dart pub publish --dry-run` then warns about a modified checked-in file, which fails the dry run.

# Rules for agents

- **Must:** every time `firebase_admin_sdk`'s `version:` changes, run `./scripts/gen-version.sh` (or `melos bootstrap`) and commit the result in the same PR.
- **Must not:** hand-edit `version.g.dart`.

# Related

- [Usage-tracking headers](/architecture/usage-tracking-headers.md)
- [The pub workspace, melos and local setup](/repo/workspace-and-melos.md)
- [Pre-GA versioning and CHANGELOG headings between releases](/release/versioning-and-changelog.md)
- [The publish dry run](/release/publish-dry-run.md)

[^version-file]: The generated version constant
[^gen-version]: `scripts/gen-version.sh`
[^melos-hooks]: The melos hooks in the root pubspec
[^publish-job]: The `publish` job in `build.yml`
