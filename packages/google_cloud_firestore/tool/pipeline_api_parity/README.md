# Pipeline API parity snapshot

`test/pipeline_api_parity_test.dart` checks that the Dart Pipelines API keeps
the same signatures as the Node.js Admin SDK: argument counts, optional
parameters, single values versus lists, which kinds of values each parameter
accepts, options objects versus named parameters, and the `isType` values.
Unit tests cannot catch these mismatches, since a test only exercises the
signature it was written against.

The test does not need Node. It reads
`test/fixtures/node_pipeline_api.json`, which this tool extracts from the
TypeScript declarations of the pinned `@google-cloud/firestore` release
(`types/firestore.d.ts`, namespace `FirebaseFirestore.Pipelines`), with the
TypeScript compiler API. It also lists the few functions and methods that the
JavaScript build exports without declaring them, so the test does not report
them as Dart-only.

## Regenerating the snapshot

```sh
cd packages/google_cloud_firestore/tool/pipeline_api_parity
npm ci
npm run extract
```

The output only depends on the pinned versions in `package-lock.json` and on
`extract_node_api.mjs`, so it is byte-for-byte reproducible. The
"Pipeline API snapshot" workflow regenerates it and fails when the committed
file differs.

Regenerate it when you change `extract_node_api.mjs`, or to compare against a
newer Node SDK:

```sh
npm install --save-exact @google-cloud/firestore@<version>
npm run extract
```

Then update `_nodeVersion` in `test/pipeline_api_parity_test.dart`, run that
test from `packages/google_cloud_firestore`, and triage what it reports.

## Triaging a failure

Each difference is one line, `id: message`, for example:

```
PipelineFunctions.join#arity: Node requires 2 argument(s), Dart requires 1 — Node join(arrayExpression: expression|string, delimiter: expression|string); Dart join(Object? array, [Object? delimiter])
```

Fix the Dart API, or record the difference in the test:

- `_knownDifferences`: intentional, with the reason.
- `_pendingFixes`: a Dart bug or gap to fix later.
- `_dartOnly`: a public Dart member Node has no counterpart for.
- `_renames`: a Node member Dart spells differently.

The test fails on stale entries, so remove an entry once the difference is
gone.
