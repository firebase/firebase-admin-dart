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

/// Live coverage of the string Pipeline functions and the generic `length`,
/// `reverse` and `concat` functions.
@Tags(['prod'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  pipelineE2E('Pipeline string functions', (ctx) {
    ctx.functionCases('string functions', [
      FunctionCase('byteLength', Expression.field('title').byteLength(), 14),
      FunctionCase('charLength', Expression.field('title').length(), 14),
      FunctionCase(
        'startsWith',
        Expression.field('title').startsWith('Dart'),
        true,
      ),
      FunctionCase(
        'endsWith',
        Expression.field('title').endsWith('lines'),
        true,
      ),
      FunctionCase('like', Expression.field('title').like('Dart%'), true),
      FunctionCase(
        'regexContains',
        Expression.field('title').regexContains('Pipe'),
        true,
      ),
      FunctionCase(
        'regexMatch',
        Expression.field('title').regexMatch(r'^Dart.*'),
        true,
      ),
      FunctionCase(
        'regexFind',
        Expression.field('title').regexFind('Pipe'),
        isNotNull,
      ),
      FunctionCase(
        'regexFindAll',
        Expression.field('title').regexFindAll('[aei]'),
        isA<List<Object?>>(),
      ),
      FunctionCase(
        'stringConcat',
        Expression.field('title').concat([' v2']),
        'Dart Pipelines v2',
      ),
      FunctionCase(
        'stringContains',
        Expression.field('title').stringContains('Pipeline'),
        true,
      ),
      FunctionCase(
        'stringIndexOf',
        Expression.field('title').stringIndexOf('Pipeline'),
        5,
      ),
      FunctionCase(
        'toUpper',
        Expression.field('title').toUpperCase(),
        'DART PIPELINES',
      ),
      FunctionCase(
        'toLower',
        Expression.field('title').toLowerCase(),
        'dart pipelines',
      ),
      FunctionCase(
        'substring',
        Expression.field('title').substringLiteral(0, 4),
        'Dart',
      ),
      // The second argument is a length, not an end index.
      FunctionCase(
        'substringLength',
        Expression.field('title').substring(5, 3),
        'Pip',
      ),
      FunctionCase(
        'substringToEnd',
        Expression.field('title').substring(5),
        'Pipelines',
      ),
      FunctionCase(
        'stringReverse',
        PipelineFunctions.stringReverse(Expression.constant('Dart')),
        'traD',
      ),
      FunctionCase(
        'stringRepeat',
        Expression.constant('ha').stringRepeat(3),
        'hahaha',
      ),
      FunctionCase(
        'stringReplaceAll',
        Expression.field('title').stringReplaceAllLiteral('i', 'I'),
        'Dart PIpelInes',
      ),
      FunctionCase(
        'stringReplaceOne',
        Expression.field('title').stringReplaceOneLiteral('i', 'I'),
        'Dart PIpelines',
      ),
      FunctionCase('trim', Expression.field('spaced').trim(), 'Dart'),
      FunctionCase('ltrim', Expression.field('spaced').ltrim(), 'Dart  '),
      FunctionCase('rtrim', Expression.field('spaced').rtrim(), '  Dart'),
      FunctionCase('split', Expression.field('csv').splitLiteral(','), [
        'dart',
        'firebase',
        'admin',
      ]),
      FunctionCase('splitStatic', PipelineFunctions.split('csv', ','), [
        'dart',
        'firebase',
        'admin',
      ]),
    ]);
  });
}
