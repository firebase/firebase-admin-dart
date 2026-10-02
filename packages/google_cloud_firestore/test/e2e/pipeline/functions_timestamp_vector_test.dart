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

/// Live coverage of the timestamp and vector Pipeline functions.
@Tags(['prod'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  pipelineE2E('Pipeline timestamp and vector functions', (ctx) {
    ctx.functionCases('timestamp functions', [
      FunctionCase(
        'currentTimestamp',
        PipelineFunctions.currentTimestamp(),
        isA<Timestamp>(),
      ),
      FunctionCase(
        'timestampTrunc',
        Expression.field('createdAt').timestampTruncate('day', 'UTC'),
        isA<Timestamp>(),
      ),
      FunctionCase(
        'unixMicrosToTimestamp',
        PipelineFunctions.unixMicrosToTimestamp(1700000000000000),
        isA<Timestamp>(),
      ),
      FunctionCase(
        'unixMillisToTimestamp',
        PipelineFunctions.unixMillisToTimestamp(1700000000000),
        isA<Timestamp>(),
      ),
      FunctionCase(
        'unixSecondsToTimestamp',
        PipelineFunctions.unixSecondsToTimestamp(1700000000),
        isA<Timestamp>(),
      ),
      FunctionCase(
        'timestampAdd',
        Expression.field('createdAt').timestampAdd('second', 60),
        isA<Timestamp>(),
      ),
      FunctionCase(
        'timestampSubtract',
        Expression.field('createdAt').timestampSubtract('second', 60),
        isA<Timestamp>(),
      ),
      FunctionCase(
        'timestampToUnixMicros',
        Expression.field('createdAt').timestampToUnixMicros(),
        1700000000000000,
      ),
      FunctionCase(
        'timestampToUnixMillis',
        Expression.field('createdAt').timestampToUnixMillis(),
        1700000000000,
      ),
      FunctionCase(
        'timestampToUnixSeconds',
        Expression.field('createdAt').timestampToUnixSeconds(),
        1700000000,
      ),
      FunctionCase(
        'timestampDiff',
        PipelineFunctions.timestampDiff(
          Expression.field('createdAt'),
          PipelineFunctions.unixSecondsToTimestamp(1699999940),
          'second',
        ),
        60,
      ),
      FunctionCase(
        'timestampExtract',
        Expression.field('createdAt').timestampExtract('year', 'UTC'),
        2023,
      ),
    ]);

    ctx.functionCases('vector functions', [
      FunctionCase(
        'cosineDistance',
        Expression.field(
          'embedding',
        ).cosineDistance(Expression.vector([1, 0, 0])),
        closeTo(0, 0.0001),
      ),
      FunctionCase(
        'dotProduct',
        Expression.field('embedding').dotProduct(Expression.vector([1, 0, 0])),
        closeTo(1, 0.0001),
      ),
      FunctionCase(
        'euclideanDistance',
        Expression.field(
          'embedding',
        ).euclideanDistance(Expression.vector([1, 0, 0])),
        closeTo(0, 0.0001),
      ),
      FunctionCase(
        'vectorLength',
        Expression.field('embedding').vectorLength(),
        3,
      ),
    ]);

    // A plain list of numbers must reach the backend as a vector, not an array.
    ctx.functionCases('vector functions with list arguments', [
      FunctionCase(
        'cosineDistance',
        Expression.field('embedding').cosineDistance(const [1.0, 0.0, 0.0]),
        closeTo(0, 0.0001),
      ),
      FunctionCase(
        'dotProduct',
        PipelineFunctions.dotProduct('embedding', const [1, 0, 0]),
        closeTo(1, 0.0001),
      ),
      FunctionCase(
        'euclideanDistance',
        Expression.field('embedding').euclideanDistance(const [1.0, 0.0, 0.0]),
        closeTo(0, 0.0001),
      ),
    ]);
  });
}
