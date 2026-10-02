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
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  pipelineE2E('Pipeline comparison and logical functions', (ctx) {
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
        'cmp',
        PipelineFunctions.cmp(Expression.field('price'), 10),
        0,
      ),
    ]);

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
      FunctionCase('nor', PipelineFunctions.nor([false, false]), true),
      FunctionCase('not', PipelineFunctions.not(false), true),
      FunctionCase(
        'conditional',
        PipelineFunctions.conditional(Expression.field('active'), 'yes', 'no'),
        'yes',
      ),
      FunctionCase(
        'ifNull',
        PipelineFunctions.ifNull(Expression.field('nullable'), 'fallback'),
        'fallback',
      ),
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
        'equal',
        Expression.field('tags').equal([
          Expression.field('metadata').mapGetLiteral('lang'),
          'firebase',
        ]),
        true,
      ),
    ]);

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
    ]);
  });
}
