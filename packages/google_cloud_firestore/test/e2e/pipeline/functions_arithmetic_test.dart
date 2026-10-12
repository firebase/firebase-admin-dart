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

/// Live coverage of the arithmetic Pipeline functions.
///
/// Result types follow the backend's arithmetic reference: `add`, `subtract`,
/// `multiply`, `divide`, `mod`, `abs`, `ceil`, `floor`, `round` and `trunc`
/// keep the type of their (widest) operand, so two int64 operands give an
/// int64 and any float64 operand gives a float64; `pow`, `sqrt`, `exp`, `ln`,
/// `log`, `log10` and `rand` always return a float64. Integer division
/// truncates toward zero and `mod` takes the sign of the dividend. Arithmetic
/// on a `NULL` operand is `NULL`.
///
/// `logicalMaximum` / `logicalMinimum` (the backend's scalar `maximum` /
/// `minimum`) return the largest / smallest operand unchanged, skipping
/// `NULL` and absent operands.
@Tags(['prod'])
library;

import 'dart:math' as math;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  pipelineE2E('Pipeline arithmetic functions', (ctx) {
    // Book 1: price 10, rating 5, discount 2, quantity 7, zero 0 (ints);
    // score -12.7, ratio 0.5, half 2.5, negativeHalf -2.5, precise 4.123456
    // (doubles); nullable null.

    ctx.functionCases('add', [
      FunctionCase(
        'fluent, int literal: int + int is int',
        Expression.field('price').add(2),
        isInt(12),
      ),
      FunctionCase(
        'fluent, field expression',
        Expression.field('price').add(Expression.field('rating')),
        isInt(15),
      ),
      FunctionCase(
        'int + double widens to double',
        Expression.field('price').add(Expression.field('ratio')),
        isDouble(10.5),
      ),
      FunctionCase(
        'int64 beyond 2^53 keeps full precision',
        Expression.field('largeInt').add(1),
        isInt(9007199254740994),
      ),
      FunctionCase(
        'a NULL operand gives NULL',
        Expression.field('price').add(Expression.field('nullable')),
        isNull,
      ),
      FunctionCase(
        'static, field name and literal',
        PipelineFunctions.add('price', 5),
        isInt(15),
      ),
      FunctionCase(
        'static, expressions',
        PipelineFunctions.add(
          Expression.field('price'),
          Expression.field('discount'),
        ),
        isInt(12),
      ),
      // Further operands are sent as nested two-operand add calls, since the
      // backend's add takes exactly two: ((10 + 1) + 2) + 3.
      FunctionCase(
        'static, further literal operands',
        PipelineFunctions.add('price', 1, [2, 3]),
        isInt(16),
      ),
      // 10 + 5 + 2.
      FunctionCase(
        'static, further expression operands',
        PipelineFunctions.add(
          Expression.field('price'),
          Expression.field('rating'),
          [Expression.field('discount')],
        ),
        isInt(17),
      ),
      // 10 + 1 + 2.
      FunctionCase(
        'fluent, further literal operands',
        Expression.field('price').add(1, [2]),
        isInt(13),
      ),
      // 10 + 2 + 5 + 7.
      FunctionCase(
        'fluent, further expression operands',
        Expression.field('price').add(Expression.field('discount'), [
          Expression.field('rating'),
          Expression.field('quantity'),
        ]),
        isInt(24),
      ),
    ]);

    ctx.functionCases('subtract', [
      FunctionCase(
        'fluent, int literal',
        Expression.field('price').subtract(3),
        isInt(7),
      ),
      FunctionCase(
        'fluent, field expression',
        Expression.field('price').subtract(Expression.field('quantity')),
        isInt(3),
      ),
      FunctionCase(
        'static, field name and literal: result may be negative',
        PipelineFunctions.subtract('price', 15),
        isInt(-5),
      ),
      FunctionCase(
        'static, expressions: double - double',
        PipelineFunctions.subtract(
          Expression.field('ratio'),
          Expression.field('half'),
        ),
        isDouble(-2),
      ),
    ]);

    ctx.functionCases('multiply', [
      FunctionCase(
        'fluent, int literal',
        Expression.field('price').multiply(2),
        isInt(20),
      ),
      FunctionCase(
        'fluent, field expression: int * double is double',
        Expression.field('price').multiply(Expression.field('ratio')),
        isDouble(5),
      ),
      FunctionCase(
        'static, field name and literal',
        PipelineFunctions.multiply('rating', 3),
        isInt(15),
      ),
      FunctionCase(
        'static, expressions',
        PipelineFunctions.multiply(
          Expression.field('price'),
          Expression.field('quantity'),
        ),
        isInt(70),
      ),
      // Further operands are sent as nested two-operand multiply calls, since
      // the backend's multiply takes exactly two: (5 * 2) * 3.
      FunctionCase(
        'static, further literal operands',
        PipelineFunctions.multiply('rating', 2, [3]),
        isInt(30),
      ),
      // 10 * 5 * 2.
      FunctionCase(
        'static, further expression operands',
        PipelineFunctions.multiply(
          Expression.field('price'),
          Expression.field('rating'),
          [Expression.field('discount')],
        ),
        isInt(100),
      ),
      // 10 * 2 * 3.
      FunctionCase(
        'fluent, further literal operands',
        Expression.field('price').multiply(2, [3]),
        isInt(60),
      ),
      // 5 * 2 * 6.
      FunctionCase(
        'fluent, further expression operands',
        Expression.field(
          'rating',
        ).multiply(Expression.field('discount'), [Expression.field('flags')]),
        isInt(60),
      ),
    ]);

    ctx.functionCases('divide', [
      FunctionCase(
        'fluent, int literal',
        Expression.field('price').divide(2),
        isInt(5),
      ),
      FunctionCase(
        'fluent, double literal: widens to double',
        Expression.field('price').divide(4.0),
        isDouble(2.5),
      ),
      FunctionCase(
        'fluent, field expression: int / double',
        Expression.field('price').divide(Expression.field('ratio')),
        isDouble(20),
      ),
      FunctionCase(
        'static, field name and literal: integer division truncates',
        PipelineFunctions.divide('price', 3),
        isInt(3),
      ),
      FunctionCase(
        'static, expressions: integer division truncates toward zero',
        PipelineFunctions.divide(
          Expression.constant(-7),
          Expression.field('discount'),
        ),
        isInt(-3),
      ),
    ]);

    ctx.functionCases('mod', [
      FunctionCase(
        'fluent, int literal',
        Expression.field('price').mod(4),
        isInt(2),
      ),
      FunctionCase(
        'fluent, field expression',
        Expression.field('price').mod(Expression.field('quantity')),
        isInt(3),
      ),
      FunctionCase(
        'fluent, double dividend',
        Expression.field('half').mod(2),
        isDouble(0.5),
      ),
      FunctionCase(
        'static, field name and literal',
        PipelineFunctions.mod('price', 3),
        isInt(1),
      ),
      FunctionCase(
        'static, expressions: takes the sign of the dividend',
        PipelineFunctions.mod(Expression.constant(-10), Expression.constant(3)),
        isInt(-1),
      ),
    ]);

    ctx.functionCases('abs', [
      FunctionCase(
        'fluent, double',
        Expression.field('score').abs(),
        isDouble(12.7),
      ),
      FunctionCase(
        'static, field name',
        PipelineFunctions.abs('negativeHalf'),
        isDouble(2.5),
      ),
      FunctionCase(
        'static, expression: int stays int',
        PipelineFunctions.abs(Expression.constant(-10)),
        isInt(10),
      ),
    ]);

    ctx.functionCases('ceil', [
      FunctionCase('fluent', Expression.constant(12.2).ceil(), isDouble(13)),
      FunctionCase(
        'fluent, int stays int',
        Expression.field('price').ceil(),
        isInt(10),
      ),
      FunctionCase(
        'static, field name: negative half',
        PipelineFunctions.ceil('negativeHalf'),
        isDouble(-2),
      ),
      FunctionCase(
        'static, expression',
        PipelineFunctions.ceil(Expression.field('score')),
        isDouble(-12),
      ),
    ]);

    ctx.functionCases('floor', [
      FunctionCase('fluent', Expression.constant(12.8).floor(), isDouble(12)),
      FunctionCase(
        'static, field name: negative half',
        PipelineFunctions.floor('negativeHalf'),
        isDouble(-3),
      ),
      FunctionCase(
        'static, expression',
        PipelineFunctions.floor(Expression.field('ratio')),
        isDouble(0),
      ),
    ]);

    ctx.functionCases('round', [
      FunctionCase('fluent', Expression.constant(12.6).round(), isDouble(13)),
      FunctionCase(
        'fluent: positive half rounds away from zero',
        Expression.field('half').round(),
        isDouble(3),
      ),
      FunctionCase(
        'fluent: negative half rounds away from zero',
        Expression.field('negativeHalf').round(),
        isDouble(-3),
      ),
      FunctionCase(
        'fluent, literal decimal places',
        Expression.constant(12.68).round(1),
        isDouble(12.7),
      ),
      FunctionCase(
        'fluent, expression decimal places',
        Expression.field('precise').round(Expression.field('discount')),
        isDouble(4.12),
      ),
      FunctionCase(
        'static, field name, no decimal places',
        PipelineFunctions.round('half'),
        isDouble(3),
      ),
      FunctionCase(
        'static, field name, literal decimal places',
        PipelineFunctions.round('precise', 4),
        isDouble(4.1235),
      ),
      FunctionCase(
        'static, expression, expression decimal places',
        PipelineFunctions.round(
          Expression.field('precise'),
          Expression.constant(1),
        ),
        isDouble(4.1),
      ),
      FunctionCase(
        'static, expression, negative decimal places: int stays int',
        PipelineFunctions.round(Expression.constant(15), -1),
        isInt(20),
      ),
    ]);

    ctx.functionCases('trunc', [
      FunctionCase('fluent', Expression.constant(12.8).trunc(), isDouble(12)),
      FunctionCase(
        'fluent: truncates toward zero',
        Expression.field('negativeHalf').trunc(),
        isDouble(-2),
      ),
      FunctionCase(
        'fluent, literal decimal places',
        Expression.constant(12.89).trunc(1),
        isDouble(12.8),
      ),
      FunctionCase(
        'fluent, expression decimal places',
        Expression.field('precise').trunc(Expression.field('discount')),
        isDouble(4.12),
      ),
      FunctionCase(
        'static, field name, no decimal places',
        PipelineFunctions.trunc('score'),
        isDouble(-12),
      ),
      FunctionCase(
        'static, field name, literal decimal places',
        PipelineFunctions.trunc('precise', 4),
        isDouble(4.1234),
      ),
      FunctionCase(
        'static, expression, expression decimal places',
        PipelineFunctions.trunc(
          Expression.field('precise'),
          Expression.constant(1),
        ),
        isDouble(4.1),
      ),
      FunctionCase(
        'static, expression, negative decimal places: int stays int',
        PipelineFunctions.trunc(Expression.constant(15), -1),
        isInt(10),
      ),
    ]);

    ctx.functionCases('pow', [
      FunctionCase(
        'static, literals: int operands give a double',
        PipelineFunctions.pow(2, 3),
        isDouble(8),
      ),
      FunctionCase(
        'static, field name base',
        PipelineFunctions.pow('ratio', 2),
        isDouble(0.25),
      ),
      FunctionCase(
        'static, expressions: negative exponent',
        PipelineFunctions.pow(
          Expression.field('discount'),
          Expression.constant(-1),
        ),
        isDouble(0.5),
      ),
      FunctionCase(
        'fluent, literal exponent',
        Expression.field('rating').pow(2),
        isDouble(25),
      ),
      FunctionCase(
        'fluent, expression exponent',
        Expression.field('price').pow(Expression.field('discount')),
        isDouble(100),
      ),
    ]);

    ctx.functionCases('sqrt', [
      FunctionCase(
        'fluent: int operand gives a double',
        Expression.constant(9).sqrt(),
        isDouble(3),
      ),
      FunctionCase(
        'static, field name',
        PipelineFunctions.sqrt('discount'),
        isDouble(math.sqrt2),
      ),
      FunctionCase(
        'static, expression',
        PipelineFunctions.sqrt(Expression.field('ratio')),
        isDouble(math.sqrt1_2),
      ),
    ]);

    ctx.functionCases('exp', [
      FunctionCase(
        'static, literal',
        PipelineFunctions.exp(1),
        isDouble(math.e),
      ),
      FunctionCase(
        'static, expression',
        PipelineFunctions.exp(Expression.field('discount')),
        isDouble(math.exp(2)),
      ),
      FunctionCase('fluent', Expression.field('zero').exp(), isDouble(1)),
    ]);

    ctx.functionCases('ln', [
      FunctionCase(
        'static, literal',
        PipelineFunctions.ln(math.e),
        isDouble(1),
      ),
      FunctionCase(
        'static, expression',
        PipelineFunctions.ln(Expression.constant(1)),
        isDouble(0),
      ),
      FunctionCase(
        'fluent',
        Expression.field('price').ln(),
        isDouble(math.log(10)),
      ),
    ]);

    ctx.functionCases('log', [
      FunctionCase(
        'static, literals',
        PipelineFunctions.log(8, 2),
        isDouble(3),
      ),
      FunctionCase(
        'static, expressions',
        PipelineFunctions.log(
          Expression.constant(100),
          Expression.field('price'),
        ),
        isDouble(2),
      ),
      FunctionCase(
        'static, field name, no base: natural logarithm',
        PipelineFunctions.log('price'),
        isDouble(math.log(10)),
      ),
      FunctionCase(
        'fluent, literal base',
        Expression.field('price').log(10),
        isDouble(1),
      ),
      FunctionCase(
        'fluent, expression base',
        Expression.constant(1024).log(Expression.field('discount')),
        isDouble(10),
      ),
      FunctionCase(
        'fluent, no base: natural logarithm',
        Expression.field('price').log(),
        isDouble(math.log(10)),
      ),
    ]);

    ctx.functionCases('log10', [
      FunctionCase(
        'static, literal',
        PipelineFunctions.log10(100),
        isDouble(2),
      ),
      FunctionCase(
        'static, expression',
        PipelineFunctions.log10(Expression.constant(1000)),
        isDouble(3),
      ),
      FunctionCase('fluent', Expression.field('price').log10(), isDouble(1)),
    ]);

    ctx.functionCases('rand', [
      FunctionCase(
        'a double in [0, 1)',
        PipelineFunctions.rand(),
        allOf(isA<double>(), inClosedOpenRange(0, 1)),
      ),
    ]);

    ctx.functionCases('logicalMaximum', [
      FunctionCase(
        'static, field name and literal',
        PipelineFunctions.logicalMaximum('price', 15),
        isInt(15),
      ),
      FunctionCase(
        'static, expressions and others',
        PipelineFunctions.logicalMaximum(
          Expression.field('rating'),
          Expression.field('discount'),
          [Expression.field('price'), 3],
        ),
        isInt(10),
      ),
      FunctionCase(
        'static: NULL and absent operands are skipped',
        PipelineFunctions.logicalMaximum(
          'missing',
          Expression.field('nullable'),
          [Expression.field('rating')],
        ),
        isInt(5),
      ),
      FunctionCase(
        'fluent, literal: returns the operand unchanged',
        Expression.field('score').logicalMaximum(-20),
        isDouble(-12.7),
      ),
      FunctionCase(
        'fluent, expression and others',
        Expression.field('price').logicalMaximum(Expression.field('rating'), [
          30,
          Expression.field('quantity'),
        ]),
        isInt(30),
      ),
    ]);

    ctx.functionCases('logicalMinimum', [
      FunctionCase(
        'static, field name and literal',
        PipelineFunctions.logicalMinimum('price', 15),
        isInt(10),
      ),
      FunctionCase(
        'static, expressions and others',
        PipelineFunctions.logicalMinimum(
          Expression.field('rating'),
          Expression.field('price'),
          [Expression.field('quantity'), 3],
        ),
        isInt(3),
      ),
      FunctionCase(
        'static: NULL and absent operands are skipped',
        PipelineFunctions.logicalMinimum(
          'nullable',
          Expression.field('missing'),
          [Expression.field('discount')],
        ),
        isInt(2),
      ),
      FunctionCase(
        'fluent, literal: returns the operand unchanged',
        Expression.field('score').logicalMinimum(0),
        isDouble(-12.7),
      ),
      FunctionCase(
        'fluent, expression and others: int and double operands compare '
        'numerically',
        Expression.field('price').logicalMinimum(Expression.field('ratio'), [
          20,
          Expression.field('rating'),
        ]),
        isDouble(0.5),
      ),
      FunctionCase(
        'fluent: only NULL and absent operands give NULL',
        Expression.field(
          'nullable',
        ).logicalMinimum(Expression.field('missing')),
        isNull,
      ),
    ]);
  });
}
