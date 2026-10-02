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

void main() {
  pipelineE2E('Pipeline execution', (ctx) {
    test('requests explain stats via typed options', () async {
      final snapshot = await ctx.firestore
          .pipeline()
          .collection(ctx.collectionPath)
          .where(ctx.runFilter(Expression.field('active').equal(true)))
          .execute(
            explain: const PipelineExplainOptions(
              mode: PipelineExplainMode.analyze,
              outputFormat: PipelineExplainOutputFormat.text,
            ),
          );

      // `analyze` runs the pipeline and returns planning stats alongside the
      // results, which is what proves the option names reached the backend.
      expect(snapshot.results, isNotEmpty);
      expect(snapshot.explainStats, isNotNull);
      expect(snapshot.explainStats!.text, isNotEmpty);
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
        return [for (final result in snapshot.results) result.get('title')];
      }, transactionOptions: ReadOnlyTransactionOptions());

      expect(titles, ['Dart Pipelines', 'Firestore Admin']);
    });
  });
}
