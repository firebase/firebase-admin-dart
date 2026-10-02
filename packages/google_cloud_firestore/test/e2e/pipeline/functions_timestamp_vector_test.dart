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
///
/// Book 1's `createdAt` is 2023-11-14T22:13:20Z (`1700000000`), and its
/// `updatedAt` is exactly one day and 123456 microseconds later
/// (`Timestamp(1700086400, 123456000)`). In the time zones used below that
/// instant is:
///
/// | Zone | Local time | UTC offset |
/// | --- | --- | --- |
/// | `UTC` | 2023-11-14 22:13:20 | +0 |
/// | `Asia/Tokyo` | 2023-11-15 07:13:20 | +9 |
/// | `MST` | 2023-11-14 15:13:20 | -7 |
/// | `America/Los_Angeles` | 2023-11-14 14:13:20 (PST) | -8 |
///
/// Book 1's `embedding` is the vector `[1, 0, 0]`.
@Tags(['prod'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

Timestamp _ts(int seconds, [int nanoseconds = 0]) {
  return Timestamp(seconds: seconds, nanoseconds: nanoseconds);
}

/// Book 1's `createdAt`.
final _createdAt = DateTime.utc(2023, 11, 14, 22, 13, 20);

/// 2023-11-14T00:00:00Z, book 1's `createdAt` truncated to the UTC day.
const _createdAtUtcDay = 1699920000;

void main() {
  pipelineE2E('Pipeline timestamp and vector functions', (ctx) {
    ctx.functionCases('currentTimestamp', [
      FunctionCase(
        'is close to the client clock',
        PipelineFunctions.currentTimestamp(),
        isA<Timestamp>().having(
          (now) => now.toDate().difference(DateTime.now()).inMinutes.abs(),
          'minutes from the client clock',
          inInclusiveRange(0, 9),
        ),
      ),
      FunctionCase(
        'composes as an operand',
        PipelineFunctions.timestampDiff(
          PipelineFunctions.currentTimestamp(),
          'createdAt',
          'day',
        ),
        allOf(
          isA<int>(),
          closeTo(DateTime.now().difference(_createdAt).inDays, 1),
        ),
      ),
    ]);

    ctx.functionCases('timestamp to Unix conversions', [
      // The conversions truncate: updatedAt carries 123456000 nanoseconds.
      FunctionCase(
        'static timestampToUnixSeconds with a field name',
        PipelineFunctions.timestampToUnixSeconds('updatedAt'),
        isInt(1700086400),
      ),
      FunctionCase(
        'static timestampToUnixSeconds with an expression',
        PipelineFunctions.timestampToUnixSeconds(
          Expression.constant(_ts(1741380235, 123456789)),
        ),
        isInt(1741380235),
      ),
      FunctionCase(
        'fluent timestampToUnixSeconds',
        Expression.field('createdAt').timestampToUnixSeconds(),
        isInt(1700000000),
      ),
      FunctionCase(
        'static timestampToUnixMillis with a field name',
        PipelineFunctions.timestampToUnixMillis('updatedAt'),
        isInt(1700086400123),
      ),
      FunctionCase(
        'static timestampToUnixMillis with an expression',
        PipelineFunctions.timestampToUnixMillis(
          Expression.constant(_ts(1741380235, 123456789)),
        ),
        isInt(1741380235123),
      ),
      FunctionCase(
        'fluent timestampToUnixMillis',
        Expression.field('createdAt').timestampToUnixMillis(),
        isInt(1700000000000),
      ),
      FunctionCase(
        'static timestampToUnixMicros with a field name',
        PipelineFunctions.timestampToUnixMicros('updatedAt'),
        isInt(1700086400123456),
      ),
      FunctionCase(
        'static timestampToUnixMicros with an expression',
        PipelineFunctions.timestampToUnixMicros(
          Expression.constant(_ts(1741380235, 123456789)),
        ),
        isInt(1741380235123456),
      ),
      FunctionCase(
        'fluent timestampToUnixMicros',
        Expression.field('createdAt').timestampToUnixMicros(),
        isInt(1700000000000000),
      ),
    ]);

    ctx.functionCases('Unix to timestamp conversions', [
      FunctionCase(
        'static unixSecondsToTimestamp with a number',
        PipelineFunctions.unixSecondsToTimestamp(1700000000),
        _ts(1700000000),
      ),
      FunctionCase(
        'static unixSecondsToTimestamp with an expression',
        PipelineFunctions.unixSecondsToTimestamp(
          Expression.field('unixSeconds'),
        ),
        _ts(1700000000),
      ),
      FunctionCase(
        'fluent unixSecondsToTimestamp',
        Expression.field('unixSeconds').unixSecondsToTimestamp(),
        _ts(1700000000),
      ),
      FunctionCase(
        'static unixMillisToTimestamp with a number',
        PipelineFunctions.unixMillisToTimestamp(1700086400123),
        _ts(1700086400, 123000000),
      ),
      // A String is a field name, not a constant.
      FunctionCase(
        'static unixMillisToTimestamp with a field name',
        PipelineFunctions.unixMillisToTimestamp('unixMillis'),
        _ts(1700000000),
      ),
      FunctionCase(
        'static unixMillisToTimestamp with an expression',
        PipelineFunctions.unixMillisToTimestamp(Expression.field('unixMillis')),
        _ts(1700000000),
      ),
      FunctionCase(
        'fluent unixMillisToTimestamp',
        Expression.constant(1700086400123).unixMillisToTimestamp(),
        _ts(1700086400, 123000000),
      ),
      FunctionCase(
        'static unixMicrosToTimestamp with a number',
        PipelineFunctions.unixMicrosToTimestamp(1700086400123456),
        _ts(1700086400, 123456000),
      ),
      FunctionCase(
        'static unixMicrosToTimestamp with an expression',
        PipelineFunctions.unixMicrosToTimestamp(Expression.field('unixMicros')),
        _ts(1700000000),
      ),
      FunctionCase(
        'fluent unixMicrosToTimestamp',
        Expression.field('unixMicros').unixMicrosToTimestamp(),
        _ts(1700000000),
      ),
      FunctionCase(
        'micros round trip keeps the sub-second part',
        Expression.field(
          'updatedAt',
        ).timestampToUnixMicros().unixMicrosToTimestamp(),
        _ts(1700086400, 123456000),
      ),
    ]);

    ctx.functionCases('timestampAdd', [
      FunctionCase(
        'static with plain values',
        PipelineFunctions.timestampAdd('createdAt', 'day', 1),
        _ts(1700086400),
      ),
      // rating is 5 on book 1.
      FunctionCase(
        'static with expressions',
        PipelineFunctions.timestampAdd(
          Expression.field('createdAt'),
          Expression.constant('hour'),
          Expression.field('rating'),
        ),
        _ts(1700018000),
      ),
      FunctionCase(
        'fluent with plain values',
        Expression.field('createdAt').timestampAdd('second', 60),
        _ts(1700000060),
      ),
      FunctionCase(
        'fluent with expressions',
        Expression.field(
          'createdAt',
        ).timestampAdd(Expression.constant('minute'), Expression.constant(30)),
        _ts(1700001800),
      ),
      FunctionCase(
        'microsecond keeps nanosecond precision',
        Expression.field('updatedAt').timestampAdd('microsecond', 10),
        _ts(1700086400, 123466000),
      ),
      FunctionCase(
        'millisecond carries into seconds',
        Expression.field('updatedAt').timestampAdd('millisecond', 900),
        _ts(1700086401, 23456000),
      ),
    ]);

    ctx.functionCases('timestampSubtract', [
      FunctionCase(
        'static with plain values',
        PipelineFunctions.timestampSubtract('updatedAt', 'day', 1),
        _ts(1700000000, 123456000),
      ),
      // price is 10 on book 1.
      FunctionCase(
        'static with expressions',
        PipelineFunctions.timestampSubtract(
          Expression.field('updatedAt'),
          Expression.constant('millisecond'),
          Expression.field('price'),
        ),
        _ts(1700086400, 113456000),
      ),
      FunctionCase(
        'fluent with plain values',
        Expression.field('createdAt').timestampSubtract('second', 60),
        _ts(1699999940),
      ),
      FunctionCase(
        'fluent with expressions borrows from seconds',
        Expression.field('createdAt').timestampSubtract(
          Expression.constant('microsecond'),
          Expression.constant(1),
        ),
        _ts(1699999999, 999999000),
      ),
    ]);

    // updatedAt - createdAt is exactly 86400.123456 seconds, so every unit
    // below gives the same whole number however the backend rounds.
    ctx.functionCases('timestampDiff', [
      FunctionCase(
        'static with field names',
        PipelineFunctions.timestampDiff(
          'updatedAt',
          'createdAt',
          'microsecond',
        ),
        isInt(86400123456),
      ),
      FunctionCase(
        'static with field names, end before start',
        PipelineFunctions.timestampDiff(
          'createdAt',
          'updatedAt',
          'microsecond',
        ),
        isInt(-86400123456),
      ),
      FunctionCase(
        'static in hours',
        PipelineFunctions.timestampDiff('updatedAt', 'createdAt', 'hour'),
        isInt(24),
      ),
      FunctionCase(
        'static with expressions',
        PipelineFunctions.timestampDiff(
          Expression.field('updatedAt'),
          Expression.field('createdAt'),
          Expression.constant('day'),
        ),
        isInt(1),
      ),
      FunctionCase(
        'static with a computed start',
        PipelineFunctions.timestampDiff(
          Expression.field('createdAt'),
          PipelineFunctions.unixSecondsToTimestamp(1699999940),
          'second',
        ),
        isInt(60),
      ),
      FunctionCase(
        'fluent with plain values',
        Expression.field('updatedAt').timestampDiff('createdAt', 'millisecond'),
        isInt(86400123),
      ),
      FunctionCase(
        'fluent with expressions',
        Expression.field('updatedAt').timestampDiff(
          Expression.field('createdAt'),
          Expression.constant('minute'),
        ),
        isInt(1440),
      ),
    ]);

    ctx.functionCases('timestampTruncate', [
      FunctionCase(
        'static with plain values, timezone omitted',
        PipelineFunctions.timestampTruncate('createdAt', 'day'),
        _ts(_createdAtUtcDay),
      ),
      FunctionCase(
        'static to the month',
        PipelineFunctions.timestampTruncate('createdAt', 'month'),
        _ts(1698796800),
      ),
      FunctionCase(
        'static to the year',
        PipelineFunctions.timestampTruncate('createdAt', 'year'),
        _ts(1672531200),
      ),
      // Local midnight on 2023-11-15 in Tokyo is 2023-11-14T15:00:00Z.
      FunctionCase(
        'static with expressions and a plain timezone',
        PipelineFunctions.timestampTruncate(
          Expression.field('createdAt'),
          Expression.constant('day'),
          'Asia/Tokyo',
        ),
        _ts(_createdAtUtcDay + 15 * 3600),
      ),
      // Local midnight on 2023-11-14 in MST is 2023-11-14T07:00:00Z.
      FunctionCase(
        'static with a timezone expression',
        PipelineFunctions.timestampTruncate(
          'createdAt',
          'day',
          Expression.constant('MST'),
        ),
        _ts(_createdAtUtcDay + 7 * 3600),
      ),
      FunctionCase(
        'fluent with a plain timezone',
        Expression.field('createdAt').timestampTruncate('day', 'UTC'),
        _ts(_createdAtUtcDay),
      ),
      FunctionCase(
        'fluent to the second drops the sub-second part',
        Expression.field('updatedAt').timestampTruncate('second'),
        _ts(1700086400),
      ),
      FunctionCase(
        'fluent to the millisecond',
        Expression.field('updatedAt').timestampTruncate('millisecond'),
        _ts(1700086400, 123000000),
      ),
      FunctionCase(
        'fluent with a granularity expression, timezone omitted',
        Expression.field(
          'createdAt',
        ).timestampTruncate(Expression.constant('hour')),
        _ts(1699999200),
      ),
      // Local midnight on 2023-11-14 in Los Angeles (PST) is 08:00Z.
      FunctionCase(
        'fluent with expressions',
        Expression.field('createdAt').timestampTruncate(
          Expression.constant('day'),
          Expression.constant('America/Los_Angeles'),
        ),
        _ts(_createdAtUtcDay + 8 * 3600),
      ),
    ]);

    ctx.functionCases('timestampExtract', [
      FunctionCase(
        'static with plain values, timezone omitted',
        PipelineFunctions.timestampExtract('createdAt', 'year'),
        isInt(2023),
      ),
      FunctionCase(
        'static month',
        PipelineFunctions.timestampExtract('createdAt', 'month'),
        isInt(11),
      ),
      FunctionCase(
        'static day defaults to UTC',
        PipelineFunctions.timestampExtract('createdAt', 'day'),
        isInt(14),
      ),
      FunctionCase(
        'static with expressions and a plain timezone',
        PipelineFunctions.timestampExtract(
          Expression.field('createdAt'),
          Expression.constant('day'),
          'Asia/Tokyo',
        ),
        isInt(15),
      ),
      FunctionCase(
        'static with a timezone expression',
        PipelineFunctions.timestampExtract(
          'createdAt',
          'hour',
          Expression.constant('MST'),
        ),
        isInt(15),
      ),
      FunctionCase(
        'fluent with a plain timezone',
        Expression.field('createdAt').timestampExtract('year', 'UTC'),
        isInt(2023),
      ),
      FunctionCase(
        'fluent with timezone omitted',
        Expression.field('createdAt').timestampExtract('hour'),
        isInt(22),
      ),
      FunctionCase(
        'fluent minute',
        Expression.field('createdAt').timestampExtract('minute'),
        isInt(13),
      ),
      FunctionCase(
        'fluent with expressions',
        Expression.field('createdAt').timestampExtract(
          Expression.constant('hour'),
          Expression.constant('America/Los_Angeles'),
        ),
        isInt(14),
      ),
    ]);

    // Vector positions take a VectorValue, a plain list of numbers (which must
    // reach the backend as a vector, not an array) or an expression. The
    // [0.1, 0.1] / [0.5, 0.8] values are the Node SDK system test's.
    ctx.functionCases('cosineDistance', [
      FunctionCase(
        'static with a field name and a list',
        PipelineFunctions.cosineDistance('embedding', [0, 1, 0]),
        isDouble(1),
      ),
      FunctionCase(
        'static with expressions',
        PipelineFunctions.cosineDistance(
          Expression.field('embedding'),
          Expression.vector([1, 1, 0]),
        ),
        isDouble(0.29289321881345254),
      ),
      FunctionCase(
        'static with a field expression on the right',
        PipelineFunctions.cosineDistance(
          Expression.vector([1, 1, 0]),
          Expression.field('embedding'),
        ),
        isDouble(0.29289321881345254),
      ),
      FunctionCase(
        'static with a VectorValue',
        PipelineFunctions.cosineDistance(
          Expression.constant(FieldValue.vector([0.1, 0.1])),
          FieldValue.vector([0.5, 0.8]),
        ),
        isDouble(0.02560880430538015),
      ),
      FunctionCase(
        'fluent with a vector expression',
        Expression.field(
          'embedding',
        ).cosineDistance(Expression.vector([1, 0, 0])),
        isDouble(0),
      ),
      FunctionCase(
        'fluent with a list',
        Expression.field('embedding').cosineDistance(const [1.0, 1.0, 0.0]),
        isDouble(0.29289321881345254),
      ),
      FunctionCase(
        'fluent with a VectorValue',
        Expression.constant(
          FieldValue.vector([0.1, 0.1]),
        ).cosineDistance(FieldValue.vector([0.5, 0.8])),
        isDouble(0.02560880430538015),
      ),
    ]);

    ctx.functionCases('dotProduct', [
      FunctionCase(
        'static with a field name and a list',
        PipelineFunctions.dotProduct('embedding', const [2.5, 4, 5]),
        isDouble(2.5),
      ),
      FunctionCase(
        'static with expressions',
        PipelineFunctions.dotProduct(
          Expression.field('embedding'),
          Expression.vector([2.5, 4, 5]),
        ),
        isDouble(2.5),
      ),
      FunctionCase(
        'static with a VectorValue',
        PipelineFunctions.dotProduct(
          Expression.constant(FieldValue.vector([0.1, 0.1])),
          FieldValue.vector([0.5, 0.8]),
        ),
        isDouble(0.13),
      ),
      FunctionCase(
        'fluent with a vector expression',
        Expression.field('embedding').dotProduct(Expression.vector([1, 0, 0])),
        isDouble(1),
      ),
      FunctionCase(
        'fluent with a field expression',
        Expression.vector([
          2.5,
          4,
          5,
        ]).dotProduct(Expression.field('embedding')),
        isDouble(2.5),
      ),
      FunctionCase(
        'fluent with a list',
        Expression.field('embedding').dotProduct([-1.5, 4, 5]),
        isDouble(-1.5),
      ),
      FunctionCase(
        'fluent with a VectorValue',
        Expression.constant(
          FieldValue.vector([0.1, 0.1]),
        ).dotProduct(FieldValue.vector([0.5, 0.8])),
        isDouble(0.13),
      ),
    ]);

    ctx.functionCases('euclideanDistance', [
      FunctionCase(
        'static with a field name and a list',
        PipelineFunctions.euclideanDistance('embedding', [4, 4, 0]),
        isDouble(5),
      ),
      FunctionCase(
        'static with expressions',
        PipelineFunctions.euclideanDistance(
          Expression.field('embedding'),
          Expression.vector([0, 1, 0]),
        ),
        isDouble(1.4142135623730951),
      ),
      FunctionCase(
        'static with a VectorValue',
        PipelineFunctions.euclideanDistance(
          Expression.constant(FieldValue.vector([0.1, 0.1])),
          FieldValue.vector([0.5, 0.8]),
        ),
        isDouble(0.806225774829855),
      ),
      FunctionCase(
        'fluent with a vector expression',
        Expression.field(
          'embedding',
        ).euclideanDistance(Expression.vector([1, 0, 0])),
        isDouble(0),
      ),
      FunctionCase(
        'fluent with a field expression',
        Expression.vector([
          4,
          4,
          0,
        ]).euclideanDistance(Expression.field('embedding')),
        isDouble(5),
      ),
      FunctionCase(
        'fluent with a list',
        Expression.field('embedding').euclideanDistance(const [1.0, 2.0, 2.0]),
        isDouble(2.8284271247461903),
      ),
      FunctionCase(
        'fluent with a VectorValue',
        Expression.field(
          'embedding',
        ).euclideanDistance(FieldValue.vector([1, 3, 4])),
        isDouble(5),
      ),
    ]);

    ctx.functionCases('vectorLength', [
      FunctionCase(
        'static with a field name',
        PipelineFunctions.vectorLength('embedding'),
        isInt(3),
      ),
      FunctionCase(
        'static with an expression',
        PipelineFunctions.vectorLength(Expression.vector([1, 2, 3, 4])),
        isInt(4),
      ),
      FunctionCase(
        'fluent',
        Expression.field('embedding').vectorLength(),
        isInt(3),
      ),
    ]);
  });
}
