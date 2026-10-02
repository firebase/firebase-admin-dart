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

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  pipelineE2E('Pipeline results', (ctx) {
    test('exposes document metadata and nested fields', () async {
      final metadataSnapshot = await ctx.book1Pipeline().limit(1).execute();

      expect(metadataSnapshot.results.single.createTime, isNotNull);
      expect(metadataSnapshot.results.single.updateTime, isNotNull);
      expect(metadataSnapshot.results.single.ref, isNotNull);
      // get resolves nested dot-paths and FieldPaths, as in Node.
      expect(metadataSnapshot.results.single.get('metadata.lang'), 'dart');
      expect(
        metadataSnapshot.results.single.get(
          FieldPath(const ['metadata', 'category']),
        ),
        'sdk',
      );
      expect(metadataSnapshot.results.single.get('metadata.missing'), isNull);
    });
  });
}
