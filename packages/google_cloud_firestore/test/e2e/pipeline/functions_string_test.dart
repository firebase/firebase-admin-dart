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
///
/// Each function is exercised in its static form with a field-name `String`
/// and with an expression, and in its fluent form; value arguments are passed
/// both as plain values and as expressions (`constant(...)` or a field).
@Tags(['prod'])
library;

import 'package:google_cloud_firestore/google_cloud_firestore.dart';
import 'package:test/test.dart';

import 'harness.dart';

void main() {
  pipelineE2E('Pipeline string functions', (ctx) {
    // `unicode` is 'café ☕ 日本': 9 code points, 16 UTF-8 bytes.
    ctx.functionCases('lengths', [
      FunctionCase(
        'byteLength',
        Expression.field('title').byteLength(),
        isInt(14),
      ),
      FunctionCase(
        'byteLength static counts UTF-8 bytes',
        PipelineFunctions.byteLength('unicode'),
        isInt(16),
      ),
      FunctionCase(
        'byteLength static of a bytes value',
        PipelineFunctions.byteLength(Expression.field('bytes')),
        isInt(2),
      ),
      FunctionCase(
        'charLength',
        Expression.field('empty').charLength(),
        isInt(0),
      ),
      FunctionCase(
        'charLength static counts code points',
        PipelineFunctions.charLength('unicode'),
        isInt(9),
      ),
      FunctionCase(
        'charLength static with an expression',
        PipelineFunctions.charLength(Expression.field('greeting')),
        isInt(13),
      ),
      FunctionCase(
        'length of a string',
        Expression.field('title').length(),
        isInt(14),
      ),
      FunctionCase(
        'length of a vector',
        Expression.field('embedding').length(),
        isInt(3),
      ),
      FunctionCase(
        'length static of an array',
        PipelineFunctions.length('tags'),
        isInt(2),
      ),
      FunctionCase(
        'length static of a map',
        PipelineFunctions.length(Expression.field('metadata')),
        isInt(2),
      ),
    ]);

    ctx.functionCases('reverse', [
      FunctionCase(
        'reverse',
        Expression.field('greeting').reverse(),
        '!dlroW ,olleH',
      ),
      FunctionCase(
        'reverse static',
        PipelineFunctions.reverse('prefix'),
        'traD',
      ),
      FunctionCase(
        'reverse static with an expression',
        PipelineFunctions.reverse(Expression.field('title')),
        'senilepiP traD',
      ),
      FunctionCase(
        'stringReverse',
        Expression.field('semicolons').stringReverse(),
        'c;b;a',
      ),
      FunctionCase(
        'stringReverse static',
        PipelineFunctions.stringReverse('title'),
        'senilepiP traD',
      ),
      FunctionCase(
        'stringReverse static with an expression',
        PipelineFunctions.stringReverse(Expression.constant('Dart')),
        'traD',
      ),
    ]);

    ctx.functionCases('concatenation', [
      FunctionCase(
        'concat',
        Expression.field('title').concat([' v2']),
        'Dart Pipelines v2',
      ),
      FunctionCase(
        'concat with an expression',
        Expression.field('prefix').concat([', ', Expression.field('greeting')]),
        'Dart, Hello, World!',
      ),
      // A field-name first argument; the other Strings are literals.
      FunctionCase(
        'concat static with more values',
        PipelineFunctions.concat('prefix', ' & ', [
          Expression.field('title'),
          '!',
        ]),
        'Dart & Dart Pipelines!',
      ),
      FunctionCase(
        'concat static of two arrays',
        PipelineFunctions.concat(
          Expression.field('tags'),
          Expression.field('words'),
        ),
        ['dart', 'firebase', 'dart', 'firebase'],
      ),
      FunctionCase(
        'stringConcat',
        Expression.field(
          'prefix',
        ).stringConcat([' + ', Expression.field('title')]),
        'Dart + Dart Pipelines',
      ),
      // The first value names a field; the others are literals or expressions.
      FunctionCase(
        'stringConcat static',
        PipelineFunctions.stringConcat([
          'prefix',
          ' ',
          Expression.field('greeting'),
        ]),
        'Dart Hello, World!',
      ),
    ]);

    ctx.functionCases('prefix, suffix and pattern predicates', [
      FunctionCase(
        'startsWith',
        Expression.field('title').startsWith('Dart'),
        true,
      ),
      FunctionCase(
        'startsWith is case-sensitive',
        Expression.field('title').startsWith('dart'),
        false,
      ),
      FunctionCase(
        'startsWith with an expression',
        Expression.field('sentence').startsWith(Expression.field('prefix')),
        true,
      ),
      FunctionCase(
        'startsWith static',
        PipelineFunctions.startsWith('greeting', 'Hello'),
        true,
      ),
      FunctionCase(
        'endsWith',
        Expression.field('title').endsWith('lines'),
        true,
      ),
      FunctionCase(
        'endsWith with an expression',
        Expression.field('sentence').endsWith(Expression.constant('fast')),
        true,
      ),
      FunctionCase(
        'endsWith static',
        PipelineFunctions.endsWith('email', '.com'),
        true,
      ),
      FunctionCase('like', Expression.field('title').like('Dart%'), true),
      FunctionCase(
        'like is case-sensitive',
        Expression.field('title').like('dart%'),
        false,
      ),
      FunctionCase(
        'like static',
        PipelineFunctions.like('email', '%@example.com'),
        true,
      ),
      FunctionCase(
        'like static with an expression',
        PipelineFunctions.like(
          Expression.field('title'),
          Expression.constant('%Pipe%'),
        ),
        true,
      ),
      FunctionCase(
        'stringContains',
        Expression.field('title').stringContains('Pipeline'),
        true,
      ),
      FunctionCase(
        'stringContains with an expression',
        Expression.field(
          'email',
        ).stringContains(Expression.constant('@example.')),
        true,
      ),
      FunctionCase(
        'stringContains static',
        PipelineFunctions.stringContains('sentence', 'fun'),
        true,
      ),
    ]);

    // Patterns use RE2 syntax.
    ctx.functionCases('regular expressions', [
      FunctionCase(
        'regexContains',
        Expression.field('title').regexContains('Pipe'),
        true,
      ),
      FunctionCase(
        'regexContains is case-sensitive',
        Expression.field('title').regexContains('pipe'),
        false,
      ),
      FunctionCase(
        'regexContains static with an expression',
        PipelineFunctions.regexContains(
          Expression.field('title'),
          Expression.constant('(?i)pipe'),
        ),
        true,
      ),
      FunctionCase(
        'regexMatch',
        Expression.field('title').regexMatch(r'^Dart.*'),
        true,
      ),
      FunctionCase(
        'regexMatch static',
        PipelineFunctions.regexMatch('csv', '[a-z,]+'),
        true,
      ),
      // Unlike regexContains, the pattern must match the whole string.
      FunctionCase(
        'regexMatch static needs a full match',
        PipelineFunctions.regexMatch(
          Expression.field('title'),
          Expression.constant('Dart'),
        ),
        false,
      ),
      FunctionCase(
        'regexFind',
        Expression.field('title').regexFind(r'P\w+'),
        'Pipelines',
      ),
      FunctionCase(
        'regexFind with an expression',
        Expression.field('greeting').regexFind(Expression.constant(r'\w+')),
        'Hello',
      ),
      FunctionCase(
        'regexFind static',
        PipelineFunctions.regexFind('email', '@.+'),
        '@example.com',
      ),
      FunctionCase(
        'regexFind static returns the first match',
        PipelineFunctions.regexFind(
          Expression.field('sentence'),
          Expression.constant(r'f\w+'),
        ),
        'fun',
      ),
      FunctionCase(
        'regexFindAll',
        Expression.field('title').regexFindAll('[aei]'),
        ['a', 'i', 'e', 'i', 'e'],
      ),
      FunctionCase(
        'regexFindAll with an expression',
        Expression.field('semicolons').regexFindAll(Expression.constant(r'\w')),
        ['a', 'b', 'c'],
      ),
      FunctionCase(
        'regexFindAll static',
        PipelineFunctions.regexFindAll('csv', '[a-z]+'),
        ['dart', 'firebase', 'admin'],
      ),
      FunctionCase(
        'regexFindAll static with an expression',
        PipelineFunctions.regexFindAll(
          Expression.field('sentence'),
          Expression.constant('Dart'),
        ),
        ['Dart', 'Dart'],
      ),
    ]);

    // Indexes are 0-based.
    ctx.functionCases('stringIndexOf', [
      FunctionCase(
        'stringIndexOf',
        Expression.field('title').stringIndexOf('Pipeline'),
        isInt(5),
      ),
      FunctionCase(
        'stringIndexOf with an expression',
        Expression.field(
          'semicolons',
        ).stringIndexOf(Expression.field('delimiter')),
        isInt(1),
      ),
      FunctionCase(
        'stringIndexOf static',
        PipelineFunctions.stringIndexOf('sentence', 'fun'),
        isInt(8),
      ),
      FunctionCase(
        'stringIndexOf static with an expression',
        PipelineFunctions.stringIndexOf(
          Expression.field('greeting'),
          Expression.constant('World'),
        ),
        isInt(7),
      ),
    ]);

    ctx.functionCases('case conversion', [
      FunctionCase(
        'toUpperCase',
        Expression.field('title').toUpperCase(),
        'DART PIPELINES',
      ),
      FunctionCase(
        'toLowerCase',
        Expression.field('title').toLowerCase(),
        'dart pipelines',
      ),
      FunctionCase(
        'toUpper static',
        PipelineFunctions.toUpper('prefix'),
        'DART',
      ),
      FunctionCase(
        'toUpper static with an expression',
        PipelineFunctions.toUpper(Expression.field('greeting')),
        'HELLO, WORLD!',
      ),
      FunctionCase(
        'toLower static',
        PipelineFunctions.toLower('title'),
        'dart pipelines',
      ),
      FunctionCase(
        'toLower static with an expression',
        PipelineFunctions.toLower(Expression.field('greeting')),
        'hello, world!',
      ),
    ]);

    // The position is a 0-based index and the optional second argument a
    // length, not an end index. `rating` is 5 on book 1.
    ctx.functionCases('substring', [
      FunctionCase(
        'substringLiteral',
        Expression.field('title').substringLiteral(0, 4),
        'Dart',
      ),
      FunctionCase(
        'substringLiteral to the end',
        Expression.field('email').substringLiteral(9),
        'example.com',
      ),
      FunctionCase(
        'substring with a length',
        Expression.field('title').substring(5, 3),
        'Pip',
      ),
      FunctionCase(
        'substring to the end',
        Expression.field('title').substring(5),
        'Pipelines',
      ),
      FunctionCase(
        'substring with expressions',
        Expression.field(
          'greeting',
        ).substring(Expression.constant(7), Expression.field('rating')),
        'World',
      ),
      FunctionCase(
        'substring static',
        PipelineFunctions.substring('email', 0, 3),
        'dev',
      ),
      FunctionCase(
        'substring static to the end with an expression',
        PipelineFunctions.substring(
          Expression.field('title'),
          Expression.field('rating'),
        ),
        'Pipelines',
      ),
      FunctionCase(
        'substring static with an expression length',
        PipelineFunctions.substring('sentence', 8, Expression.constant(3)),
        'fun',
      ),
      // Positions and lengths count code points for a string.
      FunctionCase(
        'substring static counts code points',
        PipelineFunctions.substring('unicode', 5, 1),
        '☕',
      ),
    ]);

    // `discount` is 2 and `rating` 5 on book 1.
    ctx.functionCases('stringRepeat', [
      FunctionCase(
        'stringRepeat',
        Expression.constant('ha').stringRepeat(3),
        'hahaha',
      ),
      FunctionCase(
        'stringRepeat with an expression',
        Expression.constant('-').stringRepeat(Expression.field('rating')),
        '-----',
      ),
      FunctionCase(
        'stringRepeat static',
        PipelineFunctions.stringRepeat('prefix', 2),
        'DartDart',
      ),
      FunctionCase(
        'stringRepeat static with expressions',
        PipelineFunctions.stringRepeat(
          Expression.field('delimiter'),
          Expression.field('discount'),
        ),
        ';;',
      ),
    ]);

    // The search value is a literal substring, not a pattern.
    ctx.functionCases('replacement', [
      FunctionCase(
        'stringReplaceAllLiteral',
        Expression.field('title').stringReplaceAllLiteral('i', 'I'),
        'Dart PIpelInes',
      ),
      FunctionCase(
        'stringReplaceAll',
        Expression.field('sentence').stringReplaceAll('Dart', 'Go'),
        'Go is fun and Go is fast',
      ),
      FunctionCase(
        'stringReplaceAll with expressions',
        Expression.field('csv').stringReplaceAll(
          Expression.constant(','),
          Expression.field('delimiter'),
        ),
        'dart;firebase;admin',
      ),
      FunctionCase(
        'stringReplaceAll static replaces a literal dot',
        PipelineFunctions.stringReplaceAll('email', '.', '_'),
        'dev_team@example_com',
      ),
      FunctionCase(
        'stringReplaceAll static with expressions',
        PipelineFunctions.stringReplaceAll(
          Expression.field('semicolons'),
          Expression.field('delimiter'),
          Expression.constant(', '),
        ),
        'a, b, c',
      ),
      FunctionCase(
        'stringReplaceOneLiteral',
        Expression.field('title').stringReplaceOneLiteral('i', 'I'),
        'Dart PIpelines',
      ),
      FunctionCase(
        'stringReplaceOne',
        Expression.field('email').stringReplaceOne('.', '_'),
        'dev_team@example.com',
      ),
      FunctionCase(
        'stringReplaceOne with expressions',
        Expression.field('csv').stringReplaceOne(
          Expression.constant(','),
          Expression.constant(' & '),
        ),
        'dart & firebase,admin',
      ),
      FunctionCase(
        'stringReplaceOne static',
        PipelineFunctions.stringReplaceOne('sentence', 'Dart', 'Go'),
        'Go is fun and Dart is fast',
      ),
      FunctionCase(
        'stringReplaceOne static with expressions',
        PipelineFunctions.stringReplaceOne(
          Expression.field('semicolons'),
          Expression.field('delimiter'),
          Expression.constant('+'),
        ),
        'a+b;c',
      ),
    ]);

    // Without a value, whitespace is trimmed; a value is a set of characters,
    // not a substring.
    ctx.functionCases('trimming', [
      FunctionCase('trim', Expression.field('spaced').trim(), 'Dart'),
      FunctionCase(
        'trim a value',
        Expression.field('padded').trim('_'),
        'Dart',
      ),
      FunctionCase(
        'trim an expression',
        Expression.field('semicolons').trim(Expression.constant('ac')),
        ';b;',
      ),
      FunctionCase('trim static', PipelineFunctions.trim('spaced'), 'Dart'),
      FunctionCase(
        'trim static a value',
        PipelineFunctions.trim(Expression.field('padded'), '_'),
        'Dart',
      ),
      FunctionCase(
        'trim static an expression',
        PipelineFunctions.trim('greeting', Expression.constant('H!')),
        'ello, World',
      ),
      FunctionCase('ltrim', Expression.field('spaced').ltrim(), 'Dart  '),
      FunctionCase(
        'ltrim a value',
        Expression.field('padded').ltrim('_'),
        'Dart__',
      ),
      FunctionCase(
        'ltrim an expression',
        Expression.field('semicolons').ltrim(Expression.constant('a;')),
        'b;c',
      ),
      FunctionCase('ltrim static', PipelineFunctions.ltrim('spaced'), 'Dart  '),
      FunctionCase(
        'ltrim static a value',
        PipelineFunctions.ltrim(Expression.field('padded'), '_'),
        'Dart__',
      ),
      FunctionCase(
        'ltrim static an expression',
        PipelineFunctions.ltrim('greeting', Expression.constant('Hel')),
        'o, World!',
      ),
      FunctionCase('rtrim', Expression.field('spaced').rtrim(), '  Dart'),
      FunctionCase(
        'rtrim a value',
        Expression.field('padded').rtrim('_'),
        '__Dart',
      ),
      FunctionCase(
        'rtrim an expression',
        Expression.field('semicolons').rtrim(Expression.constant(';c')),
        'a;b',
      ),
      FunctionCase('rtrim static', PipelineFunctions.rtrim('spaced'), '  Dart'),
      FunctionCase(
        'rtrim static a value',
        PipelineFunctions.rtrim(Expression.field('padded'), '_'),
        '__Dart',
      ),
      FunctionCase(
        'rtrim static an expression',
        PipelineFunctions.rtrim('greeting', Expression.constant('!dl')),
        'Hello, Wor',
      ),
    ]);

    ctx.functionCases('split', [
      FunctionCase('splitLiteral', Expression.field('csv').splitLiteral(','), [
        'dart',
        'firebase',
        'admin',
      ]),
      FunctionCase('split', Expression.field('email').split('@'), [
        'dev.team',
        'example.com',
      ]),
      FunctionCase(
        'split with an expression',
        Expression.field('sentence').split(Expression.constant(' and ')),
        ['Dart is fun', 'Dart is fast'],
      ),
      // The field-name first argument is a field; the delimiter a literal.
      FunctionCase('split static', PipelineFunctions.split('csv', ','), [
        'dart',
        'firebase',
        'admin',
      ]),
      FunctionCase(
        'split static with expressions',
        PipelineFunctions.split(
          Expression.field('semicolons'),
          Expression.field('delimiter'),
        ),
        ['a', 'b', 'c'],
      ),
    ]);

    // Comparing two fields of each book, so every book gives its own answer.
    ctx.filterCases('string predicates across books', [
      FilterCase(
        'startsWith static with expressions',
        PipelineFunctions.startsWith(
          Expression.field('title'),
          Expression.field('prefix'),
        ),
        ['Dart Pipelines', 'Firestore Admin'],
      ),
      FilterCase(
        'endsWith static with expressions',
        PipelineFunctions.endsWith(
          Expression.field('title'),
          Expression.field('prefix'),
        ),
        ['Inactive Draft'],
      ),
      FilterCase(
        'stringContains static with expressions',
        PipelineFunctions.stringContains(
          Expression.field('greeting'),
          Expression.field('prefix'),
        ),
        ['Inactive Draft'],
      ),
      FilterCase(
        'like with an expression',
        Expression.field('greeting').like(Expression.constant('Hello%')),
        ['Dart Pipelines', 'Firestore Admin'],
      ),
      FilterCase(
        'regexContains static',
        PipelineFunctions.regexContains('email', r'@example\.(com|org)$'),
        ['Dart Pipelines', 'Firestore Admin'],
      ),
      // Each book's `prefix` is used as its pattern.
      FilterCase(
        'regexContains with an expression',
        Expression.field('greeting').regexContains(Expression.field('prefix')),
        ['Inactive Draft'],
      ),
      // `dev.team` holds a dot, so book 1's email cannot fully match.
      FilterCase(
        'regexMatch with an expression',
        Expression.field(
          'email',
        ).regexMatch(Expression.constant(r'[a-z]+@example\.(org|net)')),
        ['Firestore Admin', 'Inactive Draft'],
      ),
    ]);
  });
}
