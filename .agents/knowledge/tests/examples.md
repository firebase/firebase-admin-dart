---
type: Constraint
title: The admin examples are workspace members tested in CI
description: "`packages/firebase_admin_sdk/example/` and `example_server_app/` are unpublished workspace members whose tests CI runs, while `google_cloud_firestore/example/` has no CI coverage."
tags: [tests, examples, ci]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/example/**
  - packages/firebase_admin_sdk/example_server_app/**
  - packages/google_cloud_firestore/example/**
sources:
  - id: admin-example
    resource: ../../../packages/firebase_admin_sdk/example
    symbol: "publish_to: none"
    title: The admin example package, unpublished
  - id: server-example
    resource: ../../../packages/firebase_admin_sdk/example_server_app
    symbol: "publish_to: none"
    title: The example server app, unpublished
  - id: ci-example-tests
    resource: ../../../.github/workflows/build.yml
    symbol: example_server_app
    title: The example test steps in the `test` job
---

# Constraint

- `packages/firebase_admin_sdk/example/` and `packages/firebase_admin_sdk/example_server_app/` are members of the pub workspace and are never published (`publish_to: none`).[^admin-example][^server-example]
- CI runs `dart test` in both, in the `test` job of `.github/workflows/build.yml`.[^ci-example-tests]
- `example_server_app` has a Dockerfile, and the root `analysis_options.yaml` excludes it from analysis.
- `packages/google_cloud_firestore/example/` is not a workspace member, and nothing in CI runs or tests it.

# Why

The maintainers' stated reason: the example server's test assertions went stale after its routes changed, because CI ran only the SDK and Firestore unit tests.

# Enforced by

The two example test steps in the `test` job of `.github/workflows/build.yml`.

# Rules for agents

- **Must:** when you change or remove a public API that an example uses, update that example. Run the tests of the admin `example/` and `example_server_app/`, and check that `google_cloud_firestore/example/` still analyzes; it has no tests.

# Related

- [Lints, analysis and formatting](/ci/lint-and-format.md)

[^admin-example]: The admin example package
[^server-example]: The example server app
[^ci-example-tests]: The example test steps in CI
