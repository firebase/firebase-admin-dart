---
type: Decision
title: Pipelines parity with Node is checked by machine
description: Firestore Pipelines are checked against the pinned Node SDK in CI, by golden requests, an API-signature snapshot, a single-implementation test and a live E2E coverage guard, and every difference from Node is a table entry with its reason.
tags: [firestore, pipelines, node-parity, tests, generated]
agents_md: when-touching
governs:
  - packages/google_cloud_firestore/lib/src/pipeline.dart
  - packages/google_cloud_firestore/lib/src/transaction.dart
  - packages/google_cloud_firestore/lib/google_cloud_firestore.dart
  - packages/google_cloud_firestore/test/pipeline_*.dart
  - packages/google_cloud_firestore/test/e2e/**
  - packages/google_cloud_firestore/test/fixtures/pipeline_golden/**
  - packages/google_cloud_firestore/test/fixtures/node_pipeline_api.json
  - packages/google_cloud_firestore/tool/**
  - .github/workflows/pipeline_golden.yml
  - .github/workflows/pipeline_api_snapshot.yml
  - .github/workflows/e2e_pipeline.yml
sources:
  - id: golden-test
    resource: ../../../../packages/google_cloud_firestore/test/pipeline_golden_test.dart
    symbol: final _knownDivergences
    title: The golden wire-format test and `_knownDivergences`
  - id: golden-gaps
    resource: ../../../../packages/google_cloud_firestore/test/pipeline_golden_test.dart
    symbol: const _dartApiGaps
    title: "`_dartApiGaps`: golden cases Dart can't express"
  - id: api-parity-test
    resource: ../../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: const _pendingFixes
    title: The API-signature parity test and `_pendingFixes`
  - id: known-differences
    resource: ../../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: const _knownDifferences
    title: "`_knownDifferences`: deliberate signature differences and their reasons"
  - id: node-version
    resource: ../../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: const _nodeVersion
    title: The Node version the parity test expects
  - id: single-implementation-test
    resource: ../../../../packages/google_cloud_firestore/test/pipeline_single_implementation_test.dart
    symbol: const _exceptions
    title: The single-implementation test
  - id: e2e-coverage-test
    resource: ../../../../packages/google_cloud_firestore/test/pipeline_e2e_coverage_test.dart
    symbol: "**Adding a Pipeline API member:**"
    title: The credential-free guard over the live E2E suite
  - id: golden-readme
    resource: ../../../../packages/google_cloud_firestore/tool/pipeline_golden/README.md
    symbol: "## When Dart and Node differ"
    title: How the golden fixtures are generated, regenerated and triaged
  - id: parity-readme
    resource: ../../../../packages/google_cloud_firestore/tool/pipeline_api_parity/README.md
    symbol: "## Triaging a failure"
    title: How the API snapshot is extracted, regenerated and triaged
  - id: e2e-readme
    resource: ../../../../packages/google_cloud_firestore/test/e2e/README.md
    symbol: "## Coverage guard"
    title: The live E2E suite's setup, rules and reasons
  - id: golden-pin
    resource: ../../../../packages/google_cloud_firestore/tool/pipeline_golden/package.json
    symbol: "@google-cloud/firestore"
    title: The Node SDK pin of the golden tool
  - id: parity-pin
    resource: ../../../../packages/google_cloud_firestore/tool/pipeline_api_parity/package.json
    symbol: "@google-cloud/firestore"
    title: The Node SDK pin of the snapshot tool
  - id: golden-workflow
    resource: ../../../../.github/workflows/pipeline_golden.yml
    symbol: npm run generate
    title: The workflow that regenerates the fixtures and fails on drift
  - id: snapshot-workflow
    resource: ../../../../.github/workflows/pipeline_api_snapshot.yml
    symbol: npm run extract
    title: The workflow that regenerates the snapshot and fails on drift
  - id: e2e-workflow
    resource: ../../../../.github/workflows/e2e_pipeline.yml
    symbol: All tests skipped
    title: The live E2E workflow and its skip guards
  - id: execute-options-readme
    resource: ../../../../packages/google_cloud_firestore/README.md
    symbol: pure description of what to fetch
    title: The package README on query-level options and `execute()`
  - id: node-pipelines
    resource: https://github.com/googleapis/google-cloud-node/tree/main/handwritten/firestore/dev/src/pipelines
    title: Node's Pipelines source
---

# Where it lives

- Enforced by: four unit tests, for the wire format (`pipeline_golden_test.dart`),[^golden-test] the signatures (`pipeline_api_parity_test.dart`),[^api-parity-test] one implementation per function (`pipeline_single_implementation_test.dart`)[^single-implementation-test] and a live case per public member (`pipeline_e2e_coverage_test.dart`);[^e2e-coverage-test] and the `pipeline_golden.yml`[^golden-workflow] and `pipeline_api_snapshot.yml`[^snapshot-workflow] workflows, which fail on stale generated files.
- The golden fixtures, how to regenerate them and the wire-format tables: `tool/pipeline_golden/README.md`, under `## When Dart and Node differ`.[^golden-readme]
- The API snapshot, how to regenerate it or bump Node, and the signature tables: `tool/pipeline_api_parity/README.md`, under `## Triaging a failure`.[^parity-readme]
- The live suite, its database, secrets, index and skip guards: `test/e2e/README.md`, under `## Coverage guard`,[^e2e-readme] and `e2e_pipeline.yml`.[^e2e-workflow]
- The Node pins: `@google-cloud/firestore` in each tool's `package.json`,[^golden-pin][^parity-pin] and `_nodeVersion` in `pipeline_api_parity_test.dart`.[^node-version]

# Decision

Firestore Pipelines are checked against Node by machine, in CI. No other product is ([Port of the Node.js Admin SDK](/architecture/node-port.md)). The tests, their tables and the READMEs above are the source of truth; this concept keeps only what they don't say outright.

- **Every difference from Node is a table entry, with its reason.** Each test lists its allowed differences in tables, and a stale entry fails the test. The READMEs say which table takes which kind of difference.[^golden-readme][^parity-readme]
- **`_knownDivergences` entries are deliberate, not bugs.** Where the pinned Node SDK sends a request the backend rejects, or that drops or misapplies an option, Dart sends what the backend accepts.[^node-pipelines] Each entry records why, usually as the backend's error, and a check asserts the shape Dart sends.[^golden-test]
- **`_pendingFixes` and `_dartApiGaps` entries are unresolved, not decisions.** Most are gaps: Node APIs that Dart lacks or gets wrong, such as `pipeline.stream()`.[^api-parity-test][^golden-gaps] The parity test's `_pendingFixes` also holds Dart-only functions waiting for a backend check, to keep or drop.
- **`_knownDifferences` holds Dart's deliberate additions,** such as `Pipeline.execute(readTime:)` and the options `Transaction.executePipeline` takes.[^known-differences] Query-level options go to `execute()`, not onto the Pipeline; the package README gives the reason.[^execute-options-readme]
- **The tables are complete only for the pinned Node release.** APIs Node adds later appear only when the pin is bumped.[^node-version] The two tools pin `@google-cloud/firestore` separately, and nothing checks that the pins match.[^golden-pin][^parity-pin]

# Why

The maintainers' stated reasons are in the tool READMEs, the test-file headers and each table entry. The central one: the expected requests and signatures come from the Node SDK itself, never from this package, so a test can't pass by asserting Dart's own output.[^golden-readme]

# Rules for agents

- **Must:** match Node by default. Record each deliberate difference in the right table, with its reason. A new `_knownDivergences` entry needs a reason, ideally the backend's error, and a check of the shape Dart sends.
- **Must not:** "fix" a `_knownDivergences` entry back to Node's wire format, or make a failing golden test pass by changing its expected side.
- **Must:** when you implement a Node API listed in `_pendingFixes` or `_dartApiGaps`, match Node's signature and wire format, then delete the entry.
- **Must:** keep Dart's additions in `_knownDifferences`, and keep query-level options on `execute()`.
- **Must not:** add a public Pipeline API without a golden case and a live case in its family's E2E file.
- **Must:** regenerate the fixtures and the snapshot with their tools, in the same PR as a change to `cases.js`, the extractor or a pin, and review the diff.
- **Must not:** edit the fixtures or the snapshot by hand.
- **Must:** bump the pin in both tools' `package.json` together, update `_nodeVersion`, regenerate both, then triage.
- **Must not:** give the E2E suite a `(default)` database fallback, point it at another database, or weaken its skip guards.

# Related

- [Port of the Node.js Admin SDK](/architecture/node-port.md)
- [Firestore runs over REST, with buffered streaming](/firestore/rest-transport.md), which owns why `pipeline.stream()` can't stream incrementally
- [Firestore follows Node, with a few FlutterFire look-alikes](/firestore/node-not-flutterfire.md), for the FlutterFire-style aliases
- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md), for renames, option objects and JS Web SDK names
- [Prod and WIF test runs](/tests/prod-and-wif.md)
- [The publish dry run must pass for both packages](/release/publish-dry-run.md)

[^golden-test]: The golden wire-format test
[^golden-gaps]: `_dartApiGaps`
[^api-parity-test]: The API-signature parity test
[^known-differences]: `_knownDifferences`
[^node-version]: `_nodeVersion`
[^single-implementation-test]: The single-implementation test
[^e2e-coverage-test]: The E2E coverage guard
[^golden-readme]: The golden tool's README
[^parity-readme]: The snapshot tool's README
[^e2e-readme]: The live suite's README
[^golden-pin]: The golden tool's pin
[^parity-pin]: The snapshot tool's pin
[^golden-workflow]: `pipeline_golden.yml`
[^snapshot-workflow]: `pipeline_api_snapshot.yml`
[^e2e-workflow]: `e2e_pipeline.yml`
[^execute-options-readme]: The package README on `execute()` options
[^node-pipelines]: Node's Pipelines source
