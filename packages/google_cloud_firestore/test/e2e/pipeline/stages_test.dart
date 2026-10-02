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

import 'dart:math' as math;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// The titles of the three seeded books, in book order.
const _allTitles = ['Dart Pipelines', 'Firestore Admin', 'Inactive Draft'];

/// The data of every result [pipeline] produces, in order.
Future<List<DocumentData>> _dataOf(Pipeline pipeline) async {
  final snapshot = await pipeline.execute();
  return [for (final result in snapshot.results) result.data()];
}

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
      expect(snapshot.results.last.get('title'), 'Firestore Admin');
    });

    test('select takes field names, fields and aliased expressions', () async {
      final data = await _dataOf(
        ctx.book1Pipeline().select([
          'title',
          'price',
          Expression.field('rating'),
          Expression.field('discount').as('markdown'),
        ]),
      );

      // Only the selected fields remain.
      expect(data, [
        {'title': 'Dart Pipelines', 'price': 10, 'rating': 5, 'markdown': 2},
      ]);
    });

    test('an alias names the field its expression lands on', () async {
      final aliased = Expression.field('price').as('cost');

      expect(aliased.name, 'cost');
      expect(aliased.expression, isA<PipelineField>());
      expect((aliased.expression as PipelineField).path, 'price');
      expect(await _dataOf(ctx.book1Pipeline().select([aliased])), [
        {'cost': 10},
      ]);
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

    test('removeFields drops fields named by string or field', () async {
      final data = await _dataOf(
        ctx.book1Pipeline().removeFields([Expression.field('price'), 'rating']),
      );

      expect(data, hasLength(1));
      // Every other seeded field is still there.
      expect(
        data.single.keys,
        unorderedEquals(
          ctx.seed[0].keys.where((key) => key != 'price' && key != 'rating'),
        ),
      );
      expect(data.single['title'], 'Dart Pipelines');
    });

    test('sort applies its orderings in sequence', () async {
      // active descending puts the two active books first (false sorts before
      // true); price descending then orders those two.
      expect(
        await ctx.titlesOf(
          ctx.runPipeline().sort([
            descending(Expression.field('active')),
            descending('price'),
          ]),
        ),
        ['Firestore Admin', 'Dart Pipelines', 'Inactive Draft'],
      );

      // half is 2.5 on every book, so score descending decides the order.
      expect(
        await ctx.titlesOf(
          ctx.runPipeline().sort([
            ascending('half'),
            Expression.field('score').descending(),
          ]),
        ),
        ['Inactive Draft', 'Firestore Admin', 'Dart Pipelines'],
      );

      // flags: book 1 = 6, book 2 = 3, book 3 = 5.
      expect(
        await ctx.titlesOf(
          ctx.runPipeline().sort([ascending(Expression.field('flags'))]),
        ),
        ['Firestore Admin', 'Inactive Draft', 'Dart Pipelines'],
      );
    });

    test('offset skips sorted inputs before limit', () async {
      final sorted = ctx.runPipeline().sort([
        Expression.field('price').ascending(),
      ]);

      expect(await ctx.titlesOf(sorted.offset(1)), [
        'Firestore Admin',
        'Inactive Draft',
      ]);
      expect(await ctx.titlesOf(sorted.offset(1).limit(1)), [
        'Firestore Admin',
      ]);
      expect(await ctx.titlesOf(sorted.offset(3)), isEmpty);
    });

    test('distinct returns each unique combination of groups', () async {
      expect(
        await _dataOf(
          ctx
              .runPipeline()
              .distinct([
                'active',
                Expression.field('metadata').mapGetLiteral('lang').as('lang'),
              ])
              .sort([ascending('active')]),
        ),
        [
          {'active': false, 'lang': 'dart'},
          {'active': true, 'lang': 'dart'},
        ],
      );
    });

    test('unnest by field name replaces the array with each element', () async {
      expect(
        await _dataOf(
          ctx.book1Pipeline().unnest('tags').select(['title', 'tags']).sort([
            ascending('tags'),
          ]),
        ),
        [
          {'title': 'Dart Pipelines', 'tags': 'dart'},
          {'title': 'Dart Pipelines', 'tags': 'firebase'},
        ],
      );
    });

    test('unnest an aliased field keeps the source array', () async {
      expect(
        await _dataOf(
          ctx
              .book1Pipeline()
              .unnest(Expression.field('scores').as('element'))
              .select(['scores', 'element'])
              .sort([ascending('element')]),
        ),
        [
          {
            'scores': [1.5, 2.5, -0.5],
            'element': -0.5,
          },
          {
            'scores': [1.5, 2.5, -0.5],
            'element': 1.5,
          },
          {
            'scores': [1.5, 2.5, -0.5],
            'element': 2.5,
          },
        ],
      );
    });

    test('unnest with an index field numbers each element', () async {
      // tags: book 1 = [dart, firebase], book 2 = [firebase], book 3 = [draft].
      expect(
        await _dataOf(
          ctx
              .runPipeline()
              .unnest(
                Expression.field('tags').as('tag'),
                indexField: 'tagIndex',
              )
              .select(['title', 'tag', 'tagIndex'])
              .sort([ascending('tag'), ascending('tagIndex')]),
        ),
        [
          {'title': 'Dart Pipelines', 'tag': 'dart', 'tagIndex': 0},
          {'title': 'Inactive Draft', 'tag': 'draft', 'tagIndex': 0},
          {'title': 'Firestore Admin', 'tag': 'firebase', 'tagIndex': 0},
          {'title': 'Dart Pipelines', 'tag': 'firebase', 'tagIndex': 1},
        ],
      );
    });

    test('replaceWith a field name promotes that map', () async {
      expect(await _dataOf(ctx.book1Pipeline().replaceWith('metadata')), [
        {'lang': 'dart', 'category': 'sdk'},
      ]);
    });

    test('replaceWith an expression uses the map it evaluates to', () async {
      expect(
        await _dataOf(
          ctx.book1Pipeline().replaceWith(Expression.field('stats')),
        ),
        [
          {'views': 100, 'likes': 7},
        ],
      );
      expect(
        await _dataOf(
          ctx.book1Pipeline().replaceWith(
            PipelineFunctions.map([
              'name',
              Expression.field('title'),
              'answer',
              42,
            ]),
          ),
        ),
        [
          {'name': 'Dart Pipelines', 'answer': 42},
        ],
      );
    });

    test('union appends the other pipeline, keeping duplicates', () async {
      expect(
        await ctx.titlesOf(
          ctx
              .book1Pipeline()
              .union(ctx.runPipeline())
              .sort([ascending('price')])
              .select(['title']),
        ),
        [
          'Dart Pipelines',
          'Dart Pipelines',
          'Firestore Admin',
          'Inactive Draft',
        ],
      );
    });

    test('sample by document count returns that many inputs', () async {
      final titles = await ctx.titlesOf(ctx.runPipeline().sample(documents: 2));

      expect(titles, hasLength(2));
      expect(titles.toSet(), hasLength(2));
      expect(titles, everyElement(isIn(_allTitles)));
    });

    test('sample by percentage returns a subset of the inputs', () async {
      final titles = await ctx.titlesOf(
        ctx.runPipeline().sample(percentage: 0.5),
      );

      // Each input is kept at random, so only the bounds are deterministic.
      expect(titles.length, lessThanOrEqualTo(3));
      expect(titles.toSet(), hasLength(titles.length));
      expect(titles, everyElement(isIn(_allTitles)));
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
      // Book 1's embedding is the query vector itself.
      expect(
        vectorSnapshot.results.single.get('distance'),
        isNumber(0, tolerance: 1e-9),
      );
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

    // The query vector [3, 2, 1] ranks the books 1, 2, 3 under every measure:
    // euclidean distances 3, sqrt(11), sqrt(13); dot products 3, 2, 1; cosine
    // distances 1 - 3/sqrt(14), 1 - 2/sqrt(14), 1 - 1/sqrt(14).

    test('findNearest by euclidean distance, without a limit', () async {
      final snapshot = await ctx
          .runPipeline()
          .findNearest(
            vectorField: Expression.field('embedding'),
            queryVector: const [3.0, 2.0, 1.0],
            distanceMeasure: DistanceMeasure.euclidean,
            distanceResultField: 'distance',
          )
          .execute();

      expect([
        for (final result in snapshot.results) result.get('title'),
      ], _allTitles);
      expect(
        [for (final result in snapshot.results) result.get('distance')],
        [isNumber(3), isNumber(math.sqrt(11)), isNumber(math.sqrt(13))],
      );
    });

    test('findNearest by dot product returns the largest first', () async {
      final snapshot = await ctx
          .runPipeline()
          .findNearest(
            vectorField: 'embedding',
            queryVector: Expression.vector([3, 2, 1]),
            distanceMeasure: DistanceMeasure.dotProduct,
            limit: 2,
            distanceResultField: 'similarity',
          )
          .execute();

      expect(
        [for (final result in snapshot.results) result.get('title')],
        ['Dart Pipelines', 'Firestore Admin'],
      );
      expect(
        [for (final result in snapshot.results) result.get('similarity')],
        [isNumber(3), isNumber(2)],
      );
    });

    test('findNearest by cosine distance', () async {
      final snapshot = await ctx
          .runPipeline()
          .findNearest(
            vectorField: 'embedding',
            queryVector: const [3.0, 2.0, 1.0],
            distanceMeasure: DistanceMeasure.cosine,
            limit: 3,
            distanceResultField: 'distance',
          )
          .execute();

      expect([
        for (final result in snapshot.results) result.get('title'),
      ], _allTitles);
      expect(
        [for (final result in snapshot.results) result.get('distance')],
        [
          isNumber(1 - 3 / math.sqrt(14)),
          isNumber(1 - 2 / math.sqrt(14)),
          isNumber(1 - 1 / math.sqrt(14)),
        ],
      );
    });

    test('findNearest drops inputs beyond the distance threshold', () async {
      // Euclidean distances 3 and sqrt(11) ~ 3.317 are within 3.5;
      // sqrt(13) ~ 3.606 is not.
      expect(
        await ctx.titlesOf(
          ctx.runPipeline().findNearest(
            vectorField: 'embedding',
            queryVector: const [3.0, 2.0, 1.0],
            distanceMeasure: DistanceMeasure.euclidean,
            limit: 3,
            distanceThreshold: 3.5,
          ),
        ),
        ['Dart Pipelines', 'Firestore Admin'],
      );
    });

    test('rawStage sends stages by their backend name', () async {
      // price > 15 keeps books 2 and 3; descending price puts book 3 first,
      // and the offset skips it.
      expect(
        await ctx.titlesOf(
          ctx
              .runPipeline()
              .rawStage('where', [Expression.field('price').greaterThan(15)])
              .rawStage('sort', [
                {
                  'direction': 'descending',
                  'expression': Expression.field('price'),
                },
              ])
              .rawStage('offset', [1])
              .rawStage('limit', [1]),
        ),
        ['Firestore Admin'],
      );
    });

    test('rawStage select takes a map of expressions', () async {
      expect(
        await _dataOf(
          ctx.book1Pipeline().rawStage('select', [
            {
              'name': Expression.field('title'),
              'cost': Expression.field('price'),
            },
          ]),
        ),
        [
          {'name': 'Dart Pipelines', 'cost': 10},
        ],
      );
    });

    test('rawStage passes stage options', () async {
      final data = await _dataOf(
        ctx
            .runPipeline()
            .rawStage(
              'find_nearest',
              [
                Expression.field('embedding'),
                FieldValue.vector([3, 2, 1]),
                'euclidean',
              ],
              options: {
                'distance_field': Expression.field('distance'),
                'limit': 2,
              },
            )
            .select(['title', 'distance']),
      );

      expect(data, [
        {'title': 'Dart Pipelines', 'distance': isNumber(3)},
        {'title': 'Firestore Admin', 'distance': isNumber(math.sqrt(11))},
      ]);
    });
  });
}
