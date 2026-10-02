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

/// Live coverage of the comparison and logical Pipeline functions.
@Tags(['prod'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
// The top-level Pipeline `greaterThan` / `lessThan` share their names with
// package:matcher's matchers.
import 'package:test/test.dart' hide greaterThan, lessThan;

import 'harness.dart';

void main() {
  pipelineE2E('Pipeline comparison and logical functions', (ctx) {
    // Book 1: price 10, rating 5, discount 2, quantity 7, zero 0,
    // score -12.7, ratio 0.5, half 2.5, title 'Dart Pipelines'.
    ctx.functionCases('comparison functions', [
      FunctionCase('equal', Expression.field('price').equal(10), true),
      FunctionCase('notEqual', Expression.field('price').notEqual(11), true),
      FunctionCase(
        'greaterThan',
        Expression.field('price').greaterThan(9),
        true,
      ),
      FunctionCase(
        'greaterThanOrEqual',
        Expression.field('price').greaterThanOrEqual(10),
        true,
      ),
      FunctionCase('lessThan', Expression.field('price').lessThan(11), true),
      FunctionCase(
        'lessThanOrEqual',
        Expression.field('price').lessThanOrEqual(10),
        true,
      ),
      FunctionCase(
        'lessThan is false at the boundary',
        Expression.field('price').lessThan(10),
        false,
      ),
      FunctionCase(
        'equal against an expression',
        Expression.field('price').equal(Expression.field('rating').multiply(2)),
        true,
      ),
      FunctionCase(
        'notEqual against an expression',
        Expression.field('price').notEqual(Expression.field('discount')),
        true,
      ),
      FunctionCase(
        'greaterThan against an expression',
        Expression.field('price').greaterThan(Expression.field('quantity')),
        true,
      ),
      FunctionCase(
        'greaterThanOrEqual against an expression',
        Expression.field(
          'discount',
        ).greaterThanOrEqual(Expression.field('rating')),
        false,
      ),
      FunctionCase(
        'lessThan against an expression',
        Expression.field('rating').lessThan(Expression.field('price')),
        true,
      ),
      FunctionCase(
        'lessThanOrEqual against an expression',
        Expression.field('price').lessThanOrEqual(Expression.field('discount')),
        false,
      ),
    ]);

    // In the static and top-level forms the left operand is a field position
    // (a String names a field) while the right operand is a value position (a
    // String is a string literal).
    ctx.functionCases('comparison functions (PipelineFunctions)', [
      FunctionCase(
        'equal with a field name and a literal',
        PipelineFunctions.equal('rating', 5),
        true,
      ),
      FunctionCase(
        'equal with two expressions',
        PipelineFunctions.equal(
          Expression.field('price'),
          Expression.field('rating').multiply(2),
        ),
        true,
      ),
      FunctionCase(
        'notEqual with a field name and a literal',
        PipelineFunctions.notEqual('title', 'Firestore Admin'),
        true,
      ),
      FunctionCase(
        'notEqual with two expressions',
        PipelineFunctions.notEqual(
          Expression.field('quantity'),
          Expression.field('stats').mapGetLiteral('likes'),
        ),
        false,
      ),
      FunctionCase(
        'lessThan with a field name and a literal',
        PipelineFunctions.lessThan('score', 0),
        true,
      ),
      FunctionCase(
        'lessThan with a literal left operand',
        PipelineFunctions.lessThan(5, Expression.field('price')),
        true,
      ),
      FunctionCase(
        'lessThan with two expressions',
        PipelineFunctions.lessThan(
          Expression.field('price'),
          Expression.field('discount'),
        ),
        false,
      ),
      FunctionCase(
        'lessThanOrEqual with a field name and a literal',
        PipelineFunctions.lessThanOrEqual('zero', 0),
        true,
      ),
      FunctionCase(
        'lessThanOrEqual with two expressions',
        PipelineFunctions.lessThanOrEqual(
          Expression.field('quantity'),
          Expression.field('discount'),
        ),
        false,
      ),
      FunctionCase(
        'greaterThan with a field name and a string literal',
        PipelineFunctions.greaterThan('title', 'Dart'),
        true,
      ),
      FunctionCase(
        'greaterThan with two expressions',
        PipelineFunctions.greaterThan(
          Expression.field('zero'),
          Expression.field('quantity'),
        ),
        false,
      ),
      FunctionCase(
        'greaterThanOrEqual with a field name and a literal',
        PipelineFunctions.greaterThanOrEqual('rating', 5),
        true,
      ),
      FunctionCase(
        'greaterThanOrEqual with two expressions',
        PipelineFunctions.greaterThanOrEqual(
          Expression.field('ratio'),
          Expression.field('half'),
        ),
        false,
      ),
    ]);

    ctx.functionCases('comparison functions (top-level)', [
      FunctionCase(
        'equal with a field name and a literal',
        equal('price', 10),
        true,
      ),
      FunctionCase(
        'equal treats a right-hand String as a literal',
        equal('title', 'title'),
        false,
      ),
      FunctionCase(
        'equal with two expressions',
        equal(Expression.field('rating'), Expression.field('price')),
        false,
      ),
      FunctionCase(
        'notEqual with a field name and a literal',
        notEqual('price', 11),
        true,
      ),
      FunctionCase(
        'notEqual with two expressions',
        notEqual(Expression.field('price'), Expression.constant(10)),
        false,
      ),
      FunctionCase(
        'lessThan with a field name and an expression',
        lessThan('rating', Expression.field('price')),
        true,
      ),
      FunctionCase(
        'lessThan with an expression and a literal',
        lessThan(Expression.field('price'), 10),
        false,
      ),
      FunctionCase(
        'lessThanOrEqual with a field name and a literal',
        lessThanOrEqual('price', 10),
        true,
      ),
      FunctionCase(
        'lessThanOrEqual with two expressions',
        lessThanOrEqual(Expression.field('price'), Expression.field('rating')),
        false,
      ),
      FunctionCase(
        'greaterThan with a field name and an expression',
        greaterThan('price', Expression.field('rating')),
        true,
      ),
      FunctionCase(
        'greaterThan with an expression and a literal',
        greaterThan(Expression.field('rating'), 5),
        false,
      ),
      FunctionCase(
        'greaterThanOrEqual with a field name and a literal',
        greaterThanOrEqual('rating', 5),
        true,
      ),
      FunctionCase(
        'greaterThanOrEqual with two expressions',
        greaterThanOrEqual(
          Expression.field('discount'),
          Expression.field('rating'),
        ),
        false,
      ),
    ]);

    // cmp returns -1, 0 or 1 as the left operand sorts before, equal to or
    // after the right one.
    ctx.functionCases('cmp', [
      FunctionCase(
        'cmp',
        PipelineFunctions.cmp(Expression.field('price'), 10),
        0,
      ),
      FunctionCase(
        'cmp with a field name and an expression',
        PipelineFunctions.cmp('rating', Expression.field('price')),
        isInt(-1),
      ),
      FunctionCase(
        'cmp with two expressions',
        PipelineFunctions.cmp(
          Expression.field('price'),
          Expression.field('discount'),
        ),
        isInt(1),
      ),
    ]);

    // Book 1: active true, archived false.
    ctx.functionCases('logical functions', [
      FunctionCase(
        'and',
        PipelineFunctions.and([true, Expression.field('active')]),
        true,
      ),
      FunctionCase(
        'or',
        PipelineFunctions.or([false, Expression.field('active')]),
        true,
      ),
      FunctionCase('xor', PipelineFunctions.xor([true, false]), true),
      FunctionCase(
        'xor with expressions',
        PipelineFunctions.xor([
          Expression.field('active'),
          Expression.field('archived'),
        ]),
        true,
      ),
      FunctionCase(
        'xor with two true operands',
        PipelineFunctions.xor([
          Expression.field('price').equal(10),
          Expression.field('rating').equal(5),
          Expression.field('archived'),
        ]),
        false,
      ),
      FunctionCase('nor', PipelineFunctions.nor([false, false]), true),
      FunctionCase(
        'nor with expressions',
        PipelineFunctions.nor([
          Expression.field('archived'),
          Expression.field('price').greaterThan(10),
        ]),
        true,
      ),
      FunctionCase(
        'nor with a true operand',
        PipelineFunctions.nor([false, Expression.field('active')]),
        false,
      ),
      FunctionCase('not', PipelineFunctions.not(false), true),
      FunctionCase(
        'not with an expression',
        PipelineFunctions.not(Expression.field('active')),
        false,
      ),
      FunctionCase(
        'fluent not',
        Expression.field('archived').equal(true).not(),
        true,
      ),
      FunctionCase(
        'top-level and',
        and([equal('price', 10), greaterThan('rating', 4)]),
        true,
      ),
      FunctionCase(
        'top-level and with a false operand',
        and([equal('price', 10), equal('archived', true)]),
        false,
      ),
      FunctionCase(
        'top-level or',
        or([equal('price', 20), equal('rating', 5)]),
        true,
      ),
      FunctionCase(
        'top-level or with no true operand',
        or([equal('price', 20), lessThan('rating', 3)]),
        false,
      ),
      FunctionCase('top-level not', not(equal('price', 10)), false),
    ]);

    ctx.functionCases('conditional', [
      FunctionCase(
        'conditional',
        PipelineFunctions.conditional(Expression.field('active'), 'yes', 'no'),
        'yes',
      ),
      FunctionCase(
        'conditional with a literal condition and expression branches',
        PipelineFunctions.conditional(
          false,
          Expression.field('price'),
          Expression.field('rating'),
        ),
        isInt(5),
      ),
      FunctionCase(
        'fluent conditional with literal branches',
        Expression.field(
          'rating',
        ).greaterThanOrEqual(5).conditional('great', 'good'),
        'great',
      ),
      FunctionCase(
        'fluent conditional with expression branches',
        Expression.field('price')
            .greaterThan(15)
            .conditional(
              Expression.field('price'),
              Expression.field('discount'),
            ),
        isInt(2),
      ),
    ]);

    // Book 1: nullable null, no field named `missing`. coalesce returns its
    // first argument that is neither absent nor null.
    ctx.functionCases('ifNull and coalesce', [
      FunctionCase(
        'ifNull',
        PipelineFunctions.ifNull(Expression.field('nullable'), 'fallback'),
        'fallback',
      ),
      FunctionCase(
        'ifNull with a field name and an expression',
        PipelineFunctions.ifNull('nullable', Expression.field('price')),
        isInt(10),
      ),
      FunctionCase(
        'ifNull keeps a non-null value',
        PipelineFunctions.ifNull('title', 'fallback'),
        'Dart Pipelines',
      ),
      FunctionCase(
        'fluent ifNull with a literal',
        Expression.field('nullable').ifNull(42),
        isInt(42),
      ),
      FunctionCase(
        'fluent ifNull with an expression',
        Expression.field('nullable').ifNull(Expression.field('title')),
        'Dart Pipelines',
      ),
      FunctionCase(
        'fluent ifNull keeps a non-null value',
        Expression.field('price').ifNull(0),
        isInt(10),
      ),
      FunctionCase(
        'coalesce with a field name and a literal',
        PipelineFunctions.coalesce('nullable', 'fallback'),
        'fallback',
      ),
      FunctionCase(
        'coalesce keeps a present value',
        PipelineFunctions.coalesce('price', 0),
        isInt(10),
      ),
      FunctionCase(
        'coalesce skips absent and null values',
        PipelineFunctions.coalesce(
          Expression.field('missing'),
          Expression.field('nullable'),
          [Expression.field('title'), 'unused'],
        ),
        'Dart Pipelines',
      ),
      FunctionCase(
        'coalesce falls through to a literal',
        PipelineFunctions.coalesce(
          Expression.field('missing'),
          Expression.field('nullable'),
          ['last'],
        ),
        'last',
      ),
      FunctionCase(
        'fluent coalesce with a literal',
        Expression.field('nullable').coalesce('fallback'),
        'fallback',
      ),
      FunctionCase(
        'fluent coalesce with expressions',
        Expression.field('missing').coalesce(Expression.field('nullable'), [
          Expression.field('rating'),
          0,
        ]),
        isInt(5),
      ),
    ]);

    // switchOn takes alternating conditions and results, and an optional
    // trailing default; it returns the result of the first true condition.
    ctx.functionCases('switchOn', [
      FunctionCase(
        'switchOn picks the first true condition',
        PipelineFunctions.switchOn([
          Expression.field('price').greaterThan(20),
          'expensive',
          Expression.field('price').greaterThan(5),
          'mid',
          'cheap',
        ]),
        'mid',
      ),
      FunctionCase(
        'switchOn falls back to the default',
        PipelineFunctions.switchOn([
          Expression.field('archived'),
          'archived',
          Expression.field('price').lessThan(5),
          'cheap',
          Expression.field('title'),
        ]),
        'Dart Pipelines',
      ),
      FunctionCase(
        'switchOn with literal conditions',
        PipelineFunctions.switchOn([
          false,
          'no',
          true,
          Expression.field('rating'),
        ]),
        isInt(5),
      ),
    ]);

    ctx.functionCases('equalAny and notEqualAny', [
      // The first argument is a field position: a bare String means a field
      // reference, not a string literal. Passing 'dart' here asked about a
      // non-existent field named `dart`, which made equalAny false and made
      // notEqualAny true for the wrong reason.
      FunctionCase(
        'equalAny',
        PipelineFunctions.equalAny(
          'title',
          Expression.array(['Dart Pipelines', 'Unrelated Title']),
        ),
        true,
      ),
      FunctionCase(
        'notEqualAny',
        PipelineFunctions.notEqualAny(
          'title',
          Expression.array(['Unrelated Title', 'Another Title']),
        ),
        true,
      ),
      FunctionCase(
        'equalAny with an expression and a list',
        PipelineFunctions.equalAny(Expression.field('price'), [10, 20]),
        true,
      ),
      FunctionCase(
        'notEqualAny with an expression and a list',
        PipelineFunctions.notEqualAny(Expression.field('price'), [10, 20]),
        false,
      ),
      FunctionCase(
        'fluent equalAny with an array field',
        Expression.constant('firebase').equalAny(Expression.field('tags')),
        true,
      ),
      FunctionCase(
        'fluent notEqualAny with a list',
        Expression.field(
          'title',
        ).notEqualAny(['Firestore Admin', 'Inactive Draft']),
        true,
      ),
      FunctionCase(
        'fluent notEqualAny with an array field',
        Expression.constant('graphql').notEqualAny(Expression.field('tags')),
        true,
      ),
    ]);

    // Collections that hold expressions must be built with array(...) /
    // map(...); the backend rejects them inside a literal array or map value.
    ctx.functionCases('collections holding expressions', [
      FunctionCase(
        'equalAny',
        PipelineFunctions.equalAny('rating', [Expression.field('score'), 5]),
        true,
      ),
      FunctionCase(
        'equalAnyMatchesExpression',
        Expression.field(
          'price',
        ).equalAny([Expression.field('rating').multiply(2), 3]),
        true,
      ),
      FunctionCase(
        'notEqualAny',
        PipelineFunctions.notEqualAny('rating', [Expression.field('price'), 4]),
        true,
      ),
      FunctionCase(
        'fluent notEqualAny',
        Expression.field('rating').notEqualAny([
          Expression.field('discount'),
          Expression.field('price').subtract(5),
        ]),
        false,
      ),
      FunctionCase(
        'equal',
        Expression.field('tags').equal([
          Expression.field('metadata').mapGetLiteral('lang'),
          'firebase',
        ]),
        true,
      ),
      FunctionCase(
        'top-level equal',
        equal('tags', [
          Expression.field('metadata').mapGetLiteral('lang'),
          'firebase',
        ]),
        true,
      ),
      // Book 1's stats are {views: 100, likes: 7}.
      FunctionCase(
        'PipelineFunctions.equal with a map',
        PipelineFunctions.equal('stats', {
          'views': Expression.field('price').multiply(10),
          'likes': Expression.field('quantity'),
        }),
        true,
      ),
      FunctionCase(
        'conditional',
        PipelineFunctions.conditional(
          Expression.field('price').greaterThan(5),
          [Expression.field('price'), Expression.field('rating')],
          Expression.field('tags'),
        ),
        [10, 5],
      ),
      FunctionCase(
        'fluent conditional',
        Expression.field('price').equal(10).conditional({
          'doubled': Expression.field('price').multiply(2),
        }, 'n/a'),
        {'doubled': 20},
      ),
    ]);

    // Books 1-3: price 10/20/30, rating 5/4/2, discount 2/3/4,
    // active true/true/false, archived false/false/true.
    ctx.filterCases('filters', [
      // Regression: the list was sent as a literal array value, which the
      // backend rejected with "Value type is not supported:
      // FIELD_REFERENCE_VALUE". Book 1 matches the literal 2, book 2 its own
      // `flags` (3).
      FilterCase(
        'filters with a search space holding expressions',
        PipelineFunctions.equalAny('discount', [Expression.field('flags'), 2]),
        ['Dart Pipelines', 'Firestore Admin'],
      ),
      FilterCase(
        'compares two fields per document',
        Expression.field('rating').lessThan(Expression.field('discount')),
        ['Inactive Draft'],
      ),
      FilterCase(
        'and',
        and([greaterThan('price', 10), lessThan('rating', 5)]),
        ['Firestore Admin', 'Inactive Draft'],
      ),
      FilterCase('or', or([equal('price', 10), equal('active', false)]), [
        'Dart Pipelines',
        'Inactive Draft',
      ]),
      FilterCase('not', not(equal('active', true)), ['Inactive Draft']),
      FilterCase(
        'xor',
        PipelineFunctions.xor([
          Expression.field('active'),
          greaterThan('price', 15),
        ]),
        ['Dart Pipelines', 'Inactive Draft'],
      ),
      FilterCase(
        'nor',
        PipelineFunctions.nor([
          Expression.field('archived'),
          greaterThan('price', 15),
        ]),
        ['Dart Pipelines'],
      ),
      // The second entry is rating * 5. Book 1: 10 is in [10, 25]; book 2: 20
      // is in [10, 20]; book 3: 30 is not in [10, 10].
      FilterCase(
        'notEqualAny with a per-document search space',
        Expression.field(
          'price',
        ).notEqualAny([10, Expression.field('rating').multiply(5)]),
        ['Inactive Draft'],
      ),
    ]);
  });
}
