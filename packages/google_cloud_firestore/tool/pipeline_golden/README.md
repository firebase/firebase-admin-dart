# Pipeline golden fixtures

`test/pipeline_golden_test.dart` checks that every Firestore Pipeline request
this package sends is identical to the one the Node.js SDK
(`@google-cloud/firestore`, pinned in `package.json`) sends for the same
Pipeline. The expected requests come from the Node SDK itself, never from this
package, so a test cannot pass by asserting our own output.

This directory holds the Node side: `cases.js` builds a corpus of named
Pipelines with the Node SDK, and `generate.js` writes the request Node sends for
each one to `test/fixtures/pipeline_golden/<area>.json`.

## Regenerating

Requires Node.js 22 or later. From this directory:

```sh
npm ci
npm run generate
```

Then run `dart test test/pipeline_golden_test.dart` from the package root.

Regenerate when you:

- **add or change a case** in `cases.js` (add the matching Dart case to
  `test/pipeline_golden_test.dart` in the same change), or
- **bump the pinned Node SDK**: change the exact version in `package.json`,
  run `npm install` to update `package-lock.json`, regenerate, and review the
  fixture diff; it is the list of wire-format changes Node made.

Never edit the fixtures by hand. CI (`.github/workflows/pipeline_golden.yml`)
regenerates them and fails if the committed files are stale.

## How capture works

Nothing touches the network. `generate.js` creates a `Firestore` for project
`test-project`, database `(default)` (the ids the Dart test uses), and replaces
`Firestore.requestStream`, the single call the SDK makes to run
`executePipeline`, with a stub that records the request and returns an empty
response stream. Everything before it is the SDK's own code:
`Pipeline.execute(options)`, user data validation and `StructuredPipeline`
serialization.

The recorded `ExecutePipelineRequest` is converted to proto3 JSON the way
google-gax does for the REST transport (`Type.fromObject` + `toProto3JSON`,
using the SDK's own `protobufjs`, protos and `proto3-json-serializer`). That is
the same encoding the Dart SDK sends, via
`ExecutePipelineRequest.toJson()`.

Both sides then apply the same normalization before comparing:

- object keys are sorted (`name` first, for readability); protobuf maps are
  unordered,
- empty `args`, `options`, `fields` and `values` are dropped: proto3 JSON omits
  empty repeated and map fields, and protobufjs keeps some (`options: {}` on
  every stage). An empty `mapValue` or `arrayValue` is kept: it is a value.

Numbers compare by value, so a `doubleValue` of `1` (JavaScript) equals `1.0`
(Dart). Every value is deterministic: fixed timestamps, no generated IDs.

## The corpus

Case ids are `<area>/<subject>/<variant>`, and each area has its own fixture
file:

| Area | Covers |
| --- | --- |
| `sources` | `collection` (path, nested path, reference), `collectionGroup`, `database`, `documents` |
| `queries` | `createFrom` of collection, collection-group and vector queries: every filter operator, composite filters, orderings, implicit orderings, limits, `limitToLast`, offsets, cursors, projections |
| `stages` | every stage Node exposes, with each argument shape and option |
| `options` | `execute` options: `indexMode`, `explainOptions`, `rawOptions` |
| `values` | constants of every type, field paths, variables, plain values and collections in value positions |
| `functions` | every Node Pipeline function |
| `aggregates` | every aggregate function |

Function variants follow one scheme. `static-...` calls the top-level function
(`PipelineFunctions.x`, or a top-level helper such as `equal`, in Dart) and
`method-...` the `Expression` method (`PipelineExpression` in Dart).
`field-name` is a field passed as a string, `expression` an `Expression`,
`literal` a plain value. Functions are wrapped in the smallest Pipeline that
takes them: `aggregate(fn.as('result'))`, `where(fn)` for booleans, otherwise
`select(fn.as('result'))`.

`generate.js` fails if any top-level function or `Expression` method the Node
SDK exports has no case, so a Node upgrade that adds a function also adds a
gap to fill.

## When Dart and Node differ

Every fixture id needs a Dart case in `test/pipeline_golden_test.dart`, and
every Dart case a fixture. A difference that is not listed fails the test with
a path-by-path diff. Three lists in the test document the exceptions, and each
entry is itself checked:

- `_knownDivergences`: Dart deliberately sends something else. The entry's
  check asserts the intended Dart shape.
- `_pendingFixes`: an unintended difference awaiting a fix. The test fails
  once it matches Node, so the entry gets removed.
- `_dartApiGaps`: Node APIs Dart cannot express. The test fails if a Dart case
  is added for one.
