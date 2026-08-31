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

import 'dart:io';
import 'dart:typed_data';

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

const _projectIdEnv = 'FIRESTORE_PIPELINE_E2E_PROJECT_ID';
const _databaseIdEnv = 'FIRESTORE_PIPELINE_E2E_DATABASE_ID';
const _collectionPath = 'pipeline_e2e_books';

void main() {
  final projectId =
      Platform.environment[_projectIdEnv] ??
      Platform.environment['GOOGLE_CLOUD_PROJECT'] ??
      Platform.environment['GCLOUD_PROJECT'];
  // No '(default)' fallback on purpose. CI credential helpers such as
  // google-github-actions/auth export GOOGLE_CLOUD_PROJECT, so a project-only
  // guard would silently arm this suite against whatever project happened to
  // be authenticated, using its default database — which may be Standard
  // edition (no Pipelines at all) or simply lack the vector index this suite
  // needs. Both variables must be set deliberately.
  final databaseId = Platform.environment[_databaseIdEnv];
  final shouldRun =
      projectId != null &&
      projectId.isNotEmpty &&
      databaseId != null &&
      databaseId.isNotEmpty;

  group('Firestore Pipeline E2E', skip: shouldRun ? null : _skipReason, () {
    late Firestore firestore;
    late String runId;
    late List<DocumentReference<DocumentData>> docs;

    setUp(() async {
      firestore = Firestore(
        settings: Settings(projectId: projectId, databaseId: databaseId),
      );
      runId = 'run_${DateTime.now().microsecondsSinceEpoch}';
      docs = [
        firestore.doc('$_collectionPath/${runId}_book_1'),
        firestore.doc('$_collectionPath/${runId}_book_2'),
        firestore.doc('$_collectionPath/${runId}_book_3'),
      ];

      await Future.wait([
        docs[0].set({
          'runId': runId,
          'title': 'Dart Pipelines',
          'active': true,
          'price': 10,
          'rating': 5,
          'discount': 2,
          'score': -12.7,
          'flags': 6,
          'bytes': Uint8List.fromList([0x0f, 0xf0]),
          'tags': ['dart', 'firebase'],
          'numbers': [3, 1, 2, 3],
          'words': ['dart', 'firebase'],
          'metadata': {'lang': 'dart', 'category': 'sdk'},
          'pathRef': docs[1],
          'nullable': null,
          'spaced': '  Dart  ',
          'csv': 'dart,firebase,admin',
          'createdAt': Timestamp(seconds: 1700000000, nanoseconds: 0),
          'embedding': FieldValue.vector([1, 0, 0]),
        }),
        docs[1].set({
          'runId': runId,
          'title': 'Firestore Admin',
          'active': true,
          'price': 20,
          'rating': 4,
          'discount': 3,
          'score': 3.2,
          'flags': 3,
          'bytes': Uint8List.fromList([0xaa, 0x55]),
          'tags': ['firebase'],
          'numbers': [4, 5],
          'words': ['firebase'],
          'metadata': {'lang': 'dart', 'category': 'admin'},
          'pathRef': docs[0],
          'nullable': null,
          'spaced': ' Admin ',
          'csv': 'firestore,admin',
          'createdAt': Timestamp(seconds: 1700003600, nanoseconds: 0),
          'embedding': FieldValue.vector([0, 1, 0]),
        }),
        docs[2].set({
          'runId': runId,
          'title': 'Inactive Draft',
          'active': false,
          'price': 30,
          'rating': 2,
          'discount': 4,
          'score': 8.9,
          'flags': 5,
          'bytes': Uint8List.fromList([0xff, 0x00]),
          'tags': ['draft'],
          'numbers': [9],
          'words': ['draft'],
          'metadata': {'lang': 'dart', 'category': 'draft'},
          'pathRef': docs[0],
          'nullable': null,
          'spaced': ' Draft ',
          'csv': 'inactive,draft',
          'createdAt': Timestamp(seconds: 1700007200, nanoseconds: 0),
          'embedding': FieldValue.vector([0, 0, 1]),
        }),
      ]);
    });

    tearDown(() async {
      await Future.wait([for (final doc in docs) doc.delete()]);
    });

    test('executes a real pipeline with expressions and metadata', () async {
      final snapshot = await firestore
          .pipeline()
          .collection(_collectionPath)
          .where(_runFilter(runId, Expression.field('active').asBoolean()))
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

      final metadataSnapshot = await firestore
          .pipeline()
          .collection(_collectionPath)
          .where(
            _runFilter(
              runId,
              Expression.field('title').equal('Dart Pipelines'),
            ),
          )
          .limit(1)
          .execute();

      expect(metadataSnapshot.results.single.createTime, isNotNull);
      expect(metadataSnapshot.results.single.updateTime, isNotNull);
      expect(metadataSnapshot.results.single.document, isNotNull);
    });

    test('executes aggregate pipeline stages', () async {
      final aggregateSnapshot = await firestore
          .pipeline()
          .collection(_collectionPath)
          .where(_runFilter(runId, Expression.field('active').equal(true)))
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

    test('executes a pipeline inside a transaction', () async {
      final titles = await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.executePipeline(
          firestore
              .pipeline()
              .collection(_collectionPath)
              .where(_runFilter(runId, Expression.field('active').equal(true)))
              .sort([Expression.field('price').ascending()])
              .select([Expression.field('title')]),
        );
        return [for (final result in snapshot.results) result.get('title')];
      }, transactionOptions: ReadOnlyTransactionOptions());

      expect(titles, ['Dart Pipelines', 'Firestore Admin']);
    });

    test('executes a documents source stage', () async {
      final snapshot = await firestore
          .pipeline()
          .documents([docs[0], docs[2]])
          .sort([Expression.field('price').ascending()])
          .select([Expression.field('title')])
          .execute();

      expect(snapshot.results.map((result) => result.get('title')), [
        'Dart Pipelines',
        'Inactive Draft',
      ]);
    });

    group('function catalog', () {
      for (final scenario in _functionScenarios) {
        test(scenario.name, () async {
          final snapshot = await firestore
              .pipeline()
              .collection(_collectionPath)
              .where(
                _runFilter(
                  runId,
                  Expression.field('title').equal('Dart Pipelines'),
                ),
              )
              .select([
                for (final expectation in scenario.expectations)
                  expectation.expression.as(expectation.alias),
              ])
              .limit(1)
              .execute();

          expect(snapshot.results, hasLength(1));
          final result = snapshot.results.single;
          for (final expectation in scenario.expectations) {
            _expectPipelineValue(
              result.get(expectation.alias),
              expectation.expected,
              reason: '${scenario.name}.${expectation.alias}',
            );
          }
        });
      }
    });

    group('aggregate function catalog', () {
      for (final scenario in _aggregateScenarios) {
        test(scenario.name, () async {
          final snapshot = await firestore
              .pipeline()
              .collection(_collectionPath)
              .where(Expression.field('runId').equal(runId))
              .aggregate([
                for (final expectation in scenario.expectations)
                  expectation.expression.as(expectation.alias),
              ])
              .execute();

          expect(snapshot.results, hasLength(1));
          final result = snapshot.results.single;
          for (final expectation in scenario.expectations) {
            _expectPipelineValue(
              result.get(expectation.alias),
              expectation.expected,
              reason: '${scenario.name}.${expectation.alias}',
            );
          }
        });
      }
    });

    test('executes vector nearest-neighbor stage', () async {
      final vectorSnapshot = await firestore
          .pipeline()
          .collection(_collectionPath)
          .where(Expression.field('runId').equal(runId))
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
  });
}

const _skipReason =
    'Set both FIRESTORE_PIPELINE_E2E_PROJECT_ID and '
    'FIRESTORE_PIPELINE_E2E_DATABASE_ID to run against a real Firebase '
    'project. The database must be Enterprise edition; Pipelines are not '
    'available on Standard. CI authenticates with Application Default '
    'Credentials, for example via Workload Identity Federation.';

PipelineBooleanExpression _runFilter(
  String runId, [
  PipelineBooleanExpression? condition,
]) {
  return PipelineFunctions.and([
    Expression.field('runId').equal(runId),
    ?condition,
  ]);
}

final _aggregateScenarios = <_FunctionScenario>[
  _FunctionScenario('aggregate functions', [
    _FunctionExpectation('count', PipelineFunctions.count(), 3),
    _FunctionExpectation(
      'countIf',
      PipelineFunctions.countIf(Expression.field('active')),
      2,
    ),
    _FunctionExpectation(
      'countDistinct',
      Expression.field('metadata').mapGetLiteral('lang').countDistinct(),
      1,
    ),
    _FunctionExpectation('sum', Expression.field('price').sum(), 60),
    _FunctionExpectation(
      'average',
      Expression.field('rating').average(),
      closeTo(11 / 3, 0.0001),
    ),
    _FunctionExpectation('minimum', Expression.field('price').minimum(), 10),
    _FunctionExpectation('maximum', Expression.field('price').maximum(), 30),
    _FunctionExpectation(
      'first',
      Expression.field('title').first(),
      isA<String>(),
    ),
    _FunctionExpectation(
      'last',
      Expression.field('title').last(),
      isA<String>(),
    ),
    _FunctionExpectation(
      'arrayAgg',
      Expression.field('title').arrayAgg(),
      containsAll(['Dart Pipelines', 'Firestore Admin', 'Inactive Draft']),
    ),
    _FunctionExpectation(
      'arrayAggDistinct',
      Expression.field('metadata').mapGetLiteral('lang').arrayAggDistinct(),
      ['dart'],
    ),
  ]),
];

final _functionScenarios = <_FunctionScenario>[
  _FunctionScenario('arithmetic functions', [
    _FunctionExpectation(
      'abs',
      Expression.field('score').abs(),
      closeTo(12.7, 0.0001),
    ),
    _FunctionExpectation('add', Expression.field('price').add(2), 12),
    _FunctionExpectation('subtract', Expression.field('price').subtract(3), 7),
    _FunctionExpectation('multiply', Expression.field('price').multiply(2), 20),
    _FunctionExpectation('divide', Expression.field('price').divide(2), 5),
    _FunctionExpectation('mod', Expression.field('price').modulo(4), 2),
    _FunctionExpectation('ceil', Expression.constant(12.2).ceil(), 13),
    _FunctionExpectation('floor', Expression.constant(12.8).floor(), 12),
    _FunctionExpectation('round', Expression.constant(12.6).round(), 13),
    _FunctionExpectation('trunc', Expression.constant(12.8).trunc(), 12),
    _FunctionExpectation('pow', PipelineFunctions.pow(2, 3), 8),
    _FunctionExpectation('sqrt', Expression.constant(9).sqrt(), 3),
    _FunctionExpectation(
      'exp',
      PipelineFunctions.exp(1),
      closeTo(2.71828, 0.001),
    ),
    _FunctionExpectation(
      'ln',
      PipelineFunctions.ln(2.718281828),
      closeTo(1, 0.001),
    ),
    _FunctionExpectation('log', PipelineFunctions.log(8, 2), closeTo(3, 0.001)),
    _FunctionExpectation(
      'log10',
      PipelineFunctions.log10(100),
      closeTo(2, 0.001),
    ),
    _FunctionExpectation('rand', PipelineFunctions.rand(), isA<num>()),
  ]),
  _FunctionScenario('array functions', [
    _FunctionExpectation('array', Expression.array([1, 2, 3]), [1, 2, 3]),
    _FunctionExpectation(
      'arrayConcat',
      Expression.field('tags').arrayConcat(['admin']),
      ['dart', 'firebase', 'admin'],
    ),
    _FunctionExpectation(
      'arrayConcatMultiple',
      Expression.field('tags').arrayConcatMultiple([
        ['admin'],
        ['sdk'],
      ]),
      ['dart', 'firebase', 'admin', 'sdk'],
    ),
    _FunctionExpectation(
      'arrayContainsValue',
      Expression.field('tags').arrayContainsElement('dart'),
      true,
    ),
    _FunctionExpectation(
      'arrayContainsElement',
      Expression.field(
        'tags',
      ).arrayContainsElement(Expression.constant('firebase')),
      true,
    ),
    _FunctionExpectation(
      'arrayContainsAll',
      Expression.field('tags').arrayContainsAll(['dart', 'firebase']),
      true,
    ),
    _FunctionExpectation(
      'arrayContainsAllFrom',
      Expression.field('tags').arrayContainsAllFrom(Expression.array(['dart'])),
      true,
    ),
    _FunctionExpectation(
      'arrayContainsAny',
      Expression.field('tags').arrayContainsAny(['missing', 'dart']),
      true,
    ),
    _FunctionExpectation(
      'arrayFilter',
      Expression.field(
        'tags',
      ).arrayFilter('tag', Expression.variable('tag').notEqual('firebase')),
      ['dart'],
    ),
    _FunctionExpectation(
      'arrayGet',
      PipelineFunctions.arrayGet(Expression.field('numbers'), 1),
      1,
    ),
    _FunctionExpectation(
      'arrayLength',
      Expression.field('numbers').arrayLength(),
      4,
    ),
    _FunctionExpectation(
      'arrayReverse',
      Expression.field('numbers').arrayReverse(),
      [3, 2, 1, 3],
    ),
    _FunctionExpectation(
      'arrayFirst',
      Expression.field('numbers').arrayFirst(),
      3,
    ),
    _FunctionExpectation(
      'arrayFirstN',
      Expression.field('numbers').arrayFirstN(2),
      [3, 1],
    ),
    _FunctionExpectation(
      'arrayIndexOf',
      Expression.field('numbers').arrayIndexOf(1),
      1,
    ),
    _FunctionExpectation(
      'arrayIndexOfAll',
      Expression.field('numbers').arrayIndexOfAll(3),
      [0, 3],
    ),
    _FunctionExpectation(
      'arrayLast',
      Expression.field('numbers').arrayLast(),
      3,
    ),
    _FunctionExpectation(
      'arrayLastN',
      Expression.field('numbers').arrayLastN(2),
      [2, 3],
    ),
    _FunctionExpectation(
      'arrayLastIndexOf',
      Expression.field('numbers').arrayLastIndexOf(3),
      3,
    ),
    _FunctionExpectation(
      'arraySlice',
      Expression.field('numbers').arraySlice(1, 2),
      [1, 2],
    ),
    _FunctionExpectation(
      'arrayTransform',
      Expression.field(
        'numbers',
      ).arrayTransform('n', Expression.variable('n').add(1)),
      [4, 2, 3, 4],
    ),
    _FunctionExpectation(
      'arrayTransformWithIndex',
      Expression.field('numbers').arrayTransformWithIndex(
        'n',
        'i',
        Expression.variable('n').add(Expression.variable('i')),
      ),
      [3, 2, 4, 6],
    ),
    _FunctionExpectation(
      'maximumN',
      Expression.field('numbers').arrayMaximumN(2),
      [3, 3],
    ),
    _FunctionExpectation(
      'minimumN',
      Expression.field('numbers').arrayMinimumN(2),
      [1, 2],
    ),
    _FunctionExpectation(
      'join',
      Expression.field('words').joinLiteral('-'),
      'dart-firebase',
    ),
  ]),
  _FunctionScenario('comparison functions', [
    _FunctionExpectation('equal', Expression.field('price').equal(10), true),
    _FunctionExpectation(
      'notEqual',
      Expression.field('price').notEqual(11),
      true,
    ),
    _FunctionExpectation(
      'greaterThan',
      Expression.field('price').greaterThan(9),
      true,
    ),
    _FunctionExpectation(
      'greaterThanOrEqual',
      Expression.field('price').greaterThanOrEqual(10),
      true,
    ),
    _FunctionExpectation(
      'lessThan',
      Expression.field('price').lessThan(11),
      true,
    ),
    _FunctionExpectation(
      'lessThanOrEqual',
      Expression.field('price').lessThanOrEqual(10),
      true,
    ),
    _FunctionExpectation(
      'cmp',
      PipelineFunctions.cmp(Expression.field('price'), 10),
      0,
    ),
  ]),
  _FunctionScenario('debugging functions', [
    _FunctionExpectation('exists', Expression.field('title').exists(), true),
    _FunctionExpectation(
      'isAbsent',
      Expression.field('missing').isAbsent(),
      true,
    ),
    _FunctionExpectation(
      'ifAbsent',
      Expression.field('missing').ifAbsent('fallback'),
      'fallback',
    ),
    _FunctionExpectation('isError', Expression.field('title').isError(), false),
    _FunctionExpectation(
      'ifError',
      Expression.field('title').ifError('caught'),
      'Dart Pipelines',
    ),
  ]),
  _FunctionScenario('reference functions', [
    _FunctionExpectation(
      'collectionId',
      Expression.field('pathRef').collectionId(),
      isA<String>(),
    ),
    _FunctionExpectation(
      'documentId',
      Expression.field('pathRef').documentId(),
      allOf(startsWith('run_'), endsWith('_book_2')),
    ),
    _FunctionExpectation(
      'parent',
      Expression.field('pathRef').parent(),
      isNotNull,
    ),
    _FunctionExpectation(
      'referenceSlice',
      Expression.field('pathRef').referenceSlice(0, 2),
      isNotNull,
    ),
  ]),
  _FunctionScenario('logical functions', [
    _FunctionExpectation(
      'and',
      PipelineFunctions.and([true, Expression.field('active')]),
      true,
    ),
    _FunctionExpectation(
      'or',
      PipelineFunctions.or([false, Expression.field('active')]),
      true,
    ),
    _FunctionExpectation('xor', PipelineFunctions.xor([true, false]), true),
    _FunctionExpectation('nor', PipelineFunctions.nor([false, false]), true),
    _FunctionExpectation('not', PipelineFunctions.not(false), true),
    _FunctionExpectation(
      'conditional',
      PipelineFunctions.conditional(Expression.field('active'), 'yes', 'no'),
      'yes',
    ),
    _FunctionExpectation(
      'ifNull',
      PipelineFunctions.ifNull(Expression.field('nullable'), 'fallback'),
      'fallback',
    ),
    // The first argument is a field position: a bare String means a field
    // reference, not a string literal. Passing 'dart' here asked about a
    // non-existent field named `dart`, which made equalAny false and made
    // notEqualAny true for the wrong reason.
    _FunctionExpectation(
      'equalAny',
      PipelineFunctions.equalAny(
        'title',
        Expression.array(['Dart Pipelines', 'Unrelated Title']),
      ),
      true,
    ),
    _FunctionExpectation(
      'notEqualAny',
      PipelineFunctions.notEqualAny(
        'title',
        Expression.array(['Unrelated Title', 'Another Title']),
      ),
      true,
    ),
  ]),
  _FunctionScenario('map functions', [
    _FunctionExpectation('map', PipelineFunctions.map(['a', 1, 'b', 2]), {
      'a': 1,
      'b': 2,
    }),
    _FunctionExpectation(
      'mapGet',
      Expression.field('metadata').mapGetLiteral('category'),
      'sdk',
    ),
    _FunctionExpectation(
      'mapSet',
      Expression.field('metadata').mapSet('edition', 'enterprise'),
      containsPair('edition', 'enterprise'),
    ),
    _FunctionExpectation(
      'mapRemove',
      Expression.field('metadata').mapRemove(['lang']),
      isNot(contains('lang')),
    ),
    _FunctionExpectation(
      'mapMerge',
      Expression.field('metadata').mapMerge([
        {'edition': 'enterprise'},
      ]),
      containsPair('edition', 'enterprise'),
    ),
    _FunctionExpectation(
      'currentDocument',
      currentDocument(),
      isA<Map<Object?, Object?>>(),
    ),
    _FunctionExpectation(
      'mapKeys',
      Expression.field('metadata').mapKeys(),
      containsAll(['lang', 'category']),
    ),
    _FunctionExpectation(
      'mapValues',
      Expression.field('metadata').mapValues(),
      containsAll(['dart', 'sdk']),
    ),
    _FunctionExpectation(
      'mapEntries',
      Expression.field('metadata').mapEntries(),
      isA<List<Object?>>(),
    ),
  ]),
  _FunctionScenario('string functions', [
    _FunctionExpectation(
      'byteLength',
      Expression.field('title').byteLength(),
      14,
    ),
    _FunctionExpectation('charLength', Expression.field('title').length(), 14),
    _FunctionExpectation(
      'startsWith',
      Expression.field('title').startsWith('Dart'),
      true,
    ),
    _FunctionExpectation(
      'endsWith',
      Expression.field('title').endsWith('lines'),
      true,
    ),
    _FunctionExpectation('like', Expression.field('title').like('Dart%'), true),
    _FunctionExpectation(
      'regexContains',
      Expression.field('title').regexContains('Pipe'),
      true,
    ),
    _FunctionExpectation(
      'regexMatch',
      Expression.field('title').regexMatch(r'^Dart.*'),
      true,
    ),
    _FunctionExpectation(
      'regexFind',
      Expression.field('title').regexFind('Pipe'),
      isNotNull,
    ),
    _FunctionExpectation(
      'regexFindAll',
      Expression.field('title').regexFindAll('[aei]'),
      isA<List<Object?>>(),
    ),
    _FunctionExpectation(
      'stringConcat',
      Expression.field('title').concat([' v2']),
      'Dart Pipelines v2',
    ),
    _FunctionExpectation(
      'stringContains',
      Expression.field('title').stringContains('Pipeline'),
      true,
    ),
    _FunctionExpectation(
      'stringIndexOf',
      Expression.field('title').stringIndexOf('Pipeline'),
      5,
    ),
    _FunctionExpectation(
      'toUpper',
      Expression.field('title').toUpperCase(),
      'DART PIPELINES',
    ),
    _FunctionExpectation(
      'toLower',
      Expression.field('title').toLowerCase(),
      'dart pipelines',
    ),
    _FunctionExpectation(
      'substring',
      Expression.field('title').substringLiteral(0, 4),
      'Dart',
    ),
    _FunctionExpectation(
      'stringReverse',
      PipelineFunctions.stringReverse(Expression.constant('Dart')),
      'traD',
    ),
    _FunctionExpectation(
      'stringRepeat',
      Expression.constant('ha').stringRepeat(3),
      'hahaha',
    ),
    _FunctionExpectation(
      'stringReplaceAll',
      Expression.field('title').stringReplaceAllLiteral('i', 'I'),
      'Dart PIpelInes',
    ),
    _FunctionExpectation(
      'stringReplaceOne',
      Expression.field('title').stringReplaceOneLiteral('i', 'I'),
      'Dart PIpelines',
    ),
    _FunctionExpectation('trim', Expression.field('spaced').trim(), 'Dart'),
    _FunctionExpectation('ltrim', Expression.field('spaced').ltrim(), 'Dart  '),
    _FunctionExpectation('rtrim', Expression.field('spaced').rtrim(), '  Dart'),
    _FunctionExpectation('split', Expression.field('csv').splitLiteral(','), [
      'dart',
      'firebase',
      'admin',
    ]),
  ]),
  _FunctionScenario('timestamp and type functions', [
    _FunctionExpectation(
      'currentTimestamp',
      PipelineFunctions.currentTimestamp(),
      isA<Timestamp>(),
    ),
    _FunctionExpectation(
      'timestampTrunc',
      Expression.field('createdAt').timestampTrunc('day', 'UTC'),
      isA<Timestamp>(),
    ),
    _FunctionExpectation(
      'unixMicrosToTimestamp',
      PipelineFunctions.unixMicrosToTimestamp(1700000000000000),
      isA<Timestamp>(),
    ),
    _FunctionExpectation(
      'unixMillisToTimestamp',
      PipelineFunctions.unixMillisToTimestamp(1700000000000),
      isA<Timestamp>(),
    ),
    _FunctionExpectation(
      'unixSecondsToTimestamp',
      PipelineFunctions.unixSecondsToTimestamp(1700000000),
      isA<Timestamp>(),
    ),
    _FunctionExpectation(
      'timestampAdd',
      Expression.field('createdAt').timestampAdd('second', 60),
      isA<Timestamp>(),
    ),
    _FunctionExpectation(
      'timestampSubtract',
      Expression.field('createdAt').timestampSubtract('second', 60),
      isA<Timestamp>(),
    ),
    _FunctionExpectation(
      'timestampToUnixMicros',
      Expression.field('createdAt').timestampToUnixMicros(),
      1700000000000000,
    ),
    _FunctionExpectation(
      'timestampToUnixMillis',
      Expression.field('createdAt').timestampToUnixMillis(),
      1700000000000,
    ),
    _FunctionExpectation(
      'timestampToUnixSeconds',
      Expression.field('createdAt').timestampToUnixSeconds(),
      1700000000,
    ),
    _FunctionExpectation(
      'timestampDiff',
      PipelineFunctions.timestampDiff(
        Expression.field('createdAt'),
        PipelineFunctions.unixSecondsToTimestamp(1699999940),
        'second',
      ),
      60,
    ),
    _FunctionExpectation(
      'timestampExtract',
      Expression.field('createdAt').timestampExtract('year', 'UTC'),
      2023,
    ),
    _FunctionExpectation(
      'type',
      Expression.field('price').type(),
      isA<String>(),
    ),
    _FunctionExpectation(
      'isType',
      Expression.field('price').isType(PipelineValueType.number),
      true,
    ),
  ]),
  _FunctionScenario('vector functions', [
    _FunctionExpectation(
      'cosineDistance',
      Expression.field(
        'embedding',
      ).cosineDistance(Expression.vector([1, 0, 0])),
      closeTo(0, 0.0001),
    ),
    _FunctionExpectation(
      'dotProduct',
      Expression.field('embedding').dotProduct(Expression.vector([1, 0, 0])),
      closeTo(1, 0.0001),
    ),
    _FunctionExpectation(
      'euclideanDistance',
      Expression.field(
        'embedding',
      ).euclideanDistance(Expression.vector([1, 0, 0])),
      closeTo(0, 0.0001),
    ),
    _FunctionExpectation(
      'vectorLength',
      Expression.field('embedding').vectorLength(),
      3,
    ),
  ]),
];

final class _FunctionScenario {
  const _FunctionScenario(this.name, this.expectations);

  final String name;
  final List<_FunctionExpectation> expectations;
}

final class _FunctionExpectation {
  const _FunctionExpectation(this.alias, this.expression, this.expected);

  final String alias;
  final PipelineExpression expression;
  final Object? expected;
}

void _expectPipelineValue(
  Object? actual,
  Object? expected, {
  required String reason,
}) {
  if (expected is Matcher) {
    expect(actual, expected, reason: reason);
    return;
  }
  expect(actual, expected, reason: reason);
}
