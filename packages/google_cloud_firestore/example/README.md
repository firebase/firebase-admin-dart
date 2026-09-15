# google_cloud_firestore examples

| File | Covers |
| --- | --- |
| [`main.dart`](main.dart) | Writing documents and running a query. |
| [`pipeline_example.dart`](pipeline_example.dart) | Firestore Pipelines: every stage, aggregates, `unnest`, `replaceWith`, `distinct`, `sample`, `union`, vector search, and converting a `Query`. |

## Reading and writing documents

```dart
import 'package:google_cloud_firestore/google_cloud_firestore.dart';

final firestore = Firestore();
final users = firestore.collection('users');

await users.doc('ada-lovelace').set({
  'first': 'Ada',
  'last': 'Lovelace',
  'born': 1815,
});

final querySnapshot =
    await users.where('born', WhereFilter.lessThan, 1900).get();

for (final doc in querySnapshot.docs) {
  print('${doc.id} => ${doc.data()}');
}
```

## Pipelines

```dart
final snapshot = await firestore
    .pipeline()
    .collection('books')
    .where(field('rating').greaterThan(4.0))
    .aggregate(
      [
        PipelineFunctions.count().as('bookCount'),
        field('rating').average().as('averageRating'),
      ],
      groups: ['genre'],
    )
    .sort([field('averageRating').descending()])
    .execute();

for (final result in snapshot.results) {
  print(result.data());
}
```

## Running

Both examples authenticate with Application Default Credentials:

```bash
gcloud auth application-default login
export GOOGLE_CLOUD_PROJECT="your-project-id"
```

Credentials from `gcloud auth application-default login` do not carry a project
ID, so `GOOGLE_CLOUD_PROJECT` must be set (or pass `projectId` to `Settings`).

```bash
dart run example/main.dart
```

Pipelines require a Firestore **Enterprise edition** database, so pass its
database ID:

```bash
dart run example/pipeline_example.dart your-enterprise-database-id
```

`pipeline_example.dart` seeds a `pipeline_example_books` collection and deletes
it afterwards. The `findNearest` example additionally needs a vector index — see
the E2E Testing section of the [package README](../README.md) for the `gcloud`
invocation that creates one.
