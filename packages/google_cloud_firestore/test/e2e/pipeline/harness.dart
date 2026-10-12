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

/// Shared harness for the live Firestore Pipelines E2E suite.
///
/// Every `*_test.dart` file in this directory:
///
/// - is tagged `@Tags(['prod'])`;
/// - imports only `package:google_cloud_firestore/google_cloud_firestore.dart`,
///   `package:test/test.dart` and this harness (plus `dart:` libraries), so a
///   public API that is missing from the barrel fails to compile here;
/// - wraps its tests in a single [pipelineE2E] call, which seeds the
///   documents described in [buildSeed] once per file and deletes them
///   afterwards.
///
/// Prefer the table-driven helpers ([PipelineE2EContext.functionCases],
/// [PipelineE2EContext.aggregateCases], [PipelineE2EContext.filterCases]):
/// each case is its own test, so one `INVALID_ARGUMENT` never hides another.
///
/// `test/pipeline_e2e_coverage_test.dart` statically checks that these files
/// exercise every public Pipeline API member, every optional parameter (both
/// supplied and omitted) and every value position (with an expression and
/// with a plain value). Adding a public Pipeline function without an E2E case
/// here makes that guard fail.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

/// Environment variable naming the project that holds the Pipelines database.
const projectIdEnv = 'FIRESTORE_PIPELINE_E2E_PROJECT_ID';

/// Environment variable naming the Enterprise-edition database to run against.
const databaseIdEnv = 'FIRESTORE_PIPELINE_E2E_DATABASE_ID';

/// The collection every E2E file seeds into.
///
/// Kept stable on purpose: the vector index the `findNearest` tests need is
/// declared on this collection group (see `test/e2e/README.md`), and per-run
/// document IDs keep concurrent runs apart.
const pipelineE2ECollection = 'pipeline_e2e_books';

/// Why the suite is skipped when it is not configured.
const pipelineE2ESkipReason =
    'Set both FIRESTORE_PIPELINE_E2E_PROJECT_ID and '
    'FIRESTORE_PIPELINE_E2E_DATABASE_ID to run against a real Firebase '
    'project. The database must be Enterprise edition; Pipelines are not '
    'available on Standard. CI authenticates with Application Default '
    'Credentials, for example via Workload Identity Federation.';

/// The alias [PipelineE2EContext.functionCases] and
/// [PipelineE2EContext.aggregateCases] store each evaluated expression under.
const valueAlias = 'v';

/// Declares a group of live Pipeline tests sharing one seeded data set.
///
/// The group is skipped unless both [projectIdEnv] and [databaseIdEnv] are
/// set. Otherwise the documents described in [buildSeed] are written once in
/// `setUpAll`, under a run ID unique to this call, and deleted in
/// `tearDownAll`.
///
/// [body] runs at declaration time, like any group body. Everything on the
/// context ([PipelineE2EContext.firestore], [PipelineE2EContext.runId], the
/// document references and the Pipeline builders) is already usable there,
/// so cases may embed `ctx.book2Ref` and similar; only executing a Pipeline
/// has to wait for a test body.
void pipelineE2E(
  String description,
  void Function(PipelineE2EContext ctx) body,
) {
  final target = _E2ETarget.fromEnvironment();
  final ctx = PipelineE2EContext._(target);

  group(description, skip: target.enabled ? null : pipelineE2ESkipReason, () {
    setUpAll(ctx._seed);
    tearDownAll(ctx._deleteSeed);
    body(ctx);
  });
}

final class _E2ETarget {
  const _E2ETarget(this.projectId, this.databaseId);

  factory _E2ETarget.fromEnvironment() {
    final projectId =
        Platform.environment[projectIdEnv] ??
        Platform.environment['GOOGLE_CLOUD_PROJECT'] ??
        Platform.environment['GCLOUD_PROJECT'];
    // No '(default)' fallback on purpose. CI credential helpers such as
    // google-github-actions/auth export GOOGLE_CLOUD_PROJECT, so a project-only
    // guard would silently arm this suite against whatever project happened to
    // be authenticated, using its default database — which may be Standard
    // edition (no Pipelines at all) or simply lack the vector index this suite
    // needs. Both variables must be set deliberately.
    final databaseId = Platform.environment[databaseIdEnv];
    return _E2ETarget(projectId, databaseId);
  }

  final String? projectId;
  final String? databaseId;

  bool get enabled =>
      projectId != null &&
      projectId!.isNotEmpty &&
      databaseId != null &&
      databaseId!.isNotEmpty;
}

var _lastRunMicros = 0;

/// A run ID unique within this isolate, in the `run_<micros>` format the
/// README's cleanup advice refers to.
String _nextRunId() {
  var micros = DateTime.now().microsecondsSinceEpoch;
  if (micros <= _lastRunMicros) micros = _lastRunMicros + 1;
  _lastRunMicros = micros;
  return 'run_$micros';
}

/// What a [pipelineE2E] body builds its tests from.
final class PipelineE2EContext {
  PipelineE2EContext._(this._target) : runId = _nextRunId();

  final _E2ETarget _target;

  /// Identifies this file's seeded documents; every seeded document carries
  /// it in its `runId` field, and their IDs start with it.
  final String runId;

  /// The Firestore instance under test.
  ///
  /// Creating it does no I/O. When the suite is skipped it points at a
  /// placeholder project, so declaration-time code can still build document
  /// references.
  late final Firestore firestore = Firestore(
    settings: _target.enabled
        ? Settings(projectId: _target.projectId, databaseId: _target.databaseId)
        : const Settings(
            projectId: 'pipeline-e2e-skipped',
            databaseId: 'pipeline-e2e-skipped',
          ),
  );

  /// The seeded collection, [pipelineE2ECollection].
  String get collectionPath => pipelineE2ECollection;

  /// The seeded documents: `[book1Ref, book2Ref, book3Ref]`.
  late final List<DocumentReference<DocumentData>> refs = [
    for (var i = 1; i <= 3; i++)
      firestore.doc('$pipelineE2ECollection/${runId}_book_$i'),
  ];

  /// Book 1, `'Dart Pipelines'`. Function cases are evaluated against it.
  DocumentReference<DocumentData> get book1Ref => refs[0];

  /// Book 2, `'Firestore Admin'`.
  DocumentReference<DocumentData> get book2Ref => refs[1];

  /// Book 3, `'Inactive Draft'`.
  DocumentReference<DocumentData> get book3Ref => refs[2];

  /// The exact data written for each of [refs], as built by [buildSeed].
  late final List<DocumentData> seed = buildSeed(runId, refs);

  /// Restricts a Pipeline to this run's documents, optionally also requiring
  /// [condition].
  ///
  /// Without [condition] this is a bare equality rather than a one-operand
  /// `and`, a shape the Node SDK's `and(first, second, ...more)` never sends.
  PipelineBooleanExpression runFilter([PipelineBooleanExpression? condition]) {
    final inRun = Expression.field('runId').equal(runId);
    return condition == null
        ? inRun
        : PipelineFunctions.and([inRun, condition]);
  }

  /// A Pipeline over this run's three seeded documents.
  Pipeline runPipeline() {
    return firestore.pipeline().collection(collectionPath).where(runFilter());
  }

  /// A Pipeline over book 1 only.
  Pipeline book1Pipeline() {
    return firestore
        .pipeline()
        .collection(collectionPath)
        .where(runFilter(Expression.field('title').equal('Dart Pipelines')));
  }

  /// Evaluates [expression] against book 1 and returns the result.
  ///
  /// Selects `expression.as(valueAlias)` from [book1Pipeline] and reads it
  /// back, failing unless exactly one result comes back.
  Future<Object?> evaluate(PipelineExpression expression) async {
    final snapshot = await book1Pipeline()
        .select([expression.as(valueAlias)])
        .limit(1)
        .execute();
    expect(snapshot.results, hasLength(1));
    return snapshot.results.single.get(valueAlias);
  }

  /// Aggregates [accumulator] over this run's three documents and returns the
  /// result.
  Future<Object?> evaluateAggregate(PipelineExpression accumulator) async {
    final snapshot = await runPipeline().aggregate([
      accumulator.as(valueAlias),
    ]).execute();
    expect(snapshot.results, hasLength(1));
    return snapshot.results.single.get(valueAlias);
  }

  /// Returns the titles [pipeline] produces, in order.
  Future<List<Object?>> titlesOf(Pipeline pipeline) async {
    final snapshot = await pipeline.execute();
    return [for (final result in snapshot.results) result.get('title')];
  }

  /// Declares one test per case, evaluating each expression on book 1.
  ///
  /// See [FunctionCase] for how [FunctionCase.expected] is compared.
  void functionCases(String description, List<FunctionCase> cases) {
    group(description, () {
      for (final functionCase in cases) {
        test(functionCase.name, () async {
          expect(
            await evaluate(functionCase.expression),
            functionCase.expected,
            reason: '$description: ${functionCase.name}',
          );
        });
      }
    });
  }

  /// Declares one test per case, aggregating each accumulator over the run's
  /// three documents.
  void aggregateCases(String description, List<AggregateCase> cases) {
    group(description, () {
      for (final aggregateCase in cases) {
        test(aggregateCase.name, () async {
          expect(
            await evaluateAggregate(aggregateCase.accumulator),
            aggregateCase.expected,
            reason: '$description: ${aggregateCase.name}',
          );
        });
      }
    });
  }

  /// Declares one test per case, filtering the run's documents with each
  /// condition and comparing the matching titles, sorted by ascending price
  /// (so always in book order).
  void filterCases(String description, List<FilterCase> cases) {
    group(description, () {
      for (final filterCase in cases) {
        test(filterCase.name, () async {
          expect(
            await titlesOf(
              firestore
                  .pipeline()
                  .collection(collectionPath)
                  .where(runFilter(filterCase.condition))
                  .sort([Expression.field('price').ascending()])
                  .select([Expression.field('title')]),
            ),
            filterCase.expectedTitles,
            reason: '$description: ${filterCase.name}',
          );
        });
      }
    });
  }

  Future<void> _seed() async {
    await Future.wait([
      for (var i = 0; i < refs.length; i++) refs[i].set(seed[i]),
    ]);
  }

  Future<void> _deleteSeed() async {
    try {
      await Future.wait([for (final ref in refs) ref.delete()]);
    } finally {
      await firestore.terminate();
    }
  }
}

/// An expression evaluated on book 1 by [PipelineE2EContext.functionCases].
final class FunctionCase {
  /// Creates a case named [name].
  const FunctionCase(this.name, this.expression, this.expected);

  /// The test name.
  final String name;

  /// The expression under test. Do not alias it; the harness does.
  final PipelineExpression expression;

  /// The expected value: a [Matcher], or a value compared with `equals`.
  ///
  /// `equals` treats `13` and `13.0` as equal; use [isInt] or [isDouble]
  /// when the numeric type is part of what is being tested.
  final Object? expected;
}

/// An accumulator evaluated over the run's three documents by
/// [PipelineE2EContext.aggregateCases].
final class AggregateCase {
  /// Creates a case named [name].
  const AggregateCase(this.name, this.accumulator, this.expected);

  /// The test name.
  final String name;

  /// The aggregate expression under test. Do not alias it; the harness does.
  final PipelineExpression accumulator;

  /// The expected value: a [Matcher], or a value compared with `equals`.
  final Object? expected;
}

/// A condition applied to the run's three documents by
/// [PipelineE2EContext.filterCases].
final class FilterCase {
  /// Creates a case named [name].
  const FilterCase(this.name, this.condition, this.expectedTitles);

  /// The test name.
  final String name;

  /// The `where` condition under test; the run filter is added for you.
  final PipelineBooleanExpression condition;

  /// The titles of the matching books, in book order: any subset of
  /// `'Dart Pipelines'`, `'Firestore Admin'`, `'Inactive Draft'`.
  final List<String> expectedTitles;
}

/// Matches an [int] equal to [value].
///
/// Results decode by wire type: an `integerValue` becomes an [int] and a
/// `doubleValue` a [double], so the backend's choice of result type is
/// observable here (unlike in the Node SDK, where both are a JS `number`).
/// For example `add` on two int64 fields returns int64, while `average` returns
/// float64. Use [isInt] / [isDouble] when the result type is part of what a
/// case checks, and [isNumber], which accepts either, when it is not.
Matcher isInt(int value) => allOf(isA<int>(), equals(value));

/// Matches a [double] within [tolerance] of [value]. See [isInt].
Matcher isDouble(num value, {double tolerance = 1e-9}) {
  return allOf(isA<double>(), closeTo(value, tolerance));
}

/// Matches an [int] or a [double] within [tolerance] of [value]. See [isInt].
Matcher isNumber(num value, {double tolerance = 1e-9}) {
  return allOf(isA<num>(), closeTo(value, tolerance));
}

/// Builds the data written for each of [refs] (books 1, 2 and 3).
///
/// This is the single source of truth for expectations: compute expected
/// values from the table below, never by guessing. Every field exists on all
/// three books unless noted. No document has a field named `missing`, so use
/// it for absent-field cases.
///
/// | Field | Book 1 | Book 2 | Book 3 |
/// | --- | --- | --- | --- |
/// | `runId` | [runId] | [runId] | [runId] |
/// | `title` | `'Dart Pipelines'` (14 chars) | `'Firestore Admin'` | `'Inactive Draft'` |
/// | `active` | `true` | `true` | `false` |
/// | `archived` | `false` | `false` | `true` |
/// | `price` (int) | `10` | `20` | `30` |
/// | `rating` (int) | `5` | `4` | `2` |
/// | `discount` (int) | `2` | `3` | `4` |
/// | `flags` (int, bit flags) | `6` | `3` | `5` |
/// | `quantity` (int) | `7` | `0` | `-3` |
/// | `zero` (int) | `0` | `0` | `0` |
/// | `largeInt` (int, 2^53 + 1) | `9007199254740993` | same | same |
/// | `score` (double) | `-12.7` | `3.2` | `8.9` |
/// | `ratio` (double) | `0.5` | `1.25` | `2.0` |
/// | `half` (double) | `2.5` | `2.5` | `2.5` |
/// | `negativeHalf` (double) | `-2.5` | `-2.5` | `-2.5` |
/// | `precise` (double) | `4.123456` | same | same |
/// | `nullable` | `null` | `null` | `null` |
/// | `bytes` | `[0x0f, 0xf0]` | `[0xaa, 0x55]` | `[0xff, 0x00]` |
/// | `spaced` | `'  Dart  '` | `' Admin '` | `' Draft '` |
/// | `padded` | `'__Dart__'` | same | same |
/// | `empty` | `''` | `''` | `''` |
/// | `greeting` | `'Hello, World!'` | `'Hello, Admin!'` | `'Goodbye, Draft!'` |
/// | `prefix` | `'Dart'` | `'Fire'` | `'Draft'` |
/// | `unicode` | `'café ☕ 日本'` (9 code points, 16 UTF-8 bytes) | same | same |
/// | `email` | `'dev.team@example.com'` | `'admin@example.org'` | `'draft@example.net'` |
/// | `sentence` | `'Dart is fun and Dart is fast'` | same | same |
/// | `csv` | `'dart,firebase,admin'` | `'firestore,admin'` | `'inactive,draft'` |
/// | `semicolons` | `'a;b;c'` | same | same |
/// | `delimiter` | `';'` | same | same |
/// | `tags` | `['dart', 'firebase']` | `['firebase']` | `['draft']` |
/// | `words` | `['dart', 'firebase']` | `['firebase']` | `['draft']` |
/// | `numbers` (ints) | `[3, 1, 2, 3]` | `[4, 5]` | `[9]` |
/// | `scores` (doubles) | `[1.5, 2.5, -0.5]` | `[4.0]` | `[0.25, 0.75]` |
/// | `mixedNumbers` | `[1, 2.5, -3, 0]` | same | same |
/// | `booleans` | `[true, false, true]` | same | same |
/// | `withNulls` | `[1, null, 3]` | same | same |
/// | `emptyArray` | `[]` | `[]` | `[]` |
/// | `items` (maps) | `[{name: 'pen', qty: 2, price: 1.5}, {name: 'ink', qty: 1, price: 4.0}]` | `[{name: 'cap', qty: 5, price: 0.5}]` | `[]` |
/// | `metadata` | `{lang: 'dart', category: 'sdk'}` | `{lang: 'dart', category: 'admin'}` | `{lang: 'dart', category: 'draft'}` |
/// | `nested` | `{level1: {level2: {value: 42}}, 'dotted.key': 'dot', list: [1, 2]}` | same | same |
/// | `stats` | `{views: 100, likes: 7}` | `{views: 50, likes: 3}` | `{views: 0, likes: 0}` |
/// | `emptyMap` | `{}` | `{}` | `{}` |
/// | `createdAt` | `Timestamp(1700000000, 0)` (2023-11-14T22:13:20Z) | `Timestamp(1700003600, 0)` | `Timestamp(1700007200, 0)` |
/// | `updatedAt` (createdAt + 1 day + 0.123456 s) | `Timestamp(1700086400, 123456000)` | `Timestamp(1700090000, 123456000)` | `Timestamp(1700093600, 123456000)` |
/// | `unixSeconds` (= createdAt) | `1700000000` | `1700003600` | `1700007200` |
/// | `unixMillis` (= createdAt) | `1700000000000` | `1700003600000` | `1700007200000` |
/// | `unixMicros` (= createdAt) | `1700000000000000` | `1700003600000000` | `1700007200000000` |
/// | `location` (GeoPoint) | `(37.7749, -122.4194)` | `(40.7128, -74.006)` | `(51.5074, -0.1278)` |
/// | `pathRef` (reference) | book 2 | book 1 | book 1 |
/// | `embedding` (vector) | `[1, 0, 0]` | `[0, 1, 0]` | `[0, 0, 1]` |
/// | `sparse` | `'book 1 only'` | absent | absent |
/// | `first-name` | `'Ada'` | same | same |
/// | `last name` | `'Lovelace'` | same | same |
///
/// Document IDs are `<runId>_book_1`, `<runId>_book_2` and `<runId>_book_3`.
List<DocumentData> buildSeed(
  String runId,
  List<DocumentReference<DocumentData>> refs,
) {
  Timestamp at(int seconds, [int nanoseconds = 0]) {
    return Timestamp(seconds: seconds, nanoseconds: nanoseconds);
  }

  // Fields whose values do not vary between books.
  final shared = <String, Object?>{
    'runId': runId,
    'zero': 0,
    'largeInt': 9007199254740993,
    'half': 2.5,
    'negativeHalf': -2.5,
    'precise': 4.123456,
    'nullable': null,
    'padded': '__Dart__',
    'empty': '',
    'unicode': 'café ☕ 日本',
    'sentence': 'Dart is fun and Dart is fast',
    'semicolons': 'a;b;c',
    'delimiter': ';',
    'mixedNumbers': [1, 2.5, -3, 0],
    'booleans': [true, false, true],
    'withNulls': [1, null, 3],
    'emptyArray': <Object?>[],
    'nested': {
      'level1': {
        'level2': {'value': 42},
      },
      'dotted.key': 'dot',
      'list': [1, 2],
    },
    'emptyMap': <String, Object?>{},
    // Names that are not identifiers, which field paths must quote.
    'first-name': 'Ada',
    'last name': 'Lovelace',
  };

  return [
    {
      ...shared,
      'title': 'Dart Pipelines',
      'active': true,
      'archived': false,
      'price': 10,
      'rating': 5,
      'discount': 2,
      'flags': 6,
      'quantity': 7,
      'score': -12.7,
      'ratio': 0.5,
      'bytes': Uint8List.fromList([0x0f, 0xf0]),
      'spaced': '  Dart  ',
      'greeting': 'Hello, World!',
      'prefix': 'Dart',
      'email': 'dev.team@example.com',
      'csv': 'dart,firebase,admin',
      'tags': ['dart', 'firebase'],
      'words': ['dart', 'firebase'],
      'numbers': [3, 1, 2, 3],
      'scores': [1.5, 2.5, -0.5],
      'items': [
        {'name': 'pen', 'qty': 2, 'price': 1.5},
        {'name': 'ink', 'qty': 1, 'price': 4.0},
      ],
      'metadata': {'lang': 'dart', 'category': 'sdk'},
      'stats': {'views': 100, 'likes': 7},
      'createdAt': at(1700000000),
      'updatedAt': at(1700086400, 123456000),
      'unixSeconds': 1700000000,
      'unixMillis': 1700000000000,
      'unixMicros': 1700000000000000,
      'location': GeoPoint(latitude: 37.7749, longitude: -122.4194),
      'pathRef': refs[1],
      'embedding': FieldValue.vector([1, 0, 0]),
      'sparse': 'book 1 only',
    },
    {
      ...shared,
      'title': 'Firestore Admin',
      'active': true,
      'archived': false,
      'price': 20,
      'rating': 4,
      'discount': 3,
      'flags': 3,
      'quantity': 0,
      'score': 3.2,
      'ratio': 1.25,
      'bytes': Uint8List.fromList([0xaa, 0x55]),
      'spaced': ' Admin ',
      'greeting': 'Hello, Admin!',
      'prefix': 'Fire',
      'email': 'admin@example.org',
      'csv': 'firestore,admin',
      'tags': ['firebase'],
      'words': ['firebase'],
      'numbers': [4, 5],
      'scores': [4.0],
      'items': [
        {'name': 'cap', 'qty': 5, 'price': 0.5},
      ],
      'metadata': {'lang': 'dart', 'category': 'admin'},
      'stats': {'views': 50, 'likes': 3},
      'createdAt': at(1700003600),
      'updatedAt': at(1700090000, 123456000),
      'unixSeconds': 1700003600,
      'unixMillis': 1700003600000,
      'unixMicros': 1700003600000000,
      'location': GeoPoint(latitude: 40.7128, longitude: -74.006),
      'pathRef': refs[0],
      'embedding': FieldValue.vector([0, 1, 0]),
    },
    {
      ...shared,
      'title': 'Inactive Draft',
      'active': false,
      'archived': true,
      'price': 30,
      'rating': 2,
      'discount': 4,
      'flags': 5,
      'quantity': -3,
      'score': 8.9,
      'ratio': 2.0,
      'bytes': Uint8List.fromList([0xff, 0x00]),
      'spaced': ' Draft ',
      'greeting': 'Goodbye, Draft!',
      'prefix': 'Draft',
      'email': 'draft@example.net',
      'csv': 'inactive,draft',
      'tags': ['draft'],
      'words': ['draft'],
      'numbers': [9],
      'scores': [0.25, 0.75],
      'items': <Object?>[],
      'metadata': {'lang': 'dart', 'category': 'draft'},
      'stats': {'views': 0, 'likes': 0},
      'createdAt': at(1700007200),
      'updatedAt': at(1700093600, 123456000),
      'unixSeconds': 1700007200,
      'unixMillis': 1700007200000,
      'unixMicros': 1700007200000000,
      'location': GeoPoint(latitude: 51.5074, longitude: -0.1278),
      'pathRef': refs[0],
      'embedding': FieldValue.vector([0, 0, 1]),
    },
  ];
}
