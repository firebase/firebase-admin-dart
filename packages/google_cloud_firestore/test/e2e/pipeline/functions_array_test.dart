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

/// Live coverage of the array Pipeline functions.
@Tags(['prod'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  pipelineE2E('Pipeline array functions', (ctx) {
    ctx.functionCases('array functions', [
      FunctionCase('array', Expression.array([1, 2, 3]), [1, 2, 3]),
      FunctionCase(
        'arrayConcat',
        Expression.field('tags').arrayConcat(['admin']),
        ['dart', 'firebase', 'admin'],
      ),
      FunctionCase(
        'arrayConcatMultiple',
        Expression.field('tags').arrayConcatMultiple([
          ['admin'],
          ['sdk'],
        ]),
        ['dart', 'firebase', 'admin', 'sdk'],
      ),
      FunctionCase(
        'arrayContainsValue',
        Expression.field('tags').arrayContains('dart'),
        true,
      ),
      FunctionCase(
        'arrayContainsElement',
        Expression.field('tags').arrayContains(Expression.constant('firebase')),
        true,
      ),
      FunctionCase(
        'arrayContainsAll',
        Expression.field('tags').arrayContainsAll(['dart', 'firebase']),
        true,
      ),
      FunctionCase(
        'arrayContainsAllFrom',
        Expression.field(
          'tags',
        ).arrayContainsAllFrom(Expression.array(['dart'])),
        true,
      ),
      FunctionCase(
        'arrayContainsAny',
        Expression.field('tags').arrayContainsAny(['missing', 'dart']),
        true,
      ),
      FunctionCase(
        'arrayFilter',
        Expression.field(
          'tags',
        ).arrayFilter('tag', Expression.variable('tag').notEqual('firebase')),
        ['dart'],
      ),
      FunctionCase(
        'arrayGet',
        PipelineFunctions.arrayGet(Expression.field('numbers'), 1),
        1,
      ),
      FunctionCase('arrayLength', Expression.field('numbers').arrayLength(), 4),
      FunctionCase('arrayReverse', Expression.field('numbers').arrayReverse(), [
        3,
        2,
        1,
        3,
      ]),
      FunctionCase('arrayFirst', Expression.field('numbers').arrayFirst(), 3),
      FunctionCase('arrayFirstN', Expression.field('numbers').arrayFirstN(2), [
        3,
        1,
      ]),
      FunctionCase(
        'arrayIndexOf',
        Expression.field('numbers').arrayIndexOf(1),
        1,
      ),
      FunctionCase(
        'arrayIndexOfAll',
        Expression.field('numbers').arrayIndexOfAll(3),
        [0, 3],
      ),
      FunctionCase('arrayLast', Expression.field('numbers').arrayLast(), 3),
      FunctionCase('arrayLastN', Expression.field('numbers').arrayLastN(2), [
        2,
        3,
      ]),
      FunctionCase(
        'arrayLastIndexOf',
        Expression.field('numbers').arrayLastIndexOf(3),
        3,
      ),
      FunctionCase('arraySlice', Expression.field('numbers').arraySlice(1, 2), [
        1,
        2,
      ]),
      FunctionCase(
        'arrayTransform',
        Expression.field(
          'numbers',
        ).arrayTransform('n', Expression.variable('n').add(1)),
        [4, 2, 3, 4],
      ),
      FunctionCase(
        'arrayTransformWithIndex',
        Expression.field('numbers').arrayTransformWithIndex(
          'n',
          'i',
          Expression.variable('n').add(Expression.variable('i')),
        ),
        [3, 2, 4, 6],
      ),
      FunctionCase(
        'arrayMaximum',
        Expression.field('numbers').arrayMaximum(),
        3,
      ),
      FunctionCase('maximumN', Expression.field('numbers').arrayMaximumN(2), [
        3,
        3,
      ]),
      FunctionCase(
        'arrayMinimum',
        Expression.field('numbers').arrayMinimum(),
        1,
      ),
      FunctionCase('minimumN', Expression.field('numbers').arrayMinimumN(2), [
        1,
        2,
      ]),
      FunctionCase('arraySum', Expression.field('numbers').arraySum(), 9),
      // The static helpers must emit the same backend names as the fluent
      // forms (`maximum`, not `array_maximum`).
      FunctionCase(
        'staticArrayMaximum',
        PipelineFunctions.arrayMaximum('numbers'),
        3,
      ),
      FunctionCase(
        'staticArrayMaximumN',
        PipelineFunctions.arrayMaximumN('numbers', 2),
        [3, 3],
      ),
      FunctionCase(
        'staticArrayMinimum',
        PipelineFunctions.arrayMinimum('numbers'),
        1,
      ),
      FunctionCase(
        'staticArrayMinimumN',
        PipelineFunctions.arrayMinimumN('numbers', 2),
        [1, 2],
      ),
      FunctionCase('staticArraySum', PipelineFunctions.arraySum('numbers'), 9),
      FunctionCase(
        'join',
        Expression.field('words').joinLiteral('-'),
        'dart-firebase',
      ),
      FunctionCase(
        'joinStatic',
        PipelineFunctions.join('words', ', '),
        'dart, firebase',
      ),
    ]);

    // Collections that hold expressions must be built with array(...) /
    // map(...); the backend rejects them inside a literal array or map value.
    ctx.functionCases('collections holding expressions', [
      FunctionCase(
        'arrayContainsAll',
        PipelineFunctions.arrayContainsAll('tags', [
          Expression.field('metadata').mapGetLiteral('lang'),
          'firebase',
        ]),
        true,
      ),
      FunctionCase(
        'arrayContainsAny',
        Expression.field('tags').arrayContainsAny([
          Expression.field('metadata').mapGetLiteral('lang'),
          'missing',
        ]),
        true,
      ),
      FunctionCase(
        'arrayConcat',
        Expression.field('tags').arrayConcat([Expression.field('title')]),
        ['dart', 'firebase', 'Dart Pipelines'],
      ),
      FunctionCase(
        'nestedArray',
        Expression.array([
          1,
          [Expression.field('price')],
        ]),
        [
          1,
          [10],
        ],
      ),
    ]);
  });
}
