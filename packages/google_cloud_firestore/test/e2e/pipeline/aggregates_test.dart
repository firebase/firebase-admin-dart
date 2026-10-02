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

    // Aggregated over the run's three books; see buildSeed in harness.dart.
    ctx.aggregateCases('count', [
      // count() with no argument counts every input, like countAll().
      AggregateCase('static, no argument', PipelineFunctions.count(), 3),
      AggregateCase('countAll', PipelineFunctions.countAll(), 3),
      // Only book 1 has `sparse`, and no book has `missing`.
      AggregateCase('static, field name', PipelineFunctions.count('sparse'), 1),
      AggregateCase(
        'static, expression',
        PipelineFunctions.count(Expression.field('missing')),
        0,
      ),
      AggregateCase('fluent', Expression.field('title').count(), 3),
    ]);

    ctx.aggregateCases('countIf', [
      AggregateCase(
        'static, expression',
        PipelineFunctions.countIf(Expression.field('active')),
        2,
      ),
      // A constant true condition holds for every input.
      AggregateCase('static, constant', PipelineFunctions.countIf(true), 3),
      // price > 15: books 2 and 3.
      AggregateCase(
        'fluent',
        Expression.field('price').greaterThan(15).countIf(),
        2,
      ),
    ]);

    ctx.aggregateCases('countDistinct', [
      // active: true, true, false.
      AggregateCase(
        'static, field name',
        PipelineFunctions.countDistinct('active'),
        2,
      ),
      // half is 2.5 on every book.
      AggregateCase(
        'static, expression',
        PipelineFunctions.countDistinct(Expression.field('half')),
        1,
      ),
      AggregateCase(
        'fluent',
        Expression.field('metadata').mapGetLiteral('lang').countDistinct(),
        1,
      ),
    ]);

    ctx.aggregateCases('sum', [
      // rating: 5 + 4 + 2.
      AggregateCase('static, field name', PipelineFunctions.sum('rating'), 11),
      // score: -12.7 + 3.2 + 8.9.
      AggregateCase(
        'static, expression',
        PipelineFunctions.sum(Expression.field('score')),
        isNumber(-0.6),
      ),
      AggregateCase('fluent', Expression.field('price').sum(), 60),
    ]);

    ctx.aggregateCases('average', [
      // price: (10 + 20 + 30) / 3.
      AggregateCase(
        'static, field name',
        PipelineFunctions.average('price'),
        isDouble(20),
      ),
      // ratio: (0.5 + 1.25 + 2.0) / 3.
      AggregateCase(
        'static, expression',
        PipelineFunctions.average(Expression.field('ratio')),
        isDouble(1.25),
      ),
      // rating: (5 + 4 + 2) / 3.
      AggregateCase(
        'fluent',
        Expression.field('rating').average(),
        isDouble(11 / 3),
      ),
    ]);

    ctx.aggregateCases('minimum', [
      AggregateCase(
        'static, field name',
        PipelineFunctions.minimum('score'),
        isDouble(-12.7),
      ),
      AggregateCase(
        'static, expression on timestamps',
        PipelineFunctions.minimum(Expression.field('createdAt')),
        Timestamp(seconds: 1700000000, nanoseconds: 0),
      ),
      AggregateCase('fluent', Expression.field('price').minimum(), 10),
    ]);

    ctx.aggregateCases('maximum', [
      AggregateCase(
        'static, field name',
        PipelineFunctions.maximum('rating'),
        5,
      ),
      AggregateCase(
        'static, expression on strings',
        PipelineFunctions.maximum(Expression.field('title')),
        'Inactive Draft',
      ),
      AggregateCase('fluent', Expression.field('price').maximum(), 30),
    ]);

    ctx.aggregateCases('arrayAggDistinct', [
      // The order of distinct values is unspecified.
      AggregateCase(
        'static, field name',
        PipelineFunctions.arrayAggDistinct('active'),
        unorderedEquals([true, false]),
      ),
      AggregateCase(
        'static, expression',
        PipelineFunctions.arrayAggDistinct(Expression.field('half')),
        [2.5],
      ),
      AggregateCase(
        'fluent',
        Expression.field('metadata').mapGetLiteral('lang').arrayAggDistinct(),
        ['dart'],
      ),
    ]);

    test('first, last and arrayAgg follow the input order', () async {
      final snapshot =
          await ctx.runPipeline().sort([ascending('price')]).aggregate([
            PipelineFunctions.first('title').as('firstTitle'),
            PipelineFunctions.first(Expression.field('price')).as('firstPrice'),
            Expression.field('rating').first().as('firstRating'),
            PipelineFunctions.last('title').as('lastTitle'),
            PipelineFunctions.last(Expression.field('price')).as('lastPrice'),
            Expression.field('rating').last().as('lastRating'),
            PipelineFunctions.arrayAgg('title').as('titles'),
            PipelineFunctions.arrayAgg(
              Expression.field('rating'),
            ).as('ratings'),
            Expression.field('price').arrayAgg().as('prices'),
          ]).execute();

      expect(snapshot.results.single.data(), {
        'firstTitle': 'Dart Pipelines',
        'firstPrice': 10,
        'firstRating': 5,
        'lastTitle': 'Inactive Draft',
        'lastPrice': 30,
        'lastRating': 2,
        'titles': ['Dart Pipelines', 'Firestore Admin', 'Inactive Draft'],
        'ratings': [5, 4, 2],
        'prices': [10, 20, 30],
      });
    });

    test('aggregates per group', () async {
      final snapshot = await ctx
          .runPipeline()
          .aggregate(
            [
              PipelineFunctions.countAll().as('books'),
              PipelineFunctions.sum('rating').as('totalRating'),
              PipelineFunctions.average('price').as('averagePrice'),
            ],
            groups: [
              'active',
              Expression.field('metadata').mapGetLiteral('lang').as('lang'),
            ],
          )
          .sort([ascending('active')])
          .execute();

      // Book 3 is inactive; books 1 and 2 are active.
      expect(
        [for (final result in snapshot.results) result.data()],
        [
          {
            'active': false,
            'lang': 'dart',
            'books': 1,
            'totalRating': 2,
            'averagePrice': isDouble(30),
          },
          {
            'active': true,
            'lang': 'dart',
            'books': 2,
            'totalRating': 9,
            'averagePrice': isDouble(15),
          },
        ],
      );
    });

    test('aggregates per group named by a FieldPath', () async {
      // A FieldPath names a group as a String does. Only book 3 is archived.
      final snapshot = await ctx
          .runPipeline()
          .aggregate(
            [PipelineFunctions.countAll().as('books')],
            groups: [
              FieldPath(const ['archived']),
            ],
          )
          .sort([ascending('archived')])
          .execute();

      expect(
        [for (final result in snapshot.results) result.data()],
        [
          {'archived': false, 'books': 2},
          {'archived': true, 'books': 1},
        ],
      );
    });
  });
}
