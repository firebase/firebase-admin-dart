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

/// Live coverage of `Firestore.pipeline` and the `PipelineSource` stages.
@Tags(['prod'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  pipelineE2E('Pipeline sources', (ctx) {
    test('executes a documents source stage', () async {
      final snapshot = await ctx.firestore
          .pipeline()
          .documents([ctx.book1Ref, ctx.book3Ref])
          .sort([Expression.field('price').ascending()])
          .select([Expression.field('title')])
          .execute();

      expect(snapshot.results.map((result) => result.get('title')), [
        'Dart Pipelines',
        'Inactive Draft',
      ]);
    });

    test('executes a collection group source stage', () async {
      final snapshot = await ctx.firestore
          .pipeline()
          .collectionGroup(ctx.collectionPath)
          .where(ctx.runFilter(Expression.field('active').equal(true)))
          .sort([Expression.field('price').ascending()])
          .select([Expression.field('title')])
          .execute();

      expect(snapshot.results.map((result) => result.get('title')), [
        'Dart Pipelines',
        'Firestore Admin',
      ]);
    });

    test('executes a pipeline created from a collection group query', () async {
      final snapshot = await ctx.firestore
          .pipeline()
          .createFrom(
            ctx.firestore
                .collectionGroup(ctx.collectionPath)
                .where('runId', WhereFilter.equal, ctx.runId)
                .where('active', WhereFilter.equal, true)
                .orderBy('price'),
          )
          .execute();

      expect(snapshot.results.map((result) => result.get('title')), [
        'Dart Pipelines',
        'Firestore Admin',
      ]);
    });
  });
}
