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
@Tags(['prod'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  pipelineE2E('Pipeline arithmetic functions', (ctx) {
    ctx.functionCases('arithmetic functions', [
      FunctionCase(
        'abs',
        Expression.field('score').abs(),
        closeTo(12.7, 0.0001),
      ),
      FunctionCase('add', Expression.field('price').add(2), 12),
      FunctionCase('subtract', Expression.field('price').subtract(3), 7),
      FunctionCase('multiply', Expression.field('price').multiply(2), 20),
      FunctionCase('divide', Expression.field('price').divide(2), 5),
      FunctionCase('mod', Expression.field('price').mod(4), 2),
      FunctionCase('ceil', Expression.constant(12.2).ceil(), 13),
      FunctionCase('floor', Expression.constant(12.8).floor(), 12),
      FunctionCase('round', Expression.constant(12.6).round(), 13),
      FunctionCase('trunc', Expression.constant(12.8).trunc(), 12),
      FunctionCase(
        'roundDecimalPlaces',
        Expression.constant(12.68).round(1),
        closeTo(12.7, 0.0001),
      ),
      FunctionCase(
        'truncDecimalPlaces',
        Expression.constant(12.89).trunc(1),
        closeTo(12.8, 0.0001),
      ),
      FunctionCase('pow', PipelineFunctions.pow(2, 3), 8),
      FunctionCase('sqrt', Expression.constant(9).sqrt(), 3),
      FunctionCase('exp', PipelineFunctions.exp(1), closeTo(2.71828, 0.001)),
      FunctionCase('ln', PipelineFunctions.ln(2.718281828), closeTo(1, 0.001)),
      FunctionCase('log', PipelineFunctions.log(8, 2), closeTo(3, 0.001)),
      FunctionCase('log10', PipelineFunctions.log10(100), closeTo(2, 0.001)),
      FunctionCase('rand', PipelineFunctions.rand(), isA<num>()),
    ]);
  });
}
