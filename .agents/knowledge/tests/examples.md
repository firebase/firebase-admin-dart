---
type: Constraint
title: The admin examples are tested in CI, Firestore's is not
description: "CI runs the tests of `firebase_admin_sdk`'s `example/` and `example_server_app/`, while `google_cloud_firestore/example/` is not a workspace member and nothing in CI analyzes or runs it."
tags: [tests, examples, ci]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/example/**
  - packages/firebase_admin_sdk/example_server_app/**
  - packages/google_cloud_firestore/example/**
sources:
  - id: ci-example-tests
    resource: ../../../.github/workflows/build.yml
    symbol: example_server_app
    title: The example test steps in the `test` job
  - id: admin-example
    resource: ../../../packages/firebase_admin_sdk/example
    symbol: "publish_to: none"
    title: The admin example package, unpublished
  - id: server-example
    resource: ../../../packages/firebase_admin_sdk/example_server_app
    symbol: "publish_to: none"
    title: The example server app, unpublished
---

# Where it lives

- Enforced by: the example test steps in the `test` job, which name `example_server_app` in `.github/workflows/build.yml`.[^ci-example-tests] Nothing covers the Firestore example.
- The admin examples, unpublished workspace members: `packages/firebase_admin_sdk/example/`[^admin-example] and `packages/firebase_admin_sdk/example_server_app/`.[^server-example]

# Constraint

`packages/google_cloud_firestore/example/` holds plain Dart files inside the Firestore package. It isn't a workspace member, and CI neither analyzes it, since CI analyzes only `firebase_admin_sdk`, nor runs it.

# Why

The maintainers' stated reason for testing the admin examples: the example server's test assertions went stale after its routes changed, because CI ran only the SDK and Firestore unit tests.

# Rules for agents

- **Must:** when you change or remove a public API that an example uses, update that example. Run the tests of the admin `example/` and `example_server_app/`, and check that `google_cloud_firestore/example/` still analyzes; it has no tests.

# Related

- [Lints, analysis and formatting](/ci/lint-and-format.md)

[^ci-example-tests]: The example test steps in CI
[^admin-example]: The admin example package
[^server-example]: The example server app
