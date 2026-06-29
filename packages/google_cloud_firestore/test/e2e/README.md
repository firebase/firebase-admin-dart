# Firestore Pipeline E2E Tests

These tests run against a real Firebase/Google Cloud project and are skipped by
default.

Required environment:

```sh
export FIRESTORE_PIPELINE_E2E_PROJECT_ID="your-project-id"
export FIRESTORE_PIPELINE_E2E_DATABASE_ID="your-enterprise-database-id"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
dart test -P prod test/e2e/pipeline_e2e_test.dart
```

The target database must support Firestore Pipelines. The service account needs
permission to create, read, query, and delete Firestore documents.

The suite writes temporary documents, executes Pipeline queries against them,
and deletes the documents in teardown. It covers source stages, projection,
sorting, aggregates, result metadata, vector search, and the supported
expression helpers.

Vector nearest-neighbor coverage requires this vector index:

```sh
gcloud firestore indexes composite create \
  --project="your-project-id" \
  --database="your-enterprise-database-id" \
  --collection-group="pipeline_e2e_books" \
  --query-scope=COLLECTION \
  --field-config=field-path="runId",order=ASCENDING \
  --field-config=field-path="embedding",vector-config='{"dimension":"3","flat":"{}"}'
```

The vector index is part of the expected CI setup. The E2E suite uses the stable
`pipeline_e2e_books` collection group and unique per-run document IDs so the
index can be created once and reused.

For CI, store the service account JSON as a secret, write it to a temporary file,
set `GOOGLE_APPLICATION_CREDENTIALS` to that file path, and run:

```sh
dart test -P prod test/e2e/pipeline_e2e_test.dart
```
