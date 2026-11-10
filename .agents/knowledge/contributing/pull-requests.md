---
type: Constraint
title: "Pull requests: titles, template, review and CLA"
description: "Only squash merges are allowed, so PR titles and single commits follow Conventional Commits; PRs fill `.github/PULL_REQUEST_TEMPLATE.md` but take the CHANGELOG heading from the versioning rules, bots review and report coverage automatically, the issue templates are copied from another project, and the three identical `LICENSE` files stay untouched."
tags: [contributing, git, review, licence, legal]
agents_md: always
governs:
  - .github/PULL_REQUEST_TEMPLATE.md
  - .github/ISSUE_TEMPLATE/**
  - LICENSE
  - packages/*/LICENSE
sources:
  - id: contributing-commit-messages
    resource: ../../../CONTRIBUTING.md
    symbol: "### Commit Messages"
    title: CONTRIBUTING's commit-message rules
  - id: repo-merge-settings
    resource: https://api.github.com/repos/firebase/firebase-admin-dart
    symbol: allow_squash_merge
    title: The repository's merge settings (squash only, `COMMIT_OR_PR_TITLE`, `COMMIT_MESSAGES`)
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

- Enforced by (squash merges and titles): the repository's merge settings, for squash-only merges.[^repo-merge-settings] Nothing checks the title format.
- Enforced by (template, review, licence and CLA): review only. Branch protection requires the `cla/google` status (see [what gates merging](/ci/workflows.md)).
- Commit-message style, such as the imperative mood: `### Commit Messages` in `CONTRIBUTING.md`.[^contributing-commit-messages]
- The template's sections: `## Breaking Change` and the rest of `.github/PULL_REQUEST_TEMPLATE.md`.[^pr-template]
- Review, proposal-first and the CLA: `If you want to implement a new feature`, `### Code Reviews` and `### Contributor License Agreement` in `CONTRIBUTING.md`.[^contributing-proposal][^contributing-cla]
- Issue templates from another project: `riverpod` in `.github/ISSUE_TEMPLATE/config.yml`.[^issue-template-config]
- The licence: `LICENSE` at the root, and identical copies in `packages/firebase_admin_sdk/` and `packages/google_cloud_firestore/`.[^root-license][^admin-license][^firestore-license]

# Constraint

## Squash merges and titles

- Only squash merges are allowed. Merge commits and rebase merges are disabled, and branches are deleted on merge.
- The squash subject is the PR title, or, for a single-commit PR, that commit's subject. The squash body keeps the commit messages.
- Titles follow Conventional Commits: `type(scope): imperative summary`. Nothing states or checks this; the history follows it.

## Template, review, licence and CLA

- Gemini Code Assist posts automated reviews (`/gemini review`), and a bot posts a coverage comment.
- **Trap:** the template's CHANGELOG example matches neither package's heading (see [Versioning and CHANGELOG headings](/release/releases-and-versioning.md)).
- **Trap:** the issue templates in `.github/ISSUE_TEMPLATE/` come from another project: `config.yml` links to riverpod's discussions, and `bug_report.md` talks about "provider".
- The three `LICENSE` files are identical copies, one per published package and one at the root.

# Why

## Squash merges and titles

Why the project uses Conventional Commits isn't recorded; the convention is followed but never stated. Ask a maintainer before changing it.

## Template, review, licence and CLA

- The maintainers' stated reason for the template's shape: it was trimmed to match how PRs are written, after nobody had used the longer one.
- The likely reason for the per-package copies (not recorded): each published package needs its own `LICENSE`, which pub requires.

# Rules for agents

- **Should:** title the PR, and the commit of a single-commit PR, as a Conventional Commit: `type(scope): summary`, in the imperative mood, with the package or product as the scope when one applies. Take the type and scope from those in `git log`.
- **Must:** fill every section of the template, including the Breaking Change answer.
- **Must:** for the CHANGELOG heading, follow [Versioning and CHANGELOG headings](/release/releases-and-versioning.md), not the template's example.
- **Must not:** tick "I signed the CLA" on the user's behalf.
- **Must:** keep the three `LICENSE` files identical.
- **Must not:** edit `LICENSE`.

# Related

- [Releases, versioning, CHANGELOG and version.g.dart](/release/releases-and-versioning.md)
- [Apache-2.0 header on every source file](/conventions/license-headers.md)
- [CI workflows: what runs, what gates merging, hardening](/ci/workflows.md)

[^repo-merge-settings]: The repository's merge settings
[^contributing-commit-messages]: CONTRIBUTING's commit-message rules
[^pr-template]: The PR template
[^contributing-proposal]: CONTRIBUTING's proposal-first rule
[^contributing-cla]: CONTRIBUTING's CLA section
[^issue-template-config]: The issue template configuration
[^root-license]: The root licence
[^admin-license]: The admin package's copy
[^firestore-license]: The Firestore package's copy
