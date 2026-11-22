---
type: Decision
title: Published as firebase_admin_sdk, owned by Google
description: The package is published as `firebase_admin_sdk` from the `firebase/firebase-admin-dart` repository, no longer as `dart_firebase_admin`, and source headers name Google LLC.
tags: [packaging, ownership, release]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/pubspec.yaml
  - packages/firebase_admin_sdk/README.md
sources:
  - id: pubspec-name
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "name: firebase_admin_sdk"
    title: The package name
  - id: readme-history
    resource: ../../../packages/firebase_admin_sdk/README.md
    symbol: "## Package history"
    title: The README's Package history section
  - id: header-template
    resource: ../../../scripts/header_template.txt
    symbol: Google LLC
    title: The license header, with Google LLC as copyright holder
---

# Where it lives

- Enforced by: nothing; review only.
- The package name: `name:` in the admin `pubspec.yaml`.[^pubspec-name]
- The copyright holder: `scripts/header_template.txt`.[^header-template]
- Where the code came from, and thanks to the name's previous owner: `## Package history` in the admin README.[^readme-history]

# Decision

`dart_firebase_admin` is the retired name and is not used. pub.dev also lists older, unrelated `firebase_admin_sdk` versions by the name's previous owner; this package's versions start above them.

# Why

The maintainers' stated reason, in part: the name had churned and needed to be settled, and `firebase_admin_sdk` was the outcome. The headers name Google LLC to align with legal guidance.

Why this name was chosen over others isn't recorded; ask a maintainer. The rule on the Package history section and Invertase branding rests only on the change that renamed the package.

# Rules for agents

- **Must not:** publish under `dart_firebase_admin`.
- **Ask first:** before removing the README's Package history section, or adding Invertase branding or copyright lines outside it. The section itself links to Invertase.

# Related

- [Apache-2.0 header on every source file](/conventions/license-headers.md)
- [Releases, versioning, CHANGELOG and version.g.dart](/release/releases-and-versioning.md)

[^pubspec-name]: The package name in the pubspec
[^header-template]: `scripts/header_template.txt`
[^readme-history]: README Package history
