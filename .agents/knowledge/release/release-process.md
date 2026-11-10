---
type: Constraint
title: Releases are manual and done by Google maintainers
description: A release PR strips the unreleased markers, then `google_cloud_firestore` and `firebase_admin_sdk` are published by hand under the `firebase.google.com` publisher and tagged by hand; there is no publish workflow.
tags: [release, publishing]
agents_md: always
governs:
  - packages/*/pubspec.yaml
  - packages/*/CHANGELOG.md
sources:
  - id: admin-version
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "version:"
    title: The admin version a release PR finalizes
  - id: firestore-changelog
    resource: ../../../packages/google_cloud_firestore/CHANGELOG.md
    title: The Firestore CHANGELOG a release PR finalizes
  - id: gen-version
    resource: ../../../scripts/gen-version.sh
    title: The script a release PR runs to regenerate `version.g.dart`
---

# Where it lives

- Enforced by: the pub.dev permissions of the `firebase.google.com` publisher. Nothing in the repo.
- What a release PR finalizes: `version:` in `packages/firebase_admin_sdk/pubspec.yaml`[^admin-version] and the top heading of `packages/google_cloud_firestore/CHANGELOG.md`.[^firestore-changelog]

# Constraint

Google maintainers release by hand:

1. **Release PR.** A PR titled `chore(release): prepare firestore vA and admin vB`:
   - drops `-wip` from the admin version and renames Firestore's `## Unreleased` to the version;
   - bumps the versions;
   - raises the admin package's lower bound on `google_cloud_firestore` when needed (see [the pub workspace](/repo/workspace-and-melos.md));
   - regenerates `version.g.dart` with `scripts/gen-version.sh`.[^gen-version]
2. **Publish.** After it merges, `google_cloud_firestore` is published first, then `firebase_admin_sdk`, under the verified pub.dev publisher `firebase.google.com`. A release can also publish one package alone.
3. **Tag.** Tags named `<package>-v<version>` are created by hand for most releases. Tagging isn't consistent: some releases have no tag, and some tags are annotated while others are lightweight.

There is no publish workflow, and there are no GitHub Releases. The release doesn't go through `melos version` or `melos publish`. That is inferred from the tag messages, which aren't in melos's format, and from the hand-written CHANGELOGs, even though the root `pubspec.yaml` has a melos `version` hook.

# Why

The maintainers' stated reason for the release PR: it prepares the release by dropping the WIP suffixes and updating the version constants, and it makes the admin package require the new `google_cloud_firestore` version.

The likely reason for the order (not recorded): the admin package may need the new Firestore version on pub.dev before it can be published.

Who holds publish rights isn't recorded, nor why a proposed publish workflow wasn't merged. Ask a maintainer.

# Rules for agents

- **Must:** when you raise the admin package's lower bound on `google_cloud_firestore`, note in the PR that Firestore has to be released first.
- **Must not:** run `dart pub publish` without `--dry-run`, create or push tags, or prepare a release PR, unless the user explicitly asks.

# Related

- [Pre-GA versioning and CHANGELOG headings between releases](/release/versioning-and-changelog.md)
- [The publish dry run](/release/publish-dry-run.md)
- [The pub workspace, melos and local setup](/repo/workspace-and-melos.md)
- [version.g.dart is generated from the pubspec](/generated/version-g-dart.md)
- [Dependency constraint style](/dependencies/constraint-style.md)

[^admin-version]: The admin package version
[^firestore-changelog]: The Firestore CHANGELOG
[^gen-version]: `scripts/gen-version.sh`
