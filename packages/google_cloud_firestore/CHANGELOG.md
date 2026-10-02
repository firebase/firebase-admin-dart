## Unreleased

- Added `CollectionReference.listDocumentsPages()`, which lists a collection's documents, including missing documents, one `DocumentReferencePage` at a time. It takes an optional `pageSize` and a `pageToken` to resume from a previous page's `nextPageToken`, so large collections can be walked without holding every reference in memory.
- Fixed `CollectionReference.listDocuments()` returning only the first page of results. It now follows `nextPageToken` until the collection is exhausted, matching the Node Admin SDK, so large collections and missing documents past the first page are no longer silently dropped.
- Fixed `DocumentReference.listCollections()` and `Firestore.listCollections()` returning only the first page of collection IDs. They now follow `nextPageToken` until every collection has been returned.
- **Breaking:** `PipelineFunctions.join` and `PipelineFunctions.split` now require their delimiter, matching `PipelineExpression` and the Node Admin SDK. A one-argument call was always rejected by the backend with `INVALID_ARGUMENT`.
- **Breaking:** `PipelineFunctions.mapRemove` and `PipelineExpression.mapRemove` take a single key (a `String` or an expression) and send `map_remove(map, key)`, like the Node Admin SDK, instead of an `Iterable` of keys. Chain `.mapRemove('a').mapRemove('b')` to remove several keys.
- **Breaking:** `PipelineFunctions.arrayTransform` no longer takes a trailing index alias. Use the new `PipelineFunctions.arrayTransformWithIndex(array, elementAlias, indexAlias, transform)`, which matches `PipelineExpression.arrayTransformWithIndex` and the Node Admin SDK and sends the same `array_transform` function.
- Fixed `PipelineFunctions.arrayMaximum`, `arrayMaximumN`, `arrayMinimum`, `arrayMinimumN` and `arraySum` sending function names (`array_maximum`, ...) that the backend rejects. They now send `maximum`, `maximum_n`, `minimum`, `minimum_n` and `sum`, like their `PipelineExpression` counterparts.
- Fixed `Pipeline.addFields` sending one `alias` function per field instead of a single map keyed by alias, which the backend rejected.
- Fixed `PipelineSource.collectionGroup()`, and `createFrom()` on a collection group query, omitting the leading root ancestor argument of the `collection_group` stage.
- Fixed `PipelineValueType.double` sending `'double'` instead of `'float64'`, which made `isType` fail. Added the `int32`, `decimal128`, `maxKey`, `minKey`, `objectId` and `regex` value types.
- Fixed `cosineDistance`, `dotProduct`, `euclideanDistance` and `Pipeline.findNearest` sending a plain list of numbers as an array instead of a vector.
- Fixed Pipeline functions such as `equalAny`, `notEqualAny`, `arrayContainsAll`, `arrayContainsAny` and `mapMerge` failing when a `List` or `Map` argument holds expressions. Collection arguments are now sent as `array(...)` / `map(...)` functions, like the Node Admin SDK, and the static and fluent forms encode identically.
- Fixed the top-level `ascending()` and `descending()` sorting by a string constant when given a field name. A `String` now names a field, like everywhere else in the Pipeline API and in the Node Admin SDK.
- Fixed `PipelineResult.get` ignoring nested paths. It now accepts a `String` or a `FieldPath` and resolves dot-separated paths such as `'metadata.lang'`, like `DocumentSnapshot.get`.
- `Pipeline.select`, `addFields`, `aggregate` and `distinct` now throw an `ArgumentError` on a duplicate field name or alias instead of silently keeping the last one, like the Node Admin SDK.
- `PipelineExpression.substring` and `substringLiteral` now take `(position, [length])` like `PipelineFunctions.substring`: the second argument is a length, not an end index, and can be omitted.
- `PipelineExpression.round` now accepts the optional `decimalPlaces` argument.
- Exported the top-level `variable()` Pipeline helper.
- Every Pipeline function now has a single implementation shared by all of its forms. The fluent `PipelineExpression` method, the top-level helper (`equal`, `and`, `not`, ...) and the `Expression` alias forward to the `PipelineFunctions` function (and `field`, `constant` and `variable` to `Expression`), so every form sends the same request.
- `PipelineFunctions.arraySlice` now takes an optional `length`, like `PipelineExpression.arraySlice` and the Node Admin SDK.
- `PipelineFunctions.raw` now accepts `options`, like `Expression.raw`.
- `PipelineExpression.arrayContainsAll` and `arrayContainsAny` now also accept an array expression, like their `PipelineFunctions` forms and the Node Admin SDK.
- Fixed Pipeline field names that are not simple identifiers being sent unquoted. They are now backtick-quoted like the Node Admin SDK, so `field('first-name')` sends `` `first-name` ``. `field()` and `Expression.field()` also accept a `FieldPath`. `PipelineField.path` returns the quoted path, and `field('')` and `field('a..b')` now throw.
- Fixed field paths containing a backtick being escaped as a lone backslash, which named a different field, in queries, field masks and Pipelines.
- Fixed `Pipeline.createFrom()` and `DocumentSnapshot` query cursors leaving `!=` and `not-in` fields out of the implicit ordering, and ordering inequality fields by their quoted names instead of segment by segment, unlike the backend and the Node Admin SDK. A snapshot cursor now needs a value for every inequality field.
- Fixed `Pipeline.createFrom()` of a query with a cursor on a descending ordering keeping the wrong side of the bound.
- Fixed `Pipeline.createFrom()` of a `VectorQuery` sending its `distanceThreshold` as an undocumented `find_nearest` option. It is now applied as a filter on the distance.
- Fixed `indexMode` being sent as an `index_mode` option the backend rejects; it is deprecated. `Pipeline.execute()` and `Transaction.executePipeline()` now ignore `indexMode`, and `PipelineIndexMode` is deprecated too: its only value, `recommended`, is already the backend's default.
- Fixed `Pipeline.findNearest(distanceThreshold:)` sending a `distance_threshold` option, which the backend rejects. It now adds a `where` stage after `find_nearest` that keeps the results within the threshold, as `Pipeline.createFrom()` does for a `VectorQuery`.
- Fixed Pipeline results failing to decode when a reference that names no document, such as the database root returned by `parent()`, is nested in a map or array. It now decodes to its resource name at every depth, as it already did for top-level fields.
- Pipeline raw options now match the Node Admin SDK. Every stage and source takes an optional `rawOptions`. Keys in `rawOptions` and `rawStage(options:)` are dot-separated paths merged into the typed options, and keys with an empty segment throw an `ArgumentError`. `rawStage` sends collections nested in a `Map` argument as `map(...)` / `array(...)` functions.
- `PipelineFunctions.add` and `multiply` take an optional trailing list of further operands, and `PipelineExpression.add` and `multiply` take `(second, [others])`, like the variadic Node Admin SDK functions. Further operands are sent as nested two-operand calls, `add(add(a, b), c)`, since the backend's `add` and `multiply` take exactly two operands.
- `PipelineSource.documents()` also accepts document paths such as `'books/book1'`, validated like `Firestore.doc()`.
- `PipelineFunctions.map()` also accepts a Dart `Map`, as in `map({'title': field('title')})`.
- Added the `PipelineOrdering.expr` and `PipelineOrdering.direction` getters.

## 0.5.5

- Fixed slow and failing requests under high concurrency by pooling shared HTTP/2 connections by default instead of opening a new HTTP/1.1 connection per request, via `package:http2`'s `Http2Client`. Credential endpoints that speak plain HTTP, such as the GCE/Cloud Run metadata server, keep using HTTP/1.1.
- Widen dependency upper bounds for `google_cloud_firestore_v1` (`>=0.5.2 <0.7.0`) and `google_cloud_rpc` (`>=0.5.2 <0.7.0`).
- Update `handleFirestoreException` to inspect `ServiceException.status` and `ServiceException.message` for compatibility with `google_cloud_rpc 0.6.0`.

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
