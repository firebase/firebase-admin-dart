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

/// A book 1 field holding a value of [type], or `null` when the Admin SDK
/// cannot write one, and a field holding a value of another type.
///
/// Exhaustive on purpose: a new [PipelineValueType] fails to compile here
/// until it gets a case.
(String?, String) _isTypeFields(PipelineValueType type) {
  return switch (type) {
    PipelineValueType.nullValue => ('nullable', 'title'),
    PipelineValueType.boolean => ('active', 'price'),
    PipelineValueType.number => ('score', 'title'),
    PipelineValueType.int32 => (null, 'price'),
    PipelineValueType.int64 => ('price', 'score'),
    PipelineValueType.double => ('score', 'price'),
    PipelineValueType.decimal128 => (null, 'score'),
    PipelineValueType.timestamp => ('createdAt', 'unixSeconds'),
    PipelineValueType.string => ('title', 'bytes'),
    PipelineValueType.bytes => ('bytes', 'title'),
    PipelineValueType.reference => ('pathRef', 'title'),
    PipelineValueType.geoPoint => ('location', 'metadata'),
    PipelineValueType.array => ('tags', 'metadata'),
    PipelineValueType.map => ('metadata', 'tags'),
    PipelineValueType.vector => ('embedding', 'numbers'),
    PipelineValueType.maxKey => (null, 'title'),
    PipelineValueType.minKey => (null, 'title'),
    PipelineValueType.objectId => (null, 'title'),
    PipelineValueType.regex => (null, 'title'),
  };
}

/// The backend type name of each book 1 field, as `type` returns it.
const _typeNames = {
  'nullable': 'null',
  'active': 'boolean',
  'price': 'int64',
  'score': 'float64',
  'createdAt': 'timestamp',
  'title': 'string',
  'bytes': 'bytes',
  'pathRef': 'reference',
  'location': 'geo_point',
  'tags': 'array',
  'metadata': 'map',
  'embedding': 'vector',
};

void main() {
  pipelineE2E('Pipeline type and debugging functions', (ctx) {
    // Integer division by zero is an error.
    final divisionByZero = Expression.constant(1).divide(0);

    ctx.functionCases('expression primitives', [
      FunctionCase('field', field('title'), 'Dart Pipelines'),
      FunctionCase(
        'field with a nested path',
        field('nested.level1.level2.value'),
        isInt(42),
      ),
      FunctionCase('constant', constant('literal'), 'literal'),
    ]);

    test('PipelineField.path names the selected field', () async {
      final title = field('title');
      final snapshot = await ctx.book1Pipeline().select([title]).execute();
      expect(title.path, 'title');
      expect(snapshot.results.single.get(title.path), 'Dart Pipelines');
    });

    ctx.functionCases('raw functions', [
      FunctionCase(
        'pipelineFunction',
        pipelineFunction('add', [field('price'), 1]),
        isInt(11),
      ),
      FunctionCase(
        'Expression.raw',
        Expression.raw('multiply', [field('rating'), 3]),
        isInt(15),
      ),
      FunctionCase(
        'PipelineFunctions.raw',
        PipelineFunctions.raw('string_concat', [field('prefix'), '!']),
        'Dart!',
      ),
      FunctionCase(
        'asBoolean',
        pipelineFunction('equal', [field('rating'), 5]).asBoolean().not(),
        false,
      ),
    ]);

    ctx.filterCases('raw boolean functions', [
      FilterCase(
        'PipelineFunctions.raw as a condition',
        PipelineFunctions.raw('greater_than', [field('price'), 15]).asBoolean(),
        ['Firestore Admin', 'Inactive Draft'],
      ),
    ]);

    ctx.functionCases('debugging functions', [
      FunctionCase('exists', field('title').exists(), true),
      FunctionCase(
        'exists on an absent field',
        field('missing').exists(),
        false,
      ),
      FunctionCase('exists on a null field', field('nullable').exists(), true),
      FunctionCase(
        'static exists on an expression',
        PipelineFunctions.exists(field('missing')),
        false,
      ),
      FunctionCase('isAbsent', field('missing').isAbsent(), true),
      FunctionCase(
        'isAbsent on a null field',
        field('nullable').isAbsent(),
        false,
      ),
      FunctionCase(
        'static isAbsent on an expression',
        PipelineFunctions.isAbsent(field('title')),
        false,
      ),
      FunctionCase(
        'ifAbsent',
        field('missing').ifAbsent('fallback'),
        'fallback',
      ),
      FunctionCase(
        'ifAbsent on a present field',
        field('title').ifAbsent('fallback'),
        'Dart Pipelines',
      ),
      FunctionCase(
        'ifAbsent on a null field',
        field('nullable').ifAbsent('fallback'),
        isNull,
      ),
      FunctionCase(
        'ifAbsent with an expression',
        field('missing').ifAbsent(field('title')),
        'Dart Pipelines',
      ),
      // Only book 1 has `sparse`; a literal 'sparse' would come back as is.
      FunctionCase(
        'static ifAbsent on a field name',
        PipelineFunctions.ifAbsent('sparse', 'none'),
        'book 1 only',
      ),
      FunctionCase(
        'static ifAbsent on expressions',
        PipelineFunctions.ifAbsent(field('missing'), field('prefix')),
        'Dart',
      ),
      FunctionCase('isError', divisionByZero.isError(), true),
      FunctionCase('isError without an error', field('title').isError(), false),
      FunctionCase(
        'static isError on an expression',
        PipelineFunctions.isError(divisionByZero),
        true,
      ),
      FunctionCase(
        'static isError on a plain value',
        PipelineFunctions.isError(0),
        false,
      ),
      FunctionCase('ifError', divisionByZero.ifError('was error'), 'was error'),
      FunctionCase(
        'ifError with an expression',
        divisionByZero.ifError(field('title')),
        'Dart Pipelines',
      ),
      FunctionCase(
        'ifError without an error',
        field('title').ifError('caught'),
        'Dart Pipelines',
      ),
      FunctionCase(
        'ifError on a boolean expression',
        divisionByZero.greaterThan(1).ifError(constant(true)).asBoolean().not(),
        false,
      ),
      FunctionCase(
        'static ifError on expressions',
        PipelineFunctions.ifError(divisionByZero, constant('was error')),
        'was error',
      ),
      FunctionCase(
        'static ifError on plain values',
        PipelineFunctions.ifError(42, 'caught'),
        isInt(42),
      ),
    ]);

    // A field-name String is a field reference: `exists('sparse')` holds for
    // book 1 only, where a literal 'sparse' would hold for every book.
    ctx.filterCases('debugging functions on field names', [
      FilterCase('static exists', PipelineFunctions.exists('sparse'), [
        'Dart Pipelines',
      ]),
      FilterCase('static isAbsent', PipelineFunctions.isAbsent('sparse'), [
        'Firestore Admin',
        'Inactive Draft',
      ]),
    ]);

    ctx.functionCases('type', [
      for (final MapEntry(key: fieldName, value: typeName)
          in _typeNames.entries)
        FunctionCase('type of $fieldName', field(fieldName).type(), typeName),
      // A literal 'price' would be a string.
      FunctionCase(
        'static type on a field name',
        PipelineFunctions.type('price'),
        'int64',
      ),
      FunctionCase(
        'static type on an expression',
        PipelineFunctions.type(field('location')),
        'geo_point',
      ),
    ]);

    // Each value is checked against a field of its type, where one can be
    // written, and against a field of another type. The negative case alone
    // still proves the backend accepts the type name.
    ctx.functionCases('isType', [
      for (final type in PipelineValueType.values)
        if (_isTypeFields(type) case (final matching, final other)) ...[
          if (matching != null)
            FunctionCase(
              '${type.name} on $matching',
              field(matching).isType(type),
              true,
            ),
          FunctionCase(
            '${type.name} on $other',
            field(other).isType(type),
            false,
          ),
        ],
      FunctionCase(
        'number on an integer',
        field('price').isType(PipelineValueType.number),
        true,
      ),
      FunctionCase(
        'decimal128 on an integer',
        field('price').isType(PipelineValueType.decimal128),
        false,
      ),
      FunctionCase('a type name String', field('price').isType('int64'), true),
      FunctionCase(
        'a type name expression',
        field('price').isType(constant('int64')),
        true,
      ),
      // A literal 'price' would be a string.
      FunctionCase(
        'static isType on a field name',
        PipelineFunctions.isType('price', PipelineValueType.int64),
        true,
      ),
      FunctionCase(
        'static isType on expressions',
        PipelineFunctions.isType(field('score'), constant('float64')),
        true,
      ),
      FunctionCase(
        'static isType with a type name String',
        PipelineFunctions.isType('score', 'int64'),
        false,
      ),
    ]);
  });
}
