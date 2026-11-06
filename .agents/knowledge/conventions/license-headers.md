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
    title: The `check-license-header` job and its `addlicense` command
---

# Constraint

Every source file starts with the Apache-2.0 header in `scripts/header_template.txt`, whose copyright owner is Google LLC.[^header-template]

The `check-license-header` job in `.github/workflows/build.yml` checks it with `addlicense --check`, using that template. The job pins the `addlicense` version, and its `--ignore` list names the file types it skips, among them `*.g.dart`, YAML, shell scripts and `.js`/`.ts`.[^license-job]

- To add headers, run the job's `addlicense` command from the repo root without `--check`.
- Files addlicense can't comment, such as Markdown, JSON and `.rules`, are skipped.
- `.js` and `.ts` tool files carry the header by convention; CI skips them. `.mjs` files are checked like `.dart` files.

# Why

- The maintainers' stated reason for the owner text: to align the header template and source files with legal guidance (Google LLC as copyright owner).
- The likely reason for the header itself (not recorded): Google's open-source policy for a Google-owned repository.
- The likely behaviour of the check (not recorded): `addlicense --check` only looks for a license marker such as "copyright" near the top of each file; it doesn't compare the exact text or the year.

# Enforced by

The `check-license-header` job in `.github/workflows/build.yml`.[^license-job]

# Rules for agents

- **Must:** add the header to every new `.dart` file, including tests and tool scripts, and to Dockerfiles and `.mjs` files.
- **Must:** use `scripts/header_template.txt`.
- **Must not:** add headers to `*.g.dart` files.
- **Ask first:** before changing the year on existing files or in the template.

# Related

- [Apache-2.0 licence and the Google CLA](/contributing/license-and-cla.md)
- [Published as firebase_admin_sdk, owned by Google](/architecture/package-name-and-ownership.md)

[^header-template]: `scripts/header_template.txt`
[^license-job]: The `check-license-header` job
