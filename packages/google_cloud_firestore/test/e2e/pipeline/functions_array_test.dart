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
    ctx.functionCases('array construction', [
      FunctionCase('array', Expression.array([1, 2, 3]), [1, 2, 3]),
      FunctionCase(
        'array with an expression element',
        Expression.array([Expression.field('prefix'), 'x']),
        ['Dart', 'x'],
      ),
      FunctionCase(
        'static array of plain values',
        PipelineFunctions.array(['a', 1, true, null]),
        ['a', 1, true, null],
      ),
      FunctionCase(
        'static array with expression elements',
        PipelineFunctions.array([
          Expression.field('title'),
          Expression.field('rating'),
          0,
        ]),
        ['Dart Pipelines', 5, 0],
      ),
    ]);

    ctx.functionCases('arrayConcat', [
      FunctionCase(
        'arrayConcat',
        Expression.field('tags').arrayConcat(['admin']),
        ['dart', 'firebase', 'admin'],
      ),
      FunctionCase(
        'arrayConcat with an array expression',
        Expression.field('tags').arrayConcat(Expression.field('words')),
        ['dart', 'firebase', 'dart', 'firebase'],
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
        'static arrayConcat',
        PipelineFunctions.arrayConcat([
          'tags',
          ['admin'],
          Expression.field('emptyArray'),
          [null],
        ]),
        ['dart', 'firebase', 'admin', null],
      ),
      FunctionCase(
        'static arrayConcat of expressions',
        PipelineFunctions.arrayConcat([
          Expression.field('numbers'),
          Expression.field('scores'),
        ]),
        [3, 1, 2, 3, 1.5, 2.5, -0.5],
      ),
    ]);

    ctx.functionCases('arrayContains', [
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
        'static arrayContains',
        PipelineFunctions.arrayContains('tags', 'firebase'),
        true,
      ),
      FunctionCase(
        'static arrayContains with expressions',
        PipelineFunctions.arrayContains(
          Expression.field('numbers'),
          Expression.field('discount'),
        ),
        true,
      ),
      FunctionCase(
        'static arrayContains of a value not in the array',
        PipelineFunctions.arrayContains('numbers', Expression.field('rating')),
        false,
      ),
      FunctionCase(
        'arrayContainsAll',
        Expression.field('tags').arrayContainsAll(['dart', 'firebase']),
        true,
      ),
      FunctionCase(
        'arrayContainsAll with an array expression',
        Expression.field(
          'words',
        ).arrayContainsAll(Expression.array(['firebase', 'dart'])),
        true,
      ),
      FunctionCase(
        'static arrayContainsAll with expressions',
        PipelineFunctions.arrayContainsAll(
          Expression.field('tags'),
          Expression.field('words'),
        ),
        true,
      ),
      FunctionCase(
        'static arrayContainsAll with a missing value',
        PipelineFunctions.arrayContainsAll('numbers', [1, 4]),
        false,
      ),
      FunctionCase(
        'arrayContainsAllFrom',
        Expression.field(
          'tags',
        ).arrayContainsAllFrom(Expression.array(['dart'])),
        true,
      ),
      FunctionCase(
        'arrayContainsAllFrom with a list',
        Expression.field('tags').arrayContainsAllFrom(['dart', 'missing']),
        false,
      ),
      FunctionCase(
        'arrayContainsAny',
        Expression.field('tags').arrayContainsAny(['missing', 'dart']),
        true,
      ),
      FunctionCase(
        'arrayContainsAny with an array expression',
        Expression.field(
          'tags',
        ).arrayContainsAny(Expression.array(['sdk', 'admin'])),
        false,
      ),
      FunctionCase(
        'static arrayContainsAny',
        PipelineFunctions.arrayContainsAny('tags', ['missing', 'firebase']),
        true,
      ),
      FunctionCase(
        'static arrayContainsAny with expressions',
        PipelineFunctions.arrayContainsAny(
          Expression.field('numbers'),
          Expression.array([9, 4]),
        ),
        false,
      ),
    ]);

    ctx.functionCases('arrayFilter and arrayTransform', [
      FunctionCase(
        'arrayFilter',
        Expression.field(
          'tags',
        ).arrayFilter('tag', Expression.variable('tag').notEqual('firebase')),
        ['dart'],
      ),
      FunctionCase(
        'static arrayFilter',
        PipelineFunctions.arrayFilter(
          'numbers',
          'n',
          variable('n').greaterThan(1),
        ),
        [3, 2, 3],
      ),
      FunctionCase(
        'static arrayFilter with a constant predicate',
        PipelineFunctions.arrayFilter(Expression.field('tags'), 'tag', false),
        <Object?>[],
      ),
      FunctionCase(
        'arrayTransform',
        Expression.field(
          'numbers',
        ).arrayTransform('n', Expression.variable('n').add(1)),
        [4, 2, 3, 4],
      ),
      // A list body holding the variable is built with array(...), so each
      // element maps to a pair.
      FunctionCase(
        'arrayTransform with a list body',
        Expression.field('tags').arrayTransform('t', [variable('t'), 1]),
        [
          ['dart', 1],
          ['firebase', 1],
        ],
      ),
      FunctionCase(
        'static arrayTransform',
        PipelineFunctions.arrayTransform(
          'numbers',
          'n',
          variable('n').multiply(2),
        ),
        [6, 2, 4, 6],
      ),
      FunctionCase(
        'static arrayTransform with a constant body',
        PipelineFunctions.arrayTransform(Expression.field('tags'), 't', 'x'),
        ['x', 'x'],
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
        'arrayTransformWithIndex with a constant body',
        Expression.field('tags').arrayTransformWithIndex('t', 'i', 7),
        [7, 7],
      ),
      FunctionCase(
        'static arrayTransformWithIndex',
        PipelineFunctions.arrayTransformWithIndex(
          'tags',
          't',
          'i',
          variable('i'),
        ),
        [0, 1],
      ),
      FunctionCase(
        'static arrayTransformWithIndex with a list body',
        PipelineFunctions.arrayTransformWithIndex(
          Expression.field('scores'),
          's',
          'i',
          [variable('i'), variable('s')],
        ),
        [
          [0, 1.5],
          [1, 2.5],
          [2, -0.5],
        ],
      ),
    ]);

    ctx.functionCases('element access', [
      FunctionCase(
        'arrayGet',
        Expression.field('tags').arrayGet(1),
        'firebase',
      ),
      // A negative index counts from the end.
      FunctionCase(
        'arrayGet with a negative index',
        Expression.field('scores').arrayGet(Expression.constant(-1)),
        -0.5,
      ),
      FunctionCase(
        'static arrayGet',
        PipelineFunctions.arrayGet(Expression.field('numbers'), 1),
        1,
      ),
      FunctionCase(
        'static arrayGet with an index expression',
        PipelineFunctions.arrayGet('numbers', Expression.field('discount')),
        2,
      ),
      FunctionCase('arrayFirst', Expression.field('numbers').arrayFirst(), 3),
      FunctionCase(
        'static arrayFirst',
        PipelineFunctions.arrayFirst('tags'),
        'dart',
      ),
      FunctionCase(
        'static arrayFirst of an expression',
        PipelineFunctions.arrayFirst(Expression.field('scores')),
        1.5,
      ),
      FunctionCase('arrayFirstN', Expression.field('numbers').arrayFirstN(2), [
        3,
        1,
      ]),
      FunctionCase(
        'arrayFirstN with an expression count',
        Expression.field('scores').arrayFirstN(Expression.constant(2)),
        [1.5, 2.5],
      ),
      FunctionCase(
        'static arrayFirstN',
        PipelineFunctions.arrayFirstN('tags', 1),
        ['dart'],
      ),
      FunctionCase(
        'static arrayFirstN with expressions',
        PipelineFunctions.arrayFirstN(
          Expression.field('numbers'),
          Expression.field('discount'),
        ),
        [3, 1],
      ),
      FunctionCase('arrayLast', Expression.field('numbers').arrayLast(), 3),
      FunctionCase(
        'static arrayLast',
        PipelineFunctions.arrayLast('tags'),
        'firebase',
      ),
      FunctionCase(
        'static arrayLast of an expression',
        PipelineFunctions.arrayLast(Expression.field('scores')),
        -0.5,
      ),
      FunctionCase('arrayLastN', Expression.field('numbers').arrayLastN(2), [
        2,
        3,
      ]),
      FunctionCase(
        'arrayLastN with an expression count',
        Expression.field('tags').arrayLastN(Expression.constant(1)),
        ['firebase'],
      ),
      FunctionCase(
        'static arrayLastN',
        PipelineFunctions.arrayLastN('scores', 2),
        [2.5, -0.5],
      ),
      FunctionCase(
        'static arrayLastN with expressions',
        PipelineFunctions.arrayLastN(
          Expression.field('numbers'),
          Expression.field('discount'),
        ),
        [2, 3],
      ),
      FunctionCase('arraySlice', Expression.field('numbers').arraySlice(1, 2), [
        1,
        2,
      ]),
      FunctionCase(
        'arraySlice without a length runs to the end',
        Expression.field('scores').arraySlice(1),
        [2.5, -0.5],
      ),
      FunctionCase(
        'arraySlice with expressions',
        Expression.field(
          'numbers',
        ).arraySlice(Expression.constant(1), Expression.field('discount')),
        [1, 2],
      ),
      // A negative offset counts from the end: -2 is index 2 of [3, 1, 2, 3].
      FunctionCase(
        'arraySlice with a negative offset',
        Expression.field('numbers').arraySlice(-2, 1),
        [2],
      ),
      FunctionCase(
        'static arraySlice',
        PipelineFunctions.arraySlice('tags', 0, 1),
        ['dart'],
      ),
      FunctionCase(
        'static arraySlice without a length runs to the end',
        PipelineFunctions.arraySlice('numbers', 1),
        [1, 2, 3],
      ),
      FunctionCase(
        'static arraySlice with expressions',
        PipelineFunctions.arraySlice(
          Expression.field('numbers'),
          Expression.field('discount'),
          Expression.constant(1),
        ),
        [2],
      ),
    ]);

    ctx.functionCases('index search', [
      FunctionCase(
        'arrayIndexOf',
        Expression.field('numbers').arrayIndexOf(1),
        1,
      ),
      FunctionCase(
        'arrayIndexOf an expression',
        Expression.field('tags').arrayIndexOf(Expression.constant('firebase')),
        isInt(1),
      ),
      FunctionCase(
        'static arrayIndexOf',
        PipelineFunctions.arrayIndexOf('numbers', 3),
        isInt(0),
      ),
      FunctionCase(
        'static arrayIndexOf with expressions',
        PipelineFunctions.arrayIndexOf(
          Expression.field('numbers'),
          Expression.field('discount'),
        ),
        isInt(2),
      ),
      FunctionCase(
        'static arrayIndexOf of a value not in the array',
        PipelineFunctions.arrayIndexOf('tags', 'missing'),
        isInt(-1),
      ),
      FunctionCase(
        'static arrayIndexOf of null',
        PipelineFunctions.arrayIndexOf('withNulls', null),
        isInt(1),
      ),
      FunctionCase(
        'arrayIndexOfAll',
        Expression.field('numbers').arrayIndexOfAll(3),
        [0, 3],
      ),
      FunctionCase(
        'arrayIndexOfAll an expression',
        Expression.field(
          'numbers',
        ).arrayIndexOfAll(Expression.field('discount')),
        [2],
      ),
      FunctionCase(
        'arrayIndexOfAll of a value not in the array',
        Expression.field('tags').arrayIndexOfAll('missing'),
        <Object?>[],
      ),
      FunctionCase(
        'static arrayIndexOfAll',
        PipelineFunctions.arrayIndexOfAll('booleans', true),
        [0, 2],
      ),
      FunctionCase(
        'static arrayIndexOfAll with expressions',
        PipelineFunctions.arrayIndexOfAll(
          Expression.field('booleans'),
          Expression.field('archived'),
        ),
        [1],
      ),
      FunctionCase(
        'arrayLastIndexOf',
        Expression.field('numbers').arrayLastIndexOf(3),
        3,
      ),
      FunctionCase(
        'arrayLastIndexOf an expression',
        Expression.field(
          'booleans',
        ).arrayLastIndexOf(Expression.field('active')),
        isInt(2),
      ),
      FunctionCase(
        'static arrayLastIndexOf',
        PipelineFunctions.arrayLastIndexOf('booleans', false),
        isInt(1),
      ),
      FunctionCase(
        'static arrayLastIndexOf with expressions',
        PipelineFunctions.arrayLastIndexOf(
          Expression.field('numbers'),
          Expression.constant(3),
        ),
        isInt(3),
      ),
      FunctionCase(
        'static arrayLastIndexOf of a value not in the array',
        PipelineFunctions.arrayLastIndexOf('tags', 'missing'),
        isInt(-1),
      ),
    ]);

    ctx.functionCases('arrayLength and arrayReverse', [
      FunctionCase('arrayLength', Expression.field('numbers').arrayLength(), 4),
      FunctionCase(
        'static arrayLength',
        PipelineFunctions.arrayLength('tags'),
        isInt(2),
      ),
      FunctionCase(
        'static arrayLength of an expression',
        PipelineFunctions.arrayLength(Expression.field('emptyArray')),
        isInt(0),
      ),
      FunctionCase('arrayReverse', Expression.field('numbers').arrayReverse(), [
        3,
        2,
        1,
        3,
      ]),
      FunctionCase(
        'static arrayReverse',
        PipelineFunctions.arrayReverse('scores'),
        [-0.5, 2.5, 1.5],
      ),
      FunctionCase(
        'static arrayReverse of an expression',
        PipelineFunctions.arrayReverse(Expression.field('tags')),
        ['firebase', 'dart'],
      ),
    ]);

    // maximumN returns the largest elements in descending order and minimumN
    // the smallest in ascending order, as in the Node SDK system tests.
    ctx.functionCases('maximum, minimum and sum', [
      FunctionCase(
        'arrayMaximum',
        Expression.field('numbers').arrayMaximum(),
        3,
      ),
      FunctionCase(
        'arrayMaximumN',
        Expression.field('numbers').arrayMaximumN(2),
        [3, 3],
      ),
      FunctionCase(
        'arrayMaximumN with an expression count',
        Expression.field('scores').arrayMaximumN(Expression.constant(1)),
        [2.5],
      ),
      FunctionCase(
        'arrayMinimum',
        Expression.field('numbers').arrayMinimum(),
        1,
      ),
      FunctionCase(
        'arrayMinimumN',
        Expression.field('numbers').arrayMinimumN(2),
        [1, 2],
      ),
      FunctionCase(
        'arrayMinimumN with an expression count',
        Expression.field('tags').arrayMinimumN(Expression.field('discount')),
        ['dart', 'firebase'],
      ),
      FunctionCase('arraySum', Expression.field('numbers').arraySum(), 9),
      FunctionCase(
        'arraySum of mixed ints and doubles',
        Expression.field('mixedNumbers').arraySum(),
        isDouble(0.5),
      ),
      // The static helpers must emit the same backend names as the fluent
      // forms (`maximum`, not `array_maximum`).
      FunctionCase(
        'static arrayMaximum',
        PipelineFunctions.arrayMaximum('numbers'),
        3,
      ),
      FunctionCase(
        'static arrayMaximum of an expression',
        PipelineFunctions.arrayMaximum(Expression.field('scores')),
        isDouble(2.5),
      ),
      FunctionCase(
        'static arrayMaximumN',
        PipelineFunctions.arrayMaximumN('numbers', 2),
        [3, 3],
      ),
      FunctionCase(
        'static arrayMaximumN with expressions',
        PipelineFunctions.arrayMaximumN(
          Expression.field('tags'),
          Expression.constant(1),
        ),
        ['firebase'],
      ),
      FunctionCase(
        'static arrayMinimum',
        PipelineFunctions.arrayMinimum('numbers'),
        1,
      ),
      FunctionCase(
        'static arrayMinimum of an expression',
        PipelineFunctions.arrayMinimum(Expression.field('mixedNumbers')),
        isInt(-3),
      ),
      FunctionCase(
        'static arrayMinimumN',
        PipelineFunctions.arrayMinimumN('numbers', 2),
        [1, 2],
      ),
      FunctionCase(
        'static arrayMinimumN with expressions',
        PipelineFunctions.arrayMinimumN(
          Expression.field('scores'),
          Expression.constant(2),
        ),
        [-0.5, 1.5],
      ),
      FunctionCase('static arraySum', PipelineFunctions.arraySum('numbers'), 9),
      FunctionCase(
        'static arraySum of an expression',
        PipelineFunctions.arraySum(Expression.field('scores')),
        isDouble(3.5),
      ),
      FunctionCase('static maximumN', PipelineFunctions.maximumN('scores', 2), [
        2.5,
        1.5,
      ]),
      FunctionCase(
        'static maximumN with expressions',
        PipelineFunctions.maximumN(
          Expression.field('mixedNumbers'),
          Expression.field('discount'),
        ),
        [2.5, 1],
      ),
      FunctionCase('static minimumN', PipelineFunctions.minimumN('scores', 2), [
        -0.5,
        1.5,
      ]),
      FunctionCase(
        'static minimumN with expressions',
        PipelineFunctions.minimumN(
          Expression.field('mixedNumbers'),
          Expression.field('discount'),
        ),
        [-3, 0],
      ),
    ]);

    ctx.functionCases('join', [
      FunctionCase(
        'joinLiteral',
        Expression.field('words').joinLiteral('-'),
        'dart-firebase',
      ),
      FunctionCase(
        'join',
        Expression.field('words').join('/'),
        'dart/firebase',
      ),
      FunctionCase(
        'join with an expression delimiter',
        Expression.field('tags').join(Expression.field('delimiter')),
        'dart;firebase',
      ),
      FunctionCase(
        'static join',
        PipelineFunctions.join('words', ', '),
        'dart, firebase',
      ),
      FunctionCase(
        'static join with expressions',
        PipelineFunctions.join(
          Expression.array(['a', 'b', 'c']),
          Expression.field('delimiter'),
        ),
        'a;b;c',
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
        'fluent arrayContainsAll',
        Expression.field(
          'numbers',
        ).arrayContainsAll([Expression.field('discount'), 3]),
        true,
      ),
      FunctionCase(
        'fluent arrayContainsAll with a value not in the array',
        Expression.field(
          'numbers',
        ).arrayContainsAll([Expression.field('rating'), 3]),
        false,
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
        'static arrayContainsAny',
        PipelineFunctions.arrayContainsAny('numbers', [
          Expression.field('rating'),
          Expression.field('discount'),
        ]),
        true,
      ),
      FunctionCase(
        'arrayConcat',
        Expression.field('tags').arrayConcat([Expression.field('title')]),
        ['dart', 'firebase', 'Dart Pipelines'],
      ),
      FunctionCase(
        'static arrayConcat',
        PipelineFunctions.arrayConcat([
          'tags',
          [Expression.field('prefix'), 'sdk'],
        ]),
        ['dart', 'firebase', 'Dart', 'sdk'],
      ),
      FunctionCase(
        'arrayConcatMultiple',
        Expression.field('numbers').arrayConcatMultiple([
          Expression.field('emptyArray'),
          [Expression.field('rating'), 0],
        ]),
        [3, 1, 2, 3, 5, 0],
      ),
      FunctionCase(
        'nested array',
        Expression.array([
          1,
          [Expression.field('price')],
        ]),
        [
          1,
          [10],
        ],
      ),
      FunctionCase(
        'static nested array and map',
        PipelineFunctions.array([
          [Expression.field('rating'), 0],
          {'price': Expression.field('price')},
        ]),
        [
          [5, 0],
          {'price': 10},
        ],
      ),
    ]);

    // As in the Node SDK system tests: the first or last element of an empty
    // array is absent, while the maximum of an empty array, any of these on
    // null, and an index search in an absent field are null.
    test('empty, null and absent arrays', () async {
      final snapshot = await ctx.book1Pipeline().select([
        PipelineFunctions.arrayFirst('emptyArray').as('firstOfEmpty'),
        Expression.field('emptyArray').arrayLast().as('lastOfEmpty'),
        PipelineFunctions.arrayFirst('nullable').as('firstOfNull'),
        PipelineFunctions.arrayLast('missing').as('lastOfAbsent'),
        PipelineFunctions.arrayFirstN('emptyArray', 1).as('firstNOfEmpty'),
        PipelineFunctions.arrayLastN('nullable', 1).as('lastNOfNull'),
        PipelineFunctions.arrayMaximum('emptyArray').as('maximumOfEmpty'),
        PipelineFunctions.arrayMinimum('nullable').as('minimumOfNull'),
        PipelineFunctions.arrayIndexOf('missing', 'x').as('indexOfAbsent'),
        PipelineFunctions.arrayIndexOfAll('missing', 'x').as('indexesOfAbsent'),
      ]).execute();

      expect(snapshot.results, hasLength(1));
      expect(snapshot.results.single.data(), {
        'firstOfNull': null,
        'lastOfAbsent': null,
        'firstNOfEmpty': <Object?>[],
        'lastNOfNull': null,
        'maximumOfEmpty': null,
        'minimumOfNull': null,
        'indexOfAbsent': null,
        'indexesOfAbsent': null,
      });
    });
  });
}
