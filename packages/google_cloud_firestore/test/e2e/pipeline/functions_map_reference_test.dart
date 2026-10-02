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

/// Live coverage of the map and reference Pipeline functions.
@Tags(['prod'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  pipelineE2E('Pipeline map and reference functions', (ctx) {
    ctx.functionCases('map functions', [
      FunctionCase('map', PipelineFunctions.map(['a', 1, 'b', 2]), {
        'a': 1,
        'b': 2,
      }),
      FunctionCase(
        'mapGet',
        Expression.field('metadata').mapGetLiteral('category'),
        'sdk',
      ),
      FunctionCase(
        'mapSet',
        Expression.field('metadata').mapSet('edition', 'enterprise'),
        containsPair('edition', 'enterprise'),
      ),
      FunctionCase(
        'mapRemove',
        Expression.field('metadata').mapRemove('lang'),
        isNot(contains('lang')),
      ),
      FunctionCase(
        'mapRemove with an expression key',
        Expression.field('metadata').mapRemove(Expression.constant('lang')),
        isNot(contains('lang')),
      ),
      FunctionCase(
        'chained mapRemove',
        Expression.field('metadata').mapRemove('lang').mapRemove('category'),
        isEmpty,
      ),
      FunctionCase(
        'mapMerge',
        Expression.field('metadata').mapMerge([
          {'edition': 'enterprise'},
        ]),
        containsPair('edition', 'enterprise'),
      ),
      FunctionCase(
        'currentDocument',
        currentDocument(),
        isA<Map<Object?, Object?>>(),
      ),
      FunctionCase(
        'mapKeys',
        Expression.field('metadata').mapKeys(),
        containsAll(['lang', 'category']),
      ),
      FunctionCase(
        'mapValues',
        Expression.field('metadata').mapValues(),
        containsAll(['dart', 'sdk']),
      ),
      FunctionCase(
        'mapEntries',
        Expression.field('metadata').mapEntries(),
        isA<List<Object?>>(),
      ),
    ]);

    ctx.functionCases('reference functions', [
      FunctionCase(
        'collectionId',
        Expression.field('pathRef').collectionId(),
        isA<String>(),
      ),
      FunctionCase(
        'documentId',
        Expression.field('pathRef').documentId(),
        allOf(startsWith('run_'), endsWith('_book_2')),
      ),
      FunctionCase('parent', Expression.field('pathRef').parent(), isNotNull),
      FunctionCase(
        'referenceSlice',
        Expression.field('pathRef').referenceSlice(0, 2),
        isNotNull,
      ),
    ]);

    // Collections that hold expressions must be built with array(...) /
    // map(...); the backend rejects them inside a literal array or map value.
    ctx.functionCases('collections holding expressions', [
      FunctionCase(
        'mapMerge',
        Expression.field('metadata').mapMerge([
          {'title': Expression.field('title')},
        ]),
        containsPair('title', 'Dart Pipelines'),
      ),
      FunctionCase(
        'nestedMap',
        PipelineFunctions.map([
          'nested',
          {'price': Expression.field('price')},
        ]),
        {
          'nested': {'price': 10},
        },
      ),
    ]);
  });
}
