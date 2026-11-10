---
type: Constraint
title: PR template, review, licence and CLA
description: PRs fill `.github/PULL_REQUEST_TEMPLATE.md` but take the CHANGELOG heading from the versioning rules, bots review and report coverage automatically, the issue templates are copied from another project, and the three identical `LICENSE` files stay untouched.
tags: [contributing, review, licence, legal]
agents_md: always
governs:
  - .github/PULL_REQUEST_TEMPLATE.md
  - .github/ISSUE_TEMPLATE/**
  - LICENSE
  - packages/*/LICENSE
sources:
  - id: pr-template
    resource: ../../../.github/PULL_REQUEST_TEMPLATE.md
    symbol: "## Breaking Change"
    title: The PR template
  - id: contributing-proposal
    resource: ../../../CONTRIBUTING.md
    symbol: If you want to implement a new feature
    title: CONTRIBUTING's proposal-first and review rules
  - id: contributing-cla
    resource: ../../../CONTRIBUTING.md
    symbol: "### Contributor License Agreement"
    title: CONTRIBUTING's CLA section
  - id: issue-template-config
    resource: ../../../.github/ISSUE_TEMPLATE/config.yml
    symbol: riverpod
    title: The issue template configuration, copied from riverpod
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

# Where it lives

- Enforced by: review only. Branch protection requires the `cla/google` status (see [what gates merging](/ci/trigger-matrix.md)).
- The template's sections: `## Breaking Change` and the rest of `.github/PULL_REQUEST_TEMPLATE.md`.[^pr-template]
- Review, proposal-first and the CLA: `If you want to implement a new feature`, `### Code Reviews` and `### Contributor License Agreement` in `CONTRIBUTING.md`.[^contributing-proposal][^contributing-cla]
- Issue templates from another project: `riverpod` in `.github/ISSUE_TEMPLATE/config.yml`.[^issue-template-config]
- The licence: `LICENSE` at the root, and identical copies in `packages/firebase_admin_sdk/` and `packages/google_cloud_firestore/`.[^root-license][^admin-license][^firestore-license]

# Constraint

- Gemini Code Assist posts automated reviews (`/gemini review`), and a bot posts a coverage comment.
- **Trap:** the template's CHANGELOG example matches neither package's heading (see [Versioning and CHANGELOG headings](/release/versioning-and-changelog.md)).
- **Trap:** the issue templates in `.github/ISSUE_TEMPLATE/` come from another project: `config.yml` links to riverpod's discussions, and `bug_report.md` talks about "provider".
- The three `LICENSE` files are identical copies, one per published package and one at the root.

# Why

- The maintainers' stated reason for the template's shape: it was trimmed to match how PRs are written, after nobody had used the longer one.
- The likely reason for the per-package copies (not recorded): each published package needs its own `LICENSE`, which pub requires.

# Rules for agents

- **Must:** fill every section of the template, including the Breaking Change answer.
- **Must:** for the CHANGELOG heading, follow [Versioning and CHANGELOG headings](/release/versioning-and-changelog.md), not the template's example.
- **Must not:** tick "I signed the CLA" on the user's behalf.
- **Must:** keep the three `LICENSE` files identical.
- **Must not:** edit `LICENSE`.

# Related

- [Squash merges with Conventional Commit titles](/contributing/commit-and-pr-titles.md)
- [Versioning and CHANGELOG headings](/release/versioning-and-changelog.md)
- [Apache-2.0 header on every source file](/conventions/license-headers.md)
- [What CI runs, the coverage gate, and what gates merging](/ci/trigger-matrix.md)

[^pr-template]: The PR template
[^contributing-proposal]: CONTRIBUTING's proposal-first rule
[^contributing-cla]: CONTRIBUTING's CLA section
[^issue-template-config]: The issue template configuration
[^root-license]: The root licence
[^admin-license]: The admin package's copy
[^firestore-license]: The Firestore package's copy
