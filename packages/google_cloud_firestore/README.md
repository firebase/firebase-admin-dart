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

Firestore Pipeline operations are available for Firestore Enterprise edition
databases. They are server-side queries for projections, expressions,
aggregates, and vector search.

```dart
final snapshot = await firestore
    .pipeline()
    .collection('books')
    .where(Expression.field('active').equalValue(true))
    .sort([Expression.field('price').ascending()])
    .select([
      Expression.field('title'),
      Expression.field('price'),
      Expression.field('title').toUpperCase().as('upperTitle'),
      Expression.field('tags').arrayLength().as('tagCount'),
    ])
    .limit(10)
    .execute();

for (final result in snapshot.results) {
  print(result.data());
}
```

#### Aggregates

Aggregate stages use aliased aggregate expressions:

```dart
final snapshot = await firestore
    .pipeline()
    .collection('books')
    .where(Expression.field('active').equalValue(true))
    .aggregate([
      Expression.field('price').sum().as('totalPrice'),
      Expression.field('rating').average().as('averageRating'),
      PipelineFunctions.count().as('bookCount'),
    ])
    .execute();

final data = snapshot.results.single.data();
print(data);
```

#### Expressions

Use `Expression.field`, `Expression.constant`, and `Expression.variable` to
build expressions. Most helpers are also available as fluent methods:

```dart
final expression = Expression.field('createdAt')
    .timestampSubtract('day', 7)
    .timestampToUnixSeconds()
    .as('createdSeconds');
```

Expressions can be selected with an alias, used in filters, passed to aggregate
stages, or composed with other expression helpers.

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
