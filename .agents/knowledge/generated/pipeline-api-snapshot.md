---
type: Constraint
title: Pipeline API snapshot extracted from Node's typings
description: "`node_pipeline_api.json` is extracted from the pinned Node SDK's TypeScript declarations, and `pipeline_api_parity_test.dart` compares the Dart Pipeline API against it."
tags: [generated, firestore, pipelines, node-parity]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/test/fixtures/node_pipeline_api.json
  - packages/google_cloud_firestore/tool/pipeline_api_parity/**
  - packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
  - packages/google_cloud_firestore/test/pipeline_single_implementation_test.dart
sources:
  - id: api-snapshot
    resource: ../../../packages/google_cloud_firestore/test/fixtures/node_pipeline_api.json
    title: The Node API snapshot
  - id: extractor
    resource: ../../../packages/google_cloud_firestore/tool/pipeline_api_parity/extract_node_api.mjs
    title: The extractor that reads Node's TypeScript declarations
  - id: node-version
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: const _nodeVersion
    title: The parity test and the Node version it expects
  - id: snapshot-workflow
    resource: ../../../.github/workflows/pipeline_api_snapshot.yml
    title: The workflow that regenerates the snapshot and fails if it is stale
---

# Constraint

- `test/fixtures/node_pipeline_api.json` is extracted from the TypeScript declarations of the `@google-cloud/firestore` version pinned in `tool/pipeline_api_parity/package.json`, by `tool/pipeline_api_parity/extract_node_api.mjs` (`npm ci && npm run extract`).[^api-snapshot][^extractor]
- `test/pipeline_api_parity_test.dart` reads the Dart exports with `package:analyzer` and compares the Pipelines API shape with the snapshot. It also checks that the snapshot's Node version equals `_nodeVersion`.[^node-version]
- Its exceptions live in `_renames`, `_classes`, `_enums`, `_optionTypes`, `_dartOnly`, `_knownDifferences` and `_pendingFixes`. Stale entries fail the test. `tool/pipeline_api_parity/README.md` gives the triage rules.
- `test/pipeline_single_implementation_test.dart` requires every form of a Pipeline function (static, fluent, top-level, alias) to forward to one implementation. Its exceptions are in `_exceptions` and `_notFunctions`.
- Both tests run in the unit run. They are analyzer-based, run on the VM only, and are slow: each sets a `Timeout` of several minutes.

# Why

Stated in `tool/pipeline_api_parity/README.md`: "Unit tests cannot catch these mismatches, since a test only exercises the signature it was written against." The single-implementation test's header says that when the forms were implemented separately, they drifted apart.

# Enforced by

`.github/workflows/pipeline_api_snapshot.yml` regenerates the snapshot and fails if it is stale.[^snapshot-workflow] The two Dart tests run with the other unit tests. Nothing checks that `tool/pipeline_api_parity` and `tool/pipeline_golden` pin the same Node SDK version.

# Rules for agents

- **Must:** to bump the Node SDK, bump both `tool/pipeline_api_parity/package.json` and `tool/pipeline_golden/package.json` (`npm install --save-exact`), regenerate both artifacts, update `_nodeVersion`, then triage the differences.
- **Must not:** hand-edit `node_pipeline_api.json`.
- **Must not:** add an entry to an exception list without a stated reason.

# Related

- [Pipelines parity with Node](/firestore/pipelines/node-parity.md)
- [Pipeline golden fixtures](/generated/pipeline-golden-fixtures.md)
- [Pipeline API mirrors Node](/firestore/pipelines/dart-surface.md)
- [The publish dry run](/release/publish-dry-run.md)

[^api-snapshot]: The Node API snapshot
[^extractor]: The extractor
[^node-version]: `_nodeVersion` in the parity test
[^snapshot-workflow]: `pipeline_api_snapshot.yml`
