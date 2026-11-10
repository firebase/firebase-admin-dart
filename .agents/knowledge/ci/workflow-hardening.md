---
type: Constraint
title: Workflow security rules and Dependabot
description: "Workflow edits must pass the mandatory Alphabet zizmor scan and the org Actions allow-list, both configured outside the repo; Dependabot updates only GitHub Actions, and Dart and npm dependencies are updated by hand."
tags: [ci, security, workflows, dependencies]
agents_md: when-touching
governs:
  - .github/workflows/**
  - .github/dependabot.yaml
sources:
  - id: dependabot-cooldown
    resource: ../../../.github/dependabot.yaml
    symbol: "cooldown:"
    title: The Dependabot config, with the reasons for its cooldown, grouping and codecov ignore
  - id: codecov-pin
    resource: ../../../.github/workflows/build.yml
    symbol: codecov/codecov-action@
    title: The `codecov/codecov-action` pin, at v4
  - id: knowledge-checkout
    resource: ../../../.github/workflows/knowledge.yml
    symbol: "persist-credentials: false"
    title: Read-only permissions and a credential-free checkout
---

# Where it lives

- Enforced by: the Alphabet zizmor scan and the org Actions allow-list, both configured outside the repo (see [what gates merging](/ci/trigger-matrix.md)). The rest is review only.
- Dependabot's scope, cooldown, grouping and codecov ignore, with their reasons in comments: `cooldown:` in `.github/dependabot.yaml`.[^dependabot-cooldown]
- The one action held at an old major: `codecov/codecov-action@` in `.github/workflows/build.yml`.[^codecov-pin]
- The practice to copy, with read-only `permissions` and a checkout without credentials: `persist-credentials: false` in `.github/workflows/knowledge.yml`.[^knowledge-checkout]

# Constraint

**The zizmor scan** enforces:

- every action pinned to a full commit SHA;
- no `${{ }}` interpolation of secrets or untrusted values inside `run:` or `script:` blocks; pass them through `env:`;
- a Dependabot `cooldown`.

**The org Actions allow-list** permits only allow-listed actions. The codecov ignore in `dependabot.yaml` says which `codecov/codecov-action` major it allows.

**Not enforced:** read-only top-level `permissions`, escalated per job, and `persist-credentials: false` on checkouts are repo practice. Whether the scan requires them isn't stated, and `build.yml`'s checkouts pass without the latter.

# Why

- The maintainers' stated reasons: the SHA pins and the template-injection fix were made to unblock the mandatory zizmor check, and the Dependabot cooldown was added because the scan flags a config without one. The other Dependabot reasons are in its comments.
- The maintainers' stated reason Dependabot skips Dart: no lock files are checked in (see [no lockfiles](/dependencies/no-lockfiles-or-overrides.md)).

# Rules for agents

- **Must:** pin any new or updated action to a full commit SHA. The zizmor scan enforces it.
- **Must:** use only actions already used here or confirmed to be allow-listed.
- **Must:** keep secrets in `env:`.
- **Must not:** bump `codecov/codecov-action` past v4.
- **Must not:** remove the Dependabot cooldown.
- **Ask first:** before adding a `pub` or `npm` ecosystem to Dependabot.
- **Should:** add a `# vX` comment naming the version after the SHA, as on the `codecov/codecov-action` pin.
- **Should:** add `persist-credentials: false` to checkouts that don't push.
- **Should:** keep `permissions` read-only by default, and don't loosen existing ones.

# Related

- [What CI runs, the coverage gate, and what gates merging](/ci/trigger-matrix.md)
- [No committed lockfiles or dependency overrides](/dependencies/no-lockfiles-or-overrides.md)

[^dependabot-cooldown]: `.github/dependabot.yaml`
[^codecov-pin]: The codecov pin in `build.yml`
[^knowledge-checkout]: `knowledge.yml` permissions and checkout
