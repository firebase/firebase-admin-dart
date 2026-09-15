## 0.5.5

- Widen dependency upper bounds for `google_cloud_firestore_v1` (`>=0.5.2 <0.7.0`) and `google_cloud_rpc` (`>=0.5.2 <0.7.0`).

## 0.5.4

- Added support for Firestore Pipelines: `Firestore.pipeline()`, the `Pipeline` stage builders, the `PipelineFunctions` expression catalog, and the top-level `equal`, `notEqual`, `lessThan`, `lessThanOrEqual`, `greaterThan`, `greaterThanOrEqual`, `and`, `or`, `not`, `field`, `constant`, `ascending` and `descending` helpers. The expression surface mirrors the Node Admin SDK.
- Added `PipelineSource.createFrom()` to convert a `Query` or `VectorQuery` into an equivalent Pipeline.
- Added `Transaction.executePipeline()` to run a Pipeline at a transaction's snapshot, with the same `indexMode`, `explain` and `rawOptions` parameters as `Pipeline.execute()`.
- Added Pipeline execution options on `Pipeline.execute()`: `indexMode`, `explain` for planner statistics (read back from `PipelineSnapshot.explainStats`), and a `rawOptions` escape hatch for options this SDK does not wrap yet.
- `PipelineFunctions.minimum()`/`maximum()` are aggregate-only; use `logicalMinimum()`/`logicalMaximum()` for the element-wise form.
- Fixed `Settings.ssl` being ignored when connecting to a custom `Settings.host` endpoint without `FIRESTORE_EMULATOR_HOST`.
- Fixed `FirestoreHttpClient.getProjectId()` and `_run()` ignoring `Settings.projectId` and `Settings.credential` service account project IDs when `GOOGLE_CLOUD_PROJECT` is set in the ambient process environment.

## 0.5.3

- Added `Settings.headers` to attach custom HTTP headers to every outgoing Firestore request.
- Fixed intermittent `ClientException: Connection closed before full header was received` on queries and aggregations under high concurrency; these now retry with backoff.
- Fixed `Firestore.getAll()` retrying transient errors indefinitely; it now retries a bounded number of times before surfacing the error.
- Updated `Transaction.delete` and `Transaction.update` type constraints to accept `DocumentReference<Object?>`. (thanks to @Levin-Me)
- Made `Timestamp` encodable by adding `toJson` method. (thanks to @OutdatedGuy)
- Update dependency `googleapis_auth: ^2.3.3` to fix `auth/insufficient-permission` errors with Application Default Credentials that have no quota project set.

## 0.5.2

- Fixed `Firestore.projectId` not reading `GOOGLE_CLOUD_PROJECT` when using Application Default Credentials locally.
- Fixed `FieldMask` not available from export. (thanks to @OutdatedGuy)
- Require `google_cloud: '>=0.4.0 <0.6.0'`

## 0.5.1

- Added retry support for `WriteBatch.commit()` on transient errors (`ABORTED`, `UNAVAILABLE`, `RESOURCE_EXHAUSTED`).
- Added an example.
- Added a more detailed project description.
- Update dependency `meta: ^1.17.0` to allow workspaces with stable Flutter.

## 0.5.0

- First release.
