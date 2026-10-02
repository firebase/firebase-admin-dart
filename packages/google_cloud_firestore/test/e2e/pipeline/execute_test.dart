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

/// Live coverage of `Pipeline.execute` options, explain stats and
/// `Transaction.executePipeline`.
@Tags(['prod'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

/// The titles of the three seeded books, in book order.
const _allTitles = ['Dart Pipelines', 'Firestore Admin', 'Inactive Draft'];

/// The titles in [snapshot], in order.
List<Object?> _titles(PipelineSnapshot snapshot) {
  return [for (final result in snapshot.results) result.get('title')];
}

/// [timestamp] in whole microseconds, for ordering comparisons.
int _micros(Timestamp timestamp) {
  return timestamp.seconds * 1000000 + timestamp.nanoseconds ~/ 1000;
}

/// [timestamp] truncated to whole microseconds, the precision the backend
/// accepts for a read time.
Timestamp _truncateToMicros(Timestamp timestamp, {int secondsEarlier = 0}) {
  return Timestamp(
    seconds: timestamp.seconds - secondsEarlier,
    nanoseconds: timestamp.nanoseconds - timestamp.nanoseconds % 1000,
  );
}

/// Expects [stats] to hold a human-readable text plan, as the backend
/// returns for the `text` format (and by default).
void _expectTextStats(ExplainStats? stats) {
  expect(stats, isNotNull);
  expect(stats!.typeName, 'google.protobuf.StringValue');
  expect(stats.text, isNotEmpty);
  // Text, not JSON.
  expect(stats.text, isNot(startsWith('{')));
  expect(stats.raw, isNotNull);
}

void main() {
  pipelineE2E('Pipeline execution', (ctx) {
    /// This run's books, in book order.
    Pipeline sortedBooks() => ctx.runPipeline().sort([ascending('price')]);

    test('a pipeline keeps the Firestore instance it was built from', () {
      expect(sortedBooks().firestore, same(ctx.firestore));
    });

    test('explain analyze in text format returns stats and results', () async {
      const options = PipelineExplainOptions(
        mode: PipelineExplainMode.analyze,
        outputFormat: PipelineExplainOutputFormat.text,
      );
      expect(options.mode, PipelineExplainMode.analyze);
      expect(options.outputFormat, PipelineExplainOutputFormat.text);

      final snapshot = await sortedBooks().execute(explain: options);

      // `analyze` runs the pipeline and returns planning stats alongside the
      // results, which is what proves the option names reached the backend.
      _expectTextStats(snapshot.explainStats);
      expect(_titles(snapshot), _allTitles);
    });

    test('explain analyze defaults to the text format', () async {
      const options = PipelineExplainOptions(mode: PipelineExplainMode.analyze);
      expect(options.outputFormat, isNull);

      final snapshot = await sortedBooks().execute(explain: options);

      _expectTextStats(snapshot.explainStats);
      expect(_titles(snapshot), _allTitles);
    });

    test('explain execute returns results without stats', () async {
      final snapshot = await sortedBooks().execute(
        explain: const PipelineExplainOptions(
          mode: PipelineExplainMode.execute,
          outputFormat: PipelineExplainOutputFormat.text,
        ),
      );

      expect(snapshot.explainStats, isNull);
      expect(_titles(snapshot), _allTitles);
    });

    test('explain without a mode defaults to execute', () async {
      for (final options in const [
        PipelineExplainOptions(),
        PipelineExplainOptions(outputFormat: PipelineExplainOutputFormat.text),
      ]) {
        expect(options.mode, isNull);

        final snapshot = await sortedBooks().execute(explain: options);

        expect(snapshot.explainStats, isNull);
        expect(_titles(snapshot), _allTitles);
      }
    });

    test('executes with the recommended index mode', () async {
      final snapshot = await sortedBooks().execute(
        indexMode: PipelineIndexMode.recommended,
      );

      expect(_titles(snapshot), _allTitles);
    });

    test('rawOptions reach the backend', () async {
      final snapshot = await sortedBooks().execute(
        rawOptions: const {
          'explain_options': {'mode': 'analyze'},
        },
      );

      _expectTextStats(snapshot.explainStats);
      expect(_titles(snapshot), _allTitles);
    });

    test('rawOptions take precedence over typed options', () async {
      final snapshot = await sortedBooks().execute(
        explain: const PipelineExplainOptions(
          mode: PipelineExplainMode.execute,
        ),
        rawOptions: const {
          'explain_options': {'mode': 'analyze'},
        },
      );

      _expectTextStats(snapshot.explainStats);
      expect(_titles(snapshot), _allTitles);
    });

    test('readTime reads the database as it was at that time', () async {
      final current = await sortedBooks().execute();
      expect(_titles(current), _allTitles);

      // Before the first book was written, none of this run's books existed.
      final firstWrite = current.results
          .map((result) => result.createTime!)
          .reduce((a, b) => _micros(a) <= _micros(b) ? a : b);
      final beforeSeed = _truncateToMicros(firstWrite, secondsEarlier: 1);
      final past = await sortedBooks().execute(readTime: beforeSeed);
      expect(past.results, isEmpty);

      // By the time the first pipeline ran, all of them did.
      final seeded = _truncateToMicros(current.executionTime!);
      final atSeed = await sortedBooks().execute(readTime: seeded);
      expect(_titles(atSeed), _allTitles);

      // A read-only transaction at a read time reads at that time too.
      final inTransaction = await ctx.firestore.runTransaction(
        (transaction) => transaction.executePipeline(sortedBooks()),
        transactionOptions: ReadOnlyTransactionOptions(readTime: beforeSeed),
      );
      expect(inTransaction.results, isEmpty);
    });

    test('executes a pipeline inside a transaction', () async {
      final titles = await ctx.firestore.runTransaction((transaction) async {
        final snapshot = await transaction.executePipeline(
          ctx.firestore
              .pipeline()
              .collection(ctx.collectionPath)
              .where(ctx.runFilter(Expression.field('active').equal(true)))
              .sort([Expression.field('price').ascending()])
              .select([Expression.field('title')]),
        );
        return _titles(snapshot);
      }, transactionOptions: ReadOnlyTransactionOptions());

      expect(titles, ['Dart Pipelines', 'Firestore Admin']);
    });

    test('a transaction forwards execute options', () async {
      final pipeline = sortedBooks();

      final snapshot = await pipeline.firestore.runTransaction(
        (transaction) => transaction.executePipeline(
          pipeline,
          indexMode: PipelineIndexMode.recommended,
          // rawOptions win over the typed explain options, so this runs in
          // the default `execute` mode and returns no stats.
          explain: const PipelineExplainOptions(
            mode: PipelineExplainMode.analyze,
            outputFormat: PipelineExplainOutputFormat.text,
          ),
          rawOptions: const {
            'explain_options': {'mode': 'execute'},
          },
        ),
        transactionOptions: ReadOnlyTransactionOptions(),
      );

      expect(snapshot.explainStats, isNull);
      expect(_titles(snapshot), _allTitles);
    });
  });
}
