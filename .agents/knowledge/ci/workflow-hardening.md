---
type: Constraint
title: Workflow security rules (zizmor and the Actions allow-list)
description: "Workflow edits must pass the mandatory Alphabet zizmor scan and the org Actions allow-list; every workflow sets read-only top-level permissions, and `persist-credentials: false` is repo practice, not enforced."
tags: [ci, security, workflows]
agents_md: when-touching
governs:
  - .github/workflows/**
  - .github/dependabot.yaml
sources:
  - id: e2e-persist-credentials
    resource: ../../../.github/workflows/e2e_pipeline.yml
    symbol: "persist-credentials: false"
    title: A checkout without credentials, and secrets passed through `env:`
  - id: build-permissions
    resource: ../../../.github/workflows/build.yml
    symbol: "permissions:"
    title: Read-only top-level permissions, escalated per job
  - id: knowledge-checkout
    resource: ../../../.github/workflows/knowledge.yml
    symbol: "persist-credentials: false"
    title: The knowledge-base check's read-only permissions and credential-free checkout
---

# Constraint

**The zizmor scan**, required on the default branch by an Alphabet ruleset, enforces:

- every action pinned to a full commit SHA;
- no `${{ }}` interpolation of secrets or untrusted values inside `run:` or `script:` blocks; pass them through `env:`;
- a Dependabot `cooldown`.

**The org Actions allow-list** permits only allow-listed actions, and `codecov/codecov-action` only at v4. `build.yml` pins that action to the v4 commit SHA.

**Repo practice, not enforced:**

- Every workflow sets top-level `permissions: contents: read`, and escalates per job where needed: `pull-requests: write` for the coverage comment, `id-token: write` for WIF.[^build-permissions] Whether the scan requires this isn't stated.
- The three Firestore workflows and `knowledge.yml` set `persist-credentials: false` on their checkout.[^e2e-persist-credentials][^knowledge-checkout] The checkouts in `build.yml` don't, and its checks pass.

# Why

The maintainers' stated reasons: the SHA pins and the template-injection fix were made to unblock the mandatory zizmor check, and the Dependabot cooldown was added because the scan flags a config without one. From `e2e_pipeline.yml`: secrets are "Referenced via env, never interpolated into the script body, so the value cannot be parsed as shell", and "dropping the token keeps it out of the checkout the test process can read".

# Enforced by

An Alphabet enterprise ruleset on the default branch requires the zizmor workflow (`github_actions_scan.yml`, from another repository). The org Actions allow-list is configured outside the repo.

# Rules for agents

- **Must:** pin any new or updated action to a full commit SHA. The zizmor scan enforces it.
- **Must:** use only actions already used here or confirmed to be allow-listed.
- **Must:** keep secrets in `env:`.
- **Should:** add a `# vX` comment naming the version after the SHA, as on the `codecov/codecov-action` pin.
- **Should:** add `persist-credentials: false` to checkouts that don't push.
- **Should:** keep `permissions` read-only by default, and don't loosen existing ones.

# Related

- [Dependabot updates GitHub Actions only](/dependencies/dependabot.md)
- [What CI runs where](/ci/trigger-matrix.md)

[^build-permissions]: `build.yml` permissions
[^e2e-persist-credentials]: `e2e_pipeline.yml` checkout and secrets
[^knowledge-checkout]: `knowledge.yml` permissions and checkout
