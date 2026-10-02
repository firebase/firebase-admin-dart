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

/// Live coverage of `PipelineSnapshot` and `PipelineResult`: accessors,
/// document metadata and value decoding.
@Tags(['prod'])
library;

import 'dart:typed_data';

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// [timestamp] in whole microseconds, for ordering comparisons.
int _micros(Timestamp timestamp) {
  return timestamp.seconds * 1000000 + timestamp.nanoseconds ~/ 1000;
}

void main() {
  pipelineE2E('Pipeline results', (ctx) {
    test('exposes document metadata', () async {
      final snapshot = await ctx.book1Pipeline().limit(1).execute();
      final result = snapshot.results.single;

      expect(result.ref, isNotNull);
      expect(result.ref!.path, ctx.book1Ref.path);
      expect(result.id, '${ctx.runId}_book_1');
      // The full resource name of the document.
      expect(result.name, startsWith('projects/'));
      expect(result.name, endsWith('/documents/${ctx.book1Ref.path}'));

      // Each book is written once, so it was last updated when created, and
      // before the pipeline ran.
      expect(result.createTime, isNotNull);
      expect(result.updateTime, result.createTime);
      expect(snapshot.executionTime, isNotNull);
      expect(
        _micros(result.createTime!),
        lessThanOrEqualTo(_micros(snapshot.executionTime!)),
      );
    });

    test('get resolves dotted paths and FieldPaths', () async {
      final snapshot = await ctx.book1Pipeline().limit(1).execute();
      final result = snapshot.results.single;

      expect(result.get('metadata.lang'), 'dart');
      expect(result.get(FieldPath(const ['metadata', 'category'])), 'sdk');
      expect(result.get('nested.level1.level2.value'), 42);
      expect(
        result.get(FieldPath(const ['nested', 'level1', 'level2', 'value'])),
        42,
      );
      // A FieldPath segment may contain a dot; a dotted string splits on it.
      expect(result.get(FieldPath(const ['nested', 'dotted.key'])), 'dot');
      expect(result.get('nested.dotted.key'), isNull);
      // Missing segments, and segments that traverse a non-map, read null.
      expect(result.get('metadata.missing'), isNull);
      expect(result.get('missing'), isNull);
      expect(result.get('title.length'), isNull);
    });

    test('data decodes every seeded value type', () async {
      final snapshot = await ctx.book1Pipeline().limit(1).execute();
      final data = snapshot.results.single.data();
      final seeded = ctx.seed[0];

      // Every seeded field comes back, including the null, empty and sparse
      // ones, with the value that was written.
      expect(data.keys, unorderedEquals(seeded.keys));
      for (final key in seeded.keys) {
        if (key == 'pathRef') continue;
        expect(data[key], equals(seeded[key]), reason: key);
      }

      // Numbers decode by wire type.
      expect(data['price'], isInt(10));
      expect(data['largeInt'], isInt(9007199254740993));
      expect(data['score'], isDouble(-12.7));
      expect(data['ratio'], isDouble(0.5));
      expect(data['numbers'], [isInt(3), isInt(1), isInt(2), isInt(3)]);
      expect(data['scores'], [isDouble(1.5), isDouble(2.5), isDouble(-0.5)]);
      expect(data['mixedNumbers'], [
        isInt(1),
        isDouble(2.5),
        isInt(-3),
        isInt(0),
      ]);
      expect(data['items'], [
        {'name': 'pen', 'qty': isInt(2), 'price': isDouble(1.5)},
        {'name': 'ink', 'qty': isInt(1), 'price': isDouble(4)},
      ]);

      // The other value types decode to their Dart classes.
      expect(data['nullable'], isNull);
      expect(data['bytes'], isA<Uint8List>());
      expect(data['createdAt'], Timestamp(seconds: 1700000000, nanoseconds: 0));
      expect(
        data['updatedAt'],
        Timestamp(seconds: 1700086400, nanoseconds: 123456000),
      );
      expect(
        data['location'],
        GeoPoint(latitude: 37.7749, longitude: -122.4194),
      );
      expect(data['embedding'], isA<VectorValue>());
      expect((data['embedding']! as VectorValue).toArray(), [1, 0, 0]);
      expect(data['pathRef'], isA<DocumentReference<DocumentData>>());
      expect(
        (data['pathRef']! as DocumentReference<DocumentData>).path,
        ctx.book2Ref.path,
      );

      // The returned map is read-only.
      expect(() => data['title'] = 'changed', throwsUnsupportedError);
    });

    test('snapshot exposes its pipeline, size and execution time', () async {
      final pipeline = ctx.runPipeline().sort([ascending('price')]);
      final before = DateTime.now();
      final snapshot = await pipeline.execute();
      final after = DateTime.now();

      expect(snapshot.pipeline, same(pipeline));
      expect(snapshot.size, 3);
      expect(snapshot.empty, isFalse);
      expect(snapshot.results, hasLength(3));
      expect(snapshot.results.map((result) => result.id), [
        '${ctx.runId}_book_1',
        '${ctx.runId}_book_2',
        '${ctx.runId}_book_3',
      ]);
      // The execution time is the backend's clock; allow for skew.
      final executionTime = snapshot.executionTime!.toDate();
      expect(
        executionTime.isAfter(before.subtract(const Duration(minutes: 5))),
        isTrue,
        reason: '$executionTime vs $before',
      );
      expect(
        executionTime.isBefore(after.add(const Duration(minutes: 5))),
        isTrue,
        reason: '$executionTime vs $after',
      );
    });

    test('an empty snapshot still has an execution time', () async {
      final snapshot = await ctx.runPipeline().limit(0).execute();

      expect(snapshot.empty, isTrue);
      expect(snapshot.size, 0);
      expect(snapshot.results, isEmpty);
      expect(snapshot.executionTime, isNotNull);
    });

    test('results for the same document compare equal', () async {
      final first = await ctx.book1Pipeline().execute();
      final second = await ctx.book1Pipeline().execute();
      final others = await ctx
          .runPipeline()
          .where(Expression.field('title').notEqual('Dart Pipelines'))
          .execute();

      expect(first.results.single, second.results.single);
      expect(first.results.single.hashCode, second.results.single.hashCode);
      expect(others.results, hasLength(2));
      for (final other in others.results) {
        expect(first.results.single, isNot(other));
      }
    });

    test('aggregate results carry no document metadata', () async {
      final snapshot = await ctx.runPipeline().aggregate([
        PipelineFunctions.countAll().as('books'),
      ]).execute();
      final result = snapshot.results.single;

      expect(result.data(), {'books': 3});
      expect(result.ref, isNull);
      expect(result.id, isNull);
      expect(result.name, isNull);
      expect(result.createTime, isNull);
      expect(result.updateTime, isNull);
    });
  });
}
