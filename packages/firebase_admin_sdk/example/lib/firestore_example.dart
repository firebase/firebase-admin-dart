// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';

/// Main entry point for all Firestore examples
Future<void> firestoreExample(FirebaseApp admin) async {
  print('\n### Firestore Examples ###\n');

  await basicFirestoreExample(admin);
  await blobExample(admin);
  await multiDatabaseExample(admin);
  await batchExample(admin);
  await transactionExample(admin);
  await collectionGroupExample(admin);
  await getAllExample(admin);
  await listCollectionsExample(admin);
  await recursiveDeleteExample(admin);
  await bulkWriterExamples(admin);
  await bundleBuilderExample(admin);
}

/// Example 1: Basic Firestore operations with default database
Future<void> basicFirestoreExample(FirebaseApp admin) async {
  print('> Basic Firestore operations (default database)...\n');

  final firestore = admin.firestore();

  try {
    final collection = firestore.collection('users');
    await collection.doc('123').set({'name': 'John Doe', 'age': 27});
    final snapshot = await collection.get();
    for (final doc in snapshot.docs) {
      print('> Document data: ${doc.data()}');
    }
  } catch (e) {
    print('> Error: $e');
  }
  print('');
}

/// Example 2: Binary data (blob) stored as Uint8List
Future<void> blobExample(FirebaseApp admin) async {
  print('### Blob Example ###\n');

  final firestore = admin.firestore();
  final doc = firestore.doc('blob-demo/binary');

  try {
    await doc.set({
      'thumbnail': Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
      'empty': Uint8List(0),
    });

    final snapshot = await doc.get();
    final data = snapshot.data()!;

    print('> thumbnail bytes: ${data['thumbnail']}');
    print('> empty bytes:     ${data['empty']}\n');
  } catch (e) {
    print('> Error: $e');
  }
}

/// Example 3: Multi-database support
Future<void> multiDatabaseExample(FirebaseApp admin) async {
  print('### Multi-Database Examples ###\n');

  // Named database
  print('> Using named database "my-database"...\n');
  final namedFirestore = admin.firestore(databaseId: 'my-database');

  try {
    final collection = namedFirestore.collection('products');
    await collection.doc('product-1').set({
      'name': 'Widget',
      'price': 19.99,
      'inStock': true,
    });
    print('> Document written to named database\n');

    final doc = await collection.doc('product-1').get();
    if (doc.exists) {
      print('> Retrieved from named database: ${doc.data()}');
    }
  } catch (e) {
    print('> Error with named database: $e');
  }

  // Multiple databases simultaneously
  print('\n> Demonstrating multiple database access...\n');
  try {
    final defaultDb = admin.firestore();
    final analyticsDb = admin.firestore(databaseId: 'analytics-db');

    await defaultDb.collection('users').doc('user-1').set({
      'name': 'Alice',
      'email': 'alice@example.com',
    });

    await analyticsDb.collection('events').doc('event-1').set({
      'type': 'page_view',
      'timestamp': DateTime.now().toIso8601String(),
      'userId': 'user-1',
    });

    print('> Successfully wrote to multiple databases');
  } catch (e) {
    print('> Error with multiple databases: $e');
  }
  print('');
}

/// BulkWriter examples demonstrating common patterns
Future<void> bulkWriterExamples(FirebaseApp admin) async {
  print('### BulkWriter Examples ###\n');

  final firestore = admin.firestore();

  await bulkWriterBasicExample(firestore);
  await bulkWriterErrorHandlingExample(firestore);
}

/// Basic BulkWriter usage
Future<void> bulkWriterBasicExample(Firestore firestore) async {
  print('> Basic BulkWriter usage...\n');

  try {
    final bulkWriter = firestore.bulkWriter();

    // Queue multiple write operations (don't await individual operations)
    for (var i = 0; i < 10; i++) {
      unawaited(
        bulkWriter.set(firestore.collection('bulk-demo').doc('item-$i'), {
          'name': 'Item $i',
          'index': i,
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );
    }

    await bulkWriter.close();
    print('> Successfully wrote 10 documents in bulk\n');
  } catch (e) {
    print('> Error: $e');
  }
}

/// BulkWriter with error handling and retry logic
Future<void> bulkWriterErrorHandlingExample(Firestore firestore) async {
  print('> BulkWriter with error handling and retry logic...\n');

  try {
    final bulkWriter = firestore.bulkWriter();

    var successCount = 0;
    var errorCount = 0;

    bulkWriter.onWriteResult((ref, result) {
      successCount++;
      print('  ✓ Success: ${ref.path} at ${result.writeTime}');
    });

    bulkWriter.onWriteError((error) {
      errorCount++;
      print('  ✗ Error: ${error.documentRef.path} - ${error.message}');

      // Retry on transient errors, but not more than 3 times
      if (error.failedAttempts < 3 &&
          (error.code.name == 'unavailable' || error.code.name == 'aborted')) {
        print('    → Retrying (attempt ${error.failedAttempts + 1})...');
        return true;
      }
      return false;
    });

    // Mix of operations (queue them, don't await)
    // Use set() instead of create() to make example idempotent
    unawaited(
      bulkWriter.set(firestore.collection('orders').doc('order-1'), {
        'status': 'pending',
        'total': 99.99,
      }),
    );

    unawaited(
      bulkWriter.set(firestore.collection('orders').doc('order-2'), {
        'status': 'completed',
        'total': 149.99,
      }),
    );

    final orderRef = firestore.collection('orders').doc('order-3');
    await orderRef.set({'status': 'processing'});

    unawaited(
      bulkWriter.update(orderRef, {
        FieldPath(const ['status']): 'shipped',
        FieldPath(const ['shippedAt']): DateTime.now().toIso8601String(),
      }),
    );

    unawaited(
      bulkWriter.delete(firestore.collection('orders').doc('order-to-delete')),
    );

    await bulkWriter.close();

    print('\n> BulkWriter completed:');
    print('  - Successful writes: $successCount');
    print('  - Failed writes: $errorCount\n');
  } catch (e) {
    print('> Error: $e');
  }
}

/// BundleBuilder example demonstrating data bundle creation
Future<void> bundleBuilderExample(FirebaseApp admin) async {
  print('### BundleBuilder Example ###\n');

  final firestore = admin.firestore();

  try {
    print('> Creating a data bundle...\n');

    // Create a bundle
    final bundle = firestore.bundle('example-bundle');

    // Create and add some sample documents
    final collection = firestore.collection('bundle-demo');

    // Add individual documents
    await collection.doc('user-1').set({
      'name': 'Alice Smith',
      'role': 'admin',
      'lastLogin': DateTime.now().toIso8601String(),
    });

    await collection.doc('user-2').set({
      'name': 'Bob Johnson',
      'role': 'user',
      'lastLogin': DateTime.now().toIso8601String(),
    });

    await collection.doc('user-3').set({
      'name': 'Charlie Brown',
      'role': 'user',
      'lastLogin': DateTime.now().toIso8601String(),
    });

    // Get snapshots and add to bundle
    final doc1 = await collection.doc('user-1').get();
    final doc2 = await collection.doc('user-2').get();
    final doc3 = await collection.doc('user-3').get();

    bundle.addDocument(doc1);
    bundle.addDocument(doc2);
    bundle.addDocument(doc3);

    print('  ✓ Added 3 documents to bundle');

    // Add a query to the bundle
    final query = collection.where('role', WhereFilter.equal, 'user');
    final querySnapshot = await query.get();

    bundle.addQuery('regular-users', querySnapshot);

    print('  ✓ Added query "regular-users" to bundle');

    // Build the bundle
    final bundleData = bundle.build();

    print('\n> Bundle created successfully!');
    print('  - Bundle size: ${bundleData.length} bytes');
    print('  - Contains: 3 documents + 1 named query');
    print('\n  You can now:');
    print('  - Serve this bundle via CDN');
    print('  - Save to a file for static hosting');
    print('  - Send to clients for offline-first apps');
    print('  - Cache and reuse across multiple client sessions\n');

    // Example: Save to file (commented out)
    // import 'dart:io';
    // await File('bundle.txt').writeAsBytes(bundleData);

    // Clean up
    await collection.doc('user-1').delete();
    await collection.doc('user-2').delete();
    await collection.doc('user-3').delete();
  } catch (e) {
    print('> Error creating bundle: $e');
  }
}

/// WriteBatch example
Future<void> batchExample(FirebaseApp admin) async {
  print('### WriteBatch Example ###\n');

  final firestore = admin.firestore();

  // Simulate an order placement: atomically create the order, record it on
  // the user's profile, and decrement the product's stock — all in one batch
  // so either every write succeeds or none of them do.
  try {
    print('> Setting up initial product and user documents...\n');

    final productRef = firestore.collection('products').doc('widget-42');
    final userRef = firestore.collection('users').doc('user-1');

    await productRef.set({'name': 'Widget', 'stock': 10});
    await userRef.set({'name': 'Alice', 'orderCount': 2});

    print('> Placing order atomically with batch...\n');

    final batch = firestore.batch();
    final orderRef = firestore.collection('orders').doc();

    // 1. Create the new order document.
    batch.set(orderRef, {
      'userId': 'user-1',
      'productId': 'widget-42',
      'quantity': 1,
      'status': 'confirmed',
    });

    // 2. Increment the user's order count.
    batch.update(userRef, {
      FieldPath(const ['orderCount']): 3,
    });

    // 3. Decrement the product stock.
    batch.update(productRef, {
      FieldPath(const ['stock']): 9,
    });

    await batch.commit();
    print('> Batch committed successfully\n');

    // Clean up
    await Future.wait([
      orderRef.delete(),
      productRef.delete(),
      userRef.delete(),
    ]);
  } catch (e) {
    print('> Error: $e');
  }
}

/// runTransaction example
Future<void> transactionExample(FirebaseApp admin) async {
  print('### runTransaction Example ###\n');

  final firestore = admin.firestore();

  try {
    print('> Running a transaction...\n');

    final docRef = firestore.collection('counters').doc('visits');
    await docRef.set({'count': 0});

    await firestore.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = (snapshot.data()?['count'] as int?) ?? 0;
      transaction.update(docRef, {
        FieldPath(const ['count']): current + 1,
      });
    });

    final updated = await docRef.get();
    print('> Counter after transaction: ${updated.data()?['count']}\n');

    // Clean up
    await docRef.delete();
  } catch (e) {
    print('> Error: $e');
  }
}

/// collectionGroup example
Future<void> collectionGroupExample(FirebaseApp admin) async {
  print('### collectionGroup Example ###\n');

  final firestore = admin.firestore();

  final review1 = firestore
      .collection('restaurants')
      .doc('pizza-place')
      .collection('reviews')
      .doc('review-1');

  final review2 = firestore
      .collection('restaurants')
      .doc('burger-joint')
      .collection('reviews')
      .doc('review-2');

  try {
    print('> Querying all "reviews" subcollections across documents...\n');

    // Set up sample data
    await review1.set({'rating': 5, 'text': 'Great pizza!'});
    await review2.set({'rating': 4, 'text': 'Good burgers'});

    final query = firestore.collectionGroup('reviews');
    final snapshot = await query.get();

    print('Found ${snapshot.docs.length} review(s) across all restaurants:');
    for (final doc in snapshot.docs) {
      print('  - ${doc.ref.path}: rating=${doc.data()['rating']}');
    }
    print('');
  } catch (e) {
    print('> Error: $e');
  } finally {
    // Clean up sample data regardless of success or failure
    await Future.wait([review1.delete(), review2.delete()]);
  }
}

/// getAll example
Future<void> getAllExample(FirebaseApp admin) async {
  print('### getAll Example ###\n');

  final firestore = admin.firestore();

  try {
    print('> Fetching multiple documents in one request...\n');

    final col = firestore.collection('getall-demo');
    await col.doc('a').set({'value': 1});
    await col.doc('b').set({'value': 2});

    final refs = [col.doc('a'), col.doc('b'), col.doc('missing')];
    final snapshots = await firestore.getAll(refs);

    for (final snap in snapshots) {
      if (snap.exists) {
        print('  ${snap.ref.id}: ${snap.data()}');
      } else {
        print('  ${snap.ref.id}: does not exist');
      }
    }
    print('');

    // Clean up
    await col.doc('a').delete();
    await col.doc('b').delete();
  } catch (e) {
    print('> Error: $e');
  }
}

/// listCollections example
Future<void> listCollectionsExample(FirebaseApp admin) async {
  print('### listCollections Example ###\n');

  final firestore = admin.firestore();

  try {
    print('> Listing root-level collections...\n');

    final collections = await firestore.listCollections();
    print('Found ${collections.length} collection(s):');
    for (final col in collections) {
      print('  - ${col.id}');
    }
    print('');
  } catch (e) {
    print('> Error: $e');
  }
}

/// recursiveDelete example
Future<void> recursiveDeleteExample(FirebaseApp admin) async {
  print('### recursiveDelete Example ###\n');

  final firestore = admin.firestore();

  try {
    print('> Setting up nested data to delete...\n');

    final parent = firestore.collection('recursive-demo').doc('parent');
    await parent.set({'name': 'parent'});
    await parent.collection('children').doc('child-1').set({'name': 'child 1'});
    await parent.collection('children').doc('child-2').set({'name': 'child 2'});

    print('> Recursively deleting document and all subcollections...\n');
    await firestore.recursiveDelete(parent);
    print('Recursive delete complete\n');
  } catch (e) {
    print('> Error: $e');
  }
}
