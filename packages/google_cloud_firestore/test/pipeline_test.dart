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

import 'dart:typed_data';

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
    });

    test('data() is unmodifiable and empty rather than null', () async {
      when(
        () =>
            mockClient.v1<Stream<firestore_v1.ExecutePipelineResponse>>(any()),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.positionalArguments.single
                as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                Function(firestore_v1.Firestore api, String projectId);

        final api = FakeFirestore(
          executePipeline: (_) => Stream.fromIterable([
            firestore_v1.ExecutePipelineResponse(
              results: [firestore_v1.Document(name: '', fields: const {})],
            ),
          ]),
        );

        return callback(api, _projectId);
      });

      final snapshot = await firestore.pipeline().collection('books').execute();
      final data = snapshot.results.single.data();

      // A projection stage can drop every field; that is an empty map, not a
      // missing one, so callers never need a null check.
      expect(data, isEmpty);
      expect(() => data['title'] = 'nope', throwsUnsupportedError);
      expect(snapshot.results.single.name, isNull);
      expect(snapshot.results.single.document, isNull);
    });

    test('execute encodes options under their backend names', () async {
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
          executePipeline: (request) {
            capturedRequest = request;
            return const Stream<firestore_v1.ExecutePipelineResponse>.empty();
          },
        );

        return callback(api, _projectId);
      });

      await firestore
          .pipeline()
          .collection('books')
          .execute(
            indexMode: PipelineIndexMode.recommended,
            explain: const PipelineExplainOptions(
              mode: PipelineExplainMode.analyze,
              outputFormat: PipelineExplainOutputFormat.text,
            ),
          );

      final options = capturedRequest!.structuredPipeline!.options;
      expect(options.keys, unorderedEquals(['index_mode', 'explain_options']));
      expect(options['index_mode']!.stringValue, 'recommended');

      final explain = options['explain_options']!.mapValue!.fields;
      expect(explain['mode']!.stringValue, 'analyze');
      expect(explain['output_format']!.stringValue, 'text');
    });

    test('execute omits unset options and honours rawOptions', () async {
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
          executePipeline: (request) {
            capturedRequest = request;
            return const Stream<firestore_v1.ExecutePipelineResponse>.empty();
          },
        );

        return callback(api, _projectId);
      });

      await firestore
          .pipeline()
          .collection('books')
          .execute(
            explain: const PipelineExplainOptions(
              mode: PipelineExplainMode.analyze,
            ),
            rawOptions: const {'index_mode': 'something_new'},
          );

      final options = capturedRequest!.structuredPipeline!.options;
      expect(options.keys, unorderedEquals(['explain_options', 'index_mode']));
      // outputFormat was not set, so it is not sent.
      expect(options['explain_options']!.mapValue!.fields.keys, ['mode']);
      // rawOptions reaches the backend verbatim.
      expect(options['index_mode']!.stringValue, 'something_new');
    });

    test('decodes explain stats without losing the payload', () async {
      when(
        () =>
            mockClient.v1<Stream<firestore_v1.ExecutePipelineResponse>>(any()),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.positionalArguments.single
                as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                Function(firestore_v1.Firestore api, String projectId);

        final api = FakeFirestore(
          executePipeline: (_) => Stream.fromIterable([
            firestore_v1.ExecutePipelineResponse(
              explainStats: firestore_v1.ExplainStats(
                data: protobuf_v1.Any.from(
                  protobuf_v1.StringValue(value: 'plan: scan books'),
                ),
              ),
            ),
          ]),
        );

        return callback(api, _projectId);
      });

      final snapshot = await firestore.pipeline().collection('books').execute();

      final stats = snapshot.explainStats!;
      expect(stats.text, 'plan: scan books');
      expect(stats.typeName, 'google.protobuf.StringValue');
      // `raw` keeps the encoded payload, so a format without a `text`
      // decoding is still reachable.
      expect(stats.raw, {
        '@type': 'type.googleapis.com/google.protobuf.StringValue',
        'value': 'plan: scan books',
      });
    });

    test('executePipeline starts and reuses a transaction', () async {
      final requests = <firestore_v1.ExecutePipelineRequest>[];
      final transactionId = Uint8List.fromList([1, 2, 3]);

      when(
        () =>
            mockClient.v1<Stream<firestore_v1.ExecutePipelineResponse>>(any()),
      ).thenAnswer((invocation) async {
        final callback =
            invocation.positionalArguments.single
                as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                Function(firestore_v1.Firestore api, String projectId);

        final api = FakeFirestore(
          executePipeline: (request) {
            requests.add(request);
            return Stream.fromIterable([
              firestore_v1.ExecutePipelineResponse(
                // Only the response to the transaction-starting request
                // carries the new ID.
                transaction: requests.length == 1 ? transactionId : null,
                results: [
                  firestore_v1.Document(
                    name:
                        'projects/$_projectId/databases/enterprise/documents/books/book-1',
                    fields: {
                      'title': firestore.serializer.encodeValue('Dart')!,
                    },
                  ),
                ],
              ),
            ]);
          },
        );

        return callback(api, _projectId);
      });

      final titles = await firestore.runTransaction((transaction) async {
        final first = await transaction.executePipeline(
          firestore.pipeline().collection('books'),
        );
        final second = await transaction.executePipeline(
          firestore.pipeline().collection('authors'),
        );
        return [
          first.results.single.get('title'),
          second.results.single.get('title'),
        ];
      }, transactionOptions: ReadOnlyTransactionOptions());

      expect(titles, ['Dart', 'Dart']);
      expect(requests, hasLength(2));

      // The first read lazily starts the transaction...
      expect(requests[0].newTransaction?.readOnly, isNotNull);
      expect(requests[0].transaction, isNull);

      // ...and the second reuses the ID the backend handed back.
      expect(requests[1].newTransaction, isNull);
      expect(requests[1].transaction, transactionId);
    });

    test('executePipeline rejects a Pipeline from a different database', () {
      final other = _otherDatabase();

      expect(
        () => firestore.runTransaction(
          (transaction) =>
              transaction.executePipeline(other.pipeline().collection('books')),
          transactionOptions: ReadOnlyTransactionOptions(),
        ),
        throwsA(_crossDatabaseError),
      );
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
      // Source stages name documents relative to the database, matching the
      // `collection` stage and the Node SDK's `DocumentsSource`.
      expect(stages.first.args.single.referenceValue, '/books/book-1');
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
            PipelineFunctions.regexMatch(field('title'), r'^Dart').as('isDart'),
            PipelineFunctions.timestampToUnixMillis(
              field('publishedAt'),
            ).as('publishedMillis'),
            PipelineFunctions.cosineDistance(
              field('embedding'),
              FieldValue.vector([1, 2, 3]),
            ).as('distance'),
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
          .where(Expression.field('rating').greaterThanOrEqual(4))
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

      expect(
        stages[3].args.single.mapValue!.fields['genre']!.fieldReferenceValue,
        'genre',
      );
      expect(stages[4].args[0].fieldReferenceValue, 'tags');
      expect(stages[4].args[1].fieldReferenceValue, 'tags');
      expect(stages[4].options['index_field']!.fieldReferenceValue, 'tagIndex');
      expect(stages[5].args[0].fieldReferenceValue, 'summary');
      expect(stages[5].args[1].stringValue, 'full_replace');
      expect(
        stages[6].args.single.pipelineValue!.stages.first.name,
        'collection',
      );
      expect(stages[7].args[0].integerValue, 5);
      expect(stages[7].args[1].stringValue, 'documents');
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
              ).timestampTruncate('day', 'UTC').as('createdDay'),
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

    // Golden encodings, asserted arg-by-arg against the canonical Node SDK
    // stage definitions (`dev/src/pipelines/stage.ts`). These catch wire-format
    // drift without needing an Enterprise database.
    group('stage proto encoding', () {
      late firestore_v1.Pipeline_Stage stage;

      Future<void> capture(Pipeline pipeline) async {
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
        stage = capturedRequest!.structuredPipeline!.pipeline!.stages.last;
      }

      Pipeline base() => firestore.pipeline().collection('books');

      group('unnest', () {
        test('sends the array expression and its alias', () async {
          await capture(base().unnest(field('tags').as('tag')));

          expect(stage.name, 'unnest');
          expect(stage.args, hasLength(2));
          expect(stage.args[0].fieldReferenceValue, 'tags');
          // The alias is a required second arg; without it the backend has no
          // name to assign each emitted element to.
          expect(stage.args[1].fieldReferenceValue, 'tag');
          expect(stage.options, isEmpty);
        });

        test('defaults the alias to the field name', () async {
          await capture(base().unnest('tags'));

          expect(stage.args[0].fieldReferenceValue, 'tags');
          expect(stage.args[1].fieldReferenceValue, 'tags');
        });

        test('encodes indexField as a field reference', () async {
          await capture(base().unnest('tags', indexField: 'tagIndex'));

          expect(stage.options['index_field']!.fieldReferenceValue, 'tagIndex');
          expect(stage.options['index_field']!.stringValue, isNull);
        });

        test('rejects an unaliased computed expression', () {
          expect(
            () => base().unnest(PipelineFunctions.array([1, 2])),
            throwsA(isA<ArgumentError>()),
          );
        });
      });

      test('replace_with sends the map and the replace mode', () async {
        await capture(base().replaceWith('summary'));

        expect(stage.name, 'replace_with');
        expect(stage.args, hasLength(2));
        expect(stage.args[0].fieldReferenceValue, 'summary');
        expect(stage.args[1].stringValue, 'full_replace');
      });

      group('sample', () {
        test('sends rate and documents mode', () async {
          await capture(base().sample(documents: 10));

          expect(stage.name, 'sample');
          expect(stage.args, hasLength(2));
          expect(stage.args[0].integerValue, 10);
          expect(stage.args[1].stringValue, 'documents');
          // The rate and mode are positional args, not options.
          expect(stage.options, isEmpty);
        });

        test('sends rate and percent mode', () async {
          await capture(base().sample(percentage: 0.25));

          expect(stage.args[0].doubleValue, 0.25);
          expect(stage.args[1].stringValue, 'percent');
          expect(stage.options, isEmpty);
        });
      });

      group('distinct', () {
        test('sends a single map argument', () async {
          await capture(base().distinct(['genre', 'author']));

          expect(stage.name, 'distinct');
          expect(stage.args, hasLength(1));
          final groups = stage.args.single.mapValue!.fields;
          expect(groups.keys, ['genre', 'author']);
          expect(groups['genre']!.fieldReferenceValue, 'genre');
        });

        test('keys the map by alias for computed groups', () async {
          await capture(
            base().distinct([PipelineFunctions.toLower('genre').as('g')]),
          );

          final groups = stage.args.single.mapValue!.fields;
          expect(groups.keys, ['g']);
          expect(groups['g']!.functionValue!.name, 'to_lower');
        });
      });

      test('select and aggregate use the same projection map', () async {
        await capture(base().select(['title', field('rating')]));

        expect(stage.args, hasLength(1));
        expect(stage.args.single.mapValue!.fields.keys, ['title', 'rating']);
      });
    });

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
            PipelineFunctions.equal('title', 'Harry').as('isHarry'),
            PipelineFunctions.lessThan('price', 10).as('isCheap'),
            PipelineFunctions.arrayContains('tags', 'dart').as('isDart'),
            PipelineFunctions.mapGet('metadata', 'lang').as('lang'),
            PipelineFunctions.toUpper('title').as('upper'),
            PipelineFunctions.sum('price').as('total'),
            PipelineFunctions.arrayLength('tags').as('tagCount'),
            PipelineFunctions.timestampToUnixMillis('createdAt').as('ms'),
            PipelineFunctions.vectorLength('embedding').as('dims'),
            PipelineFunctions.exists('title').as('hasTitle'),
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
            ]).as('byline'),
            PipelineFunctions.array(['a', 'b']).as('letters'),
            // A document path is a value, matching the Node SDK.
            PipelineFunctions.documentId('books/book-1').as('id'),
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
            PipelineFunctions.coalesce('nickname', field('title')).as('name'),
            PipelineFunctions.length('tags').as('size'),
            PipelineFunctions.reverse('tags').as('reversed'),
            PipelineFunctions.concat('tags', ['extra']).as('joined'),
            PipelineFunctions.getField('metadata', 'lang').as('lang'),
            PipelineFunctions.geoDistance(
              'location',
              GeoPoint(latitude: 1, longitude: 2),
            ).as('distance'),
            score().as('relevance'),
            field('title').charLength().as('titleChars'),
            field('rating').logicalMaximum(0).as('clampedRating'),
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

    test('exposes the Node method names for every expression', () async {
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
          executePipeline: (request) {
            capturedRequest = request;
            return const Stream<firestore_v1.ExecutePipelineResponse>.empty();
          },
        );

        return callback(api, _projectId);
      });

      final active = field('active').asBoolean();

      await firestore.pipeline().collection('books').select([
        // Renamed to match the Node SDK.
        field('price').mod(4).as('remainder'),
        field('createdAt').timestampTruncate('day').as('day'),
        field('tags').arrayContains('dart').as('hasDart'),
        // Deliberately NOT `toLower`/`toUpper` as in Node: these mirror Dart's
        // own `String.toLowerCase()`/`toUpperCase()`. The backend op is still
        // `to_lower`/`to_upper`, asserted below.
        field('title').toLowerCase().as('lower'),
        field('title').toUpperCase().as('upper'),
        // Fluent forms Node has that were missing here.
        field('title').stringReverse().as('backwards'),
        active.not().as('inactive'),
        active.countIf().as('activeCount'),
        active.conditional('yes', 'no').as('label'),
        // Static catalog additions.
        PipelineFunctions.arrayMaximum('numbers').as('maxNumber'),
        PipelineFunctions.arrayMinimum('numbers').as('minNumber'),
        PipelineFunctions.arrayMaximumN('numbers', 2).as('top2'),
        PipelineFunctions.arrayMinimumN('numbers', 2).as('bottom2'),
        PipelineFunctions.arraySum('numbers').as('total'),
        PipelineFunctions.countAll().as('rows'),
      ]).execute();

      final fields = capturedRequest!
          .structuredPipeline!
          .pipeline!
          .stages[1]
          .args
          .single
          .mapValue!
          .fields;

      expect(fields['remainder']!.functionValue!.name, 'mod');
      expect(fields['lower']!.functionValue!.name, 'to_lower');
      expect(fields['upper']!.functionValue!.name, 'to_upper');
      expect(fields['day']!.functionValue!.name, 'timestamp_trunc');
      expect(fields['hasDart']!.functionValue!.name, 'array_contains');
      expect(fields['backwards']!.functionValue!.name, 'string_reverse');
      expect(fields['inactive']!.functionValue!.name, 'not');
      expect(fields['activeCount']!.functionValue!.name, 'count_if');
      expect(fields['label']!.functionValue!.name, 'conditional');
      expect(fields['maxNumber']!.functionValue!.name, 'array_maximum');
      expect(fields['minNumber']!.functionValue!.name, 'array_minimum');
      expect(fields['top2']!.functionValue!.name, 'array_maximum_n');
      expect(fields['bottom2']!.functionValue!.name, 'array_minimum_n');
      expect(fields['total']!.functionValue!.name, 'array_sum');
      expect(fields['rows']!.functionValue!.name, 'count');
      expect(fields['rows']!.functionValue!.args, isEmpty);
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

      test('rejects a collection reference from a different database', () {
        final other = _otherDatabase();

        expect(
          () => firestore.pipeline().collectionReference(
            other.collection('books'),
          ),
          throwsA(_crossDatabaseError),
        );
      });

      test('rejects documents from a different database', () {
        final other = _otherDatabase();

        expect(
          () => firestore.pipeline().documents([other.doc('books/book-1')]),
          throwsA(_crossDatabaseError),
        );
      });

      test('rejects a union with a different database', () {
        final other = _otherDatabase();

        expect(
          () => firestore
              .pipeline()
              .collection('books')
              .union(other.pipeline().collection('books')),
          throwsA(_crossDatabaseError),
        );
      });

      test('rejects a query from the same database in another project', () {
        final other = Firestore.internal(
          settings: const Settings(
            projectId: 'other-project',
            databaseId: 'enterprise',
          ),
          client: MockFirestoreHttpClient(),
        );

        // Same databaseId, different project: `(default)` in two projects is
        // the common shape of this mistake.
        expect(
          () => firestore.pipeline().createFrom(other.collection('books')),
          throwsA(_crossDatabaseError),
        );
      });

      test('allows a source whose project is not yet discovered', () {
        // Project IDs resolve on the first request when discovery is async
        // (metadata server). Builder methods must not force that resolution.
        // An empty environmentOverride blocks the synchronous strategies, so
        // this holds regardless of the ambient GOOGLE_CLOUD_PROJECT.
        final undiscovered = Firestore(
          settings: const Settings(
            databaseId: 'enterprise',
            environmentOverride: {},
          ),
        );
        expect(() => undiscovered.projectId, throwsStateError);

        expect(
          () =>
              firestore.pipeline().createFrom(undiscovered.collection('books')),
          returnsNormally,
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

Firestore _otherDatabase() {
  return Firestore.internal(
    settings: const Settings(projectId: _projectId, databaseId: 'other-db'),
    client: MockFirestoreHttpClient(),
  );
}

final _crossDatabaseError = isA<ArgumentError>().having(
  (e) => e.message,
  'message',
  contains('does not match the target database'),
);
