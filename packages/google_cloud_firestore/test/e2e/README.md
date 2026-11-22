# Firestore Pipeline E2E Tests

These tests run against a real Firebase/Google Cloud project and are skipped by
default.

Both environment variables are required — the suite skips itself unless each is
set. There is deliberately no `(default)` fallback for the database: the target
must be an **Enterprise-edition** database carrying this suite's vector index,
and falling back would let an ambient `GOOGLE_CLOUD_PROJECT` silently point the
suite somewhere it cannot pass.

```sh
export FIRESTORE_PIPELINE_E2E_PROJECT_ID="<pipelines-project-id>"
export FIRESTORE_PIPELINE_E2E_DATABASE_ID="firestore-pipeline-test"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
dart test -P prod test/e2e/pipeline/ --concurrency=1
```

The credential needs permission to create, read, query, and delete documents in
that database — `roles/datastore.user` covers it.

## Layout

The suite lives in `test/e2e/pipeline/`, one file per area:

| File | Covers |
| --- | --- |
| `harness.dart` | Shared setup, seed data and case helpers (not a test file). |
| `sources_test.dart` | `Firestore.pipeline` and the `PipelineSource` stages. |
| `stages_test.dart` | `Pipeline` stages, orderings and aliases. |
| `results_test.dart` | `PipelineSnapshot` / `PipelineResult` accessors and value decoding. |
| `execute_test.dart` | `execute` options, explain stats, `Transaction.executePipeline`. |
| `aggregates_test.dart` | Aggregate functions and the `aggregate` stage. |
| `functions_<family>_test.dart` | One file per function family: `comparison_logical`, `arithmetic`, `string`, `array`, `map_reference`, `timestamp_vector`, `type_debug`. |

Each file wraps its tests in a single `pipelineE2E(...)` call, which writes the
documents described by `buildSeed` in `harness.dart` once per file — under a
run ID unique to that file — and deletes them in `tearDownAll`. `buildSeed`'s
doc comment lists every seeded field and value; compute expectations from it.

Prefer the table-driven helpers, which declare one test per case so a single
backend rejection never hides another:

```dart
pipelineE2E('Pipeline arithmetic functions', (ctx) {
  ctx.functionCases('round', [
    // Evaluated on book 1 as select([expression.as('v')]).
    FunctionCase('static, omitted decimals', PipelineFunctions.round('half'), isNumber(3)),
    FunctionCase('fluent, with decimals', field('precise').round(2), isNumber(4.12)),
  ]);
});
```

`ctx.aggregateCases` evaluates `aggregate([...])` over the run's three
documents, and `ctx.filterCases` checks which books a `where` condition keeps.
`isInt`, `isDouble` and `isNumber` match numeric results by wire type.

Test files import only `package:google_cloud_firestore/google_cloud_firestore.dart`,
`package:test/test.dart` and the harness (plus `dart:` libraries), so a public
API missing from the barrel fails to compile here.

## Coverage guard

`test/pipeline_e2e_coverage_test.dart` is an ordinary, credential-free unit
test. It resolves these files with `package:analyzer` and fails unless every
public Pipeline API member — static and fluent forms counted separately — is
referenced here, every optional parameter is both supplied and omitted, every
`Object`-typed value position receives both an expression and a plain value,
and a few listed parameters receive specific shapes (collections holding
expressions, numeric vector lists, dotted and `FieldPath` result paths). Its
report groups gaps by family, naming the file that owns each one. The rules,
the family tables and the few exemptions are documented at the top of the
guard.

Adding a public Pipeline function therefore means adding a live case for it
here; the guard fails until you do.

Vector nearest-neighbor coverage requires this vector index:

```sh
gcloud firestore indexes composite create \
  --project="<pipelines-project-id>" \
  --database="firestore-pipeline-test" \
  --collection-group="pipeline_e2e_books" \
  --query-scope=COLLECTION \
  --field-config=field-path="runId",order=ASCENDING \
  --field-config=field-path="embedding",vector-config='{"dimension":"3","flat":"{}"}'
```

The vector index is part of the expected CI setup. The E2E suite uses the stable
`pipeline_e2e_books` collection group and unique per-run document IDs so the
index can be created once and reused.

## CI

`.github/workflows/e2e_pipeline.yml` runs this suite on `ubuntu-latest` against
the `firestore-pipeline-test` database — the same Pipelines project and database
FlutterFire's `e2e_tests_pipeline.yaml` targets, so both SDKs are validated
against one shared Enterprise-edition database.

It runs on pull requests that touch `packages/google_cloud_firestore/**`, on
pushes to `main`, nightly, and on demand via `workflow_dispatch`. Fork and
dependabot pull requests are skipped, because they do not receive secrets.

### Setup

The job authenticates as a dedicated service account in the Pipelines project,
`dart-admin-pipeline-e2e@<project>.iam.gserviceaccount.com`, which holds
`roles/datastore.user`. It is separate from the Workload Identity Federation
identity `build.yml` uses, because that one belongs to a different project.

Two repository secrets are required:

| Secret | Contents |
| --- | --- |
| `PIPELINE_E2E_SERVICE_ACCOUNT` | The full service account key JSON. |
| `PIPELINE_E2E_PROJECT_ID` | The Pipelines project ID. Kept in a secret to match how FlutterFire's workflow treats it. |

The database ID is a plain value in the workflow, not a secret — FlutterFire
hardcodes `firestore-pipeline-test` in its own test sources.

The workflow writes the key to `$RUNNER_TEMP` rather than the checkout, points
`GOOGLE_APPLICATION_CREDENTIALS` at it, and deletes it in an `always()` step.

Note that this is a long-lived credential, unlike the rest of the repo's CI. If
it is ever rotated, replace the secret and delete the old key with
`gcloud iam service-accounts keys delete`.

### Sharing the database with FlutterFire

FlutterFire's suite seeds the `pipeline-e2e` and `pipeline-search-e2e`
collections. This suite only touches `pipeline_e2e_books`, with per-run document
IDs, so the two can run concurrently without interfering.

### Guards

- `dart test` exits `0` when every test is *skipped*, which is exactly what a
  missing project or database ID produces. The workflow fails if the secret is
  empty, and again if the run reports `All tests skipped`. Without those checks
  a misconfigured job would report a green build for tests that never ran.
- `concurrency` is scoped per ref with `cancel-in-progress`, so two runs never
  write to the database on the same ref at once. A cancelled run does skip its
  `tearDownAll`, which leaves that run's `run_<micros>_book_*` documents behind.
  They are inert — every assertion filters on `runId` — but
  `pipeline_e2e_books` is worth sweeping occasionally.

### Note on IAM propagation

A freshly granted `roles/datastore.user` can take several minutes to take
effect; until it does, every test fails with
`permission_denied: Missing or insufficient permissions`. If the first run after
a permissions change fails that way, re-run it before looking for a real bug.
