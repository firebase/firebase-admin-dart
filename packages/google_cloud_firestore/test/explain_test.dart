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

@Tags(['prod'])
library;

import 'dart:async';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

/// Production-only tests for Query explain() API.
///
/// The Firestore emulator does not support the explain API, so these tests
/// require a real GCP project with GOOGLE_APPLICATION_CREDENTIALS set.
void main() {
  group('Query explain() [Production]', () {
    late Firestore firestore;
    final collectionsToCleanup = <String>[];

    setUp(() async {
      firestore = Firestore(
        settings: const Settings(projectId: 'dart-firebase-admin'),
      );
    });

    tearDown(() async {
      // Clean up all test collections
      for (final collectionId in collectionsToCleanup) {
        final collection = firestore.collection(collectionId);
        final docs = await collection.listDocuments();
        for (final doc in docs) {
          await doc.delete();
        }
      }
      collectionsToCleanup.clear();
    });

    test('can plan a query without executing', () async {
      await runZoned(() async {
        final collectionId =
            'explain-test-${DateTime.now().millisecondsSinceEpoch}';
        collectionsToCleanup.add(collectionId);
        final collection = firestore.collection(collectionId);

        await Future.wait([
          collection.add({'foo': 'bar', 'value': 1}),
          collection.add({'foo': 'bar', 'value': 2}),
          collection.add({'foo': 'baz', 'value': 3}),
        ]);

        final query = collection.where('foo', WhereFilter.equal, 'bar');
        final explainResults = await query.explain(
          const ExplainOptions(analyze: false),
        );

        // Should have metrics
        expect(explainResults.metrics, isNotNull);
        expect(explainResults.metrics.planSummary, isNotNull);
        expect(
          explainResults.metrics.planSummary.indexesUsed,
          isA<List<Map<String, Object?>>>(),
        );

        // Should NOT have execution stats or snapshot
        expect(explainResults.metrics.executionStats, isNull);
        expect(explainResults.snapshot, isNull);
      }, zoneValues: {envSymbol: <String, String>{}});
    });

    test('can execute and explain a query', () async {
      await runZoned(() async {
        final collectionId =
            'explain-execute-test-${DateTime.now().millisecondsSinceEpoch}';
        collectionsToCleanup.add(collectionId);
        final collection = firestore.collection(collectionId);

        await Future.wait([
          collection.add({'foo': 'bar', 'value': 1}),
          collection.add({'foo': 'bar', 'value': 2}),
          collection.add({'foo': 'baz', 'value': 3}),
        ]);

        final query = collection.where('foo', WhereFilter.equal, 'bar');
        final explainResults = await query.explain(
          const ExplainOptions(analyze: true),
        );

        // Should have metrics
        expect(explainResults.metrics, isNotNull);
        expect(explainResults.metrics.planSummary, isNotNull);

        // Should have execution stats
        expect(explainResults.metrics.executionStats, isNotNull);
        expect(explainResults.metrics.executionStats!.resultsReturned, 2);
        expect(
          explainResults.metrics.executionStats!.readOperations,
          greaterThan(0),
        );
        expect(
          explainResults.metrics.executionStats!.executionDuration,
          isNotEmpty,
        );
        expect(
          explainResults.metrics.executionStats!.debugStats,
          isA<Map<String, Object?>>(),
        );

        // Should have snapshot with results
        expect(explainResults.snapshot, isNotNull);
        expect(explainResults.snapshot!.docs.length, 2);
        expect(explainResults.snapshot!.docs[0].get('foo')?.value, 'bar');
      }, zoneValues: {envSymbol: <String, String>{}});
    });

    test('explain works with vector queries', () async {
      await runZoned(() async {
        // Use fixed collection name for production (requires pre-configured index)
        // Index can be created with:
        // gcloud firestore indexes composite create --project=dart-firebase-admin \
        //   --collection-group=vector-explain-test-prod --query-scope=COLLECTION \
        //   --field-config=vector-config='{"dimension":"3","flat": "{}"}',field-path=embedding
        collectionsToCleanup.add('vector-explain-test-prod');
        final collection = firestore.collection('vector-explain-test-prod');

        await Future.wait([
          collection.add({
            'embedding': FieldValue.vector([1.0, 2.0, 3.0]),
            'name': 'doc1',
          }),
          collection.add({
            'embedding': FieldValue.vector([4.0, 5.0, 6.0]),
            'name': 'doc2',
          }),
        ]);

        final vectorQuery = collection.findNearest(
          vectorField: 'embedding',
          queryVector: [1.0, 2.0, 3.0],
          limit: 2,
          distanceMeasure: DistanceMeasure.euclidean,
        );

        final explainResults = await vectorQuery.explain(
          const ExplainOptions(analyze: true),
        );

        expect(explainResults.metrics, isNotNull);
        expect(explainResults.metrics.planSummary, isNotNull);
        expect(explainResults.metrics.executionStats, isNotNull);
        expect(explainResults.snapshot, isNotNull);
        expect(explainResults.snapshot!.docs.length, 2);
      }, zoneValues: {envSymbol: <String, String>{}});
    });

    test('explain works with orderBy and limit', () async {
      await runZoned(() async {
        final collectionId =
            'ordered-explain-test-${DateTime.now().millisecondsSinceEpoch}';
        collectionsToCleanup.add(collectionId);
        final collection = firestore.collection(collectionId);

        await Future.wait([
          collection.add({'value': 3}),
          collection.add({'value': 1}),
          collection.add({'value': 2}),
        ]);

        final query = collection.orderBy('value').limit(2);
        final explainResults = await query.explain(
          const ExplainOptions(analyze: true),
        );

        expect(explainResults.metrics, isNotNull);
        expect(explainResults.snapshot, isNotNull);
        expect(explainResults.snapshot!.docs.length, 2);
        expect(explainResults.snapshot!.docs[0].get('value')?.value, 1);
        expect(explainResults.snapshot!.docs[1].get('value')?.value, 2);
      }, zoneValues: {envSymbol: <String, String>{}});
    });

    test('explain without options defaults to planning only', () async {
      await runZoned(() async {
        final collectionId =
            'explain-default-test-${DateTime.now().millisecondsSinceEpoch}';
        collectionsToCleanup.add(collectionId);
        final collection = firestore.collection(collectionId);

        await collection.add({'foo': 'bar'});

        final query = collection.where('foo', WhereFilter.equal, 'bar');
        final explainResults = await query.explain();

        // Should have metrics with plan summary
        expect(explainResults.metrics, isNotNull);
        expect(explainResults.metrics.planSummary, isNotNull);

        // Should NOT have execution stats or snapshot (defaults to analyze: false)
        expect(explainResults.metrics.executionStats, isNull);
        expect(explainResults.snapshot, isNull);
      }, zoneValues: {envSymbol: <String, String>{}});
    });
  });

  group('AggregateQuery explain() [Production]', () {
    late Firestore firestore;
    final collectionsToCleanup = <String>[];

    setUp(() async {
      firestore = Firestore(
        settings: const Settings(projectId: 'dart-firebase-admin'),
      );
    });

    tearDown(() async {
      for (final collectionId in collectionsToCleanup) {
        final collection = firestore.collection(collectionId);
        final docs = await collection.listDocuments();
        for (final doc in docs) {
          await doc.delete();
        }
      }
      collectionsToCleanup.clear();
    });

    test('can plan aggregate query without execution', () async {
      await runZoned(() async {
        final collectionId =
            'agg-explain-test-${DateTime.now().millisecondsSinceEpoch}';
        collectionsToCleanup.add(collectionId);
        final collection = firestore.collection(collectionId);

        final aggregateQuery = collection
            .where('age', WhereFilter.greaterThan, 20)
            .count();

        final result = await aggregateQuery.explain(const ExplainOptions());

        expect(result.metrics, isNotNull);
        expect(result.metrics.planSummary, isNotNull);
        expect(result.snapshot, isNull);
      }, zoneValues: {envSymbol: <String, String>{}});
    });

    test('can analyze aggregate query with execution', () async {
      await runZoned(() async {
        final collectionId =
            'agg-explain-test-${DateTime.now().millisecondsSinceEpoch}';
        collectionsToCleanup.add(collectionId);
        final collection = firestore.collection(collectionId);

        await Future.wait([
          collection.add({'name': 'Alice', 'age': 30}),
          collection.add({'name': 'Bob', 'age': 25}),
        ]);

        final aggregateQuery = collection.count();
        final result = await aggregateQuery.explain(
          const ExplainOptions(analyze: true),
        );

        expect(result.metrics, isNotNull);
        expect(result.metrics.planSummary, isNotNull);
        expect(result.metrics.executionStats, isNotNull);
        expect(result.snapshot, isNotNull);
        expect(result.snapshot!.count, 2);
      }, zoneValues: {envSymbol: <String, String>{}});
    });

    test('can analyze sum aggregation', () async {
      await runZoned(() async {
        final collectionId =
            'agg-explain-test-${DateTime.now().millisecondsSinceEpoch}';
        collectionsToCleanup.add(collectionId);
        final collection = firestore.collection(collectionId);

        await Future.wait([
          collection.add({'price': 10.5}),
          collection.add({'price': 20.0}),
        ]);

        final aggregateQuery = collection.sum('price');
        final result = await aggregateQuery.explain(
          const ExplainOptions(analyze: true),
        );

        expect(result.metrics, isNotNull);
        expect(result.snapshot, isNotNull);
        expect(result.snapshot!.getSum('price'), 30.5);
      }, zoneValues: {envSymbol: <String, String>{}});
    });

    test('can analyze average aggregation', () async {
      await runZoned(() async {
        final collectionId =
            'agg-explain-test-${DateTime.now().millisecondsSinceEpoch}';
        collectionsToCleanup.add(collectionId);
        final collection = firestore.collection(collectionId);

        await Future.wait([
          collection.add({'score': 80}),
          collection.add({'score': 90}),
          collection.add({'score': 100}),
        ]);

        final aggregateQuery = collection.average('score');
        final result = await aggregateQuery.explain(
          const ExplainOptions(analyze: true),
        );

        expect(result.metrics, isNotNull);
        expect(result.snapshot, isNotNull);
        expect(result.snapshot!.getAverage('score'), 90.0);
      }, zoneValues: {envSymbol: <String, String>{}});
    });

    test('can analyze multiple aggregations', () async {
      await runZoned(() async {
        final collectionId =
            'agg-explain-test-${DateTime.now().millisecondsSinceEpoch}';
        collectionsToCleanup.add(collectionId);
        final collection = firestore.collection(collectionId);

        await Future.wait([
          collection.add({'value': 10}),
          collection.add({'value': 20}),
          collection.add({'value': 30}),
        ]);

        final aggregateQuery = collection.aggregate(
          const count(),
          const sum('value'),
          const average('value'),
        );

        final result = await aggregateQuery.explain(
          const ExplainOptions(analyze: true),
        );

        expect(result.metrics, isNotNull);
        expect(result.snapshot, isNotNull);
        expect(result.snapshot!.count, 3);
        expect(result.snapshot!.getSum('value'), 60);
        expect(result.snapshot!.getAverage('value'), 20.0);
      }, zoneValues: {envSymbol: <String, String>{}});
    });

    test('explain without options defaults to planning only', () async {
      await runZoned(() async {
        final collectionId =
            'agg-explain-default-test-${DateTime.now().millisecondsSinceEpoch}';
        collectionsToCleanup.add(collectionId);
        final collection = firestore.collection(collectionId);

        await collection.add({'value': 10});

        final aggregateQuery = collection.count();
        final result = await aggregateQuery.explain();

        // Should have metrics with plan summary
        expect(result.metrics, isNotNull);
        expect(result.metrics.planSummary, isNotNull);

        // Should NOT have execution stats or snapshot (defaults to analyze: false)
        expect(result.metrics.executionStats, isNull);
        expect(result.snapshot, isNull);
      }, zoneValues: {envSymbol: <String, String>{}});
    });
  });
}
