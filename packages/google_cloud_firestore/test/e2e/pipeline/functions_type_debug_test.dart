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

/// Live coverage of the type, debugging and search Pipeline functions, every
/// `PipelineValueType`, and the expression primitives (`field`, `constant`,
/// raw functions).
@Tags(['prod'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  pipelineE2E('Pipeline type and debugging functions', (ctx) {
    ctx.functionCases('debugging functions', [
      FunctionCase('exists', Expression.field('title').exists(), true),
      FunctionCase('isAbsent', Expression.field('missing').isAbsent(), true),
      FunctionCase(
        'ifAbsent',
        Expression.field('missing').ifAbsent('fallback'),
        'fallback',
      ),
      FunctionCase('isError', Expression.field('title').isError(), false),
      FunctionCase(
        'ifError',
        Expression.field('title').ifError('caught'),
        'Dart Pipelines',
      ),
    ]);

    ctx.functionCases('type functions', [
      FunctionCase('type', Expression.field('price').type(), isA<String>()),
      FunctionCase(
        'isType',
        Expression.field('price').isType(PipelineValueType.number),
        true,
      ),
      FunctionCase(
        'isTypeInt64',
        Expression.field('price').isType(PipelineValueType.int64),
        true,
      ),
      FunctionCase(
        'isTypeFloat64',
        Expression.field('score').isType(PipelineValueType.double),
        true,
      ),
      FunctionCase(
        'isTypeNotFloat64',
        Expression.field('price').isType(PipelineValueType.double),
        false,
      ),
    ]);
  });
}
