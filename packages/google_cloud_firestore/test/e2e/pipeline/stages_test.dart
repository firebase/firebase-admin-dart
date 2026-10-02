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

/// Live coverage of the `Pipeline` stage methods, orderings and aliases.
@Tags(['prod'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  pipelineE2E('Pipeline stages', (ctx) {
    test('where, sort, select and limit', () async {
      final snapshot = await ctx.firestore
          .pipeline()
          .collection(ctx.collectionPath)
          .where(ctx.runFilter(Expression.field('active').asBoolean()))
          .sort([Expression.field('price').ascending()])
          .select([
            Expression.field('title'),
            Expression.field('price'),
            Expression.field('title').toUpperCase().as('upperTitle'),
            Expression.field('tags').arrayLength().as('tagCount'),
            Expression.field(
              'metadata',
            ).mapGetLiteral('category').as('category'),
            Expression.field(
              'createdAt',
            ).timestampToUnixSeconds().as('createdSeconds'),
          ])
          .limit(2)
          .execute();

      expect(snapshot.results, hasLength(2));
      expect(snapshot.executionTime, isNotNull);
      expect(snapshot.results.first.get('title'), 'Dart Pipelines');
      expect(snapshot.results.first.get('price'), 10);
      expect(snapshot.results.first.get('upperTitle'), 'DART PIPELINES');
      expect(snapshot.results.first.get('tagCount'), 2);
      expect(snapshot.results.first.get('category'), 'sdk');
    });

    test('executes an addFields stage', () async {
      final snapshot = await ctx.book1Pipeline().addFields([
        Expression.field('rating').as('copiedRating'),
        Expression.constant(true).as('annotated'),
      ]).execute();

      expect(snapshot.results, hasLength(1));
      final result = snapshot.results.single;
      expect(result.get('copiedRating'), 5);
      expect(result.get('annotated'), true);
      // Existing fields are kept alongside the added ones.
      expect(result.get('title'), 'Dart Pipelines');

      // A single field must still be sent as a map, not an alias function.
      final single = await ctx.book1Pipeline().addFields([
        Expression.field('title').toUpperCase().as('upper'),
      ]).execute();

      expect(single.results.single.get('upper'), 'DART PIPELINES');
    });

    test('executes vector nearest-neighbor stage', () async {
      final vectorSnapshot = await ctx
          .runPipeline()
          .findNearest(
            vectorField: 'embedding',
            queryVector: Expression.vector([1, 0, 0]),
            distanceMeasure: DistanceMeasure.cosine,
            limit: 1,
            distanceResultField: 'distance',
          )
          .execute();

      expect(vectorSnapshot.results, hasLength(1));
      expect(vectorSnapshot.results.single.get('title'), 'Dart Pipelines');
      expect(vectorSnapshot.results.single.get('distance'), isNotNull);
    });

    test('executes vector nearest-neighbor stage with a list', () async {
      final vectorSnapshot = await ctx
          .runPipeline()
          .findNearest(
            vectorField: 'embedding',
            queryVector: const [1.0, 0.0, 0.0],
            distanceMeasure: DistanceMeasure.cosine,
            limit: 1,
            distanceResultField: 'distance',
          )
          .execute();

      expect(vectorSnapshot.results, hasLength(1));
      expect(vectorSnapshot.results.single.get('title'), 'Dart Pipelines');
    });
  });
}
