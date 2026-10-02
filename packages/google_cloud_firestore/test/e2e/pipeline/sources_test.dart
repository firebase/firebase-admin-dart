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

/// Live coverage of `Firestore.pipeline` and the `PipelineSource` stages.
@Tags(['prod'])
library;

import 'dart:math' as math;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// The IDs of the documents [query] returns, in order.
Future<List<String>> _queryIds(Query<DocumentData> query) async {
  final snapshot = await query.get();
  return [for (final doc in snapshot.docs) doc.id];
}

/// The IDs of the documents [vectorQuery] returns, in order.
Future<List<String>> _vectorQueryIds(
  VectorQuery<DocumentData> vectorQuery,
) async {
  final snapshot = await vectorQuery.get();
  return [for (final doc in snapshot.docs) doc.id];
}

/// The IDs of the documents [pipeline] returns, in order.
Future<List<String?>> _pipelineIds(Pipeline pipeline) async {
  final snapshot = await pipeline.execute();
  return [for (final result in snapshot.results) result.id];
}

void main() {
  pipelineE2E('Pipeline sources', (ctx) {
    final book1 = ctx.book1Ref.id;
    final book2 = ctx.book2Ref.id;
    final book3 = ctx.book3Ref.id;

    /// A Query over this run's three documents.
    Query<DocumentData> runQuery() {
      return ctx.firestore
          .collection(ctx.collectionPath)
          .where('runId', WhereFilter.equal, ctx.runId);
    }

    /// [runQuery], as a vector query from [3, 2, 1] on `embedding`.
    ///
    /// The query vector ranks the books 1, 2, 3 under every measure:
    /// euclidean distances 3, sqrt(11) ~ 3.317 and sqrt(13) ~ 3.606; cosine
    /// distances 1 - 3/sqrt(14) ~ 0.198, 1 - 2/sqrt(14) ~ 0.465 and
    /// 1 - 1/sqrt(14) ~ 0.733; dot products 3, 2 and 1.
    VectorQuery<DocumentData> runVectorQuery(
      DistanceMeasure distanceMeasure, {
      double? distanceThreshold,
      String? distanceResultField,
    }) {
      return runQuery().findNearest(
        vectorField: 'embedding',
        queryVector: const <double>[3, 2, 1],
        limit: 3,
        distanceMeasure: distanceMeasure,
        distanceThreshold: distanceThreshold,
        distanceResultField: distanceResultField,
      );
    }

    test('executes a documents source stage', () async {
      final snapshot = await ctx.firestore
          .pipeline()
          .documents([ctx.book1Ref, ctx.book3Ref])
          .sort([Expression.field('price').ascending()])
          .select([Expression.field('title')])
          .execute();

      expect(snapshot.results.map((result) => result.get('title')), [
        'Dart Pipelines',
        'Inactive Draft',
      ]);
    });

    test('documents takes document paths and references', () async {
      // A path is read like Firestore.doc reads it, ignoring a leading slash.
      expect(
        await ctx.titlesOf(
          ctx.firestore
              .pipeline()
              .documents([
                ctx.book1Ref.path,
                '/${ctx.book2Ref.path}',
                ctx.book3Ref,
              ])
              .sort([ascending('price')])
              .select(['title']),
        ),
        ['Dart Pipelines', 'Firestore Admin', 'Inactive Draft'],
      );
    });

    test('executes a collection group source stage', () async {
      final snapshot = await ctx.firestore
          .pipeline()
          .collectionGroup(ctx.collectionPath)
          .where(ctx.runFilter(Expression.field('active').equal(true)))
          .sort([Expression.field('price').ascending()])
          .select([Expression.field('title')])
          .execute();

      expect(snapshot.results.map((result) => result.get('title')), [
        'Dart Pipelines',
        'Firestore Admin',
      ]);
    });

    test('collectionReference starts from that collection', () async {
      expect(
        await ctx.titlesOf(
          ctx.firestore
              .pipeline()
              .collectionReference(ctx.firestore.collection(ctx.collectionPath))
              .where(ctx.runFilter())
              .sort([ascending('price')])
              .select(['title']),
        ),
        ['Dart Pipelines', 'Firestore Admin', 'Inactive Draft'],
      );
    });

    test('database starts from every document', () async {
      // The database source cannot be filtered before its first stage, so the
      // run filter comes straight after it.
      expect(
        await ctx.titlesOf(
          ctx.firestore
              .pipeline()
              .database()
              .where(ctx.runFilter())
              .sort([ascending('price')])
              .select(['title']),
        ),
        ['Dart Pipelines', 'Firestore Admin', 'Inactive Draft'],
      );
    });

    test('executes a pipeline created from a query', () async {
      // Translates the filter, the descending order and the limit.
      expect(
        await ctx.titlesOf(
          ctx.firestore.pipeline().createFrom(
            ctx.firestore
                .collection(ctx.collectionPath)
                .where('runId', WhereFilter.equal, ctx.runId)
                .orderBy('price', descending: true)
                .limit(2),
          ),
        ),
        ['Inactive Draft', 'Firestore Admin'],
      );
    });

    test('executes a pipeline created from a vector query', () async {
      // Euclidean distances from [3, 2, 1]: book 1 = 3, book 2 = sqrt(11),
      // book 3 = sqrt(13).
      expect(
        await ctx.titlesOf(
          ctx.firestore.pipeline().createFrom(
            ctx.firestore
                .collection(ctx.collectionPath)
                .where('runId', WhereFilter.equal, ctx.runId)
                .findNearest(
                  vectorField: 'embedding',
                  queryVector: const <double>[3, 2, 1],
                  limit: 2,
                  distanceMeasure: DistanceMeasure.euclidean,
                ),
          ),
        ),
        ['Dart Pipelines', 'Firestore Admin'],
      );
    });

    test('executes a pipeline created from a collection group query', () async {
      final snapshot = await ctx.firestore
          .pipeline()
          .createFrom(
            ctx.firestore
                .collectionGroup(ctx.collectionPath)
                .where('runId', WhereFilter.equal, ctx.runId)
                .where('active', WhereFilter.equal, true)
                .orderBy('price'),
          )
          .execute();

      expect(snapshot.results.map((result) => result.get('title')), [
        'Dart Pipelines',
        'Firestore Admin',
      ]);
    });

    // != and not-in are inequalities, so createFrom sorts by the filtered
    // field, then by the document key, as a Standard database orders the
    // Query. Ratings are 5, 4 and 2: excluding 4 leaves book 3, then book 1.
    //
    // Only the documents the Query returns are compared, not their order: the
    // Node SDK's system tests skip the != comparison on Enterprise databases,
    // whose implicit Query order is not settled.
    for (final (name, filter) in [
      (
        '!=',
        (Query<DocumentData> query) =>
            query.where('rating', WhereFilter.notEqual, 4),
      ),
      (
        'not-in',
        (Query<DocumentData> query) =>
            query.where('rating', WhereFilter.notIn, [4]),
      ),
    ]) {
      test('createFrom orders a $name query by its field first', () async {
        final query = filter(runQuery());

        expect(await _pipelineIds(ctx.firestore.pipeline().createFrom(query)), [
          book3,
          book1,
        ]);
        expect(await _queryIds(query), unorderedEquals([book3, book1]));
      });
    }

    // A cursor is a position in the query's order: on a descending rating
    // (5, 4, 2), startAt(4) keeps 4 and below.
    for (final (name, cursor, expected) in [
      (
        'startAt',
        (Query<DocumentData> query) => query.startAt([4]),
        [book2, book3],
      ),
      (
        'startAfter',
        (Query<DocumentData> query) => query.startAfter([4]),
        [book3],
      ),
      (
        'endBefore',
        (Query<DocumentData> query) => query.endBefore([2]),
        [book1, book2],
      ),
      (
        'endAt with limitToLast',
        (Query<DocumentData> query) => query.endAt([4]).limitToLast(1),
        [book2],
      ),
    ]) {
      test('createFrom keeps the $name side of a descending cursor', () async {
        final query = cursor(runQuery().orderBy('rating', descending: true));

        expect(await _queryIds(query), expected);
        expect(
          await _pipelineIds(ctx.firestore.pipeline().createFrom(query)),
          expected,
        );
      });
    }

    test(
      'a DocumentSnapshot cursor on a != query orders by that field',
      () async {
        // The cursor orders by rating, then the document key, so starting at
        // book 3 (rating 2) keeps book 3, then book 1 (rating 5). Ordering by
        // the document key alone would keep book 3 only.
        final query = runQuery()
            .where('rating', WhereFilter.notEqual, 4)
            .startAtDocument(await ctx.book3Ref.get());

        expect(await _queryIds(query), [book3, book1]);
        expect(await _pipelineIds(ctx.firestore.pipeline().createFrom(query)), [
          book3,
          book1,
        ]);
      },
    );

    // Each threshold keeps books 1 and 2 and drops book 3: at most 3.5 for
    // euclidean, at most 0.5 for cosine, at least 1.5 for dot product.
    for (final (distanceMeasure, distanceThreshold) in [
      (DistanceMeasure.euclidean, 3.5),
      (DistanceMeasure.cosine, 0.5),
      (DistanceMeasure.dotProduct, 1.5),
    ]) {
      test(
        'createFrom keeps a ${distanceMeasure.name} distance threshold',
        () async {
          final vectorQuery = runVectorQuery(
            distanceMeasure,
            distanceThreshold: distanceThreshold,
          );

          expect(await _vectorQueryIds(vectorQuery), [book1, book2]);
          expect(
            await _pipelineIds(
              ctx.firestore.pipeline().createFrom(vectorQuery),
            ),
            [book1, book2],
          );
        },
      );
    }

    test(
      'createFrom filters a distance threshold on its result field',
      () async {
        final vectorQuery = runVectorQuery(
          DistanceMeasure.euclidean,
          distanceThreshold: 3.5,
          distanceResultField: 'distance',
        );

        final querySnapshot = await vectorQuery.get();
        final pipelineSnapshot = await ctx.firestore
            .pipeline()
            .createFrom(vectorQuery)
            .execute();

        // Each result carries its euclidean distance in the result field.
        final distances = [isNumber(3), isNumber(math.sqrt(11))];
        expect([for (final doc in querySnapshot.docs) doc.id], [book1, book2]);
        expect([
          for (final doc in querySnapshot.docs) doc.data()['distance'],
        ], distances);
        expect(
          [for (final result in pipelineSnapshot.results) result.id],
          [book1, book2],
        );
        expect([
          for (final result in pipelineSnapshot.results) result.get('distance'),
        ], distances);
      },
    );
  });
}
