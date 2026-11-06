---
type: Constraint
title: PR template and review
description: PRs fill `.github/PULL_REQUEST_TEMPLATE.md`, all PRs need review, new features need an issue with a proposal first, and Gemini Code Assist and a coverage bot comment automatically.
tags: [contributing, review]
agents_md: always
governs:
  - .github/PULL_REQUEST_TEMPLATE.md
  - .github/ISSUE_TEMPLATE/**
sources:
  - id: pr-template
    resource: ../../../.github/PULL_REQUEST_TEMPLATE.md
    symbol: "## Breaking Change"
    title: The PR template
  - id: issue-template-config
    resource: ../../../.github/ISSUE_TEMPLATE/config.yml
    title: The issue template configuration
---

# Constraint

- Every PR fills `.github/PULL_REQUEST_TEMPLATE.md`: Description, Related Issues, a checklist (Contributing Guide, CHANGELOG, tests, local validation, docs, CLA) and a Breaking Change yes/no.[^pr-template]
- Every PR needs review, including those from project members.
- A new feature needs an issue with a proposal before the PR.
- Gemini Code Assist posts automated reviews (`/gemini review`), and a bot posts a coverage comment.
- The issue templates in `.github/ISSUE_TEMPLATE/` come from another project: `config.yml` links to riverpod's discussions, and `bug_report.md` talks about "provider".[^issue-template-config]

# Why

The maintainers' stated reason for the template's shape: it was trimmed to match how PRs are written, after nobody had used the longer one. CONTRIBUTING.md states the review and proposal rules.

# Enforced by

Review only.

# Rules for agents

- **Must:** fill every section of the template, including the Breaking Change answer.
- **Must:** for the CHANGELOG heading, follow [Versioning and CHANGELOG headings](/release/versioning-and-changelog.md), not the template's example (`## Unreleased fix/major/minor`).
- **Must not:** tick "I signed the CLA" on the user's behalf.

# Related

- [Squash merges with Conventional Commit titles](/contributing/commit-and-pr-titles.md)
- [Apache-2.0 licence and the Google CLA](/contributing/license-and-cla.md)
- [Versioning and CHANGELOG headings](/release/versioning-and-changelog.md)

[^pr-template]: The PR template
[^issue-template-config]: The issue template configuration
