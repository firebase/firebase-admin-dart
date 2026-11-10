---
type: Constraint
title: Pre-GA versioning and CHANGELOG headings between releases
description: Packages stay on 0.x until GA with no fixed release cadence; between releases `firebase_admin_sdk` carries a `-wip` version and heading, while `google_cloud_firestore` keeps its released version under `## Unreleased`, and the PR template's example matches neither.
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
  - id: pr-template-example
    resource: ../../../.github/PULL_REQUEST_TEMPLATE.md
    symbol: "## Unreleased fix/major/minor"
    title: The PR template's CHANGELOG example, which matches neither package
---

# Where it lives

- Enforced by: nothing; review only.
- The admin version between releases: `version:` in `packages/firebase_admin_sdk/pubspec.yaml`.[^admin-version]
- The headings to add entries under: the top of `packages/firebase_admin_sdk/CHANGELOG.md`[^admin-changelog] and of `packages/google_cloud_firestore/CHANGELOG.md`.[^firestore-changelog]
- An example heading that matches neither package: `## Unreleased fix/major/minor` in `.github/PULL_REQUEST_TEMPLATE.md`.[^pr-template-example]

# Constraint

Both packages stay on 0.x until GA, and releases have no fixed cadence.

Between releases, the two packages follow different conventions:

- `firebase_admin_sdk` carries the next version as `X.Y.Z-wip`, in its pubspec and as its top CHANGELOG heading. The first user-visible change after a release bumps `version:` to `X.Y.Z-wip`, adds the `## X.Y.Z-wip` heading, and regenerates `version.g.dart`.
- `google_cloud_firestore` keeps its last released version, and collects entries under `## Unreleased`.
- A change's entry goes under the unreleased heading, never under a released version. Breaking entries start with `**Breaking:**`, as in the Firestore CHANGELOG. Dependency changes get their own entry.

What the release PR does to these headings is in [the release process](/release/release-process.md).

# Why

The maintainers' stated reasons: `firebase_admin_sdk` is not GA, so releases have no fixed cycle. Reviewers move entries under a new `-wip` section because the previous version is already released and the release commit strips the suffix. A user proposed a weekly release schedule; a maintainer answered that releases have no fixed cycle before GA.

Why the two packages use different conventions isn't recorded. Ask a maintainer before changing either. The likely reason (not recorded): `-wip` keeps the version in the usage-tracking headers distinct from the released one, which matters only for the admin package, the only one with `version.g.dart`.

# Rules for agents

- **Must:** add a CHANGELOG entry for every user-visible change in the affected package, under the existing top heading: `## X.Y.Z-wip` for `firebase_admin_sdk`, `## Unreleased` for `google_cloud_firestore`.
- **Must:** if `firebase_admin_sdk` has no `-wip` heading, bump to the next patch `-wip` and regenerate `version.g.dart`.
- **Must not:** add entries to a released CHANGELOG section.
- **Must not:** create a new numbered release heading, or remove `-wip`.
- **Must not:** bump to 1.0 without a GA decision.

# Related

- [version.g.dart is generated from the pubspec](/generated/version-g-dart.md)
- [Releases are manual and done by Google maintainers](/release/release-process.md)
- [PR template, review, licence and CLA](/contributing/pr-template-and-review.md)
- [ActionCodeSettings has linkDomain, not dynamicLinkDomain](/auth/dynamic-link-domain-removed.md)

[^admin-version]: The admin package version
[^admin-changelog]: The admin CHANGELOG
[^firestore-changelog]: The Firestore CHANGELOG
[^pr-template-example]: The PR template's CHANGELOG example
