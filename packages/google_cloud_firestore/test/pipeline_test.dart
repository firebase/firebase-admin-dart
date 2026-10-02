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
      expect(snapshot.results.single.ref, firestore.doc('books/book-1'));
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
      expect(snapshot.results.single.id, 'book-1');
      // The snapshot carries the Pipeline that produced it, as in Node.
      expect(snapshot.pipeline, isA<Pipeline>());
    });

    test('result get resolves nested field paths', () async {
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
            return Stream.value(
              firestore_v1.ExecutePipelineResponse(
                results: [
                  firestore_v1.Document(
                    fields: {
                      'title': firestore.serializer.encodeValue('Dart')!,
                      'metadata': firestore.serializer.encodeValue({
                        'lang': 'dart',
                        'stats': {'pages': 42, 'note': null},
                      })!,
                      'a.b': firestore.serializer.encodeValue('dotted')!,
                    },
                  ),
                ],
              ),
            );
          },
        );

        return callback(api, _projectId);
      });

      final snapshot = await firestore.pipeline().collection('books').execute();
      final result = snapshot.results.single;

      expect(result.get('title'), 'Dart');
      expect(result.get('metadata.lang'), 'dart');
      expect(result.get('metadata.stats.pages'), 42);
      expect(result.get('metadata.stats'), {'pages': 42, 'note': null});
      expect(result.get(FieldPath(const ['metadata', 'lang'])), 'dart');
      // A FieldPath segment may contain a dot; a string is split on dots.
      expect(result.get(FieldPath(const ['a.b'])), 'dotted');
      expect(result.get('a.b'), isNull);

      // Missing fields and paths through non-map values resolve to null.
      expect(result.get('missing'), isNull);
      expect(result.get('metadata.missing.deeper'), isNull);
      expect(result.get('title.length'), isNull);
      expect(result.get('metadata.stats.note'), isNull);

      // Invalid paths are rejected, as in DocumentSnapshot.get.
      expect(() => result.get('metadata..lang'), throwsArgumentError);
      expect(() => result.get('.metadata'), throwsArgumentError);
      expect(() => result.get(''), throwsArgumentError);
      expect(() => result.get(42), throwsArgumentError);
    });

    test('results compare by reference and fields, not read time', () async {
      firestore_v1.ExecutePipelineResponse chunk({
        required String path,
        required Object? title,
        int seconds = 42,
      }) {
        final time = protobuf_v1.Timestamp(seconds: seconds);
        return firestore_v1.ExecutePipelineResponse(
          results: [
            firestore_v1.Document(
              name: 'projects/$_projectId/databases/enterprise/documents/$path',
              fields: {'title': firestore.serializer.encodeValue(title)!},
              createTime: time,
              updateTime: time,
            ),
          ],
        );
      }

      Future<PipelineResult> runOne(
        firestore_v1.ExecutePipelineResponse response,
      ) async {
        when(
          () => mockClient.v1<Stream<firestore_v1.ExecutePipelineResponse>>(
            any(),
          ),
        ).thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments.single
                  as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                  Function(firestore_v1.Firestore api, String projectId);
          return callback(
            FakeFirestore(executePipeline: (_) => Stream.value(response)),
            _projectId,
          );
        });

        final snapshot = await firestore
            .pipeline()
            .collection('books')
            .execute();
        return snapshot.results.single;
      }

      final first = await runOne(chunk(path: 'books/book-1', title: 'Dart'));
      final same = await runOne(chunk(path: 'books/book-1', title: 'Dart'));
      final laterRead = await runOne(
        chunk(path: 'books/book-1', title: 'Dart', seconds: 99),
      );
      final otherFields = await runOne(
        chunk(path: 'books/book-1', title: 'Other'),
      );
      final otherDoc = await runOne(chunk(path: 'books/book-2', title: 'Dart'));

      // Distinct instances, same document and fields.
      expect(identical(first, same), isFalse);
      expect(first, equals(same));
      expect(first.hashCode, same.hashCode);

      // Read times are excluded, matching Node's `isEqual`.
      expect(first, equals(laterRead));

      expect(first, isNot(equals(otherFields)));
      expect(first, isNot(equals(otherDoc)));

      // Same resource name, different Firestore instance. `DocumentReference`
      // equality includes the instance, so these must not compare equal --
      // comparing the raw `name` string instead would wrongly say they do.
      final otherClient = MockFirestoreHttpClient();
      when(() => otherClient.cachedProjectId).thenReturn(_projectId);
      final otherInstance = Firestore.internal(
        settings: const Settings(
          projectId: _projectId,
          databaseId: 'enterprise',
        ),
        client: otherClient,
      );

      expect(first.ref, isNot(equals(otherInstance.doc('books/book-1'))));
      expect(
        first.name,
        'projects/$_projectId/databases/enterprise/documents/books/book-1',
      );
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
      expect(snapshot.results.single.ref, isNull);
    });

    group('reference values in results', () {
      const documents = 'projects/$_projectId/databases/enterprise/documents';
      // `parent()` of a top-level document returns the database root, and a
      // reference can also name a collection; neither is a document.
      const root = documents;
      const collection = '$documents/books';
      const subcollection = '$documents/books/book-1/chapters';
      const document = '$documents/books/book-1';
      const subcollectionDocument = '$documents/books/book-1/chapters/c1';

      firestore_v1.Value ref(String name) {
        return firestore_v1.Value(referenceValue: name);
      }

      firestore_v1.Value array(List<firestore_v1.Value> values) {
        return firestore_v1.Value(
          arrayValue: firestore_v1.ArrayValue(values: values),
        );
      }

      firestore_v1.Value map(Map<String, firestore_v1.Value> fields) {
        return firestore_v1.Value(
          mapValue: firestore_v1.MapValue(fields: fields),
        );
      }

      Future<PipelineResult> decode(Map<String, firestore_v1.Value> fields) {
        when(
          () => mockClient.v1<Stream<firestore_v1.ExecutePipelineResponse>>(
            any(),
          ),
        ).thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments.single
                  as Future<Stream<firestore_v1.ExecutePipelineResponse>>
                  Function(firestore_v1.Firestore api, String projectId);
          return callback(
            FakeFirestore(
              executePipeline: (_) => Stream.value(
                firestore_v1.ExecutePipelineResponse(
                  results: [firestore_v1.Document(fields: fields)],
                ),
              ),
            ),
            _projectId,
          );
        });

        return firestore
            .pipeline()
            .collection('books')
            .execute()
            .then((snapshot) => snapshot.results.single);
      }

      // Every kind of reference, in the order the expectations below use.
      final all = [
        ref(document),
        ref(subcollectionDocument),
        ref(root),
        ref(collection),
        ref(subcollection),
      ];
      // `firestore` is only assigned in setUp, so build these per test.
      late List<Object?> allDecoded;
      setUp(() {
        allDecoded = [
          firestore.doc('books/book-1'),
          firestore.doc('books/book-1/chapters/c1'),
          root,
          collection,
          subcollection,
        ];
      });

      test('decode the same way at the top level', () async {
        final result = await decode({
          'document': all[0],
          'subcollectionDocument': all[1],
          'root': all[2],
          'collection': all[3],
          'subcollection': all[4],
        });

        expect(result.data(), {
          'document': allDecoded[0],
          'subcollectionDocument': allDecoded[1],
          'root': allDecoded[2],
          'collection': allDecoded[3],
          'subcollection': allDecoded[4],
        });
        expect(result.get('document'), isA<DocumentReference<DocumentData>>());
        expect(result.get('root'), isA<String>());
      });

      test('decode the same way inside a map', () async {
        final result = await decode({
          'm': map({for (var i = 0; i < all.length; i++) 'r$i': all[i]}),
        });

        expect(result.get('m'), {
          for (var i = 0; i < allDecoded.length; i++) 'r$i': allDecoded[i],
        });
        expect(result.get('m.r0'), firestore.doc('books/book-1'));
        expect(result.get('m.r2'), root);
      });

      test('decode the same way inside an array', () async {
        final result = await decode({'a': array(all)});

        expect(result.get('a'), allDecoded);
      });

      test('decode the same way nested two deep', () async {
        final result = await decode({
          'mapInMap': map({
            'inner': map({'root': all[2], 'document': all[0]}),
          }),
          'arrayInMap': map({'inner': array(all)}),
          'mapInArray': array([
            map({'collection': all[3], 'document': all[0]}),
          ]),
          'arrayInArray': array([array(all)]),
        });

        expect(result.data(), {
          'mapInMap': {
            'inner': {'root': root, 'document': allDecoded[0]},
          },
          'arrayInMap': {'inner': allDecoded},
          'mapInArray': [
            {'collection': collection, 'document': allDecoded[0]},
          ],
          'arrayInArray': [allDecoded],
        });
        expect(result.get('mapInMap.inner.root'), root);
      });

      test('leave regular document decoding unchanged', () {
        // Outside Pipelines a non-document reference is still rejected, at
        // any depth; only document references decode.
        final serializer = firestore.serializer;

        expect(serializer.decodeValue(all[0]), allDecoded[0]);
        expect(serializer.decodeValue(map({'d': all[0]})), {
          'd': allDecoded[0],
        });
        expect(() => serializer.decodeValue(all[3]), throwsArgumentError);
        expect(
          () => serializer.decodeValue(array([all[4]])),
          throwsArgumentError,
        );
      });
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

    test('executePipeline sends options alongside the transaction', () async {
      final requests = <firestore_v1.ExecutePipelineRequest>[];

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
                transaction: Uint8List.fromList([9, 9]),
                explainStats: firestore_v1.ExplainStats(
                  data: protobuf_v1.Any.from(
                    protobuf_v1.StringValue(value: 'plan: scan books'),
                  ),
                ),
              ),
            ]);
          },
        );

        return callback(api, _projectId);
      });

      final stats = await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.executePipeline(
          firestore.pipeline().collection('books'),
          indexMode: PipelineIndexMode.recommended,
          explain: const PipelineExplainOptions(
            mode: PipelineExplainMode.analyze,
            outputFormat: PipelineExplainOutputFormat.text,
          ),
        );
        return snapshot.explainStats;
      }, transactionOptions: ReadOnlyTransactionOptions());

      final request = requests.single;

      // Pipeline options and the transaction live on different parts of the
      // request, so neither clobbers the other.
      final options = request.structuredPipeline!.options;
      expect(options['index_mode']!.stringValue, 'recommended');
      expect(
        options['explain_options']!.mapValue!.fields['mode']!.stringValue,
        'analyze',
      );
      expect(request.newTransaction?.readOnly, isNotNull);

      // Explain stats survive the transaction path, which Node drops.
      expect(stats?.text, 'plan: scan books');
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

    test('join always sends the array and the delimiter', () async {
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

      // The backend only accepts `join(array, delimiter)`: a one-argument
      // `join` is rejected with INVALID_ARGUMENT, so the delimiter is required.
      await firestore.pipeline().collection('books').select([
        PipelineFunctions.join('tags', ', ').as('staticJoin'),
        PipelineFunctions.join(
          field('tags'),
          field('separator'),
        ).as('expressionJoin'),
        field('tags').join(', ').as('fluentJoin'),
      ]).execute();

      final fields = capturedRequest!
          .structuredPipeline!
          .pipeline!
          .stages[1]
          .args
          .single
          .mapValue!
          .fields;

      for (final alias in ['staticJoin', 'fluentJoin']) {
        final join = fields[alias]!.functionValue!;
        expect(join.name, 'join', reason: alias);
        expect(join.args, hasLength(2), reason: alias);
        expect(join.args[0].fieldReferenceValue, 'tags', reason: alias);
        expect(join.args[1].stringValue, ', ', reason: alias);
      }

      final expressionJoin = fields['expressionJoin']!.functionValue!;
      expect(expressionJoin.name, 'join');
      expect(expressionJoin.args, hasLength(2));
      expect(expressionJoin.args[0].fieldReferenceValue, 'tags');
      expect(expressionJoin.args[1].fieldReferenceValue, 'separator');
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
              Expression.field('metadata').mapRemove('draft').as('removed'),
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

    test('isType encodes PipelineValueType as backend type names', () async {
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

      // The names the backend accepts for `is_type` (and the Node SDK's `Type`
      // union). Covers every member so a new one can't ship unchecked.
      const expected = {
        PipelineValueType.nullValue: 'null',
        PipelineValueType.boolean: 'boolean',
        PipelineValueType.number: 'number',
        PipelineValueType.int32: 'int32',
        PipelineValueType.int64: 'int64',
        PipelineValueType.double: 'float64',
        PipelineValueType.decimal128: 'decimal128',
        PipelineValueType.timestamp: 'timestamp',
        PipelineValueType.string: 'string',
        PipelineValueType.bytes: 'bytes',
        PipelineValueType.reference: 'reference',
        PipelineValueType.geoPoint: 'geo_point',
        PipelineValueType.array: 'array',
        PipelineValueType.map: 'map',
        PipelineValueType.vector: 'vector',
        PipelineValueType.maxKey: 'max_key',
        PipelineValueType.minKey: 'min_key',
        PipelineValueType.objectId: 'object_id',
        PipelineValueType.regex: 'regex',
      };
      expect(expected.keys, unorderedEquals(PipelineValueType.values));

      await firestore.pipeline().collection('books').select([
        for (final type in PipelineValueType.values)
          Expression.field('value').isType(type).as(type.name),
      ]).execute();

      final fields = capturedRequest!
          .structuredPipeline!
          .pipeline!
          .stages[1]
          .args
          .single
          .mapValue!
          .fields;
      for (final MapEntry(key: type, value: wireName) in expected.entries) {
        final function = fields[type.name]!.functionValue!;
        expect(function.name, 'is_type');
        expect(function.args.last.stringValue, wireName, reason: type.name);
      }
      // Regression: `double` used to encode as 'double', which the backend
      // rejects with INVALID_ARGUMENT.
      expect(fields['double']!.functionValue!.args.last.stringValue, 'float64');
    });

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

      group('collection_group', () {
        test('sends the root ancestor before the collection id', () async {
          await capture(firestore.pipeline().collectionGroup('books'));

          expect(stage.name, 'collection_group');
          // The backend stage is `collection_group(ancestor, collection_id)`
          // and rejects a lone collection id.
          expect(stage.args, hasLength(2));
          expect(stage.args[0].referenceValue, '');
          expect(stage.args[1].stringValue, 'books');
          expect(stage.options, isEmpty);
        });

        test('keeps the empty root reference on the wire', () async {
          await capture(firestore.pipeline().collectionGroup('books'));

          expect(stage.args[0].toJson(), {'referenceValue': ''});
        });
      });

      test('database sends no arguments', () async {
        await capture(firestore.pipeline().database());

        expect(stage.name, 'database');
        expect(stage.args, isEmpty);
      });

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

      group('add_fields', () {
        test('sends a single map argument keyed by alias', () async {
          await capture(
            base().addFields([
              field('rating').as('copiedRating'),
              constant(true).as('annotated'),
            ]),
          );

          expect(stage.name, 'add_fields');
          // The backend stage takes exactly one MapValue argument; one arg per
          // field is rejected with "takes [1..1] argument(s)".
          expect(stage.args, hasLength(1));
          final fields = stage.args.single.mapValue!.fields;
          expect(fields.keys, ['copiedRating', 'annotated']);
          expect(fields['copiedRating']!.fieldReferenceValue, 'rating');
          expect(fields['annotated']!.booleanValue, isTrue);
          expect(stage.options, isEmpty);
        });

        test('wraps a single field in a map, not an alias function', () async {
          await capture(
            base().addFields([field('title').toUpperCase().as('upper')]),
          );

          expect(stage.args, hasLength(1));
          expect(stage.args.single.functionValue, isNull);
          final fields = stage.args.single.mapValue!.fields;
          expect(fields.keys, ['upper']);
          expect(fields['upper']!.functionValue!.name, 'to_upper');
        });
      });

      group('substring', () {
        test('sends position and length, in that order', () async {
          await capture(
            base().select([
              field('title').substring(2, 3).as('fluent'),
              field('title').substringLiteral(2, 3).as('literal'),
              PipelineFunctions.substring('title', 2, 3).as('static'),
            ]),
          );

          final fields = stage.args.single.mapValue!.fields;
          for (final alias in ['fluent', 'literal', 'static']) {
            final function = fields[alias]!.functionValue!;
            expect(function.name, 'substring', reason: alias);
            expect(function.args, hasLength(3), reason: alias);
            expect(function.args[0].fieldReferenceValue, 'title');
            expect(function.args[1].integerValue, 2, reason: alias);
            // A length (as in Node), not an end index like String.substring.
            expect(function.args[2].integerValue, 3, reason: alias);
          }
        });

        test('omits the length when it is not given', () async {
          await capture(
            base().select([
              field('title').substring(2).as('fluent'),
              field('title').substringLiteral(2).as('literal'),
              PipelineFunctions.substring('title', 2).as('static'),
            ]),
          );

          final fields = stage.args.single.mapValue!.fields;
          for (final alias in ['fluent', 'literal', 'static']) {
            final function = fields[alias]!.functionValue!;
            expect(function.name, 'substring', reason: alias);
            // Regression: the fluent forms required a second `end` argument,
            // so "to the end of the input" could not be expressed.
            expect(function.args, hasLength(2), reason: alias);
            expect(function.args[1].integerValue, 2, reason: alias);
          }
        });

        test('accepts expressions for position and length', () async {
          await capture(
            base().select([
              field(
                'title',
              ).substring(field('start'), field('count')).as('fromFields'),
            ]),
          );

          final function =
              stage.args.single.mapValue!.fields['fromFields']!.functionValue!;
          expect(function.args[1].fieldReferenceValue, 'start');
          expect(function.args[2].fieldReferenceValue, 'count');
        });
      });

      test('select and aggregate use the same projection map', () async {
        await capture(base().select(['title', field('rating')]));

        expect(stage.args, hasLength(1));
        expect(stage.args.single.mapValue!.fields.keys, ['title', 'rating']);
      });

      test('top-level variable() encodes a variable reference', () async {
        // Uses the barrel's top-level `variable`, so dropping it from the
        // public exports fails compilation here.
        final kept = variable('tag').notEqual('draft');
        final aliased = Expression.variable('tag').notEqual('draft');
        await capture(
          base().select([
            field('tags').arrayFilter('tag', kept).as('kept'),
            field('tags').arrayFilter('tag', aliased).as('aliased'),
          ]),
        );

        final fields = stage.args.single.mapValue!.fields;
        final filter = fields['kept']!.functionValue!;
        expect(filter.name, 'array_filter');
        expect(filter.args[0].fieldReferenceValue, 'tags');
        expect(filter.args[1].stringValue, 'tag');
        final predicate = filter.args[2].functionValue!;
        expect(predicate.name, 'not_equal');
        expect(predicate.args[0].variableReferenceValue, 'tag');
        expect(predicate.args[0].fieldReferenceValue, isNull);
        expect(predicate.args[1].stringValue, 'draft');

        // `variable` and `Expression.variable` are interchangeable.
        expect(fields['aliased']!.toJson(), fields['kept']!.toJson());
      });
    });

    // Mirrors the Node SDK's `OptionsUtil` and `rawStage`.
    group('raw options and raw stages', () {
      final requests = <firestore_v1.ExecutePipelineRequest>[];

      setUp(() {
        requests.clear();
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
            executePipeline: (request) {
              requests.add(request);
              return Stream.value(
                firestore_v1.ExecutePipelineResponse(
                  transaction: Uint8List.fromList([9, 9]),
                ),
              );
            },
          );

          return callback(api, _projectId);
        });
      });

      Pipeline base() => firestore.pipeline().collection('books');

      Map<String, Object?> json(Map<String, firestore_v1.Value> options) {
        return {
          for (final MapEntry(:key, :value) in options.entries)
            key: value.toJson(),
        };
      }

      Map<String, Object?> executeOptions() {
        return json(requests.single.structuredPipeline!.options);
      }

      List<firestore_v1.Pipeline_Stage> stages() {
        return requests.single.structuredPipeline!.pipeline!.stages;
      }

      Map<String, Object?> string(String value) => {'stringValue': value};

      Map<String, Object?> map(Map<String, Object?> fields) {
        return {
          'mapValue': {'fields': fields},
        };
      }

      test(
        'execute merges dotted rawOptions keys into typed options',
        () async {
          await base().execute(
            indexMode: PipelineIndexMode.recommended,
            explain: const PipelineExplainOptions(
              mode: PipelineExplainMode.analyze,
            ),
            rawOptions: const {
              'explain_options.output_format': 'json',
              'index_mode': 'custom',
              'a.b.c': 'deep',
            },
          );

          expect(executeOptions(), {
            // A single map: the dotted key lands next to the typed mode.
            'explain_options': map({
              'mode': string('analyze'),
              'output_format': string('json'),
            }),
            'index_mode': string('custom'),
            'a': map({
              'b': map({'c': string('deep')}),
            }),
          });
        },
      );

      test(
        'a rawOptions key without a dot replaces the typed option',
        () async {
          await base().execute(
            explain: const PipelineExplainOptions(
              mode: PipelineExplainMode.analyze,
              outputFormat: PipelineExplainOutputFormat.text,
            ),
            rawOptions: const {
              'explain_options': {'mode': 'execute'},
            },
          );

          expect(executeOptions(), {
            'explain_options': map({'mode': string('execute')}),
          });
        },
      );

      test(
        'Transaction.executePipeline merges dotted rawOptions keys',
        () async {
          await firestore.runTransaction(
            (transaction) => transaction.executePipeline(
              base(),
              explain: const PipelineExplainOptions(
                mode: PipelineExplainMode.analyze,
              ),
              rawOptions: const {'explain_options.output_format': 'text'},
            ),
            transactionOptions: ReadOnlyTransactionOptions(),
          );

          expect(executeOptions(), {
            'explain_options': map({
              'mode': string('analyze'),
              'output_format': string('text'),
            }),
          });
        },
      );

      test('raw option keys apply in order', () async {
        await base()
            .rawStage(
              'custom',
              const [],
              options: const {
                // A dotted key merges into an earlier map...
                'merged': {'a': 1},
                'merged.b': 'two',
                // ...a key without a dot replaces what came before...
                'replaced.a': 1,
                'replaced': 'value',
                // ...and a dotted key replaces a value that is not a map.
                'promoted': 'value',
                'promoted.a': true,
                // Backticks are not unescaped.
                'a.`b`': 1,
              },
            )
            .execute();

        expect(json(stages().last.options), {
          'merged': map({
            'a': {'integerValue': '1'},
            'b': string('two'),
          }),
          'replaced': string('value'),
          'promoted': map({
            'a': {'booleanValue': true},
          }),
          'a': map({
            '`b`': {'integerValue': '1'},
          }),
        });
      });

      test('every stage takes rawOptions', () async {
        const raw = {'foo': 'bar', 'outer.inner': 1};
        final other = firestore.pipeline().collection('magazines');

        await firestore
            .pipeline()
            .collection('books', rawOptions: raw)
            .where(field('rating').greaterThan(1), rawOptions: raw)
            .select(['title', 'rating', 'tags'], rawOptions: raw)
            .addFields([field('rating').as('score')], rawOptions: raw)
            .removeFields(['score'], rawOptions: raw)
            .sort([field('title').ascending()], rawOptions: raw)
            .offset(1, rawOptions: raw)
            .limit(10, rawOptions: raw)
            .distinct(['title', 'tags'], rawOptions: raw)
            .aggregate(
              [PipelineFunctions.countAll().as('total')],
              groups: ['title'],
              rawOptions: raw,
            )
            .replaceWith('title', rawOptions: raw)
            .union(other, rawOptions: raw)
            .sample(documents: 5, rawOptions: raw)
            .unnest('tags', rawOptions: raw)
            .findNearest(
              vectorField: 'embedding',
              queryVector: const [1, 2],
              distanceMeasure: DistanceMeasure.cosine,
              rawOptions: raw,
            )
            .search({'query': documentMatches('dart')}, rawOptions: raw)
            .execute();

        final expected = {
          'foo': string('bar'),
          'outer': map({
            'inner': {'integerValue': '1'},
          }),
        };
        expect(stages().map((stage) => stage.name), [
          'collection',
          'where',
          'select',
          'add_fields',
          'remove_fields',
          'sort',
          'offset',
          'limit',
          'distinct',
          'aggregate',
          'replace_with',
          'union',
          'sample',
          'unnest',
          'find_nearest',
          'search',
        ]);
        for (final stage in stages()) {
          final options = json(stage.options);
          if (stage.name == 'search') options.remove('query');
          expect(options, expected, reason: stage.name);
        }
        // The nested Pipeline keeps its own, empty, options.
        final union = stages().firstWhere((stage) => stage.name == 'union');
        expect(union.args.single.pipelineValue!.stages.single.options, isEmpty);
      });

      test('every source takes rawOptions', () async {
        const raw = {'foo': 'bar'};
        final source = firestore.pipeline();

        for (final pipeline in [
          source.collection('books', rawOptions: raw),
          source.collectionReference(
            firestore.collection('books'),
            rawOptions: raw,
          ),
          source.collectionGroup('books', rawOptions: raw),
          source.database(rawOptions: raw),
          source.documents([firestore.doc('books/b')], rawOptions: raw),
        ]) {
          requests.clear();
          await pipeline.execute();
          expect(json(stages().single.options), {'foo': string('bar')});
        }
      });

      test('rawOptions override typed stage options', () async {
        await base()
            .findNearest(
              vectorField: 'embedding',
              queryVector: const [1, 2],
              distanceMeasure: DistanceMeasure.euclidean,
              limit: 10,
              distanceResultField: 'distance',
              rawOptions: const {'limit': 20, 'extra.flag': true},
            )
            .unnest(
              'tags',
              indexField: 'index',
              rawOptions: {'index_field': field('position')},
            )
            .search(
              {'query': documentMatches('dart'), 'limit': 10},
              rawOptions: const {'limit': 20},
            )
            .execute();

        final [_, nearest, unnest, search] = stages();
        expect(json(nearest.options), {
          'limit': {'integerValue': '20'},
          'distance_field': {'fieldReferenceValue': 'distance'},
          'extra': map({
            'flag': {'booleanValue': true},
          }),
        });
        expect(json(unnest.options), {
          'index_field': {'fieldReferenceValue': 'position'},
        });
        expect(search.options['limit']!.integerValue, 20);
      });

      test('rejects raw option keys with an empty segment', () async {
        for (final key in ['', '.', 'a.', '.a', 'a..b']) {
          final options = {key: 1};
          final invalid = throwsA(
            isA<ArgumentError>().having((e) => e.invalidValue, 'key', key),
          );

          expect(
            () => base().rawStage('custom', [], options: options),
            invalid,
          );
          expect(() => base().limit(1, rawOptions: options), invalid);
          expect(
            () => firestore.pipeline().database(rawOptions: options),
            invalid,
          );
          await expectLater(base().execute(rawOptions: options), invalid);
          await expectLater(
            firestore.runTransaction(
              (transaction) =>
                  transaction.executePipeline(base(), rawOptions: options),
              transactionOptions: ReadOnlyTransactionOptions(),
            ),
            invalid,
          );
        }
        expect(requests, isEmpty);
      });

      test('rawStage converts collections nested in a map argument', () async {
        await base().rawStage('custom', [
          {
            'field': field('f'),
            'literal': 1,
            'nestedMap': {'lang': field('lang')},
            'nestedList': [field('a'), 1],
            'literalMap': constant({'x': 1}),
          },
          // A list argument stays a literal value, as in Node.
          [
            field('b'),
            {'c': 1},
          ],
        ]).execute();

        final [mapArg, listArg] = stages().last.args;
        final fields = mapArg.mapValue!.fields;
        expect(fields['field']!.fieldReferenceValue, 'f');
        expect(fields['literal']!.integerValue, 1);

        final nestedMap = fields['nestedMap']!.functionValue!;
        expect(nestedMap.name, 'map');
        expect(nestedMap.args.map((arg) => arg.toJson()), [
          string('lang'),
          {'fieldReferenceValue': 'lang'},
        ]);

        final nestedList = fields['nestedList']!.functionValue!;
        expect(nestedList.name, 'array');
        expect(nestedList.args.map((arg) => arg.toJson()), [
          {'fieldReferenceValue': 'a'},
          {'integerValue': '1'},
        ]);

        expect(fields['literalMap']!.mapValue!.fields['x']!.integerValue, 1);

        expect(listArg.arrayValue!.values.map((value) => value.toJson()), [
          {'fieldReferenceValue': 'b'},
          map({
            'c': {'integerValue': '1'},
          }),
        ]);
      });
    });

    // Mirrors the Node SDK's `field()`, which sends
    // `FieldPath.fromArgument(path).formattedName`.
    group('field paths', () {
      group('field() canonicalizes the path', () {
        void expectPath(Object fieldPath, String expected) {
          expect(field(fieldPath).path, expected, reason: '$fieldPath');
          expect(Expression.field(fieldPath).path, expected);
        }

        test('keeps simple identifiers as they are', () {
          expectPath('title', 'title');
          expectPath('_private', '_private');
          expectPath('isbn13', 'isbn13');
          expectPath('__name__', '__name__');
        });

        test('quotes segments that are not simple identifiers', () {
          expectPath('first-name', '`first-name`');
          expectPath('last name', '`last name`');
          expectPath('naïve', '`naïve`');
          expectPath('1st', '`1st`');
          expectPath('a/b', '`a/b`');
        });

        test('escapes backticks and backslashes inside a segment', () {
          expectPath('a`b', r'`a\`b`');
          expectPath(r'a\b', r'`a\\b`');
        });

        test('reads a dotted String as nested segments', () {
          expectPath('metadata.lang', 'metadata.lang');
          expectPath('author.first-name', 'author.`first-name`');
          expectPath('my map.key', '`my map`.key');
        });

        test('keeps each FieldPath segment whole, dots included', () {
          expectPath(FieldPath(const ['a.b']), '`a.b`');
          expectPath(FieldPath(const ['a.b', 'c']), '`a.b`.c');
          expectPath(FieldPath(const ['metadata', 'lang']), 'metadata.lang');
          expectPath(FieldPath(const ['first-name']), '`first-name`');
          expectPath(FieldPath.documentId, '__name__');
        });

        test('rejects other types and empty segments', () {
          for (final invalid in <Object>[42, '', 'a..b', '.a', 'a.']) {
            expect(
              () => field(invalid),
              throwsArgumentError,
              reason: '$invalid',
            );
            expect(() => Expression.field(invalid), throwsArgumentError);
          }
        });
      });

      group('on the wire', () {
        late List<firestore_v1.Pipeline_Stage> stages;

        Future<void> run(Object pipelineOrQuery) async {
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
                return const Stream<
                  firestore_v1.ExecutePipelineResponse
                >.empty();
              },
            );

            return callback(api, _projectId);
          });

          final pipeline = pipelineOrQuery is Pipeline
              ? pipelineOrQuery
              : firestore.pipeline().createFrom(pipelineOrQuery);
          await pipeline.execute();
          stages = capturedRequest!.structuredPipeline!.pipeline!.stages;
        }

        Pipeline base() => firestore.pipeline().collection('books');
        Map<String, Object?> ref(String path) => {'fieldReferenceValue': path};
        Object? json(firestore_v1.Value value) => value.toJson();

        test(
          'field() and String field arguments send the quoted path',
          () async {
            await run(
              base().where(PipelineFunctions.equal('first-name', 'Ada')).select(
                [
                  field(FieldPath(const ['a.b'])).as('result'),
                ],
              ),
            );

            final equal = stages[1].args.single.functionValue!;
            expect(json(equal.args[0]), ref('`first-name`'));
            // The value position keeps the string as a literal.
            expect(equal.args[1].stringValue, 'Ada');

            final select = stages[2].args.single.mapValue!.fields;
            expect(json(select['result']!), ref('`a.b`'));
          },
        );

        test(
          'select keys a String by itself and a PipelineField by its path',
          () async {
            await run(
              base().select([
                'first-name',
                field('last name'),
                'metadata.lang',
                field(FieldPath(const ['a.b'])),
              ]),
            );

            final fields = stages[1].args.single.mapValue!.fields;
            expect(fields.map((key, value) => MapEntry(key, json(value))), {
              'first-name': ref('`first-name`'),
              '`last name`': ref('`last name`'),
              'metadata.lang': ref('metadata.lang'),
              '`a.b`': ref('`a.b`'),
            });
          },
        );

        test('distinct and aggregate groups are keyed like select', () async {
          await run(
            base()
                .distinct(['first-name', field('last name')])
                .aggregate(
                  [PipelineFunctions.countAll().as('total')],
                  groups: ['first-name', field('last name')],
                ),
          );

          final expected = {
            'first-name': ref('`first-name`'),
            '`last name`': ref('`last name`'),
          };
          final distinct = stages[1].args.single.mapValue!.fields;
          expect(
            distinct.map((key, value) => MapEntry(key, json(value))),
            expected,
          );
          final groups = stages[2].args[1].mapValue!.fields;
          expect(
            groups.map((key, value) => MapEntry(key, json(value))),
            expected,
          );
        });

        test('removeFields and sort send quoted paths', () async {
          await run(
            base().removeFields(['first-name', field('last name')]).sort([
              ascending('first-name'),
              field('last name').descending(),
            ]),
          );

          expect(stages[1].args.map(json), [
            ref('`first-name`'),
            ref('`last name`'),
          ]);
          expect(
            stages[2].args.map(
              (ordering) => json(ordering.mapValue!.fields['expression']!),
            ),
            [ref('`first-name`'), ref('`last name`')],
          );
        });

        test('unnest quotes its target and index field once', () async {
          await run(base().unnest(field('my tags')));
          // Node quotes this target twice; see the golden corpus.
          expect(stages[1].args.map(json), [
            ref('`my tags`'),
            ref('`my tags`'),
          ]);

          await run(
            base().unnest(field('tags').as('my tag'), indexField: 'tag index'),
          );
          expect(stages[1].args.map(json), [ref('tags'), ref('`my tag`')]);
          expect(json(stages[1].options['index_field']!), ref('`tag index`'));
        });

        test('findNearest quotes the vector and distance fields', () async {
          await run(
            base().findNearest(
              vectorField: 'my embedding',
              queryVector: const [1.0, 2.0],
              distanceMeasure: DistanceMeasure.euclidean,
              distanceResultField: 'my distance',
            ),
          );

          expect(json(stages[1].args[0]), ref('`my embedding`'));
          expect(
            json(stages[1].options['distance_field']!),
            ref('`my distance`'),
          );
        });

        group('createFrom', () {
          test('quotes FieldPath filters and orderings once', () async {
            await run(
              firestore
                  .collection('books')
                  .where(FieldPath(const ['a.b']), WhereFilter.equal, 1)
                  .where('a`b', WhereFilter.equal, 2)
                  .orderBy(FieldPath(const ['c.d'])),
            );

            final dotted = stages[1].args.single.functionValue!;
            expect(
              json(dotted.args[0].functionValue!.args.single),
              ref('`a.b`'),
            );
            final backtick = stages[2].args.single.functionValue!;
            expect(
              json(backtick.args[0].functionValue!.args.single),
              ref(r'`a\`b`'),
            );
            final sort = stages.singleWhere((stage) => stage.name == 'sort');
            expect(
              json(sort.args.first.mapValue!.fields['expression']!),
              ref('`c.d`'),
            );
          });

          test('keeps the projection paths quoted once', () async {
            await run(
              firestore.collection('books').select([
                FieldPath(const ['first-name']),
                FieldPath(const ['a.b']),
                FieldPath(const ['metadata', 'lang']),
              ]),
            );

            final select = stages.singleWhere(
              (stage) => stage.name == 'select',
            );
            final fields = select.args.single.mapValue!.fields;
            // Node quotes these twice; see the golden corpus.
            expect(fields.map((key, value) => MapEntry(key, json(value))), {
              '`first-name`': ref('`first-name`'),
              '`a.b`': ref('`a.b`'),
              'metadata.lang': ref('metadata.lang'),
            });
          });

          test('reads FieldPath vector and distance fields', () async {
            await run(
              firestore
                  .collection('books')
                  .findNearest(
                    vectorField: FieldPath(const ['a.b']),
                    queryVector: const [1.0, 2.0],
                    limit: 3,
                    distanceMeasure: DistanceMeasure.euclidean,
                    distanceResultField: FieldPath(const ['my distance']),
                  ),
            );

            final nearest = stages.last;
            expect(nearest.name, 'find_nearest');
            expect(json(nearest.args[0]), ref('`a.b`'));
            expect(
              json(nearest.options['distance_field']!),
              ref('`my distance`'),
            );
            final exists = stages[stages.length - 2].args.single.functionValue!;
            expect(json(exists.args.single), ref('`a.b`'));
          });
        });
      });
    });

    // Mirrors the Node SDK's `selectablesToObject` / `aliasedAggregateToMap`,
    // which throw rather than let a later entry overwrite an earlier one.
    group('duplicate aliases or fields', () {
      Pipeline base() => firestore.pipeline().collection('books');

      Matcher duplicateError(String key, String argumentName) {
        return throwsA(
          isA<ArgumentError>()
              .having((e) => e.message, 'message', contains("'$key'"))
              .having((e) => e.message, 'message', contains('Duplicate'))
              .having((e) => e.name, 'name', argumentName),
        );
      }

      test('select rejects a repeated alias', () {
        expect(
          () => base().select([constant(1).as('x'), constant(2).as('x')]),
          duplicateError('x', 'selections'),
        );
      });

      test('select rejects a repeated field name', () {
        expect(
          () => base().select(['title', field('title')]),
          duplicateError('title', 'selections'),
        );
      });

      test('select rejects an alias that collides with a field name', () {
        expect(
          () => base().select(['title', constant('x').as('title')]),
          duplicateError('title', 'selections'),
        );
      });

      test('addFields rejects a repeated alias', () {
        expect(
          () => base().addFields([constant(1).as('x'), constant(2).as('x')]),
          duplicateError('x', 'fields'),
        );
      });

      test('aggregate rejects a repeated accumulator alias', () {
        expect(
          () => base().aggregate([
            PipelineFunctions.countAll().as('n'),
            field('pages').sum().as('n'),
          ]),
          duplicateError('n', 'accumulators'),
        );
      });

      test('aggregate rejects a repeated group', () {
        expect(
          () => base().aggregate(
            [PipelineFunctions.countAll().as('n')],
            groups: ['genre', PipelineFunctions.toLower('genre').as('genre')],
          ),
          duplicateError('genre', 'groups'),
        );
      });

      test('aggregate checks accumulators and groups separately', () {
        // The Node SDK builds the two maps independently, so a group and an
        // accumulator sharing a name is left for the backend to judge.
        expect(
          () => base().aggregate(
            [PipelineFunctions.countAll().as('genre')],
            groups: ['genre'],
          ),
          returnsNormally,
        );
      });

      test('distinct rejects a repeated group', () {
        expect(
          () => base().distinct(['genre', field('genre')]),
          duplicateError('genre', 'groups'),
        );
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

      test('split always sends the field and its delimiter', () async {
        await run(
          firestore.pipeline().collection('books').select([
            PipelineFunctions.split('csv', ',').as('static'),
            field('csv').split(',').as('fluent'),
            PipelineFunctions.split('csv', null).as('nullDelimiter'),
          ]),
        );

        final fields = stages[1].args.single.mapValue!.fields;
        for (final alias in ['static', 'fluent']) {
          final function = fields[alias]!.functionValue!;
          expect(function.name, 'split');
          expect(function.args, hasLength(2), reason: alias);
          expect(function.args[0].fieldReferenceValue, 'csv', reason: alias);
          expect(function.args[1].stringValue, ',', reason: alias);
        }

        // Regression: the static form made the delimiter optional and dropped
        // a null one, emitting a one-argument `split` the backend rejects.
        // Like Node, a null delimiter is now sent as a null constant.
        final nullDelimiter = fields['nullDelimiter']!.functionValue!;
        expect(nullDelimiter.args, hasLength(2));
        expect(
          nullDelimiter.args[1].nullValue,
          protobuf_v1.NullValue.nullValue,
        );
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

      test('map_remove sends exactly one key per call', () async {
        await run(
          firestore.pipeline().collection('books').select([
            PipelineFunctions.mapRemove('metadata', 'lang').as('static'),
            field('metadata').mapRemove(constant('lang')).as('expressionKey'),
            field('metadata').mapRemove('lang').mapRemove('draft').as('chain'),
          ]),
        );

        final fields = stages[1].args.single.mapValue!.fields;

        // Regression: the key used to be an Iterable spread into a variadic
        // `map_remove(map, ...keys)`; the backend contract is (map, key).
        final static = fields['static']!.functionValue!;
        expect(static.name, 'map_remove');
        expect(static.args, hasLength(2));
        expect(static.args[0].fieldReferenceValue, 'metadata');
        // A String key is a literal, not a field reference, as in Node.
        expect(static.args[1].stringValue, 'lang');
        expect(static.args[1].fieldReferenceValue, isNull);

        final expressionKey = fields['expressionKey']!.functionValue!;
        expect(expressionKey.args, hasLength(2));
        expect(expressionKey.args[1].stringValue, 'lang');

        final outer = fields['chain']!.functionValue!;
        expect(outer.name, 'map_remove');
        expect(outer.args, hasLength(2));
        expect(outer.args[1].stringValue, 'draft');
        final inner = outer.args[0].functionValue!;
        expect(inner.name, 'map_remove');
        expect(inner.args, hasLength(2));
        expect(inner.args[0].fieldReferenceValue, 'metadata');
        expect(inner.args[1].stringValue, 'lang');
      });

      test('map_remove rejects an Iterable of keys', () {
        expect(
          () => field('metadata').mapRemove(['lang', 'draft']),
          throwsArgumentError,
        );
        expect(
          () => PipelineFunctions.mapRemove('metadata', ['lang']),
          throwsArgumentError,
        );
      });
    });

    group('vector arguments', () {
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

      Pipeline base() => firestore.pipeline().collection('books');

      void expectVector(firestore_v1.Value value, List<double> expected) {
        expect(value.arrayValue, isNull, reason: 'a vector is not an ARRAY');
        final fields = value.mapValue!.fields;
        expect(fields['__type__']!.stringValue, '__vector__');
        expect(
          fields['value']!.arrayValue!.values.map((v) => v.doubleValue),
          expected,
        );
      }

      Future<Map<String, firestore_v1.Value>> selectAll(
        Object? Function() vector,
      ) async {
        await run(
          base().select([
            PipelineFunctions.cosineDistance(
              'embedding',
              vector(),
            ).as('cosine'),
            PipelineFunctions.dotProduct('embedding', vector()).as('dot'),
            PipelineFunctions.euclideanDistance(
              'embedding',
              vector(),
            ).as('euclidean'),
            field('embedding').cosineDistance(vector()).as('fluentCosine'),
            field('embedding').dotProduct(vector()).as('fluentDot'),
            field(
              'embedding',
            ).euclideanDistance(vector()).as('fluentEuclidean'),
          ]),
        );
        return stages[1].args.single.mapValue!.fields;
      }

      test('encode a List<double> as a vector', () async {
        // Regression: a plain list used to encode as an ARRAY, which the
        // backend rejects with "requires `Vector` but got `ARRAY`".
        final fields = await selectAll(() => const [1.0, 0.0, 0.5]);

        expect(fields, hasLength(6));
        for (final entry in fields.entries) {
          final function = entry.value.functionValue!;
          expect(function.args[0].fieldReferenceValue, 'embedding');
          expectVector(function.args[1], [1.0, 0.0, 0.5]);
        }
      });

      test('encode a List<int> as a vector of doubles', () async {
        final fields = await selectAll(() => const [1, 2, 3]);

        for (final function in fields.values) {
          expectVector(function.functionValue!.args[1], [1.0, 2.0, 3.0]);
        }
      });

      test('encode an untyped list of numbers as a vector', () async {
        // As decoded from JSON, for instance.
        final fields = await selectAll(() => <dynamic>[1, 2.5]);

        for (final function in fields.values) {
          expectVector(function.functionValue!.args[1], [1.0, 2.5]);
        }
      });

      test('keep a VectorValue as a vector', () async {
        final fields = await selectAll(() => FieldValue.vector([1, 2, 3]));

        for (final function in fields.values) {
          expectVector(function.functionValue!.args[1], [1.0, 2.0, 3.0]);
        }
      });

      test('pass expressions through', () async {
        final fieldFunctions = await selectAll(() => field('other'));
        for (final function in fieldFunctions.values) {
          expect(function.functionValue!.args[1].fieldReferenceValue, 'other');
        }

        final constantFunctions = await selectAll(
          () => Expression.vector([1, 2, 3]),
        );
        for (final function in constantFunctions.values) {
          expectVector(function.functionValue!.args[1], [1.0, 2.0, 3.0]);
        }
      });

      test('reject a list that is not all numbers', () {
        expect(
          () => PipelineFunctions.cosineDistance('embedding', [1, 'two']),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => field('embedding').dotProduct([field('x')]),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => base().findNearest(
            vectorField: 'embedding',
            queryVector: ['1'],
            distanceMeasure: DistanceMeasure.cosine,
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      group('findNearest', () {
        Future<firestore_v1.Value> queryVectorOf(Object queryVector) async {
          await run(
            base().findNearest(
              vectorField: 'embedding',
              queryVector: queryVector,
              distanceMeasure: DistanceMeasure.euclidean,
            ),
          );
          final stage = stages.last;
          expect(stage.name, 'find_nearest');
          expect(stage.args[0].fieldReferenceValue, 'embedding');
          expect(stage.args[2].stringValue, 'euclidean');
          return stage.args[1];
        }

        test('encodes a List<double> as a vector', () async {
          expectVector(await queryVectorOf(const [1.0, 2.0]), [1.0, 2.0]);
        });

        test('encodes a List<int> as a vector of doubles', () async {
          expectVector(await queryVectorOf(const [1, 2]), [1.0, 2.0]);
        });

        test('keeps a VectorValue as a vector', () async {
          expectVector(await queryVectorOf(FieldValue.vector([1, 2])), [
            1.0,
            2.0,
          ]);
        });

        test('passes expressions through', () async {
          expectVector(await queryVectorOf(Expression.vector([1, 2])), [
            1.0,
            2.0,
          ]);
          expect(
            (await queryVectorOf(field('target'))).fieldReferenceValue,
            'target',
          );
        });
      });
    });

    // The backend rejects expressions nested inside a literal array or map
    // value ("Value type is not supported: FIELD_REFERENCE_VALUE"), so
    // collections holding them must be built with array(...) / map(...).
    group('Collections holding expressions', () {
      late Map<String, firestore_v1.Value> fields;

      Future<void> run(Iterable<PipelineAliasedExpression> selections) async {
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
            .select(selections)
            .execute();
        final stages = capturedRequest!.structuredPipeline!.pipeline!.stages;
        fields = stages[1].args.single.mapValue!.fields;
      }

      firestore_v1.Function$ function(String alias) {
        return fields[alias]!.functionValue!;
      }

      /// Expects [value] to be `array(field(score), 5)`.
      void expectMixedArray(firestore_v1.Value value) {
        final array = value.functionValue!;
        expect(array.name, 'array');
        expect(array.args, hasLength(2));
        expect(array.args[0].fieldReferenceValue, 'score');
        expect(array.args[1].integerValue, 5);
        expect(value.arrayValue, isNull);
      }

      test('equalAny and notEqualAny build an array function', () async {
        final values = [field('score'), 5];
        await run([
          PipelineFunctions.equalAny('rating', values).as('static'),
          field('rating').equalAny(values).as('fluent'),
          PipelineFunctions.notEqualAny('rating', values).as('notStatic'),
          field('rating').notEqualAny(values).as('notFluent'),
        ]);

        for (final alias in ['static', 'fluent']) {
          expect(function(alias).name, 'equal_any');
          expect(function(alias).args[0].fieldReferenceValue, 'rating');
          expectMixedArray(function(alias).args[1]);
        }
        for (final alias in ['notStatic', 'notFluent']) {
          expect(function(alias).name, 'not_equal_any');
          expect(function(alias).args[0].fieldReferenceValue, 'rating');
          expectMixedArray(function(alias).args[1]);
        }
      });

      test(
        'arrayContainsAll and arrayContainsAny build an array function',
        () async {
          final values = [field('score'), 5];
          await run([
            PipelineFunctions.arrayContainsAll('tags', values).as('allStatic'),
            field('tags').arrayContainsAll(values).as('allFluent'),
            PipelineFunctions.arrayContainsAny('tags', values).as('anyStatic'),
            field('tags').arrayContainsAny(values).as('anyFluent'),
          ]);

          for (final alias in ['allStatic', 'allFluent']) {
            expect(function(alias).name, 'array_contains_all');
            expectMixedArray(function(alias).args[1]);
          }
          for (final alias in ['anyStatic', 'anyFluent']) {
            expect(function(alias).name, 'array_contains_any');
            expectMixedArray(function(alias).args[1]);
          }
        },
      );

      test('search spaces of plain values stay literal arrays', () async {
        // Matches the Node SDK, which sends these as a literal array value.
        await run([
          PipelineFunctions.equalAny('genre', ['fiction', 'poetry']).as('eq'),
          field('genre').notEqualAny(['fiction']).as('notEq'),
          PipelineFunctions.arrayContainsAll('tags', ['a', 'b']).as('all'),
          field('tags').arrayContainsAny(['a', constant('b')]).as('any'),
          field('genre').equalAny(field('genres')).as('expression'),
        ]);

        for (final alias in ['eq', 'notEq', 'all', 'any']) {
          final searchSpace = function(alias).args[1];
          expect(searchSpace.functionValue, isNull, reason: alias);
          expect(searchSpace.arrayValue, isNotNull, reason: alias);
        }
        expect(
          function('any').args[1].arrayValue!.values.map((v) => v.stringValue),
          ['a', 'b'],
        );
        expect(function('expression').args[1].fieldReferenceValue, 'genres');
      });

      test('static and fluent forms encode identically', () async {
        final values = [field('score'), 5, 'x'];
        await run([
          PipelineFunctions.equalAny('rating', values).as('a'),
          field('rating').equalAny(values).as('b'),
          PipelineFunctions.arrayContainsAll('tags', values).as('c'),
          field('tags').arrayContainsAll(values).as('d'),
          PipelineFunctions.arrayContainsAll('tags', ['x']).as('e'),
          field('tags').arrayContainsAll(['x']).as('f'),
        ]);

        expect(fields['a']!.toJson(), fields['b']!.toJson());
        expect(fields['c']!.toJson(), fields['d']!.toJson());
        expect(fields['e']!.toJson(), fields['f']!.toJson());
      });

      test('mapMerge builds a map function', () async {
        await run([
          PipelineFunctions.mapMerge([
            'metadata',
            {'reviewer': field('editor'), 'lang': 'dart'},
          ]).as('static'),
          field('metadata')
              .mapMerge([
                {'reviewer': field('editor'), 'lang': 'dart'},
              ])
              .as('fluent'),
          field('metadata').mapMerge([<String, Object?>{}]).as('empty'),
        ]);

        for (final alias in ['static', 'fluent']) {
          final merge = function(alias);
          expect(merge.name, 'map_merge');
          expect(merge.args[0].fieldReferenceValue, 'metadata');
          final map = merge.args[1].functionValue!;
          expect(map.name, 'map');
          expect(map.args.map((arg) => arg.toJson()), [
            {'stringValue': 'reviewer'},
            {'fieldReferenceValue': 'editor'},
            {'stringValue': 'lang'},
            {'stringValue': 'dart'},
          ]);
        }

        final empty = function('empty').args[1].functionValue!;
        expect(empty.name, 'map');
        expect(empty.args, isEmpty);
      });

      test('nested collections are built recursively', () async {
        await run([
          PipelineFunctions.array([
            1,
            [field('title')],
            {'published': field('published')},
          ]).as('array'),
          PipelineFunctions.map([
            'nested',
            {'price': field('price')},
          ]).as('map'),
        ]);

        final array = function('array');
        expect(array.name, 'array');
        expect(array.args[0].integerValue, 1);
        final inner = array.args[1].functionValue!;
        expect(inner.name, 'array');
        expect(inner.args.single.fieldReferenceValue, 'title');
        final innerMap = array.args[2].functionValue!;
        expect(innerMap.name, 'map');
        expect(innerMap.args[0].stringValue, 'published');
        expect(innerMap.args[1].fieldReferenceValue, 'published');

        final map = function('map');
        expect(map.args[0].stringValue, 'nested');
        final nested = map.args[1].functionValue!;
        expect(nested.name, 'map');
        expect(nested.args[1].fieldReferenceValue, 'price');
      });

      test('apply to every value position', () async {
        await run([
          PipelineFunctions.arrayConcat([
            'tags',
            [field('title')],
          ]).as('concat'),
          field('tags').arrayConcat([field('title')]).as('fluentConcat'),
          field('tags').arrayContains([field('title')]).as('contains'),
          equal('tags', [field('title')]).as('topLevelEqual'),
          PipelineFunctions.equal('tags', [field('title')]).as('staticEqual'),
          field('tags').equal([field('title')]).as('fluentEqual'),
          field(
            'metadata',
          ).mapSet('reviewer', {'name': field('editor')}).as('mapSet'),
          PipelineFunctions.conditional(field('active'), [
            field('title'),
          ], const <Object?>[]).as('conditional'),
          field('tags').ifAbsent([field('title')]).as('ifAbsent'),
          PipelineFunctions.logicalMaximum('tags', [field('title')]).as('max'),
        ]);

        for (final alias in [
          'concat',
          'fluentConcat',
          'contains',
          'topLevelEqual',
          'staticEqual',
          'fluentEqual',
          'ifAbsent',
          'max',
        ]) {
          final array = function(alias).args[1].functionValue;
          expect(array?.name, 'array', reason: alias);
          expect(array!.args.single.fieldReferenceValue, 'title');
        }

        final mapSet = function('mapSet');
        expect(mapSet.args[1].stringValue, 'reviewer');
        expect(mapSet.args[2].functionValue!.name, 'map');

        final conditional = function('conditional');
        expect(conditional.args[1].functionValue!.name, 'array');
        expect(conditional.args[2].functionValue!.name, 'array');
        expect(conditional.args[2].functionValue!.args, isEmpty);
      });

      test('constant and raw keep collections literal', () async {
        await run([
          field('tags').equal(constant(['a', 'b'])).as('constant'),
          PipelineFunctions.raw('array_length', [
            ['a', 'b'],
          ]).as('raw'),
          field('bytes').equal(Uint8List.fromList([1, 2])).as('bytes'),
        ]);

        expect(
          function(
            'constant',
          ).args[1].arrayValue!.values.map((v) => v.stringValue),
          ['a', 'b'],
        );
        expect(
          function(
            'raw',
          ).args.single.arrayValue!.values.map((v) => v.stringValue),
          ['a', 'b'],
        );
        expect(function('bytes').args[1].bytesValue, isNotNull);
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
      expect(fields['maxNumber']!.functionValue!.name, 'maximum');
      expect(fields['minNumber']!.functionValue!.name, 'minimum');
      expect(fields['top2']!.functionValue!.name, 'maximum_n');
      expect(fields['bottom2']!.functionValue!.name, 'minimum_n');
      expect(fields['total']!.functionValue!.name, 'sum');
      expect(fields['rows']!.functionValue!.name, 'count');
      expect(fields['rows']!.functionValue!.args, isEmpty);
    });

    test('round and trunc forward optional decimal places', () async {
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

      await firestore.pipeline().collection('books').select([
        field('price').round().as('round'),
        // Regression: the fluent form used to take no argument at all.
        field('price').round(2).as('round2'),
        field('price').round(field('places')).as('roundExpr'),
        field('price').trunc().as('trunc'),
        field('price').trunc(2).as('trunc2'),
        field('price').trunc(field('places')).as('truncExpr'),
        PipelineFunctions.round('price').as('staticRound'),
        PipelineFunctions.round('price', 2).as('staticRound2'),
        PipelineFunctions.round(
          'price',
          Expression.constant(2),
        ).as('staticRoundExpr'),
        PipelineFunctions.trunc('price').as('staticTrunc'),
        PipelineFunctions.trunc('price', 2).as('staticTrunc2'),
      ]).execute();

      final fields = capturedRequest!
          .structuredPipeline!
          .pipeline!
          .stages[1]
          .args
          .single
          .mapValue!
          .fields;

      for (final MapEntry(key: alias, value: value) in fields.entries) {
        final function = value.functionValue!;
        expect(
          function.name,
          alias.toLowerCase().contains('round') ? 'round' : 'trunc',
          reason: alias,
        );
        expect(function.args[0].fieldReferenceValue, 'price', reason: alias);
      }

      // Without decimal places only the operand is sent, matching Node.
      for (final alias in ['round', 'trunc', 'staticRound', 'staticTrunc']) {
        expect(fields[alias]!.functionValue!.args, hasLength(1), reason: alias);
      }

      for (final alias in [
        'round2',
        'trunc2',
        'staticRound2',
        'staticTrunc2',
      ]) {
        final args = fields[alias]!.functionValue!.args;
        expect(args, hasLength(2), reason: alias);
        expect(args[1].integerValue, 2, reason: alias);
      }

      for (final alias in ['roundExpr', 'truncExpr']) {
        final args = fields[alias]!.functionValue!.args;
        expect(args, hasLength(2), reason: alias);
        expect(args[1].fieldReferenceValue, 'places', reason: alias);
      }

      final staticRoundExpr = fields['staticRoundExpr']!.functionValue!.args;
      expect(staticRoundExpr, hasLength(2));
      expect(staticRoundExpr[1].integerValue, 2);
    });

    test('array aggregation helpers encode like their fluent forms', () async {
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

      final numbers = field('numbers');
      await firestore.pipeline().collection('books').select([
        PipelineFunctions.arrayMaximum('numbers').as('max'),
        numbers.arrayMaximum().as('maxFluent'),
        PipelineFunctions.arrayMaximumN('numbers', 2).as('maxN'),
        numbers.arrayMaximumN(2).as('maxNFluent'),
        PipelineFunctions.arrayMinimum('numbers').as('min'),
        numbers.arrayMinimum().as('minFluent'),
        PipelineFunctions.arrayMinimumN('numbers', 2).as('minN'),
        numbers.arrayMinimumN(2).as('minNFluent'),
        PipelineFunctions.arraySum('numbers').as('sum'),
        numbers.arraySum().as('sumFluent'),
      ]).execute();

      final fields = capturedRequest!
          .structuredPipeline!
          .pipeline!
          .stages[1]
          .args
          .single
          .mapValue!
          .fields;

      // Regression: the static helpers used to emit `array_maximum`,
      // `array_maximum_n`, `array_minimum`, `array_minimum_n` and `array_sum`,
      // which the backend rejects with "The function 'array_maximum' does not
      // exist, did you mean 'maximum'?". Node emits the unprefixed names.
      const expectedNames = {
        'max': 'maximum',
        'maxN': 'maximum_n',
        'min': 'minimum',
        'minN': 'minimum_n',
        'sum': 'sum',
      };
      for (final MapEntry(key: alias, value: name) in expectedNames.entries) {
        final helper = fields[alias]!.functionValue!;
        final fluent = fields['${alias}Fluent']!.functionValue!;

        expect(helper.name, name, reason: alias);
        expect(helper.args.first.fieldReferenceValue, 'numbers', reason: alias);
        expect(
          helper.toJson(),
          fluent.toJson(),
          reason: '$alias should encode exactly like its fluent form',
        );
      }
      expect(fields['maxN']!.functionValue!.args[1].integerValue, 2);
      expect(fields['minN']!.functionValue!.args[1].integerValue, 2);
    });

    group('Node SDK signatures', () {
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

      Future<Map<String, firestore_v1.Value>> select(
        Iterable<PipelineAliasedExpression> selections,
      ) async {
        await run(firestore.pipeline().collection('books').select(selections));
        return stages[1].args.single.mapValue!.fields;
      }

      group('variadic add and multiply', () {
        for (final (name, static, fluent) in [
          (
            'add',
            PipelineFunctions.add,
            (PipelineExpression e, Object? second, Iterable<Object?> others) =>
                e.add(second, others),
          ),
          (
            'multiply',
            PipelineFunctions.multiply,
            (PipelineExpression e, Object? second, Iterable<Object?> others) =>
                e.multiply(second, others),
          ),
        ]) {
          test('$name sends every operand to one $name call', () async {
            final fields = await select([
              static('rating', 2, [field('bonus'), 3]).as('static'),
              fluent(field('rating'), 2, [field('bonus'), 3]).as('fluent'),
            ]);

            for (final alias in ['static', 'fluent']) {
              final function = fields[alias]!.functionValue!;
              expect(function.name, name, reason: alias);
              expect(function.args.map((arg) => arg.toJson()), [
                {'fieldReferenceValue': 'rating'},
                {'integerValue': '2'},
                {'fieldReferenceValue': 'bonus'},
                {'integerValue': '3'},
              ], reason: alias);
            }
          });

          test('$name still takes exactly two operands', () async {
            final fields = await select([
              static('rating', 2).as('static'),
              fluent(field('rating'), 2, const []).as('fluent'),
            ]);

            for (final alias in ['static', 'fluent']) {
              final function = fields[alias]!.functionValue!;
              expect(function.name, name, reason: alias);
              expect(function.args, hasLength(2), reason: alias);
            }
          });
        }

        test('collections among the operands are built as functions', () async {
          final fields = await select([
            PipelineFunctions.add('a', 1, [
              [field('b')],
            ]).as('sum'),
          ]);

          final operand = fields['sum']!.functionValue!.args[2];
          expect(operand.functionValue!.name, 'array');
          expect(operand.functionValue!.args.single.fieldReferenceValue, 'b');
        });
      });

      group('documents', () {
        test('takes document paths', () async {
          await run(
            firestore.pipeline().documents([
              'books/book-1',
              '/books/book-2',
              'authors/author-1/books/book-3',
            ]),
          );

          final stage = stages.single;
          expect(stage.name, 'documents');
          expect(stage.args.map((arg) => arg.referenceValue), [
            '/books/book-1',
            '/books/book-2',
            '/authors/author-1/books/book-3',
          ]);
        });

        test('mixes paths and references', () async {
          await run(
            firestore.pipeline().documents([
              'books/book-1',
              firestore.doc('books/book-2'),
            ]),
          );

          expect(stages.single.args.map((arg) => arg.referenceValue), [
            '/books/book-1',
            '/books/book-2',
          ]);
        });

        test('rejects paths that do not point to a document', () {
          for (final path in ['books', 'authors/author-1/books', '', 'a//b']) {
            expect(
              () => firestore.pipeline().documents([path]),
              throwsArgumentError,
              reason: path,
            );
          }
        });

        test('rejects values that are neither paths nor references', () {
          expect(
            () => firestore.pipeline().documents([firestore.collection('a')]),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                contains('DocumentReference or a document path'),
              ),
            ),
          );
        });

        test('rejects an empty list', () {
          expect(
            () => firestore.pipeline().documents(const <String>[]),
            throwsArgumentError,
          );
        });
      });

      group('PipelineOrdering', () {
        test('exposes its expression and direction', () {
          final rating = field('rating');
          final ascendingOrdering = rating.ascending();
          final descendingOrdering = rating.descending();

          expect(ascendingOrdering.expr, same(rating));
          expect(ascendingOrdering.direction, 'ascending');
          expect(descendingOrdering.expr, same(rating));
          expect(descendingOrdering.direction, 'descending');
        });

        test('reads a field name passed to the top-level helpers', () {
          for (final (ordering, direction) in [
            (ascending('rating'), 'ascending'),
            (descending('rating'), 'descending'),
          ]) {
            expect(
              ordering.expr,
              isA<PipelineField>().having((f) => f.path, 'path', 'rating'),
            );
            expect(ordering.direction, direction);
          }
        });
      });

      group('map', () {
        test('takes a Map, encoded like alternating keys and values', () async {
          final fields = await select([
            PipelineFunctions.map({
              'title': field('title'),
              'rating': 5,
              'nested': {'genre': field('genre')},
              'list': [field('tags'), 1],
            }).as('fromMap'),
            PipelineFunctions.map([
              'title',
              field('title'),
              'rating',
              5,
              'nested',
              {'genre': field('genre')},
              'list',
              [field('tags'), 1],
            ]).as('fromIterable'),
          ]);

          final fromMap = fields['fromMap']!.functionValue!;
          expect(fromMap.name, 'map');
          expect(fromMap.args[0].stringValue, 'title');
          expect(fromMap.args[1].fieldReferenceValue, 'title');
          expect(fromMap.args[5].functionValue!.name, 'map');
          expect(fromMap.args[7].functionValue!.name, 'array');
          expect(
            fromMap.toJson(),
            fields['fromIterable']!.functionValue!.toJson(),
          );
        });

        test('takes an empty Map', () async {
          final fields = await select([
            PipelineFunctions.map(<String, Object?>{}).as('empty'),
          ]);

          final function = fields['empty']!.functionValue!;
          expect(function.name, 'map');
          expect(function.args, isEmpty);
        });

        test('rejects values that are neither a Map nor an Iterable', () {
          expect(() => PipelineFunctions.map('title'), throwsArgumentError);
          expect(() => PipelineFunctions.map(field('a')), throwsArgumentError);
        });
      });
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

      /// The (field, direction) pairs of the last sort stage.
      List<(String?, String?)> sortOrder() => [
        for (final arg in stages.lastWhere((s) => s.name == 'sort').args)
          (
            arg.mapValue!.fields['expression']!.fieldReferenceValue,
            arg.mapValue!.fields['direction']!.stringValue,
          ),
      ];

      test('orders by != and not-in fields like range fields', () async {
        // Regression: '!=' and 'not-in' fields were left out of the implicit
        // ordering, so the Pipeline sorted only by the document key.
        await run(
          firestore
              .collection('books')
              .where('rating', WhereFilter.greaterThan, 4)
              .where('genre', WhereFilter.notEqual, 'Horror')
              .where('author', WhereFilter.notIn, ['Anonymous']),
        );

        // Inequality fields in field path order, then the document key.
        expect(sortOrder(), [
          ('author', 'ascending'),
          ('genre', 'ascending'),
          ('rating', 'ascending'),
          ('__name__', 'ascending'),
        ]);
      });

      test('sorts inequality fields by segment, not quoted path', () async {
        await run(
          firestore
              .collection('books')
              .where('price-tier', WhereFilter.lessThan, 3)
              .where('price.amount', WhereFilter.greaterThan, 1),
        );

        // `price-tier` is quoted on the wire, but `price` sorts first.
        expect(sortOrder().map((order) => order.$1), [
          'price.amount',
          '`price-tier`',
          '__name__',
        ]);
      });

      test('implicit orderings take the last explicit direction', () async {
        await run(
          firestore
              .collection('books')
              .where('genre', WhereFilter.notIn, ['Horror'])
              .orderBy('rating', descending: true),
        );

        expect(sortOrder(), [
          ('rating', 'descending'),
          ('genre', 'descending'),
          ('__name__', 'descending'),
        ]);

        // Existence checks cover the explicit ordering and the key; the
        // inequality filter brings its own (none, for not-in).
        final exists = stages[2].args.single.functionValue!;
        expect(exists.name, 'and');
        expect(
          exists.args.map(
            (arg) => arg.functionValue!.args.single.fieldReferenceValue,
          ),
          ['rating', '__name__'],
        );
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
        // The root ancestor comes first, as in the Node SDK.
        expect(stages.first.args, hasLength(2));
        expect(stages.first.args[0].referenceValue, '');
        expect(stages.first.args[1].stringValue, 'books');
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

      test('flips cursor comparisons for descending orderings', () async {
        // Regression: cursors compared as if every ordering were ascending
        // (as Node does), so startAt(4) on a descending rating kept ratings of
        // 4 and more instead of 4 and less.
        await run(
          firestore
              .collection('books')
              .orderBy('rating', descending: true)
              .orderBy('title')
              .startAt([4, 'M'])
              .endBefore([1]),
        );

        expect(stages.map((stage) => stage.name), [
          'collection',
          'where', // existence checks
          'sort',
          'where', // startAt
          'where', // endBefore
        ]);

        // rating < 4 || (rating == 4 && (title > 'M' || title == 'M'))
        final startAt = stages[3].args.single.functionValue!;
        expect(startAt.name, 'or');
        expect(startAt.args[0].functionValue!.name, 'less_than');
        final tie = startAt.args[1].functionValue!;
        expect(tie.args[0].functionValue!.name, 'equal');
        final title = tie.args[1].functionValue!;
        expect(title.args[0].functionValue!.name, 'greater_than');
        expect(title.args[1].functionValue!.name, 'equal');

        // endBefore(1) on the descending rating keeps ratings above 1.
        final endBefore = stages[4].args.single.functionValue!;
        expect(endBefore.name, 'greater_than');
        expect(endBefore.args[1].integerValue, 1);
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
        final queryVector = findNearest.args[1].mapValue!.fields;
        expect(queryVector['__type__']!.stringValue, '__vector__');
        expect(
          queryVector['value']!.arrayValue!.values.map((v) => v.doubleValue),
          [1.0, 2.0, 3.0],
        );
        // Pipelines take a lowercase distance measure even though the
        // DistanceMeasure enum keeps the uppercase proto values.
        expect(findNearest.args[2].stringValue, 'cosine');
        expect(findNearest.options['limit']!.integerValue, 5);
        expect(
          findNearest.options['distance_field']!.fieldReferenceValue,
          'distance',
        );
      });

      group('applies a VectorQuery distanceThreshold as a filter', () {
        Future<firestore_v1.Function$> runThreshold(
          DistanceMeasure distanceMeasure, {
          String? distanceResultField,
        }) async {
          await run(
            firestore
                .collection('books')
                .findNearest(
                  vectorField: 'embedding',
                  queryVector: [1.0, 2.0, 3.0],
                  limit: 5,
                  distanceMeasure: distanceMeasure,
                  distanceResultField: distanceResultField,
                  distanceThreshold: 0.5,
                ),
          );

          // find_nearest documents no threshold option, so none is sent.
          final findNearest = stages[stages.length - 2];
          expect(findNearest.name, 'find_nearest');
          expect(
            findNearest.options.keys,
            isNot(contains('distance_threshold')),
          );

          final where = stages.last;
          expect(where.name, 'where');
          final condition = where.args.single.functionValue!;
          expect(condition.args[1].doubleValue, 0.5);
          return condition;
        }

        test('keeps euclidean distances at most the threshold', () async {
          final condition = await runThreshold(DistanceMeasure.euclidean);

          expect(condition.name, 'less_than_or_equal');
          final distance = condition.args[0].functionValue!;
          expect(distance.name, 'euclidean_distance');
          expect(distance.args[0].fieldReferenceValue, 'embedding');
          expect(
            distance.args[1].mapValue!.fields['value']!.arrayValue!.values.map(
              (v) => v.doubleValue,
            ),
            [1.0, 2.0, 3.0],
          );
        });

        test('keeps cosine distances at most the threshold', () async {
          final condition = await runThreshold(DistanceMeasure.cosine);

          expect(condition.name, 'less_than_or_equal');
          expect(condition.args[0].functionValue!.name, 'cosine_distance');
        });

        test('keeps dot products at least the threshold', () async {
          // A larger dot product means more similar vectors.
          final condition = await runThreshold(DistanceMeasure.dotProduct);

          expect(condition.name, 'greater_than_or_equal');
          expect(condition.args[0].functionValue!.name, 'dot_product');
        });

        test('reads the distance result field when there is one', () async {
          final condition = await runThreshold(
            DistanceMeasure.euclidean,
            distanceResultField: 'distance',
          );

          expect(condition.name, 'less_than_or_equal');
          expect(condition.args[0].fieldReferenceValue, 'distance');
          expect(
            stages[stages.length - 2]
                .options['distance_field']!
                .fieldReferenceValue,
            'distance',
          );
        });
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
