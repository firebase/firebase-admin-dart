---
type: Constraint
title: Dependabot updates GitHub Actions only
description: Dependabot updates only GitHub Actions, monthly, grouped and with a cooldown, while Dart and npm dependencies are updated by hand.
tags: [dependencies, ci, security]
agents_md: when-touching
governs:
  - .github/dependabot.yaml
sources:
  - id: dependabot-ecosystem
    resource: ../../../.github/dependabot.yaml
    symbol: github-actions
    title: The only Dependabot ecosystem is GitHub Actions
  - id: dependabot-cooldown
    resource: ../../../.github/dependabot.yaml
    symbol: "cooldown:"
    title: The cooldown, the grouping and the codecov ignore rule, with their reasons
---

# Constraint

Dependabot updates only GitHub Actions.[^dependabot-ecosystem] In `.github/dependabot.yaml`:[^dependabot-cooldown]

- updates run monthly;
- minor and patch bumps are grouped into one PR, and each major gets its own PR;
- a cooldown delays adopting a new release;
- major bumps of `codecov/codecov-action` are ignored.

Dart and npm dependencies are updated by hand.

# Why

The maintainers' stated reasons, mostly in comments in `dependabot.yaml`:[^dependabot-cooldown]

- No lock files are checked in, so Dependabot needn't check Dart dependencies (see [no lockfiles](/dependencies/no-lockfiles-or-overrides.md)).
- Cooldown: "so a compromised version has time to be pulled before it reaches CI". The mandatory zizmor scan also flags a Dependabot config without one.
- Grouping: majors stay ungrouped so "one blocked bump can't hold back the rest".
- codecov: "The org Actions allow-list only permits codecov/codecov-action@v4", so a major bump could never be merged.

# Enforced by

`.github/dependabot.yaml` itself.

# Rules for agents

- **Must not:** add a `pub` or `npm` ecosystem to Dependabot without discussion.
- **Must not:** bump `codecov/codecov-action` past v4.
- **Must not:** remove the cooldown.

# Related

- [Workflow security rules](/ci/workflow-hardening.md)
- [No committed lockfiles or dependency overrides](/dependencies/no-lockfiles-or-overrides.md)

[^dependabot-ecosystem]: The `github-actions` ecosystem in `dependabot.yaml`
[^dependabot-cooldown]: The cooldown, grouping and ignore rules in `dependabot.yaml`
