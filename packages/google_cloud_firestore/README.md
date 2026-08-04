A Dart client library for Google Cloud Firestore.

This package provides a complete API for interacting with Google Cloud
Firestore, including support for documents, collections, queries, transactions,
batches, and bulk writes.

It can be used standalone or as part of the
[Firebase Admin SDK](https://pub.dev/packages/firebase_admin_sdk).

## Installation

Add `google_cloud_firestore` to your `pubspec.yaml`:

```bash
dart pub add google_cloud_firestore
```

## Usage

### Initialization

#### Usage with Firebase Functions

When running inside Firebase Functions, the environment is automatically
configured with Application Default Credentials. You can simply instantiate
`Firestore` without any arguments.

```dart
import 'package:firebase_functions/firebase_functions.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';

void main(List<String> args) async {
  await fireUp(args, (firebase) {
    // Example: HTTPS callable function that reads from Firestore
    firebase.https.onCall(
      name: 'getUserData',
      (request, response) async {
        final data = request.data as Map<String, dynamic>?;
        final userId = data?['userId'] as String?;
        
        if (userId == null) {
          throw InvalidArgumentError('userId is required');
        }
        
        final firestore = firebase.adminApp.firestore();
        final snapshot = await firestore.collection('users').doc(userId).get();
        
        if (!snapshot.exists) {
          throw NotFoundError('User not found');
        }
        
        return CallableResult(snapshot.data());
      },
    );
  });
}
```

#### Usage with Firebase Admin SDK

If you are using the `firebase_admin_sdk` package, you can access Firestore via
the `FirebaseApp` instance.

```dart
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';

final app = FirebaseApp.initializeApp();
final firestore = app.firestore(); // Returns a Firestore instance from this package
```

#### Standalone Usage

You can initialize `Firestore` directly using Application Default Credentials or
by providing a service account.

```dart
import 'dart:io';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';

// Option 1: Use Application Default Credentials (ADC)
// Recommended for Google environments like Cloud Run, App Engine, etc.
// The project ID is discovered automatically from the environment.
final firestore = Firestore();

// Option 2: With a service account file
final firestoreWithSA = Firestore(
  settings: Settings(
    credential: Credential.fromServiceAccount(
      File('path/to/service-account.json'),
    ),
  ),
);

// Option 3: With explicit parameters
final firestoreWithParams = Firestore(
  settings: Settings(
    projectId: 'my-project',
    credential: Credential.fromServiceAccountParams(
      email: 'xxx@xxx.iam.gserviceaccount.com',
      privateKey: '-----BEGIN PRIVATE KEY-----...',
      projectId: 'my-project',
    ),
  ),
);
```

#### Using ADC locally with gcloud auth

When authenticating locally via `gcloud auth application-default login`, the
credentials produced (type: `authorized_user`) do not include a project ID.
You must supply it either via an environment variable or in `Settings`:

```bash
export GOOGLE_CLOUD_PROJECT=your-project-id
```

```dart
// Or set it explicitly in Settings
final firestore = Firestore(
  settings: Settings(projectId: 'your-project-id'),
);
```

### Basic Operations

#### Set / Update / Delete

```dart
final ref = firestore.collection('users').doc('user-id');

// Set a document (creates or overwrites)
await ref.set({'name': 'John Doe', 'age': 27});

// Update specific fields
await ref.update({'age': 28});

// Delete a document
await ref.delete();
```

#### Get / Query

```dart
// Get a single document
final snapshot = await firestore.collection('users').doc('user-id').get();
if (snapshot.exists) {
  print(snapshot.data());
}

// Query a collection
final querySnapshot = await firestore
    .collection('users')
    .where('age', WhereFilter.greaterThan, 18)
    .orderBy('age', descending: true)
    .get();

for (final doc in querySnapshot.docs) {
  print('${doc.id} => ${doc.data()}');
}
```

### Firestore Pipeline Operations

> **Enterprise edition only.** Pipelines require a Firestore Enterprise edition
> database. Calling `execute()` against a Standard edition database fails with a
> `FirestoreException` carrying an `unimplemented` status.

Pipelines are server-side queries built as a chain of stages. Each stage takes
the previous stage's output and produces the next, ending in `execute()`.

```dart
final snapshot = await firestore
    .pipeline()
    .collection('books')
    .where(field('rating').greaterThanValue(4.0))
    .sort([field('rating').descending()])
    .select(['title', field('rating')])
    .limit(10)
    .execute();

for (final result in snapshot.results) {
  print(result.data());
}
```

Runnable examples for every stage live in
[`example/pipeline_example.dart`](example/pipeline_example.dart).

#### Sources

A pipeline starts from exactly one source, via `firestore.pipeline()`.

| Source | Description |
| --- | --- |
| `collection(path)` | Documents in a single collection. |
| `collectionReference(ref)` | Same, from a `CollectionReference`. |
| `collectionGroup(id)` | Every collection with the given ID. |
| `database()` | Every document in the database. |
| `documents([refs])` | An explicit set of documents. |
| `createFrom(query)` | An existing `Query` or `VectorQuery`. |

```dart
firestore.pipeline().collection('books');
firestore.pipeline().collectionReference(firestore.collection('books'));
firestore.pipeline().collectionGroup('books');
firestore.pipeline().database();
firestore.pipeline().documents([firestore.doc('books/book-1')]);
```

#### Stages

**`where`** — keeps documents matching a boolean expression.

```dart
.where(and([
  field('genre').equalValue('fiction'),
  field('rating').greaterThanValue(4.0),
]))
```

**`select`** — chooses or computes the output fields. Entries may be field-name
strings, `field(...)` references, or aliased expressions. Computed expressions
must be aliased.

```dart
.select([
  'title',
  field('rating'),
  field('title').toUpperCase().as('shoutedTitle'),
])
```

**`addFields`** / **`removeFields`** — add computed fields to, or drop fields
from, the documents flowing through.

```dart
.addFields([field('price').multiply(1.2).as('priceWithTax')])
.removeFields(['internalNotes'])
```

**`aggregate`** — reduces documents to aggregates, optionally grouped. Both
accumulators and groups are projections.

```dart
.aggregate(
  [
    PipelineFunctions.count().as('bookCount'),
    field('rating').average().as('averageRating'),
  ],
  groups: ['genre'],
)
```

**`distinct`** — unique combinations of the given groups.

```dart
.distinct(['genre', field('language')])
```

**`sort`**, **`offset`**, **`limit`** — ordering and pagination.

```dart
.sort([field('rating').descending(), field('title').ascending()])
.offset(20)
.limit(10)
```

**`unnest`** — emits one document per array element. The selectable's alias
names the field each element lands on; `indexField` records its position.

```dart
.unnest(field('tags').as('tag'), indexField: 'tagIndex')
```

**`replaceWith`** — promotes a map to the top level, so each of its keys becomes
a document field.

```dart
.replaceWith('metadata')
```

**`union`** — concatenates another pipeline's results, keeping duplicates.

```dart
.union(firestore.pipeline().collection('archivedBooks'))
```

**`sample`** — pseudo-randomly keeps a fixed number of documents, or a
proportion between 0 and 1. Exactly one of the two must be given.

```dart
.sample(documents: 10)
.sample(percentage: 0.25)
```

**`findNearest`** — vector nearest-neighbour search. Needs a vector index; see
[E2E Testing](#e2e-testing) for the `gcloud` invocation.

```dart
.findNearest(
  vectorField: 'embedding',
  queryVector: FieldValue.vector([1, 2, 3]),
  distanceMeasure: DistanceMeasure.cosine,
  limit: 3,
  distanceResultField: 'distance',
)
```

**`rawStage`** — escape hatch for preview stages this SDK does not yet wrap.
`search` and `withOptions` are thin wrappers over the same mechanism.

```dart
.rawStage('sample', [10, 'documents'], options: {'stable': true})
```

#### Expressions

Expressions come from two interchangeable entry points:

- **Top-level helpers and fluent methods** — `field`, `constant`, `variable`,
  `and`, `or`, `not`, the comparison helpers, then chained methods.
- **`PipelineFunctions`** — the full catalog as static methods, useful when you
  want the function form or a helper without a fluent equivalent.

```dart
// Equivalent:
field('title').toUpperCase();
PipelineFunctions.toUpper('title');
```

`Expression.field` / `Expression.constant` are aliases for the top-level
`field` / `constant`, for callers who prefer a namespaced entry point.

**Field arguments vs value arguments.** A `String` in a *field* position means a
field reference; in a *value* position it stays a string literal. The field
position is the first argument of most helpers:

```dart
// Reads the `title` field, compares against the literal "Harry":
PipelineFunctions.startsWith('title', 'Harry');

// Compare two fields by wrapping the value position explicitly:
PipelineFunctions.startsWith('title', field('prefix'));
```

Selected expressions must be aliased with `as` (or `alias`):

```dart
.select([field('createdAt').timestampToUnixSeconds().as('createdSeconds')])
```

##### Function reference

Dart helpers map onto backend function names as follows. Every name below is
available on `PipelineFunctions`; most also exist as a fluent method.

| Category | Dart | Backend |
| --- | --- | --- |
| Comparison | `equal`, `notEqual`, `lessThan`, `lessThanOrEqual`, `greaterThan`, `greaterThanOrEqual`, `cmp` | `equal`, `not_equal`, `less_than`, `less_than_or_equal`, `greater_than`, `greater_than_or_equal`, `cmp` |
| Logical | `and`, `or`, `xor`, `nor`, `not`, `conditional`, `ifNull`, `coalesce`, `switchOn`, `equalAny`, `notEqualAny` | `and`, `or`, `xor`, `nor`, `not`, `conditional`, `if_null`, `coalesce`, `switch_on`, `equal_any`, `not_equal_any` |
| Aggregate | `count`, `countIf`, `countDistinct`, `sum`, `average`, `minimum`, `maximum`, `first`, `last`, `arrayAgg`, `arrayAggDistinct` | `count`, `count_if`, `count_distinct`, `sum`, `average`, `minimum`, `maximum`, `first`, `last`, `array_agg`, `array_agg_distinct` |
| Arithmetic | `add`, `subtract`, `multiply`, `divide`, `mod`, `abs`, `ceil`, `floor`, `round`, `trunc`, `sqrt`, `pow`, `exp`, `ln`, `log`, `log10`, `rand`, `logicalMinimum`, `logicalMaximum` | `add`, `subtract`, `multiply`, `divide`, `mod`, `abs`, `ceil`, `floor`, `round`, `trunc`, `sqrt`, `pow`, `exp`, `ln`, `log`, `log10`, `rand`, `minimum`, `maximum` |
| Array | `array`, `arrayConcat`, `arrayContains`, `arrayContainsAll`, `arrayContainsAny`, `arrayFilter`, `arrayGet`, `arrayLength`, `arrayReverse`, `arrayFirst`, `arrayFirstN`, `arrayLast`, `arrayLastN`, `arrayIndexOf`, `arrayIndexOfAll`, `arrayLastIndexOf`, `arraySlice`, `arrayTransform`, `maximumN`, `minimumN`, `join` | `array`, `array_concat`, `array_contains`, `array_contains_all`, `array_contains_any`, `array_filter`, `array_get`, `array_length`, `array_reverse`, `array_first`, `array_first_n`, `array_last`, `array_last_n`, `array_index_of`, `array_index_of_all`, `array_index_of`, `array_slice`, `array_transform`, `maximum_n`, `minimum_n`, `join` |
| String | `byteLength`, `charLength`, `startsWith`, `endsWith`, `like`, `regexContains`, `regexMatch`, `regexFind`, `regexFindAll`, `stringConcat`, `stringContains`, `stringIndexOf`, `toUpper`, `toLower`, `substring`, `stringReverse`, `stringRepeat`, `stringReplaceAll`, `stringReplaceOne`, `trim`, `ltrim`, `rtrim`, `split` | `byte_length`, `char_length`, `starts_with`, `ends_with`, `like`, `regex_contains`, `regex_match`, `regex_find`, `regex_find_all`, `string_concat`, `string_contains`, `string_index_of`, `to_upper`, `to_lower`, `substring`, `string_reverse`, `string_repeat`, `string_replace_all`, `string_replace_one`, `trim`, `ltrim`, `rtrim`, `split` |
| Generic | `length`, `reverse`, `concat` | `length`, `reverse`, `concat` |
| Map | `map`, `mapGet`, `getField`, `mapSet`, `mapRemove`, `mapMerge`, `mapKeys`, `mapValues`, `mapEntries` | `map`, `map_get`, `get_field`, `map_set`, `map_remove`, `map_merge`, `map_keys`, `map_values`, `map_entries` |
| Timestamp | `currentTimestamp`, `timestampTrunc`, `timestampAdd`, `timestampSubtract`, `timestampDiff`, `timestampExtract`, `timestampToUnixMicros`/`Millis`/`Seconds`, `unixMicrosToTimestamp`/`Millis`/`Seconds` | `current_timestamp`, `timestamp_trunc`, `timestamp_add`, `timestamp_subtract`, `timestamp_diff`, `timestamp_extract`, `timestamp_to_unix_*`, `unix_*_to_timestamp` |
| Vector | `cosineDistance`, `dotProduct`, `euclideanDistance`, `vectorLength`, `geoDistance` | `cosine_distance`, `dot_product`, `euclidean_distance`, `vector_length`, `geo_distance` |
| Reference | `collectionId`, `documentId`, `parent`, `referenceSlice`, `currentDocument` | `collection_id`, `document_id`, `parent`, `reference_slice`, `current_document` |
| Type | `type`, `isType` | `type`, `is_type` |
| Debug | `exists`, `isAbsent`, `ifAbsent`, `isError`, `ifError` | `exists`, `is_absent`, `if_absent`, `is_error`, `if_error` |
| Search | `documentMatches`, `score` | `document_matches`, `score` |

`length`/`reverse`/`concat` are the generic forms working on strings, arrays and
maps; `charLength`/`stringReverse`/`stringConcat` and
`arrayLength`/`arrayReverse`/`arrayConcat` are the type-specific ones.
`minimum`/`maximum` are the aggregate forms; use `logicalMinimum` /
`logicalMaximum` to compare several operands element-wise.

Anything not yet wrapped is reachable via `PipelineFunctions.raw` or
`pipelineFunction`:

```dart
PipelineFunctions.raw('some_new_function', [field('x'), 42]);
```

#### Executing and reading results

`execute()` optionally runs inside a transaction, or at a past read time. The
two are mutually exclusive.

```dart
final snapshot = await firestore
    .pipeline()
    .collection('books')
    .execute(readTime: Timestamp.fromDate(DateTime.now().subtract(
      const Duration(minutes: 5),
    )));
```

`PipelineSnapshot` carries the results plus execution metadata:

| Member | Description |
| --- | --- |
| `results` (alias `result`) | The returned `PipelineResult`s. |
| `size`, `empty` | Result count, and whether there are none. |
| `executionTime` | When the results were valid. |
| `transaction` | A newly created transaction ID, when the backend returns one. |
| `explainStats` | Raw explain stats, when the backend returns them. |

Each `PipelineResult` exposes its fields and, when the backend includes document
metadata, its identity:

```dart
for (final result in snapshot.results) {
  print(result.data());          // all decoded fields
  print(result.get('title'));    // a single field
  print(result.document?.path);  // null when a projection dropped metadata
  print(result.createTime);
  print(result.updateTime);
}
```

Projection stages such as `select` and `aggregate` may drop document metadata,
in which case `name`, `document`, `createTime` and `updateTime` are `null`.

#### Migrating a Query to a Pipeline

`createFrom` converts an existing `Query` or `VectorQuery`, preserving its
filters, field mask, ordering, cursors, limit and offset. This is the easiest way
to adopt pipelines incrementally: convert what you have, then append
Pipeline-only stages.

```dart
final query = firestore
    .collection('books')
    .where('genre', WhereFilter.equal, 'fiction')
    .orderBy('rating', descending: true)
    .limit(5);

final snapshot = await firestore
    .pipeline()
    .createFrom(query)
    // Stages below have no Query equivalent.
    .addFields([field('rating').multiply(10).as('score')])
    .execute();
```

Two behavioural notes:

- Query semantics require a field to exist before it can match, so each
  converted filter is paired with an existence check. `WhereFilter.notIn` is the
  exception, matching absent fields as the backend does.
- The query must target the same database as the pipeline, otherwise
  `createFrom` throws an `ArgumentError`.

#### E2E Testing

Real-project Pipeline E2E tests live in `test/e2e/pipeline_e2e_test.dart`.
They are skipped unless you provide a project and credentials:

```bash
export FIRESTORE_PIPELINE_E2E_PROJECT_ID="your-project-id"
export FIRESTORE_PIPELINE_E2E_DATABASE_ID="your-enterprise-database-id"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
dart test -P prod test/e2e/pipeline_e2e_test.dart
```

The E2E suite includes vector nearest-neighbor coverage. Create the vector index
once for the test collection group before running the suite in CI:

```bash
gcloud firestore indexes composite create \
  --project="your-project-id" \
  --database="your-enterprise-database-id" \
  --collection-group="pipeline_e2e_books" \
  --query-scope=COLLECTION \
  --field-config=field-path="runId",order=ASCENDING \
  --field-config=field-path="embedding",vector-config='{"dimension":"3","flat":"{}"}'
```

#### Get All

```dart
// Fetch multiple documents at once
final snapshots = await firestore.getAll([
  firestore.collection('users').doc('user-1'),
  firestore.collection('users').doc('user-2'),
]);

for (final snap in snapshots) {
  if (snap.exists) {
    print(snap.data());
  }
}
```

### Transactions

Transactions allow you to read and modify documents under lock. They are
committed atomically.

```dart
final balance = await firestore.runTransaction((transaction) async {
  final ref = firestore.collection('users').doc('user-id');
  final snapshot = await transaction.get(ref);
  
  final currentBalance = snapshot.exists ? snapshot.data()?['balance'] ?? 0 : 0;
  final newBalance = currentBalance + 10;
  
  transaction.update(ref, {'balance': newBalance});
  return newBalance;
});
```

### Write Batch

Use a write batch for performing multiple writes as a single atomic operation.

```dart
final batch = firestore.batch();

batch.set(firestore.collection('users').doc('user-1'), {'name': 'Alice'});
batch.update(firestore.collection('users').doc('user-2'), {FieldPath(['age']): 30});
batch.delete(firestore.collection('users').doc('user-3'));

await batch.commit();
```

### Bulk Writer

`BulkWriter` is designed for performing a large number of writes in parallel
with automatic rate limiting and retries.

```dart
import 'dart:async';

final bulkWriter = firestore.bulkWriter();

for (var i = 0; i < 1000; i++) {
  unawaited(
    bulkWriter.set(
      firestore.collection('items').doc('item-$i'),
      {'index': i},
    ),
  );
}

// Wait for all writes to complete
await bulkWriter.close();
```

## Contributing

Contributions are welcome! Please read the
[contributing guide](https://github.com/firebase/firebase-admin-dart/blob/main/CONTRIBUTING.md)
to get started.

## License

[Apache License Version 2.0](LICENSE)
