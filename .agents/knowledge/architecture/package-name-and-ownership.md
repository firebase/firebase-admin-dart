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

# Decision

- The package is published on pub.dev as `firebase_admin_sdk`.[^pubspec-name] Its former name, `dart_firebase_admin`, is not used.
- pub.dev also lists older, unrelated `firebase_admin_sdk` versions by the name's previous owner. This package's versions start above them.
- The repository is `firebase/firebase-admin-dart`, owned by Google.
- Source headers say "Copyright … Google LLC", from `scripts/header_template.txt`.[^header-template]
- The README ends with a Package history section. It says the code evolved from `dart_firebase_admin` by Invertase, and thanks the previous owner of the `firebase_admin_sdk` name.[^readme-history]

# Why

The maintainers' stated reason, in part: the name had churned and needed to be settled, and `firebase_admin_sdk` was the outcome. The README thanks the name's previous owner "for letting us take over the `firebase_admin_sdk` name". The headers name Google LLC to align with legal guidance.

Why this name was chosen over others isn't recorded; ask a maintainer. The rule on the Package history section and Invertase branding rests only on the change that renamed the package.

# Rules for agents

- **Must not:** publish under `dart_firebase_admin`.
- **Ask first:** before removing the README's Package history section, or adding Invertase branding or copyright lines outside it. The section itself links to Invertase.

# Related

- [Apache-2.0 header on every source file](/conventions/license-headers.md)
- [Releases are manual and done by Google maintainers](/release/release-process.md)

[^pubspec-name]: The package name in the pubspec
[^header-template]: `scripts/header_template.txt`
[^readme-history]: README Package history
