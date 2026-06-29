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
  });
}
