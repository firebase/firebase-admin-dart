---
type: Constraint
title: Squash merges with Conventional Commit titles
description: Only squash merges are allowed; the squash subject is the PR title (or a single-commit PR's commit subject) and the body keeps the commit messages, so PR titles and single commits follow Conventional Commits.
tags: [contributing, git]
agents_md: always
sources:
  - id: contributing-commit-messages
    resource: ../../../CONTRIBUTING.md
    symbol: "### Commit Messages"
    title: CONTRIBUTING's commit-message rules
  - id: repo-merge-settings
    resource: https://api.github.com/repos/firebase/firebase-admin-dart
    symbol: allow_squash_merge
    title: The repository's merge settings (squash only, `COMMIT_OR_PR_TITLE`, `COMMIT_MESSAGES`)
---

# Where it lives

- Enforced by: the repository's merge settings, for squash-only merges.[^repo-merge-settings] Nothing checks the title format.
- Commit-message style, such as the imperative mood: `### Commit Messages` in `CONTRIBUTING.md`.[^contributing-commit-messages]

# Constraint

- Only squash merges are allowed. Merge commits and rebase merges are disabled, and branches are deleted on merge.
- The squash subject is the PR title, or, for a single-commit PR, that commit's subject. The squash body keeps the commit messages.
- Titles follow Conventional Commits: `type(scope): imperative summary`. Nothing states or checks this; the history follows it.

# Why

Why the project uses Conventional Commits isn't recorded; the convention is followed but never stated. Ask a maintainer before changing it.

# Rules for agents

- **Should:** title the PR, and the commit of a single-commit PR, as a Conventional Commit: `type(scope): summary`, in the imperative mood, with the package or product as the scope when one applies. Take the type and scope from those in `git log`.

# Related

- [PR template, review, licence and CLA](/contributing/pr-template-and-review.md)

[^repo-merge-settings]: The repository's merge settings
[^contributing-commit-messages]: CONTRIBUTING's commit-message rules
