## Unreleased minor

- Added support for Firestore Pipelines: `Firestore.pipeline()`, the `Pipeline` stage builders, the `PipelineFunctions` expression catalog, and the top-level `equal`, `notEqual`, `lessThan`, `lessThanOrEqual`, `greaterThan`, `greaterThanOrEqual`, `and`, `or`, `not`, `field`, `constant`, `ascending` and `descending` helpers.
- Added `PipelineSource.createFrom()` to convert a `Query` or `VectorQuery` into an equivalent Pipeline.
- Added `Transaction.executePipeline()` to run a Pipeline at a transaction's snapshot.
- `PipelineSnapshot.explainStats` now returns an `ExplainStats` wrapper instead of the generated proto type.
- `Pipeline.withOptions()` now takes typed options (`PipelineIndexMode`, `PipelineExplainOptions`) instead of a raw map; `Pipeline.withRawOptions()` keeps the untyped escape hatch.
- Renamed Pipeline expression methods to match the Node Admin SDK: `modulo` is now `mod`, `arrayContainsElement` is `arrayContains`, `toLowerCase`/`toUpperCase` are `toLower`/`toUpper`, and `timestampTrunc` is `timestampTruncate`.
- Added the Pipeline expressions the Node Admin SDK has that were missing: fluent `stringReverse()`, `not()`, `countIf()` and `conditional()`, plus `PipelineFunctions.arrayMaximum()`, `arrayMaximumN()`, `arrayMinimum()`, `arrayMinimumN()`, `arraySum()` and `countAll()`.
- `PipelineFunctions.minimum()`/`maximum()` are aggregate-only; use `logicalMinimum()`/`logicalMaximum()` for the element-wise form.

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
