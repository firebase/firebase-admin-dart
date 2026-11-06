---
type: Constraint
title: Pre-GA versioning and CHANGELOG headings between releases
description: Packages stay on 0.x until GA with no fixed release cadence; between releases `firebase_admin_sdk` carries a `-wip` version and heading, while `google_cloud_firestore` keeps its released version under `## Unreleased`.
tags: [release, changelog, versioning]
agents_md: always
governs:
  - packages/*/CHANGELOG.md
  - packages/*/pubspec.yaml
sources:
  - id: admin-changelog
    resource: ../../../packages/firebase_admin_sdk/CHANGELOG.md
    title: The admin CHANGELOG, topped by a `-wip` heading between releases
  - id: firestore-changelog
    resource: ../../../packages/google_cloud_firestore/CHANGELOG.md
    title: The Firestore CHANGELOG, topped by `## Unreleased` between releases
  - id: admin-version
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "version:"
    title: The admin package version
---

# Constraint

Both packages stay on 0.x until GA, and releases have no fixed cadence.

Between releases, the two packages follow different conventions:

| | `firebase_admin_sdk` | `google_cloud_firestore` |
| --- | --- | --- |
| pubspec `version:` | the next version, as `X.Y.Z-wip`[^admin-version] | the last released version |
| Top CHANGELOG heading | `## X.Y.Z-wip`[^admin-changelog] | `## Unreleased`[^firestore-changelog] |

- In `firebase_admin_sdk`, the first user-visible change after a release bumps `version:` to `X.Y.Z-wip`, adds the `## X.Y.Z-wip` heading, and regenerates `version.g.dart`.
- The release PR drops `-wip`, or renames `## Unreleased` to the version.
- A change's entry goes under the unreleased heading, never under a released version.
- Breaking entries start with `**Breaking:**`. Dependency changes get their own entry.

# Why

The maintainers' stated reasons: `firebase_admin_sdk` is not GA, so releases have no fixed cycle. Reviewers move entries under a new `-wip` section because the previous version is already released and the release commit strips the suffix. A fixed weekly release schedule was proposed and declined.

Why the two packages use different conventions isn't recorded. Ask a maintainer before changing either. The likely reason (not recorded): `-wip` keeps the version in the usage-tracking headers distinct from the released one, which matters only for the admin package, the only one with `version.g.dart`.

# Enforced by

Not enforced; a convention. The CHANGELOG example in `.github/PULL_REQUEST_TEMPLATE.md` (`## Unreleased fix/major/minor`) matches neither package.

# Rules for agents

- **Must:** add a CHANGELOG entry for every user-visible change in the affected package, under the existing top heading: `## X.Y.Z-wip` for `firebase_admin_sdk`, `## Unreleased` for `google_cloud_firestore`.
- **Must:** if `firebase_admin_sdk` has no `-wip` heading, bump to the next patch `-wip` and regenerate `version.g.dart`.
- **Must not:** add entries to a released CHANGELOG section.
- **Must not:** create a new numbered release heading, or remove `-wip`.
- **Must not:** bump to 1.0 without a GA decision.

# Related

- [version.g.dart](/generated/version-g-dart.md)
- [Release process](/release/release-process.md)
- [`dynamicLinkDomain` removed, not deprecated](/auth/dynamic-link-domain-removed.md)

[^admin-version]: The admin package version
[^admin-changelog]: The admin CHANGELOG
[^firestore-changelog]: The Firestore CHANGELOG
