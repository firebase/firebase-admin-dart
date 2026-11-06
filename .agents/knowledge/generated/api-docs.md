---
type: Constraint
title: API docs are pub.dev dartdoc
description: The API reference is the pub.dev dartdoc, `melos run docs` writes local docs to git-ignored `doc/api/`, and new public APIs need `///` dartdoc.
tags: [docs, generated]
agents_md: when-touching
governs:
  - doc/**
  - scripts/generate-docs.sh
  - .github/workflows/**
sources:
  - id: generate-docs
    resource: ../../../scripts/generate-docs.sh
    symbol: dart doc
    title: The docs script
  - id: doc-index
    resource: ../../../doc/index.html
    title: The hand-written landing page
  - id: melos-docs
    resource: ../../../pubspec.yaml
    symbol: generate-docs.sh
    title: The melos `docs` script
---

# Constraint

- The API reference is the dartdoc on pub.dev, which CONTRIBUTING.md links to.
- Locally, `melos run docs` runs `scripts/generate-docs.sh` (`dart doc . --output ../../doc/api/<package>`) for each non-example package and writes to the git-ignored `doc/api/`.[^melos-docs][^generate-docs] `doc/index.html` is a hand-written landing page.[^doc-index]
- Every new public API needs `///` dartdoc. The `comment_references` lint checks the references in it, but nothing checks that dartdoc is present (`public_member_api_docs` is not enabled).
- No workflow builds or deploys docs. An earlier workflow deployed dartdoc to GitHub Pages and was dropped. The repo's GitHub Pages site is that workflow's last deployment, and nothing updates it.

# Why

The maintainers' stated reason for dropping the docs workflow, phrased as a question: it wasn't really needed.

# Enforced by

The `docs` script in the root `pubspec.yaml` and `scripts/generate-docs.sh` define the local build. Nothing enforces dartdoc on public APIs.

# Rules for agents

- **Must:** add dartdoc to every new public API.
- **Must not:** commit `doc/api/`.
- **Ask first:** before reintroducing a docs deployment workflow.

# Related

- [The pub workspace and melos](/repo/workspace-and-melos.md)
- [Other generated files](/generated/other-generated-files.md)

[^melos-docs]: The melos `docs` script
[^generate-docs]: `scripts/generate-docs.sh`
[^doc-index]: `doc/index.html`
