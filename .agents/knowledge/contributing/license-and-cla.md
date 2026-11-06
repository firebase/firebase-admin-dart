---
type: Constraint
title: Apache-2.0 licence and the Google CLA
description: The repo is Apache-2.0 with identical `LICENSE` copies at the root and in each package, and contributors must sign the Google CLA, whose `cla/google` status is the only check branch protection requires on `main`.
tags: [contributing, licence, legal]
agents_md: when-touching
governs:
  - LICENSE
  - packages/*/LICENSE
sources:
  - id: root-license
    resource: ../../../LICENSE
    symbol: Apache License
    title: The root licence
  - id: admin-license
    resource: ../../../packages/firebase_admin_sdk/LICENSE
    title: The admin package's copy
  - id: firestore-license
    resource: ../../../packages/google_cloud_firestore/LICENSE
    title: The Firestore package's copy
---

# Constraint

- The repo is licensed under Apache-2.0. The `LICENSE` at the root and the one in each package are identical copies.[^root-license][^admin-license][^firestore-license]
- Contributors must sign the Google CLA. Branch protection on `main` requires the `cla/google` status for non-admins, and it is the only status check branch protection requires.
- An Alphabet ruleset also requires the zizmor workflow, which lives in another repository, to pass.

# Why

The maintainers' stated reasons, in CONTRIBUTING.md: contributions must be accompanied by a Contributor License Agreement, and contributions are licensed under the Apache License 2.0.

The likely reason for the per-package copies (not recorded): each published package needs its own `LICENSE`, which pub requires.

# Enforced by

Branch protection on `main` (the `cla/google` status), and pub's publish validation for each package's `LICENSE`.

# Rules for agents

- **Must:** keep the three `LICENSE` files identical.
- **Must not:** edit `LICENSE`.

# Related

- [License headers](/conventions/license-headers.md)
- [What CI runs where](/ci/trigger-matrix.md)
- [PR template and review](/contributing/pr-template-and-review.md)

[^root-license]: The root licence
[^admin-license]: The admin package's copy
[^firestore-license]: The Firestore package's copy
