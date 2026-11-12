---
type: Constraint
title: "Releases, versioning, CHANGELOG and version.g.dart"
description: "Releases are published and tagged by hand by Google maintainers, with no publish workflow; packages stay on 0.x until GA, and between releases `firebase_admin_sdk` carries a `-wip` version and heading while `google_cloud_firestore` keeps its released version under `## Unreleased`; `version.g.dart` is written by `scripts/gen-version.sh` from the admin pubspec version, and a stale file fails the publish dry run."
tags: [release, publishing, changelog, versioning, generated]
agents_md: always
governs:
  - packages/*/pubspec.yaml
  - packages/*/CHANGELOG.md
  - packages/firebase_admin_sdk/lib/src/version.g.dart
  - packages/firebase_admin_sdk/pubspec.yaml
  - scripts/gen-version.sh
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
  - id: admin-changelog
    resource: ../../../packages/firebase_admin_sdk/CHANGELOG.md
    title: The admin CHANGELOG, topped by a `-wip` heading between releases
  - id: firestore-changelog-2
    resource: ../../../packages/google_cloud_firestore/CHANGELOG.md
    title: The Firestore CHANGELOG, topped by `## Unreleased` between releases
  - id: admin-version-2
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "version:"
    title: The admin package version
  - id: pr-template-example
    resource: ../../../.github/PULL_REQUEST_TEMPLATE.md
    symbol: "## Unreleased fix/major/minor"
    title: The PR template's CHANGELOG example, which matches neither package
  - id: version-file
    resource: ../../../packages/firebase_admin_sdk/lib/src/version.g.dart
    symbol: const String packageVersion
    title: The generated version constant
  - id: gen-version-2
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

- Enforced by (release process): the pub.dev permissions of the `firebase.google.com` publisher. Nothing in the repo.
- Enforced by (versioning and CHANGELOG headings): nothing; review only.
- Enforced by (version.g.dart): nothing compares the file with the pubspec. A stale file fails the publish dry run, `publish --dry-run` in `.github/workflows/build.yml`.[^publish-job]
- What a release PR finalizes: `version:` in `packages/firebase_admin_sdk/pubspec.yaml`[^admin-version] and the top heading of `packages/google_cloud_firestore/CHANGELOG.md`.[^firestore-changelog]
- The admin version between releases: `version:` in `packages/firebase_admin_sdk/pubspec.yaml`.[^admin-version-2]
- The headings to add entries under: the top of `packages/firebase_admin_sdk/CHANGELOG.md`[^admin-changelog] and of `packages/google_cloud_firestore/CHANGELOG.md`.[^firestore-changelog-2]
- An example heading that matches neither package: `## Unreleased fix/major/minor` in `.github/PULL_REQUEST_TEMPLATE.md`.[^pr-template-example]
- The generated constant: `const String packageVersion` in `packages/firebase_admin_sdk/lib/src/version.g.dart`.[^version-file]
- The generator: `scripts/gen-version.sh`,[^gen-version-2] which melos runs after `bootstrap` and `version` (`post: ./scripts/gen-version.sh` in the root `pubspec.yaml`).[^melos-hooks]

# Constraint

## Release process

Google maintainers release by hand:

1. **Release PR.** A PR titled `chore(release): prepare firestore vA and admin vB`:
   - drops `-wip` from the admin version and renames Firestore's `## Unreleased` to the version;
   - bumps the versions;
   - raises the admin package's lower bound on `google_cloud_firestore` when needed (see [the pub workspace](/repo/workspace-and-melos.md));
   - regenerates `version.g.dart` with `scripts/gen-version.sh`.[^gen-version]
2. **Publish.** After it merges, `google_cloud_firestore` is published first, then `firebase_admin_sdk`, under the verified pub.dev publisher `firebase.google.com`. A release can also publish one package alone.
3. **Tag.** Tags named `<package>-v<version>` are created by hand for most releases. Tagging isn't consistent: some releases have no tag, and some tags are annotated while others are lightweight.

There is no publish workflow, and there are no GitHub Releases. The release doesn't go through `melos version` or `melos publish`. That is inferred from the tag messages, which aren't in melos's format, and from the hand-written CHANGELOGs, even though the root `pubspec.yaml` has a melos `version` hook.

## Versioning and CHANGELOG headings

Both packages stay on 0.x until GA, and releases have no fixed cadence.

Between releases, the two packages follow different conventions:

- `firebase_admin_sdk` carries the next version as `X.Y.Z-wip`, in its pubspec and as its top CHANGELOG heading. The first user-visible change after a release bumps `version:` to `X.Y.Z-wip`, adds the `## X.Y.Z-wip` heading, and regenerates `version.g.dart`.
- `google_cloud_firestore` keeps its last released version, and collects entries under `## Unreleased`.
- A change's entry goes under the unreleased heading, never under a released version. Breaking entries start with `**Breaking:**`, as in the Firestore CHANGELOG. Dependency changes get their own entry.

What the release PR does to these headings is under "Release process" above.

## version.g.dart

The file is committed and must match the `version:` in `packages/firebase_admin_sdk/pubspec.yaml` exactly. Only the admin package has one; it feeds the [usage-tracking headers](/architecture/usage-tracking-headers.md).

# Why

## Release process

The maintainers' stated reason for the release PR: it prepares the release by dropping the WIP suffixes and updating the version constants, and it makes the admin package require the new `google_cloud_firestore` version.

The likely reason for the order (not recorded): the admin package may need the new Firestore version on pub.dev before it can be published.

Who holds publish rights isn't recorded, nor why a proposed publish workflow wasn't merged. Ask a maintainer.

## Versioning and CHANGELOG headings

The maintainers' stated reasons: `firebase_admin_sdk` is not GA, so releases have no fixed cycle. Reviewers move entries under a new `-wip` section because the previous version is already released and the release commit strips the suffix. A user proposed a weekly release schedule; a maintainer answered that releases have no fixed cycle before GA.

Why the two packages use different conventions isn't recorded. Ask a maintainer before changing either. The likely reason (not recorded): `-wip` keeps the version in the usage-tracking headers distinct from the released one, which matters only for the admin package, the only one with `version.g.dart`.

## version.g.dart

The maintainers have stated that a stale file breaks CI: they updated it specifically to make the publish dry run pass.

The likely mechanism (not recorded): CI's `melos bootstrap` rewrites the file, and `dart pub publish --dry-run` then warns about a modified checked-in file, which fails the dry run.

# Rules for agents

- **Must:** when you raise the admin package's lower bound on `google_cloud_firestore`, note in the PR that Firestore has to be released first.
- **Must not:** run `dart pub publish` without `--dry-run`, create or push tags, or prepare a release PR, unless the user explicitly asks.
- **Must:** add a CHANGELOG entry for every user-visible change in the affected package, under the existing top heading: `## X.Y.Z-wip` for `firebase_admin_sdk`, `## Unreleased` for `google_cloud_firestore`.
- **Must:** if `firebase_admin_sdk` has no `-wip` heading, bump to the next patch `-wip` and regenerate `version.g.dart`.
- **Must not:** add entries to a released CHANGELOG section.
- **Must not:** create a new numbered release heading, or remove `-wip`.
- **Must not:** bump to 1.0 without a GA decision.
- **Must:** every time `firebase_admin_sdk`'s `version:` changes, run `./scripts/gen-version.sh` (or `melos bootstrap`) and commit the result in the same PR.
- **Must not:** hand-edit `version.g.dart`.

# Related

- [The publish dry run](/release/publish-dry-run.md)
- [The pub workspace, melos and local setup](/repo/workspace-and-melos.md)
- [Dependency constraints: bounds, consumers and the SDK floor](/dependencies/constraints.md)
- [Pull requests: titles, template, review and CLA](/contributing/pull-requests.md)
- [ActionCodeSettings has linkDomain, not dynamicLinkDomain](/auth/dynamic-link-domain-removed.md)
- [Usage-tracking headers](/architecture/usage-tracking-headers.md)

[^admin-version]: The admin package version
[^firestore-changelog]: The Firestore CHANGELOG
[^gen-version]: `scripts/gen-version.sh`
[^admin-version-2]: The admin package version
[^admin-changelog]: The admin CHANGELOG
[^firestore-changelog-2]: The Firestore CHANGELOG
[^pr-template-example]: The PR template's CHANGELOG example
[^version-file]: The generated version constant
[^gen-version-2]: `scripts/gen-version.sh`
[^melos-hooks]: The melos hooks in the root pubspec
[^publish-job]: The `publish` job in `build.yml`
