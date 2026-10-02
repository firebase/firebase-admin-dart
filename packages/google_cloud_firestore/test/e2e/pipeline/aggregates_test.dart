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

/// Live coverage of the aggregate functions and the `aggregate` stage.
@Tags(['prod'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  pipelineE2E('Pipeline aggregates', (ctx) {
    test('executes aggregate pipeline stages', () async {
      final aggregateSnapshot = await ctx.firestore
          .pipeline()
          .collection(ctx.collectionPath)
          .where(ctx.runFilter(Expression.field('active').equal(true)))
          .aggregate([
            Expression.field('price').sum().as('totalPrice'),
            Expression.field('rating').average().as('averageRating'),
            Expression.field('title').count().as('bookCount'),
          ])
          .execute();

      expect(aggregateSnapshot.results, hasLength(1));
      expect(aggregateSnapshot.results.single.get('totalPrice'), 30);
      expect(aggregateSnapshot.results.single.get('averageRating'), 4.5);
      expect(aggregateSnapshot.results.single.get('bookCount'), 2);
    });

    ctx.aggregateCases('aggregate functions', [
      AggregateCase('count', PipelineFunctions.count(), 3),
      AggregateCase(
        'countIf',
        PipelineFunctions.countIf(Expression.field('active')),
        2,
      ),
      AggregateCase(
        'countDistinct',
        Expression.field('metadata').mapGetLiteral('lang').countDistinct(),
        1,
      ),
      AggregateCase('sum', Expression.field('price').sum(), 60),
      AggregateCase(
        'average',
        Expression.field('rating').average(),
        closeTo(11 / 3, 0.0001),
      ),
      AggregateCase('minimum', Expression.field('price').minimum(), 10),
      AggregateCase('maximum', Expression.field('price').maximum(), 30),
      AggregateCase('first', Expression.field('title').first(), isA<String>()),
      AggregateCase('last', Expression.field('title').last(), isA<String>()),
      AggregateCase(
        'arrayAgg',
        Expression.field('title').arrayAgg(),
        containsAll(['Dart Pipelines', 'Firestore Admin', 'Inactive Draft']),
      ),
      AggregateCase(
        'arrayAggDistinct',
        Expression.field('metadata').mapGetLiteral('lang').arrayAggDistinct(),
        ['dart'],
      ),
    ]);
  });
}
