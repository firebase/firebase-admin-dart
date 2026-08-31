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
dart test -P prod test/e2e/pipeline_e2e_test.dart
```

The credential needs permission to create, read, query, and delete documents in
that database — `roles/datastore.user` covers it.

The suite writes temporary documents, executes Pipeline queries against them,
and deletes the documents in teardown. It covers source stages, projection,
sorting, aggregates, result metadata, vector search, and the supported
expression helpers.

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
  `tearDown`, which leaves that run's `run_<micros>_book_*` documents behind.
  They are inert — every assertion filters on `runId` — but
  `pipeline_e2e_books` is worth sweeping occasionally.

### Note on IAM propagation

A freshly granted `roles/datastore.user` can take several minutes to take
effect; until it does, every test fails with
`permission_denied: Missing or insufficient permissions`. If the first run after
a permissions change fails that way, re-run it before looking for a real bug.
