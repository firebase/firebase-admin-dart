---
type: Constraint
title: Apache-2.0 header on every source file
description: Every source file carries the Apache-2.0 header from `scripts/header_template.txt` (the text in that file), checked in CI with addlicense.
tags: [conventions, licensing, ci]
agents_md: always
governs:
  - scripts/header_template.txt
  - .github/workflows/build.yml
sources:
  - id: header-template
    resource: ../../../scripts/header_template.txt
    symbol: Google LLC
    title: The license header template
  - id: license-job
    resource: ../../../.github/workflows/build.yml
    symbol: "check-license-header:"
    title: The `check-license-header` job, its pinned `addlicense` and its `--ignore` list
  - id: contributing-stale-command
    resource: ../../../CONTRIBUTING.md
    symbol: addlicense -f header_template.txt --check
    title: CONTRIBUTING's addlicense commands, with the wrong template path
---

# Where it lives

- Enforced by: the `check-license-header` job in `.github/workflows/build.yml`. Its `addlicense --check` command and `--ignore` list say which files are checked; run the same command without `--check` to add headers.[^license-job]
- The header text and copyright owner: `scripts/header_template.txt`.[^header-template]

# Constraint

Every source file starts with the Apache-2.0 header in `scripts/header_template.txt`.

- `.js` and `.ts` tool files carry the header by convention, although CI skips them. `.mjs` files are checked like `.dart` files.
- **Trap:** CONTRIBUTING's addlicense commands pass `-f header_template.txt`, run from the repo root, where no such file exists.[^contributing-stale-command] Use the job's `scripts/header_template.txt`.

# Why

- The maintainers' stated reason for the owner text: to align the header template and source files with legal guidance (Google LLC as copyright owner).
- The likely reason for the header itself (not recorded): Google's open-source policy for a Google-owned repository.
- The likely behaviour of the check (not recorded): `addlicense --check` only looks for a license marker such as "copyright" near the top of each file; it doesn't compare the exact text or the year.

# Rules for agents

- **Must:** add the header to every new `.dart` file, including tests and tool scripts, and to Dockerfiles and `.mjs` files.
- **Must:** use `scripts/header_template.txt`.
- **Must not:** add headers to `*.g.dart` files.
- **Ask first:** before changing the year on existing files or in the template.

# Related

- [PR template and review](/contributing/pr-template-and-review.md)
- [Published as firebase_admin_sdk, owned by Google](/architecture/package-name-and-ownership.md)

[^license-job]: The `check-license-header` job
[^header-template]: `scripts/header_template.txt`
[^contributing-stale-command]: CONTRIBUTING's addlicense commands
