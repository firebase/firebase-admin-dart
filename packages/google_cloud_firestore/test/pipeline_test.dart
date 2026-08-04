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

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:google_cloud_firestore/src/firestore_http_client.dart';
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:google_cloud_firestore_v1/testing.dart';
import 'package:google_cloud_protobuf/protobuf.dart' as protobuf_v1;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart' hide greaterThan, lessThan;

const _projectId = 'test-project';

class MockFirestoreHttpClient extends Mock implements FirestoreHttpClient {}

void main() {
  group('Firestore Pipeline', () {
    late MockFirestoreHttpClient mockClient;
    late Firestore firestore;

    setUp(() {
      mockClient = MockFirestoreHttpClient();
      firestore = Firestore.internal(
        settings: const Settings(
          projectId: _projectId,
          databaseId: 'enterprise',
        ),
        client: mockClient,
      );

      when(() => mockClient.cachedProjectId).thenReturn(_projectId);
    });

    test('serializes common stages and expressions', () async {
      firestore_v1.ExecutePipelineRequest? capturedRequest;

      when(
        () =>
            mockClient.v1<Stream<firestore_v1.ExecutePipelineResponse>>(any()),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.positionalArguments.single
                as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                Function(firestore_v1.Firestore api, String projectId);

        final api = FakeFirestore(
          executePipeline: (firestore_v1.ExecutePipelineRequest request) {
            capturedRequest = request;
            return const Stream<firestore_v1.ExecutePipelineResponse>.empty();
          },
        );

        return callback(api, _projectId);
      });

      await firestore
          .pipeline()
          .collection('cities')
          .where(
            and([
              greaterThan('population', 100000),
              lessThan('population', 1000000),
            ]),
          )
          .sort([field('name').ascending()])
          .select(['name', field('population')])
          .limit(10)
          .execute();

      final request = capturedRequest!;
      expect(request.database, 'projects/$_projectId/databases/enterprise');

      final stages = request.structuredPipeline!.pipeline!.stages;
      expect(stages.map((stage) => stage.name), [
        'collection',
        'where',
        'sort',
        'select',
        'limit',
      ]);

      expect(stages[0].args.single.referenceValue, '/cities');

      final whereFunction = stages[1].args.single.functionValue!;
      expect(whereFunction.name, 'and');
      expect(whereFunction.args[0].functionValue!.name, 'greater_than');
      expect(
        whereFunction.args[0].functionValue!.args[0].fieldReferenceValue,
        'population',
      );
      expect(whereFunction.args[0].functionValue!.args[1].integerValue, 100000);
      expect(whereFunction.args[1].functionValue!.name, 'less_than');
      expect(
        whereFunction.args[1].functionValue!.args[0].fieldReferenceValue,
        'population',
      );
      expect(
        whereFunction.args[1].functionValue!.args[1].integerValue,
        1000000,
      );

      final sortValue = stages[2].args.single.mapValue!;
      expect(sortValue.fields['direction']!.stringValue, 'ascending');
      expect(sortValue.fields['expression']!.fieldReferenceValue, 'name');

      final selectFields = stages[3].args.single.mapValue!.fields;
      expect(selectFields['name']!.fieldReferenceValue, 'name');
      expect(selectFields['population']!.fieldReferenceValue, 'population');
      expect(stages[4].args.single.integerValue, 10);
    });

    test('executes and decodes results', () async {
      final executionTime = protobuf_v1.Timestamp(seconds: 42);

      when(
        () =>
            mockClient.v1<Stream<firestore_v1.ExecutePipelineResponse>>(any()),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.positionalArguments.single
                as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                Function(firestore_v1.Firestore api, String projectId);

        final api = FakeFirestore(
          executePipeline: (_) {
            return Stream.fromIterable([
              firestore_v1.ExecutePipelineResponse(
                executionTime: executionTime,
                results: [
                  firestore_v1.Document(
                    name:
                        'projects/$_projectId/databases/enterprise/documents/books/book-1',
                    fields: {
                      'title': firestore.serializer.encodeValue('Dart')!,
                      'price': firestore.serializer.encodeValue(12.5)!,
                    },
                    createTime: executionTime,
                    updateTime: executionTime,
                  ),
                ],
              ),
            ]);
          },
        );

        return callback(api, _projectId);
      });

      final snapshot = await firestore.pipeline().collection('books').execute();

      expect(snapshot.size, 1);
      expect(snapshot.empty, isFalse);
      expect(snapshot.executionTime, Timestamp(seconds: 42, nanoseconds: 0));
      expect(snapshot.results.single.name, contains('/books/book-1'));
      expect(snapshot.results.single.document, firestore.doc('books/book-1'));
      expect(
        snapshot.results.single.createTime,
        Timestamp(seconds: 42, nanoseconds: 0),
      );
      expect(
        snapshot.results.single.updateTime,
        Timestamp(seconds: 42, nanoseconds: 0),
      );
      expect(snapshot.results.single.data(), {'title': 'Dart', 'price': 12.5});
      expect(snapshot.results.single.get('title'), 'Dart');
      expect(snapshot.result, snapshot.results);
    });

    test('supports documents source and raw stages', () async {
      firestore_v1.ExecutePipelineRequest? capturedRequest;

      when(
        () =>
            mockClient.v1<Stream<firestore_v1.ExecutePipelineResponse>>(any()),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.positionalArguments.single
                as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                Function(firestore_v1.Firestore api, String projectId);

        final api = FakeFirestore(
          executePipeline: (firestore_v1.ExecutePipelineRequest request) {
            capturedRequest = request;
            return const Stream<firestore_v1.ExecutePipelineResponse>.empty();
          },
        );

        return callback(api, _projectId);
      });

      await firestore
          .pipeline()
          .documents([firestore.doc('books/book-1')])
          .rawStage('sample', [1], options: {'stable': true})
          .execute();

      final stages = capturedRequest!.structuredPipeline!.pipeline!.stages;
      expect(stages.first.name, 'documents');
      expect(
        stages.first.args.single.referenceValue,
        'projects/$_projectId/databases/enterprise/documents/books/book-1',
      );
      expect(stages.last.name, 'sample');
      expect(stages.last.args.single.integerValue, 1);
      expect(stages.last.options['stable']!.booleanValue, isTrue);
    });

    test('serializes catalog function helpers', () async {
      firestore_v1.ExecutePipelineRequest? capturedRequest;

      when(
        () =>
            mockClient.v1<Stream<firestore_v1.ExecutePipelineResponse>>(any()),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.positionalArguments.single
                as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                Function(firestore_v1.Firestore api, String projectId);

        final api = FakeFirestore(
          executePipeline: (firestore_v1.ExecutePipelineRequest request) {
            capturedRequest = request;
            return const Stream<firestore_v1.ExecutePipelineResponse>.empty();
          },
        );

        return callback(api, _projectId);
      });

      await firestore
          .pipeline()
          .collection('books')
          .select([
            PipelineFunctions.regexMatch(
              field('title'),
              r'^Dart',
            ).alias('isDart'),
            PipelineFunctions.timestampToUnixMillis(
              field('publishedAt'),
            ).alias('publishedMillis'),
            PipelineFunctions.cosineDistance(
              field('embedding'),
              FieldValue.vector([1, 2, 3]),
            ).alias('distance'),
          ])
          .where(
            PipelineFunctions.and([
              PipelineFunctions.arrayContains(field('tags'), 'programming'),
              PipelineFunctions.isType(field('price'), 'number'),
            ]),
          )
          .execute();

      final stages = capturedRequest!.structuredPipeline!.pipeline!.stages;
      final selectedFunctions = stages[1].args.single.mapValue!.fields;
      expect(selectedFunctions['isDart']!.functionValue!.name, 'regex_match');
      expect(
        selectedFunctions['publishedMillis']!.functionValue!.name,
        'timestamp_to_unix_millis',
      );
      expect(
        selectedFunctions['distance']!.functionValue!.name,
        'cosine_distance',
      );

      final whereFunction = stages[2].args.single.functionValue!;
      expect(whereFunction.name, 'and');
      expect(whereFunction.args[0].functionValue!.name, 'array_contains');
      expect(whereFunction.args[1].functionValue!.name, 'is_type');
    });

    test('serializes FlutterFire-style expression and stage APIs', () async {
      firestore_v1.ExecutePipelineRequest? capturedRequest;

      when(
        () =>
            mockClient.v1<Stream<firestore_v1.ExecutePipelineResponse>>(any()),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.positionalArguments.single
                as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                Function(firestore_v1.Firestore api, String projectId);

        final api = FakeFirestore(
          executePipeline: (firestore_v1.ExecutePipelineRequest request) {
            capturedRequest = request;
            return const Stream<firestore_v1.ExecutePipelineResponse>.empty();
          },
        );

        return callback(api, _projectId);
      });

      final secondary = firestore.pipeline().collection('archivedBooks').select(
        ['title'],
      );

      await firestore
          .pipeline()
          .collectionReference(firestore.collection('books'))
          .where(Expression.field('rating').greaterThanOrEqualValue(4))
          .aggregate(
            [Expression.field('price').average().as('avgPrice')],
            groups: ['genre'],
          )
          .distinct(['genre'])
          .unnest(Expression.field('tags'), indexField: 'tagIndex')
          .replaceWith(Expression.field('summary'))
          .union(secondary)
          .sample(documents: 5)
          .findNearest(
            vectorField: 'embedding',
            queryVector: FieldValue.vector([1, 2, 3]),
            distanceMeasure: DistanceMeasure.cosine,
            limit: 3,
            distanceResultField: 'distance',
          )
          .search({'query': Expression.constant('dart')})
          .execute();

      final stages = capturedRequest!.structuredPipeline!.pipeline!.stages;
      expect(stages.map((stage) => stage.name), [
        'collection',
        'where',
        'aggregate',
        'distinct',
        'unnest',
        'replace_with',
        'union',
        'sample',
        'find_nearest',
        'search',
      ]);

      expect(stages[0].args.single.referenceValue, '/books');
      expect(
        stages[1].args.single.functionValue!.name,
        'greater_than_or_equal',
      );

      expect(
        stages[2].args.first.mapValue!.fields['avgPrice']!.functionValue!.name,
        'average',
      );
      expect(
        stages[2].args[1].mapValue!.fields['genre']!.fieldReferenceValue,
        'genre',
      );

      expect(stages[3].args.single.fieldReferenceValue, 'genre');
      expect(stages[4].args.single.fieldReferenceValue, 'tags');
      expect(stages[4].options['index_field']!.stringValue, 'tagIndex');
      expect(stages[5].args.single.fieldReferenceValue, 'summary');
      expect(
        stages[6].args.single.pipelineValue!.stages.first.name,
        'collection',
      );
      expect(stages[7].options['documents']!.integerValue, 5);
      expect(stages[8].args.first.fieldReferenceValue, 'embedding');
      expect(stages[8].args[2].stringValue, 'cosine');
      expect(stages[8].options['limit']!.integerValue, 3);
      expect(
        stages[8].options['distance_field']!.fieldReferenceValue,
        'distance',
      );
      expect(stages[9].options['query']!.stringValue, 'dart');
    });

    test(
      'serializes complete FlutterFire-style fluent expression surface',
      () async {
        firestore_v1.ExecutePipelineRequest? capturedRequest;

        when(
          () => mockClient.v1<Stream<firestore_v1.ExecutePipelineResponse>>(
            any(),
          ),
        ).thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments.single
                  as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                  Function(firestore_v1.Firestore api, String projectId);

          final api = FakeFirestore(
            executePipeline: (firestore_v1.ExecutePipelineRequest request) {
              capturedRequest = request;
              return const Stream<firestore_v1.ExecutePipelineResponse>.empty();
            },
          );

          return callback(api, _projectId);
        });

        await firestore
            .pipeline()
            .collection('books')
            .where(Expression.field('published').asBoolean())
            .select([
              Expression.field('tags').arrayLastIndexOf('dart').as('lastIndex'),
              Expression.field('path').parent().as('parent'),
              Expression.field('path').referenceSlice(0, 2).as('slice'),
              Expression.field('metadata').mapKeys().as('keys'),
              Expression.field('metadata').mapValues().as('values'),
              Expression.field('metadata').mapRemove(['draft']).as('removed'),
              Expression.field('metadata')
                  .mapMerge([
                    {'lang': 'dart'},
                  ])
                  .as('merged'),
              Expression.field('title').regexFind(r'Dart').as('regexFind'),
              Expression.field(
                'title',
              ).regexFindAll(r'Dart').as('regexFindAll'),
              Expression.field('title').stringContains('art').as('contains'),
              Expression.field(
                'createdAt',
              ).timestampTrunc('day', 'UTC').as('createdDay'),
              Expression.field(
                'createdAt',
              ).timestampAdd('day', 1).as('createdPlusOne'),
              Expression.field(
                'createdAt',
              ).timestampSubtract('hour', 2).as('createdMinusTwo'),
              Expression.field(
                'createdAt',
              ).timestampToUnixMicros().as('createdMicros'),
              Expression.field(
                'createdAt',
              ).timestampToUnixMillis().as('createdMillis'),
              Expression.field(
                'createdAt',
              ).timestampToUnixSeconds().as('createdSeconds'),
              Expression.field('updatedAt')
                  .timestampDiff(Expression.field('createdAt'), 'second')
                  .as('ageSeconds'),
              Expression.field('createdAt').timestampExtract('year').as('year'),
              Expression.field(
                'embedding',
              ).cosineDistance(Expression.vector([1, 2, 3])).as('cosine'),
              Expression.field(
                'embedding',
              ).dotProduct(Expression.vector([1, 2, 3])).as('dot'),
              Expression.field(
                'embedding',
              ).euclideanDistance(Expression.vector([1, 2, 3])).as('euclidean'),
              Expression.field('embedding').vectorLength().as('vectorLength'),
              Expression.field(
                'price',
              ).isType(PipelineValueType.number).as('isNumber'),
            ])
            .execute();

        final stages = capturedRequest!.structuredPipeline!.pipeline!.stages;
        expect(stages[1].args.single.fieldReferenceValue, 'published');

        final functionNames = [
          for (final arg in stages[2].args.single.mapValue!.fields.values)
            arg.functionValue!.name,
        ];

        expect(functionNames, [
          'array_index_of',
          'parent',
          'reference_slice',
          'map_keys',
          'map_values',
          'map_remove',
          'map_merge',
          'regex_find',
          'regex_find_all',
          'string_contains',
          'timestamp_trunc',
          'timestamp_add',
          'timestamp_subtract',
          'timestamp_to_unix_micros',
          'timestamp_to_unix_millis',
          'timestamp_to_unix_seconds',
          'timestamp_diff',
          'timestamp_extract',
          'cosine_distance',
          'dot_product',
          'euclidean_distance',
          'vector_length',
          'is_type',
        ]);

        final isTypeFunction =
            stages[2].args.single.mapValue!.fields['isNumber']!.functionValue!;
        expect(isTypeFunction.args.last.stringValue, 'number');
      },
    );

    group('String arguments in a field position', () {
      late List<firestore_v1.Pipeline_Stage> stages;

      Future<void> run(Pipeline pipeline) async {
        firestore_v1.ExecutePipelineRequest? capturedRequest;

        when(
          () => mockClient.v1<Stream<firestore_v1.ExecutePipelineResponse>>(
            any(),
          ),
        ).thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments.single
                  as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                  Function(firestore_v1.Firestore api, String projectId);

          final api = FakeFirestore(
            executePipeline: (firestore_v1.ExecutePipelineRequest request) {
              capturedRequest = request;
              return const Stream<firestore_v1.ExecutePipelineResponse>.empty();
            },
          );

          return callback(api, _projectId);
        });

        await pipeline.execute();
        stages = capturedRequest!.structuredPipeline!.pipeline!.stages;
      }

      test('encode as field references, not string literals', () async {
        await run(
          firestore
              .pipeline()
              .collection('books')
              .where(PipelineFunctions.startsWith('title', 'Harry')),
        );

        final function = stages[1].args.single.functionValue!;
        expect(function.name, 'starts_with');
        // Regression: 'title' used to encode as the literal text "title", so
        // the filter compared "title" against "Harry" instead of reading the
        // `title` field.
        expect(function.args[0].fieldReferenceValue, 'title');
        expect(function.args[0].stringValue, isNull);
        // The value position keeps strings as literals.
        expect(function.args[1].stringValue, 'Harry');
        expect(function.args[1].fieldReferenceValue, isNull);
      });

      test('apply across the function catalog', () async {
        await run(
          firestore.pipeline().collection('books').select([
            PipelineFunctions.equal('title', 'Harry').alias('isHarry'),
            PipelineFunctions.lessThan('price', 10).alias('isCheap'),
            PipelineFunctions.arrayContains('tags', 'dart').alias('isDart'),
            PipelineFunctions.mapGet('metadata', 'lang').alias('lang'),
            PipelineFunctions.toUpper('title').alias('upper'),
            PipelineFunctions.sum('price').alias('total'),
            PipelineFunctions.arrayLength('tags').alias('tagCount'),
            PipelineFunctions.timestampToUnixMillis('createdAt').alias('ms'),
            PipelineFunctions.vectorLength('embedding').alias('dims'),
            PipelineFunctions.exists('title').alias('hasTitle'),
          ]),
        );

        final fields = stages[1].args.single.mapValue!.fields;
        for (final entry in fields.entries) {
          expect(
            entry.value.functionValue!.args.first.fieldReferenceValue,
            isNotNull,
            reason: '${entry.key} should reference a field',
          );
        }

        expect(
          fields['isHarry']!.functionValue!.args[1].stringValue,
          'Harry',
          reason: 'the value position stays a literal',
        );
        expect(fields['lang']!.functionValue!.args[1].stringValue, 'lang');
      });

      test('leave value positions and variadic tails alone', () async {
        await run(
          firestore.pipeline().collection('books').select([
            // Only the first entry is a field position.
            PipelineFunctions.stringConcat([
              'title',
              ' by ',
              'Anon',
            ]).alias('byline'),
            PipelineFunctions.array(['a', 'b']).alias('letters'),
            // A document path is a value, matching the Node SDK.
            PipelineFunctions.documentId('books/book-1').alias('id'),
          ]),
        );

        final fields = stages[1].args.single.mapValue!.fields;

        final concat = fields['byline']!.functionValue!;
        expect(concat.args[0].fieldReferenceValue, 'title');
        expect(concat.args[1].stringValue, ' by ');
        expect(concat.args[2].stringValue, 'Anon');

        final letters = fields['letters']!.functionValue!;
        expect(letters.args.map((arg) => arg.stringValue), ['a', 'b']);

        expect(
          fields['id']!.functionValue!.args.single.stringValue,
          'books/book-1',
        );
      });
    });

    test('serializes newly added expressions', () async {
      firestore_v1.ExecutePipelineRequest? capturedRequest;

      when(
        () =>
            mockClient.v1<Stream<firestore_v1.ExecutePipelineResponse>>(any()),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.positionalArguments.single
                as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                Function(firestore_v1.Firestore api, String projectId);

        final api = FakeFirestore(
          executePipeline: (firestore_v1.ExecutePipelineRequest request) {
            capturedRequest = request;
            return const Stream<firestore_v1.ExecutePipelineResponse>.empty();
          },
        );

        return callback(api, _projectId);
      });

      await firestore
          .pipeline()
          .collection('books')
          .where(documentMatches('dart'))
          .select([
            PipelineFunctions.coalesce(
              'nickname',
              field('title'),
            ).alias('name'),
            PipelineFunctions.length('tags').alias('size'),
            PipelineFunctions.reverse('tags').alias('reversed'),
            PipelineFunctions.concat('tags', ['extra']).alias('joined'),
            PipelineFunctions.getField('metadata', 'lang').alias('lang'),
            PipelineFunctions.geoDistance(
              'location',
              GeoPoint(latitude: 1, longitude: 2),
            ).alias('distance'),
            score().alias('relevance'),
            field('title').charLength().alias('titleChars'),
            field('rating').logicalMaximum(0).alias('clampedRating'),
          ])
          .execute();

      final stages = capturedRequest!.structuredPipeline!.pipeline!.stages;
      expect(stages[1].args.single.functionValue!.name, 'document_matches');

      final fields = stages[2].args.single.mapValue!.fields;
      expect(fields['name']!.functionValue!.name, 'coalesce');
      expect(fields['size']!.functionValue!.name, 'length');
      expect(fields['reversed']!.functionValue!.name, 'reverse');
      expect(fields['joined']!.functionValue!.name, 'concat');
      expect(fields['lang']!.functionValue!.name, 'get_field');
      expect(fields['distance']!.functionValue!.name, 'geo_distance');
      expect(fields['relevance']!.functionValue!.name, 'score');
      expect(fields['relevance']!.functionValue!.args, isEmpty);
      // `length` is the generic sized-value function; `char_length` stays
      // string-specific.
      expect(fields['titleChars']!.functionValue!.name, 'char_length');
      expect(fields['clampedRating']!.functionValue!.name, 'maximum');
    });

    group('createFrom', () {
      late List<firestore_v1.Pipeline_Stage> stages;

      Future<void> run(Object query) async {
        firestore_v1.ExecutePipelineRequest? capturedRequest;

        when(
          () => mockClient.v1<Stream<firestore_v1.ExecutePipelineResponse>>(
            any(),
          ),
        ).thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments.single
                  as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                  Function(firestore_v1.Firestore api, String projectId);

          final api = FakeFirestore(
            executePipeline: (firestore_v1.ExecutePipelineRequest request) {
              capturedRequest = request;
              return const Stream<firestore_v1.ExecutePipelineResponse>.empty();
            },
          );

          return callback(api, _projectId);
        });

        await firestore.pipeline().createFrom(query).execute();
        stages = capturedRequest!.structuredPipeline!.pipeline!.stages;
      }

      test('converts filters into where stages', () async {
        await run(
          firestore
              .collection('books')
              .where('genre', WhereFilter.equal, 'fiction')
              .where('rating', WhereFilter.greaterThan, 4),
        );

        expect(stages.map((stage) => stage.name), [
          'collection',
          'where', // genre == fiction
          'where', // rating > 4
          'where', // implicit existence checks
          'sort',
        ]);
        expect(stages[0].args.single.referenceValue, '/books');

        // Each field filter is paired with an existence check so that the
        // Pipeline matches Query semantics for missing fields.
        final genre = stages[1].args.single.functionValue!;
        expect(genre.name, 'and');
        expect(genre.args[0].functionValue!.name, 'exists');
        expect(genre.args[1].functionValue!.name, 'equal');
        expect(
          genre.args[1].functionValue!.args[0].fieldReferenceValue,
          'genre',
        );
        expect(genre.args[1].functionValue!.args[1].stringValue, 'fiction');

        expect(
          stages[2].args.single.functionValue!.args[1].functionValue!.name,
          'greater_than',
        );
      });

      test('orders by the inequality field then the document key', () async {
        await run(
          firestore
              .collection('books')
              .where('rating', WhereFilter.greaterThan, 4),
        );

        final orderings = stages.last.args
            .map(
              (arg) => arg.mapValue!.fields['expression']!.fieldReferenceValue,
            )
            .toList();
        expect(orderings, ['rating', '__name__']);
      });

      test('keeps the document key ordering for key inequalities', () async {
        await run(
          firestore
              .collection('books')
              .where(
                FieldPath.documentId,
                WhereFilter.greaterThan,
                firestore.doc('books/book-1'),
              ),
        );

        final orderings = stages.last.args
            .map(
              (arg) => arg.mapValue!.fields['expression']!.fieldReferenceValue,
            )
            .toList();
        // The key must still be ordered exactly once, not dropped.
        expect(orderings, ['__name__']);
      });

      test('converts composite filters', () async {
        await run(
          firestore
              .collection('books')
              .whereFilter(
                Filter.or([
                  Filter.where('genre', WhereFilter.equal, 'fiction'),
                  Filter.where('genre', WhereFilter.equal, 'poetry'),
                ]),
              ),
        );

        final composite = stages[1].args.single.functionValue!;
        expect(composite.name, 'or');
        expect(composite.args, hasLength(2));
        for (final arg in composite.args) {
          expect(arg.functionValue!.name, 'and');
          expect(arg.functionValue!.args[1].functionValue!.name, 'equal');
        }
      });

      test('unpacks isIn filters into equal_any', () async {
        await run(
          firestore.collection('books').where('genre', WhereFilter.isIn, [
            'fiction',
            'poetry',
          ]),
        );

        final equalAny =
            stages[1].args.single.functionValue!.args[1].functionValue!;
        expect(equalAny.name, 'equal_any');
        expect(equalAny.args[1].arrayValue!.values.map((v) => v.stringValue), [
          'fiction',
          'poetry',
        ]);
      });

      test('omits the existence check for notIn filters', () async {
        await run(
          firestore.collection('books').where('genre', WhereFilter.notIn, [
            'fiction',
          ]),
        );

        // notIn matches absent fields on Enterprise, so it must not be paired
        // with `exists`.
        final filter = stages[1].args.single.functionValue!;
        expect(filter.name, 'not_equal_any');
      });

      test('converts a field mask into a select stage', () async {
        await run(
          firestore.collection('books').select([
            FieldPath(const ['title']),
            FieldPath(const ['rating']),
          ]),
        );

        expect(stages.map((stage) => stage.name), [
          'collection',
          'select',
          'where',
          'sort',
        ]);

        final selected = stages[1].args.single.mapValue!.fields;
        expect(selected.keys, ['title', 'rating']);
        expect(selected['title']!.fieldReferenceValue, 'title');
      });

      test('converts collection group queries', () async {
        await run(firestore.collectionGroup('books'));

        expect(stages.first.name, 'collection_group');
        expect(stages.first.args.single.stringValue, 'books');
      });

      test('converts orderBy, limit and offset', () async {
        await run(
          firestore
              .collection('books')
              .orderBy('rating', descending: true)
              .limit(5)
              .offset(2),
        );

        expect(stages.map((stage) => stage.name), [
          'collection',
          'where',
          'sort',
          'limit',
          'offset',
        ]);

        final orderings = stages[2].args;
        expect(
          orderings[0].mapValue!.fields['direction']!.stringValue,
          'descending',
        );
        expect(
          orderings[0].mapValue!.fields['expression']!.fieldReferenceValue,
          'rating',
        );
        // The document key inherits the last explicit direction.
        expect(
          orderings[1].mapValue!.fields['direction']!.stringValue,
          'descending',
        );
        expect(stages[3].args.single.integerValue, 5);
        expect(stages[4].args.single.integerValue, 2);
      });

      test('converts cursors into where stages', () async {
        await run(
          firestore
              .collection('books')
              .orderBy('rating')
              .startAt([4])
              .endBefore([5]),
        );

        expect(stages.map((stage) => stage.name), [
          'collection',
          'where', // existence checks
          'sort',
          'where', // startAt
          'where', // endBefore
        ]);

        // startAt is inclusive, so it admits values equal to the cursor.
        final startAt = stages[3].args.single.functionValue!;
        expect(startAt.name, 'or');
        expect(startAt.args[0].functionValue!.name, 'greater_than');
        expect(startAt.args[1].functionValue!.name, 'equal');

        // endBefore is exclusive.
        final endBefore = stages[4].args.single.functionValue!;
        expect(endBefore.name, 'less_than');
      });

      test('sorts twice for limitToLast queries', () async {
        await run(
          firestore.collection('books').orderBy('rating').limitToLast(3),
        );

        expect(stages.map((stage) => stage.name), [
          'collection',
          'where',
          'sort', // reversed, so the last N documents come first
          'limit',
          'sort', // restores the requested order
        ]);

        expect(
          stages[2].args.first.mapValue!.fields['direction']!.stringValue,
          'descending',
        );
        expect(
          stages[4].args.first.mapValue!.fields['direction']!.stringValue,
          'ascending',
        );
      });

      test('converts a VectorQuery into a find_nearest stage', () async {
        await run(
          firestore
              .collection('books')
              .findNearest(
                vectorField: 'embedding',
                queryVector: [1.0, 2.0, 3.0],
                limit: 5,
                distanceMeasure: DistanceMeasure.cosine,
                distanceResultField: 'distance',
              ),
        );

        expect(stages.map((stage) => stage.name), [
          'collection',
          'where', // existence checks
          'sort',
          'where', // embedding exists
          'find_nearest',
        ]);

        final findNearest = stages.last;
        expect(findNearest.args[0].fieldReferenceValue, 'embedding');
        // Pipelines take a lowercase distance measure even though the
        // DistanceMeasure enum keeps the uppercase proto values.
        expect(findNearest.args[2].stringValue, 'cosine');
        expect(findNearest.options['limit']!.integerValue, 5);
        expect(
          findNearest.options['distance_field']!.fieldReferenceValue,
          'distance',
        );
      });

      test('rejects a query from a different database', () {
        final other = Firestore.internal(
          settings: const Settings(
            projectId: _projectId,
            databaseId: 'other-db',
          ),
          client: MockFirestoreHttpClient(),
        );

        expect(
          () => firestore.pipeline().createFrom(other.collection('books')),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('does not match the target database'),
            ),
          ),
        );
      });

      test('rejects values that are not queries', () {
        expect(
          () => firestore.pipeline().createFrom('books'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
