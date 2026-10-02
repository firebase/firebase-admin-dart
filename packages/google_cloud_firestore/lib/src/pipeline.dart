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

part of 'firestore.dart';

/// Creates a field reference expression for Firestore Pipeline operations.
///
/// [fieldPath] is a [String] or a [FieldPath]. A [String] is a dot-separated
/// path, so `field('address.city')` reads the `city` field of the `address`
/// map; use a [FieldPath] for a field whose name contains a dot, as in
/// `field(FieldPath(['a.b']))`. Field names that are not simple identifiers
/// (such as `first-name`, `last name` or `naïve`) need no escaping: they are
/// quoted with backticks when sent, as [PipelineField.path] shows.
///
/// Throws an [ArgumentError] when [fieldPath] is neither a [String] nor a
/// [FieldPath], or has an empty segment (`''`, `'a..b'`).
PipelineField field(Object fieldPath) => Expression.field(fieldPath);

/// Creates a constant expression for Firestore Pipeline operations.
PipelineExpression constant(Object? value) => Expression.constant(value);

/// Creates a variable reference expression for Firestore Pipeline operations.
PipelineExpression variable(String name) => Expression.variable(name);

/// FlutterFire-style entry points for building Pipeline expressions.
abstract final class Expression {
  // The top-level field, constant and variable helpers forward to these. The
  // forwarding cannot go the other way: in here, a bare `field` names
  // Expression.field itself.

  /// Creates a field reference expression.
  ///
  /// [fieldPath] is a [String] (a dot-separated path) or a [FieldPath]; see
  /// the top-level [field].
  static PipelineField field(Object fieldPath) {
    return PipelineField._(_canonicalFieldPath(fieldPath));
  }

  /// Creates a constant expression.
  static PipelineExpression constant(Object? value) => _PipelineConstant(value);

  /// Creates a variable reference expression.
  static PipelineExpression variable(String name) => _PipelineVariable(name);

  /// Creates an array expression.
  static PipelineExpression array(Iterable<Object?> values) {
    return PipelineFunctions.array(values);
  }

  /// Creates a vector value expression.
  static PipelineExpression vector(List<num> values) {
    return _PipelineConstant(
      FieldValue.vector([for (final value in values) value.toDouble()]),
    );
  }

  /// Creates a raw backend function expression.
  ///
  /// See [PipelineFunctions.raw].
  static PipelineExpression raw(
    String name,
    Iterable<Object?> args, {
    Map<String, Object?> options = const {},
  }) {
    return PipelineFunctions.raw(name, args, options: options);
  }
}

/// FlutterFire-style alias for [PipelineBooleanExpression].
typedef BooleanExpression = PipelineBooleanExpression;

/// FlutterFire-style alias for [PipelineOrdering].
typedef Ordering = PipelineOrdering;

/// FlutterFire-style alias for [PipelineAliasedExpression].
typedef AliasedExpression = PipelineAliasedExpression;

/// FlutterFire-style alias for expressions that can be selected.
typedef Selectable = PipelineExpression;

/// FlutterFire-style alias for aggregate function expressions.
typedef PipelineAggregateFunction = PipelineExpression;

/// Firestore Pipeline backend value types used with [PipelineExpression.isType].
///
/// Each member encodes as the type name the backend expects, matching the
/// Node.js SDK's `Type` union. [PipelineExpression.isType] also accepts a raw
/// type name string for backend types not listed here.
enum PipelineValueType {
  /// Null values.
  nullValue('null'),

  /// Boolean values.
  boolean('boolean'),

  /// Any numeric value.
  number('number'),

  /// 32-bit integer values.
  int32('int32'),

  /// 64-bit integer values.
  int64('int64'),

  /// 64-bit floating point values, sent to the backend as `float64`.
  double('float64'),

  /// 128-bit decimal values.
  decimal128('decimal128'),

  /// Timestamp values.
  timestamp('timestamp'),

  /// String values.
  string('string'),

  /// Bytes values.
  bytes('bytes'),

  /// Document reference values.
  reference('reference'),

  /// Geo point values.
  geoPoint('geo_point'),

  /// Array values.
  array('array'),

  /// Map values.
  map('map'),

  /// Vector values.
  vector('vector'),

  /// Max key values.
  maxKey('max_key'),

  /// Min key values.
  minKey('min_key'),

  /// Object ID values.
  objectId('object_id'),

  /// Regular expression values.
  regex('regex');

  const PipelineValueType(this.value);

  /// The backend type name.
  final String value;
}

/// How the backend should choose indexes when executing a Pipeline.
enum PipelineIndexMode {
  /// Let the backend pick the indexes it recommends.
  recommended('recommended');

  const PipelineIndexMode(this.value);

  /// The value sent to the backend.
  final String value;
}

/// Whether the backend should return planning stats alongside the results.
enum PipelineExplainMode {
  /// Execute the Pipeline and return results, without planning stats.
  execute('execute'),

  /// Execute the Pipeline and return planning and execution stats alongside
  /// the results.
  analyze('analyze');

  const PipelineExplainMode(this.value);

  /// The value sent to the backend.
  final String value;
}

/// The format the backend encodes explain stats in.
enum PipelineExplainOutputFormat {
  /// A human-readable string, surfaced by [ExplainStats.text].
  text('text');

  const PipelineExplainOutputFormat(this.value);

  /// The value sent to the backend.
  final String value;
}

/// Asks the backend for statistics about how it plans and runs a Pipeline.
///
/// Pass to [Pipeline.execute]; read the result from
/// [PipelineSnapshot.explainStats].
@immutable
final class PipelineExplainOptions {
  /// Creates explain options.
  const PipelineExplainOptions({this.mode, this.outputFormat});

  /// Whether the backend should return planning stats.
  final PipelineExplainMode? mode;

  /// The format the stats are encoded in.
  final PipelineExplainOutputFormat? outputFormat;

  Map<String, Object?> get _encoded {
    return _compactOptions({
      'mode': mode?.value,
      'output_format': outputFormat?.value,
    });
  }
}

/// Creates a raw Pipeline function expression.
///
/// [args] are sent as-is: a [List] or [Map] is a literal value, which cannot
/// hold expressions. Build those with [PipelineFunctions.array] or
/// [PipelineFunctions.map].
PipelineExpression pipelineFunction(
  String name,
  Iterable<Object?> args, {
  Map<String, Object?> options = const {},
}) {
  return _PipelineFunctionExpression(name, args.toList(), options);
}

/// Creates an equality expression; same as [PipelineFunctions.equal].
PipelineBooleanExpression equal(Object? left, Object? right) {
  return PipelineFunctions.equal(left, right);
}

/// Creates a not-equal expression; same as [PipelineFunctions.notEqual].
PipelineBooleanExpression notEqual(Object? left, Object? right) {
  return PipelineFunctions.notEqual(left, right);
}

/// Creates a less-than expression; same as [PipelineFunctions.lessThan].
PipelineBooleanExpression lessThan(Object? left, Object? right) {
  return PipelineFunctions.lessThan(left, right);
}

/// Creates a less-than-or-equal expression; same as
/// [PipelineFunctions.lessThanOrEqual].
PipelineBooleanExpression lessThanOrEqual(Object? left, Object? right) {
  return PipelineFunctions.lessThanOrEqual(left, right);
}

/// Creates a greater-than expression; same as [PipelineFunctions.greaterThan].
PipelineBooleanExpression greaterThan(Object? left, Object? right) {
  return PipelineFunctions.greaterThan(left, right);
}

/// Creates a greater-than-or-equal expression; same as
/// [PipelineFunctions.greaterThanOrEqual].
PipelineBooleanExpression greaterThanOrEqual(Object? left, Object? right) {
  return PipelineFunctions.greaterThanOrEqual(left, right);
}

/// The canonical string the backend expects for the field at [fieldPath].
///
/// Mirrors the Node SDK's `field()`, which sends
/// `FieldPath.fromArgument(fieldPath).formattedName`: a [String] is split on
/// dots into segments, a [FieldPath] keeps its segments (dots included), and
/// [FieldPath._formattedName] backtick-quotes every segment that is not a
/// simple identifier. Like Node, and unlike [Query.where], a [String] may hold
/// any character other than a dot.
String _canonicalFieldPath(Object fieldPath) {
  final path = switch (fieldPath) {
    FieldPath() => fieldPath,
    String() => FieldPath(fieldPath.split('.')),
    _ => throw ArgumentError.value(
      fieldPath,
      'fieldPath',
      'Expected a String or a FieldPath.',
    ),
  };
  return path._formattedName;
}

/// Interprets a [String] in a field position as a field reference.
///
/// Mirrors the Node SDK's `fieldOrExpression`: arguments that name the target
/// of a function accept either a field name or an expression, so a bare
/// [String] means [field]. Arguments in a value position keep [String]s as
/// string literals, which is what [_encodePipelineValue] does by default.
Object? _fieldOrExpression(Object? value) {
  return value is String ? field(value) : value;
}

/// Applies [_fieldOrExpression] to the first entry of [values].
///
/// Used by variadic functions whose first argument is the target field.
List<Object?> _fieldOrExpressionFirst(Iterable<Object?> values) {
  final list = values.toList();
  if (list.isNotEmpty) {
    list[0] = _fieldOrExpression(list[0]);
  }
  return list;
}

/// Interprets a list of numbers in a vector position as a [VectorValue].
///
/// Mirrors the Node SDK's `vectorToExpr`: the vector distance functions and
/// the `find_nearest` stage take a [VectorValue], an expression, or a plain
/// list of numbers. Left to [_encodePipelineValue], a list would encode as an
/// `ARRAY`, which the backend rejects where it expects a `Vector`.
Object? _vectorOrExpression(Object? value, String name) {
  if (value is! Iterable<Object?>) return value;
  return FieldValue.vector([
    for (final element in value)
      switch (element) {
        num() => element.toDouble(),
        _ => throw ArgumentError.value(
          value,
          name,
          'Expected a VectorValue, a list of numbers, or an expression.',
        ),
      },
  ]);
}

/// Converts a Dart collection in a value position to the function that builds
/// it.
///
/// Mirrors the Node SDK's `valueToDefaultExpr`: an [Iterable] becomes an
/// `array(...)` function and a [Map] a `map(...)` function, with their entries
/// converted the same way. The backend rejects expressions nested inside a
/// literal array or map value, so this is what lets a collection such as
/// `[field('a'), 1]` hold expressions. Other values are returned unchanged;
/// wrap a collection in [constant] to send it as a literal value instead.
Object? _valueToDefaultExpr(Object? value) {
  return switch (value) {
    Uint8List() => value,
    Iterable() => PipelineFunctions.array(value),
    Map() => PipelineFunctions.map([
      for (final entry in value.entries) ...[entry.key.toString(), entry.value],
    ]),
    _ => value,
  };
}

/// Converts a [Pipeline.rawStage] argument.
///
/// Mirrors the Node SDK's `rawStage`, which sends a plain object as a literal
/// map value (`_mapValue`) and anything else as is (`constant`). A literal map
/// that is a stage argument may hold expressions, as `select`'s does, but the
/// backend rejects them one level deeper, so each value of the map goes
/// through [_valueToDefaultExpr]: a nested collection becomes the `map(...)`
/// or `array(...)` function that builds it.
Object? _rawStageArg(Object? value) {
  return switch (value) {
    Map() => {
      for (final entry in value.entries)
        entry.key.toString(): _valueToDefaultExpr(entry.value),
    },
    _ => value,
  };
}

/// Whether [value] is, or holds, an expression the backend has to evaluate.
///
/// Constants already encode to plain values, so they don't count.
bool _containsExpression(Object? value) {
  return switch (value) {
    _PipelineConstant() || _PipelineProtoValue() => false,
    PipelineExpression() || Pipeline() => true,
    Uint8List() => false,
    Iterable() => value.any(_containsExpression),
    Map() => value.values.any(_containsExpression),
    _ => false,
  };
}

/// Creates a logical AND expression; same as [PipelineFunctions.and].
PipelineBooleanExpression and(Iterable<PipelineBooleanExpression> expressions) {
  return PipelineFunctions.and(expressions);
}

/// Creates a logical OR expression; same as [PipelineFunctions.or].
PipelineBooleanExpression or(Iterable<PipelineBooleanExpression> expressions) {
  return PipelineFunctions.or(expressions);
}

/// Creates a logical NOT expression; same as [PipelineFunctions.not].
PipelineBooleanExpression not(PipelineBooleanExpression expression) {
  return PipelineFunctions.not(expression);
}

/// Returns the current document as a Pipeline expression.
PipelineExpression currentDocument() => PipelineFunctions.currentDocument();

/// Returns the relevance score assigned by a preceding search stage.
PipelineExpression score() => PipelineFunctions.score();

/// Creates an expression matching documents against the query string [rquery].
PipelineBooleanExpression documentMatches(Object? rquery) {
  return PipelineFunctions.documentMatches(rquery);
}

/// Convenience wrappers for the Firestore Pipeline function catalog.
///
/// These helpers encode to the backend function names documented in the
/// Firestore Pipeline functions reference. A [String] in a field position
/// (the target of most functions, such as `'title'` in
/// `startsWith('title', 'Harry')`) is a field name, read like [field]; in a
/// value position it is a string literal. Use [field] to reference a document
/// field in a value position.
///
/// A [List] or [Map] argument may hold expressions, as in `[field('a'), 1]`:
/// it is sent as an [array] or [map] function so the backend evaluates them.
/// Wrap a collection in [constant] to send it as a literal value instead.
///
/// The fluent [PipelineExpression] method of the same name, and any top-level
/// or [Expression] helper, forward to the function here, so every form of a
/// function builds the same expression.
abstract final class PipelineFunctions {
  static PipelineExpression _expr(String name, Iterable<Object?> args) {
    return pipelineFunction(name, args.map(_valueToDefaultExpr));
  }

  static PipelineBooleanExpression _bool(String name, Iterable<Object?> args) {
    return _PipelineBooleanExpression(name, [...args.map(_valueToDefaultExpr)]);
  }

  /// Tests [target] against the values in [searchSpace].
  ///
  /// Like the Node SDK, a list of plain values is sent as a literal array
  /// value. A list holding expressions is built with [array] instead, since the
  /// backend rejects expressions nested inside a literal array value.
  static PipelineBooleanExpression _searchSpaceFunction(
    String name,
    Object? target,
    Object? searchSpace,
  ) {
    final values = switch (searchSpace) {
      Iterable() when !_containsExpression(searchSpace) => searchSpace.toList(),
      _ => _valueToDefaultExpr(searchSpace),
    };
    return _PipelineBooleanExpression(name, [
      _valueToDefaultExpr(_fieldOrExpression(target)),
      values,
    ]);
  }

  /// Creates a raw Pipeline function expression.
  ///
  /// Unlike the other helpers, [args] are sent as-is: a [List] or [Map] is a
  /// literal value, which cannot hold expressions. Build those with [array]
  /// or [map]. [options] are sent as the function's options.
  static PipelineExpression raw(
    String name,
    Iterable<Object?> args, {
    Map<String, Object?> options = const {},
  }) {
    return pipelineFunction(name, args, options: options);
  }

  /// COUNT aggregate function.
  static PipelineExpression count([Object? fieldName]) {
    return _expr('count', _optionalArg(_fieldOrExpression(fieldName)));
  }

  /// COUNT_IF aggregate function.
  static PipelineExpression countIf(Object? condition) {
    return _expr('count_if', [condition]);
  }

  /// COUNT_DISTINCT aggregate function.
  static PipelineExpression countDistinct(Object? fieldName) {
    return _expr('count_distinct', [_fieldOrExpression(fieldName)]);
  }

  /// SUM function.
  static PipelineExpression sum(Object? fieldName) {
    return _expr('sum', [_fieldOrExpression(fieldName)]);
  }

  /// AVERAGE aggregate function.
  static PipelineExpression average(Object? fieldName) {
    return _expr('average', [_fieldOrExpression(fieldName)]);
  }

  /// MINIMUM aggregate function.
  ///
  /// For the element-wise form over several operands, use [logicalMinimum].
  static PipelineExpression minimum(Object? fieldName) {
    return _expr('minimum', [_fieldOrExpression(fieldName)]);
  }

  /// MAXIMUM aggregate function.
  ///
  /// For the element-wise form over several operands, use [logicalMaximum].
  static PipelineExpression maximum(Object? fieldName) {
    return _expr('maximum', [_fieldOrExpression(fieldName)]);
  }

  /// MINIMUM function over two or more operands.
  static PipelineExpression logicalMinimum(
    Object? fieldName,
    Object? second, [
    Iterable<Object?> others = const [],
  ]) {
    return _expr('minimum', [_fieldOrExpression(fieldName), second, ...others]);
  }

  /// MAXIMUM function over two or more operands.
  static PipelineExpression logicalMaximum(
    Object? fieldName,
    Object? second, [
    Iterable<Object?> others = const [],
  ]) {
    return _expr('maximum', [_fieldOrExpression(fieldName), second, ...others]);
  }

  /// FIRST aggregate function.
  static PipelineExpression first(Object? fieldName) {
    return _expr('first', [_fieldOrExpression(fieldName)]);
  }

  /// LAST aggregate function.
  static PipelineExpression last(Object? fieldName) {
    return _expr('last', [_fieldOrExpression(fieldName)]);
  }

  /// ARRAY_AGG aggregate function.
  static PipelineExpression arrayAgg(Object? fieldName) {
    return _expr('array_agg', [_fieldOrExpression(fieldName)]);
  }

  /// ARRAY_AGG_DISTINCT aggregate function.
  static PipelineExpression arrayAggDistinct(Object? fieldName) {
    return _expr('array_agg_distinct', [_fieldOrExpression(fieldName)]);
  }

  /// ABS arithmetic function.
  static PipelineExpression abs(Object? fieldName) {
    return _expr('abs', [_fieldOrExpression(fieldName)]);
  }

  /// ADD arithmetic function.
  ///
  /// Adds [first], [second] and any [others], sent as a single `add` call.
  static PipelineExpression add(
    Object? first,
    Object? second, [
    Iterable<Object?> others = const [],
  ]) {
    return _expr('add', [_fieldOrExpression(first), second, ...others]);
  }

  /// SUBTRACT arithmetic function.
  static PipelineExpression subtract(Object? left, Object? right) {
    return _expr('subtract', [_fieldOrExpression(left), right]);
  }

  /// MULTIPLY arithmetic function.
  ///
  /// Multiplies [first], [second] and any [others], sent as a single
  /// `multiply` call.
  static PipelineExpression multiply(
    Object? first,
    Object? second, [
    Iterable<Object?> others = const [],
  ]) {
    return _expr('multiply', [_fieldOrExpression(first), second, ...others]);
  }

  /// DIVIDE arithmetic function.
  static PipelineExpression divide(Object? left, Object? right) {
    return _expr('divide', [_fieldOrExpression(left), right]);
  }

  /// MOD arithmetic function.
  static PipelineExpression mod(Object? left, Object? right) {
    return _expr('mod', [_fieldOrExpression(left), right]);
  }

  /// CEIL arithmetic function.
  static PipelineExpression ceil(Object? fieldName) {
    return _expr('ceil', [_fieldOrExpression(fieldName)]);
  }

  /// FLOOR arithmetic function.
  static PipelineExpression floor(Object? fieldName) {
    return _expr('floor', [_fieldOrExpression(fieldName)]);
  }

  /// ROUND arithmetic function.
  ///
  /// Rounds to [decimalPlaces] decimal places when given, otherwise to the
  /// nearest integer.
  static PipelineExpression round(Object? fieldName, [Object? decimalPlaces]) {
    return _expr('round', [
      _fieldOrExpression(fieldName),
      ..._optionalArg(decimalPlaces),
    ]);
  }

  /// TRUNC arithmetic function.
  ///
  /// Truncates to [decimalPlaces] decimal places when given, otherwise to an
  /// integer.
  static PipelineExpression trunc(Object? fieldName, [Object? decimalPlaces]) {
    return _expr('trunc', [
      _fieldOrExpression(fieldName),
      ..._optionalArg(decimalPlaces),
    ]);
  }

  /// POW arithmetic function.
  static PipelineExpression pow(Object? base, Object? exponent) {
    return _expr('pow', [_fieldOrExpression(base), exponent]);
  }

  /// SQRT arithmetic function.
  static PipelineExpression sqrt(Object? fieldName) {
    return _expr('sqrt', [_fieldOrExpression(fieldName)]);
  }

  /// EXP arithmetic function.
  static PipelineExpression exp(Object? fieldName) {
    return _expr('exp', [_fieldOrExpression(fieldName)]);
  }

  /// LN arithmetic function.
  static PipelineExpression ln(Object? fieldName) {
    return _expr('ln', [_fieldOrExpression(fieldName)]);
  }

  /// LOG arithmetic function.
  static PipelineExpression log(Object? fieldName, [Object? base]) {
    return _expr('log', [_fieldOrExpression(fieldName), ..._optionalArg(base)]);
  }

  /// LOG10 arithmetic function.
  static PipelineExpression log10(Object? fieldName) {
    return _expr('log10', [_fieldOrExpression(fieldName)]);
  }

  /// RAND arithmetic function.
  static PipelineExpression rand() => _expr('rand', const []);

  /// ARRAY construction function.
  ///
  /// [values] may mix literals and expressions, as in `[field('a'), 1]`.
  static PipelineExpression array(Iterable<Object?> values) {
    return _expr('array', values);
  }

  /// ARRAY_CONCAT function.
  static PipelineExpression arrayConcat(Iterable<Object?> arrays) {
    return _expr('array_concat', _fieldOrExpressionFirst(arrays));
  }

  /// ARRAY_CONTAINS function.
  static PipelineBooleanExpression arrayContains(Object? array, Object? value) {
    return _bool('array_contains', [_fieldOrExpression(array), value]);
  }

  /// ARRAY_CONTAINS_ALL function.
  ///
  /// [searchValues] is a list of values or an array expression.
  static PipelineBooleanExpression arrayContainsAll(
    Object? array,
    Object? searchValues,
  ) {
    return _searchSpaceFunction('array_contains_all', array, searchValues);
  }

  /// ARRAY_CONTAINS_ANY function.
  ///
  /// [searchValues] is a list of values or an array expression.
  static PipelineBooleanExpression arrayContainsAny(
    Object? array,
    Object? searchValues,
  ) {
    return _searchSpaceFunction('array_contains_any', array, searchValues);
  }

  /// ARRAY_FILTER function.
  static PipelineExpression arrayFilter(
    Object? array,
    String variableName,
    Object? predicate,
  ) {
    return _expr('array_filter', [
      _fieldOrExpression(array),
      variableName,
      predicate,
    ]);
  }

  /// ARRAY_GET function.
  static PipelineExpression arrayGet(Object? array, Object? index) {
    return _expr('array_get', [_fieldOrExpression(array), index]);
  }

  /// ARRAY_LENGTH function.
  static PipelineExpression arrayLength(Object? array) {
    return _expr('array_length', [_fieldOrExpression(array)]);
  }

  /// ARRAY_REVERSE function.
  static PipelineExpression arrayReverse(Object? array) {
    return _expr('array_reverse', [_fieldOrExpression(array)]);
  }

  /// ARRAY_FIRST function.
  static PipelineExpression arrayFirst(Object? array) {
    return _expr('array_first', [_fieldOrExpression(array)]);
  }

  /// ARRAY_FIRST_N function.
  static PipelineExpression arrayFirstN(Object? array, Object? n) {
    return _expr('array_first_n', [_fieldOrExpression(array), n]);
  }

  /// MAXIMUM function over the elements of [array].
  ///
  /// The backend has no `array_maximum`; this emits `maximum`, like [maximum].
  static PipelineExpression arrayMaximum(Object? array) => maximum(array);

  /// MAXIMUM_N function over the elements of [array]; same as [maximumN].
  static PipelineExpression arrayMaximumN(Object? array, Object? n) {
    return maximumN(array, n);
  }

  /// MINIMUM function over the elements of [array].
  ///
  /// The backend has no `array_minimum`; this emits `minimum`, like [minimum].
  static PipelineExpression arrayMinimum(Object? array) => minimum(array);

  /// MINIMUM_N function over the elements of [array]; same as [minimumN].
  static PipelineExpression arrayMinimumN(Object? array, Object? n) {
    return minimumN(array, n);
  }

  /// SUM function over the elements of [array].
  ///
  /// The backend has no `array_sum`; this emits `sum`, like [sum].
  static PipelineExpression arraySum(Object? array) => sum(array);

  /// COUNT function over every input, without inspecting a field.
  static PipelineAggregateFunction countAll() => _expr('count', const []);

  /// ARRAY_INDEX_OF function.
  static PipelineExpression arrayIndexOf(Object? array, Object? value) {
    return _expr('array_index_of', [_fieldOrExpression(array), value, 'first']);
  }

  /// ARRAY_INDEX_OF_ALL function.
  static PipelineExpression arrayIndexOfAll(Object? array, Object? value) {
    return _expr('array_index_of_all', [_fieldOrExpression(array), value]);
  }

  /// ARRAY_LAST function.
  static PipelineExpression arrayLast(Object? array) {
    return _expr('array_last', [_fieldOrExpression(array)]);
  }

  /// ARRAY_LAST_N function.
  static PipelineExpression arrayLastN(Object? array, Object? n) {
    return _expr('array_last_n', [_fieldOrExpression(array), n]);
  }

  /// ARRAY_LAST_INDEX_OF function.
  static PipelineExpression arrayLastIndexOf(Object? array, Object? value) {
    return _expr('array_index_of', [_fieldOrExpression(array), value, 'last']);
  }

  /// ARRAY_SLICE function.
  ///
  /// Returns [length] elements of [array] starting at index [offset]; when
  /// [length] is omitted the slice runs to the end of the array.
  static PipelineExpression arraySlice(
    Object? array,
    Object? offset, [
    Object? length,
  ]) {
    return _expr('array_slice', [
      _fieldOrExpression(array),
      offset,
      ..._optionalArg(length),
    ]);
  }

  /// ARRAY_TRANSFORM function.
  ///
  /// Evaluates [transform] for each element of [array], with the element
  /// bound to the variable [elementAlias]. To also bind the element's index,
  /// use [arrayTransformWithIndex].
  static PipelineExpression arrayTransform(
    Object? array,
    String elementAlias,
    Object? transform,
  ) {
    return _expr('array_transform', [
      _fieldOrExpression(array),
      elementAlias,
      transform,
    ]);
  }

  /// ARRAY_TRANSFORM function, binding each element's index too.
  ///
  /// Like [arrayTransform], with the element's zero-based index bound to the
  /// variable [indexAlias].
  static PipelineExpression arrayTransformWithIndex(
    Object? array,
    String elementAlias,
    String indexAlias,
    Object? transform,
  ) {
    return _expr('array_transform', [
      _fieldOrExpression(array),
      elementAlias,
      indexAlias,
      transform,
    ]);
  }

  /// MAXIMUM_N array function.
  static PipelineExpression maximumN(Object? array, Object? n) {
    return _expr('maximum_n', [_fieldOrExpression(array), n]);
  }

  /// MINIMUM_N array function.
  static PipelineExpression minimumN(Object? array, Object? n) {
    return _expr('minimum_n', [_fieldOrExpression(array), n]);
  }

  /// JOIN function: joins the elements of [array] into a string separated by
  /// [delimiter].
  static PipelineExpression join(Object? array, Object? delimiter) {
    return _expr('join', [_fieldOrExpression(array), delimiter]);
  }

  /// EQUAL comparison function.
  static PipelineBooleanExpression equal(Object? left, Object? right) {
    return _bool('equal', [_fieldOrExpression(left), right]);
  }

  /// GREATER_THAN comparison function.
  static PipelineBooleanExpression greaterThan(Object? left, Object? right) {
    return _bool('greater_than', [_fieldOrExpression(left), right]);
  }

  /// GREATER_THAN_OR_EQUAL comparison function.
  static PipelineBooleanExpression greaterThanOrEqual(
    Object? left,
    Object? right,
  ) {
    return _bool('greater_than_or_equal', [_fieldOrExpression(left), right]);
  }

  /// LESS_THAN comparison function.
  static PipelineBooleanExpression lessThan(Object? left, Object? right) {
    return _bool('less_than', [_fieldOrExpression(left), right]);
  }

  /// LESS_THAN_OR_EQUAL comparison function.
  static PipelineBooleanExpression lessThanOrEqual(
    Object? left,
    Object? right,
  ) {
    return _bool('less_than_or_equal', [_fieldOrExpression(left), right]);
  }

  /// NOT_EQUAL comparison function.
  static PipelineBooleanExpression notEqual(Object? left, Object? right) {
    return _bool('not_equal', [_fieldOrExpression(left), right]);
  }

  /// CMP comparison function.
  static PipelineExpression cmp(Object? left, Object? right) {
    return _expr('cmp', [_fieldOrExpression(left), right]);
  }

  /// EXISTS debugging function.
  static PipelineBooleanExpression exists(Object? fieldName) {
    return _bool('exists', [_fieldOrExpression(fieldName)]);
  }

  /// IS_ABSENT debugging function.
  static PipelineBooleanExpression isAbsent(Object? fieldName) {
    return _bool('is_absent', [_fieldOrExpression(fieldName)]);
  }

  /// IF_ABSENT debugging function.
  static PipelineExpression ifAbsent(Object? fieldName, Object? replacement) {
    return _expr('if_absent', [_fieldOrExpression(fieldName), replacement]);
  }

  /// IS_ERROR debugging function.
  static PipelineBooleanExpression isError(Object? value) {
    return _bool('is_error', [value]);
  }

  /// IF_ERROR debugging function.
  static PipelineExpression ifError(Object? value, Object? catchValue) {
    return _expr('if_error', [value, catchValue]);
  }

  /// COLLECTION_ID reference function.
  static PipelineExpression collectionId(Object? reference) {
    return _expr('collection_id', [_fieldOrExpression(reference)]);
  }

  /// DOCUMENT_ID reference function.
  static PipelineExpression documentId(Object? reference) {
    return _expr('document_id', [reference]);
  }

  /// PARENT reference function.
  static PipelineExpression parent(Object? reference) {
    return _expr('parent', [reference]);
  }

  /// REFERENCE_SLICE reference function.
  static PipelineExpression referenceSlice(
    Object? reference,
    Object? offset,
    Object? length,
  ) {
    return _expr('reference_slice', [
      _fieldOrExpression(reference),
      offset,
      length,
    ]);
  }

  /// AND logical function.
  static PipelineBooleanExpression and(Iterable<Object?> expressions) {
    return _bool('and', expressions);
  }

  /// OR logical function.
  static PipelineBooleanExpression or(Iterable<Object?> expressions) {
    return _bool('or', expressions);
  }

  /// XOR logical function.
  static PipelineBooleanExpression xor(Iterable<Object?> expressions) {
    return _bool('xor', expressions);
  }

  /// NOR logical function.
  static PipelineBooleanExpression nor(Iterable<Object?> expressions) {
    return _bool('nor', expressions);
  }

  /// NOT logical function.
  static PipelineBooleanExpression not(Object? expression) {
    return _bool('not', [expression]);
  }

  /// CONDITIONAL logical function.
  static PipelineExpression conditional(
    Object? condition,
    Object? trueCase,
    Object? falseCase,
  ) {
    return _expr('conditional', [condition, trueCase, falseCase]);
  }

  /// IF_NULL logical function.
  static PipelineExpression ifNull(Object? fieldName, Object? replacement) {
    return _expr('if_null', [_fieldOrExpression(fieldName), replacement]);
  }

  /// COALESCE logical function.
  ///
  /// Returns the first argument that is neither absent nor null.
  static PipelineExpression coalesce(
    Object? fieldName,
    Object? replacement, [
    Iterable<Object?> others = const [],
  ]) {
    return _expr('coalesce', [
      _fieldOrExpression(fieldName),
      replacement,
      ...others,
    ]);
  }

  /// SWITCH_ON logical function.
  static PipelineExpression switchOn(Iterable<Object?> cases) {
    return _expr('switch_on', cases);
  }

  /// EQUAL_ANY logical function.
  ///
  /// [searchSpace] is a list of values or an array expression.
  static PipelineBooleanExpression equalAny(
    Object? fieldName,
    Object? searchSpace,
  ) {
    return _searchSpaceFunction('equal_any', fieldName, searchSpace);
  }

  /// NOT_EQUAL_ANY logical function.
  ///
  /// [searchSpace] is a list of values or an array expression.
  static PipelineBooleanExpression notEqualAny(
    Object? fieldName,
    Object? searchSpace,
  ) {
    return _searchSpaceFunction('not_equal_any', fieldName, searchSpace);
  }

  /// MAP construction function.
  ///
  /// [keyValues] alternates keys and values; values may be expressions.
  static PipelineExpression map(Iterable<Object?> keyValues) {
    return _expr('map', keyValues);
  }

  /// MAP_GET function.
  static PipelineExpression mapGet(Object? map, Object? key) {
    return _expr('map_get', [_fieldOrExpression(map), key]);
  }

  /// GET_FIELD function.
  ///
  /// Reads [key] from [map], which may be any map-valued expression.
  static PipelineExpression getField(Object? map, Object? key) {
    return _expr('get_field', [_fieldOrExpression(map), key]);
  }

  /// MAP_SET function.
  static PipelineExpression mapSet(Object? map, Iterable<Object?> keyValues) {
    return _expr('map_set', [_fieldOrExpression(map), ...keyValues]);
  }

  /// MAP_REMOVE function.
  ///
  /// Removes [key] from [map]. A [String] [map] names a field; [key] is the
  /// key itself (a [String] literal) or an expression producing it. Each call
  /// removes exactly one key, so chain calls to remove several:
  /// `mapRemove(mapRemove('address', 'city'), 'zip')`.
  ///
  /// Throws an [ArgumentError] when [key] is an [Iterable].
  static PipelineExpression mapRemove(Object? map, Object? key) {
    if (key is Iterable) {
      throw ArgumentError.value(
        key,
        'key',
        'Must be a single key. Chain mapRemove calls to remove several keys.',
      );
    }
    return _expr('map_remove', [_fieldOrExpression(map), key]);
  }

  /// MAP_MERGE function.
  static PipelineExpression mapMerge(Iterable<Object?> maps) {
    return _expr('map_merge', _fieldOrExpressionFirst(maps));
  }

  /// CURRENT_DOCUMENT function.
  static PipelineExpression currentDocument() {
    return _expr('current_document', const []);
  }

  /// MAP_KEYS function.
  static PipelineExpression mapKeys(Object? map) {
    return _expr('map_keys', [_fieldOrExpression(map)]);
  }

  /// MAP_VALUES function.
  static PipelineExpression mapValues(Object? map) {
    return _expr('map_values', [_fieldOrExpression(map)]);
  }

  /// MAP_ENTRIES function.
  static PipelineExpression mapEntries(Object? map) {
    return _expr('map_entries', [_fieldOrExpression(map)]);
  }

  /// BYTE_LENGTH string function.
  static PipelineExpression byteLength(Object? fieldName) {
    return _expr('byte_length', [_fieldOrExpression(fieldName)]);
  }

  /// CHAR_LENGTH string function.
  static PipelineExpression charLength(Object? fieldName) {
    return _expr('char_length', [_fieldOrExpression(fieldName)]);
  }

  /// LENGTH function.
  ///
  /// Unlike [charLength], this works on any sized value: strings, bytes,
  /// arrays, maps and vectors.
  static PipelineExpression length(Object? fieldName) {
    return _expr('length', [_fieldOrExpression(fieldName)]);
  }

  /// REVERSE function.
  ///
  /// Unlike [stringReverse] and [arrayReverse], this works on both strings and
  /// arrays.
  static PipelineExpression reverse(Object? fieldName) {
    return _expr('reverse', [_fieldOrExpression(fieldName)]);
  }

  /// CONCAT function.
  ///
  /// Unlike [stringConcat], this also concatenates arrays.
  static PipelineExpression concat(
    Object? fieldName,
    Object? second, [
    Iterable<Object?> others = const [],
  ]) {
    return _expr('concat', [_fieldOrExpression(fieldName), second, ...others]);
  }

  /// STARTS_WITH string function.
  static PipelineBooleanExpression startsWith(
    Object? fieldName,
    Object? prefix,
  ) {
    return _bool('starts_with', [_fieldOrExpression(fieldName), prefix]);
  }

  /// ENDS_WITH string function.
  static PipelineBooleanExpression endsWith(
    Object? fieldName,
    Object? postfix,
  ) {
    return _bool('ends_with', [_fieldOrExpression(fieldName), postfix]);
  }

  /// LIKE string function.
  static PipelineBooleanExpression like(Object? fieldName, Object? pattern) {
    return _bool('like', [_fieldOrExpression(fieldName), pattern]);
  }

  /// REGEX_CONTAINS string function.
  static PipelineBooleanExpression regexContains(
    Object? fieldName,
    Object? pattern,
  ) {
    return _bool('regex_contains', [_fieldOrExpression(fieldName), pattern]);
  }

  /// REGEX_MATCH string function.
  static PipelineBooleanExpression regexMatch(
    Object? fieldName,
    Object? pattern,
  ) {
    return _bool('regex_match', [_fieldOrExpression(fieldName), pattern]);
  }

  /// REGEX_FIND string function.
  static PipelineExpression regexFind(Object? fieldName, Object? pattern) {
    return _expr('regex_find', [_fieldOrExpression(fieldName), pattern]);
  }

  /// REGEX_FIND_ALL string function.
  static PipelineExpression regexFindAll(Object? fieldName, Object? pattern) {
    return _expr('regex_find_all', [_fieldOrExpression(fieldName), pattern]);
  }

  /// STRING_CONCAT string function.
  static PipelineExpression stringConcat(Iterable<Object?> values) {
    return _expr('string_concat', _fieldOrExpressionFirst(values));
  }

  /// STRING_CONTAINS string function.
  static PipelineBooleanExpression stringContains(
    Object? fieldName,
    Object? substring,
  ) {
    return _bool('string_contains', [_fieldOrExpression(fieldName), substring]);
  }

  /// STRING_INDEX_OF string function.
  static PipelineExpression stringIndexOf(
    Object? fieldName,
    Object? substring,
  ) {
    return _expr('string_index_of', [_fieldOrExpression(fieldName), substring]);
  }

  /// TO_UPPER string function.
  static PipelineExpression toUpper(Object? fieldName) {
    return _expr('to_upper', [_fieldOrExpression(fieldName)]);
  }

  /// TO_LOWER string function.
  static PipelineExpression toLower(Object? fieldName) {
    return _expr('to_lower', [_fieldOrExpression(fieldName)]);
  }

  /// SUBSTRING string function.
  ///
  /// Returns [length] characters (or bytes, for a bytes value) of [fieldName]
  /// starting at index [position]. [length] is a count, not an end index; when
  /// omitted the substring runs to the end of the input.
  static PipelineExpression substring(
    Object? fieldName,
    Object? position, [
    Object? length,
  ]) {
    return _expr('substring', [
      _fieldOrExpression(fieldName),
      position,
      ..._optionalArg(length),
    ]);
  }

  /// STRING_REVERSE string function.
  static PipelineExpression stringReverse(Object? fieldName) {
    return _expr('string_reverse', [_fieldOrExpression(fieldName)]);
  }

  /// STRING_REPEAT string function.
  static PipelineExpression stringRepeat(Object? fieldName, Object? count) {
    return _expr('string_repeat', [_fieldOrExpression(fieldName), count]);
  }

  /// STRING_REPLACE_ALL string function.
  static PipelineExpression stringReplaceAll(
    Object? fieldName,
    Object? from,
    Object? to,
  ) {
    return _expr('string_replace_all', [
      _fieldOrExpression(fieldName),
      from,
      to,
    ]);
  }

  /// STRING_REPLACE_ONE string function.
  static PipelineExpression stringReplaceOne(
    Object? fieldName,
    Object? from,
    Object? to,
  ) {
    return _expr('string_replace_one', [
      _fieldOrExpression(fieldName),
      from,
      to,
    ]);
  }

  /// TRIM string function.
  static PipelineExpression trim(Object? fieldName, [Object? characters]) {
    return _expr('trim', [
      _fieldOrExpression(fieldName),
      ..._optionalArg(characters),
    ]);
  }

  /// LTRIM string function.
  static PipelineExpression ltrim(Object? fieldName, [Object? characters]) {
    return _expr('ltrim', [
      _fieldOrExpression(fieldName),
      ..._optionalArg(characters),
    ]);
  }

  /// RTRIM string function.
  static PipelineExpression rtrim(Object? fieldName, [Object? characters]) {
    return _expr('rtrim', [
      _fieldOrExpression(fieldName),
      ..._optionalArg(characters),
    ]);
  }

  /// SPLIT string function.
  ///
  /// Splits [fieldName] on [delimiter]. The delimiter is required, as in the
  /// Node SDK; a string [delimiter] is sent as a literal, not a field.
  static PipelineExpression split(Object? fieldName, Object? delimiter) {
    return _expr('split', [_fieldOrExpression(fieldName), delimiter]);
  }

  /// CURRENT_TIMESTAMP function.
  static PipelineExpression currentTimestamp() {
    return _expr('current_timestamp', const []);
  }

  /// TIMESTAMP_TRUNC function.
  static PipelineExpression timestampTruncate(
    Object? fieldName,
    Object? granularity, [
    Object? timezone,
  ]) {
    return _expr('timestamp_trunc', [
      _fieldOrExpression(fieldName),
      granularity,
      ..._optionalArg(timezone),
    ]);
  }

  /// UNIX_MICROS_TO_TIMESTAMP function.
  static PipelineExpression unixMicrosToTimestamp(Object? fieldName) {
    return _expr('unix_micros_to_timestamp', [_fieldOrExpression(fieldName)]);
  }

  /// UNIX_MILLIS_TO_TIMESTAMP function.
  static PipelineExpression unixMillisToTimestamp(Object? fieldName) {
    return _expr('unix_millis_to_timestamp', [_fieldOrExpression(fieldName)]);
  }

  /// UNIX_SECONDS_TO_TIMESTAMP function.
  static PipelineExpression unixSecondsToTimestamp(Object? fieldName) {
    return _expr('unix_seconds_to_timestamp', [_fieldOrExpression(fieldName)]);
  }

  /// TIMESTAMP_ADD function.
  static PipelineExpression timestampAdd(
    Object? fieldName,
    Object? unit,
    Object? amount,
  ) {
    return _expr('timestamp_add', [
      _fieldOrExpression(fieldName),
      unit,
      amount,
    ]);
  }

  /// TIMESTAMP_SUBTRACT function.
  static PipelineExpression timestampSubtract(
    Object? fieldName,
    Object? unit,
    Object? amount,
  ) {
    return _expr('timestamp_subtract', [
      _fieldOrExpression(fieldName),
      unit,
      amount,
    ]);
  }

  /// TIMESTAMP_TO_UNIX_MICROS function.
  static PipelineExpression timestampToUnixMicros(Object? fieldName) {
    return _expr('timestamp_to_unix_micros', [_fieldOrExpression(fieldName)]);
  }

  /// TIMESTAMP_TO_UNIX_MILLIS function.
  static PipelineExpression timestampToUnixMillis(Object? fieldName) {
    return _expr('timestamp_to_unix_millis', [_fieldOrExpression(fieldName)]);
  }

  /// TIMESTAMP_TO_UNIX_SECONDS function.
  static PipelineExpression timestampToUnixSeconds(Object? fieldName) {
    return _expr('timestamp_to_unix_seconds', [_fieldOrExpression(fieldName)]);
  }

  /// TIMESTAMP_DIFF function.
  static PipelineExpression timestampDiff(
    Object? end,
    Object? start,
    Object? unit,
  ) {
    return _expr('timestamp_diff', [
      _fieldOrExpression(end),
      _fieldOrExpression(start),
      unit,
    ]);
  }

  /// TIMESTAMP_EXTRACT function.
  static PipelineExpression timestampExtract(
    Object? fieldName,
    Object? part, [
    Object? timezone,
  ]) {
    return _expr('timestamp_extract', [
      _fieldOrExpression(fieldName),
      part,
      ..._optionalArg(timezone),
    ]);
  }

  /// TYPE function.
  static PipelineExpression type(Object? fieldName) {
    return _expr('type', [_fieldOrExpression(fieldName)]);
  }

  /// IS_TYPE function.
  static PipelineBooleanExpression isType(Object? fieldName, Object? type) {
    return _bool('is_type', [_fieldOrExpression(fieldName), type]);
  }

  /// COSINE_DISTANCE vector function.
  ///
  /// [right] is a [VectorValue], a list of numbers, or an expression.
  static PipelineExpression cosineDistance(Object? left, Object? right) {
    return _expr('cosine_distance', [
      _fieldOrExpression(left),
      _vectorOrExpression(right, 'right'),
    ]);
  }

  /// DOT_PRODUCT vector function.
  ///
  /// [right] is a [VectorValue], a list of numbers, or an expression.
  static PipelineExpression dotProduct(Object? left, Object? right) {
    return _expr('dot_product', [
      _fieldOrExpression(left),
      _vectorOrExpression(right, 'right'),
    ]);
  }

  /// EUCLIDEAN_DISTANCE vector function.
  ///
  /// [right] is a [VectorValue], a list of numbers, or an expression.
  static PipelineExpression euclideanDistance(Object? left, Object? right) {
    return _expr('euclidean_distance', [
      _fieldOrExpression(left),
      _vectorOrExpression(right, 'right'),
    ]);
  }

  /// VECTOR_LENGTH vector function.
  static PipelineExpression vectorLength(Object? fieldName) {
    return _expr('vector_length', [_fieldOrExpression(fieldName)]);
  }

  /// GEO_DISTANCE function.
  ///
  /// Returns the distance in metres between the geo point at [fieldName] and
  /// [location].
  static PipelineExpression geoDistance(Object? fieldName, Object? location) {
    return _expr('geo_distance', [_fieldOrExpression(fieldName), location]);
  }

  /// DOCUMENT_MATCHES search function.
  ///
  /// Matches documents against the query string [rquery].
  static PipelineBooleanExpression documentMatches(Object? rquery) {
    return _bool('document_matches', [rquery]);
  }

  /// SCORE search function.
  ///
  /// Returns the relevance score assigned by a preceding search stage.
  static PipelineExpression score() => _expr('score', const []);
}

/// Creates an ascending Pipeline ordering.
///
/// [expression] is a field name or an expression, like
/// [PipelineExpression.ascending] on that expression.
PipelineOrdering ascending(Object expression) {
  return PipelineOrdering._(
    'ascending',
    expression is String ? field(expression) : expression,
  );
}

/// Creates a descending Pipeline ordering.
///
/// [expression] is a field name or an expression, like
/// [PipelineExpression.descending] on that expression.
PipelineOrdering descending(Object expression) {
  return PipelineOrdering._(
    'descending',
    expression is String ? field(expression) : expression,
  );
}

/// The starting point for constructing Firestore Pipeline operations.
@immutable
final class PipelineSource {
  const PipelineSource._(this._firestore);

  final Firestore _firestore;

  /// Starts a Pipeline over documents in the collection at [collectionPath].
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [Pipeline.rawStage]'s `options` do.
  Pipeline collection(
    String collectionPath, {
    Map<String, Object?> rawOptions = const {},
  }) {
    _validateResourcePath('collectionPath', collectionPath);
    return collectionReference(
      _firestore.collection(collectionPath),
      rawOptions: rawOptions,
    );
  }

  /// Starts a Pipeline over every collection with [collectionId].
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [Pipeline.rawStage]'s `options` do.
  Pipeline collectionGroup(
    String collectionId, {
    Map<String, Object?> rawOptions = const {},
  }) {
    if (collectionId.contains('/')) {
      throw ArgumentError(
        'Invalid collectionId "$collectionId". Collection IDs must not contain "/".',
      );
    }
    // The backend stage is `collection_group(ancestor, collection_id)`. An
    // empty reference names the database root as the ancestor, matching the
    // Node SDK's `CollectionGroupSource`.
    return _start('collection_group', [
      _PipelineProtoValue(firestore_v1.Value(referenceValue: '')),
      collectionId,
    ], rawOptions: rawOptions);
  }

  /// Starts a Pipeline over every document in the database.
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [Pipeline.rawStage]'s `options` do.
  Pipeline database({Map<String, Object?> rawOptions = const {}}) {
    return _start('database', const [], rawOptions: rawOptions);
  }

  /// Starts a Pipeline over the provided collection reference.
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [Pipeline.rawStage]'s `options` do.
  ///
  /// Throws an [ArgumentError] when [collectionReference] targets a different
  /// database than this Pipeline.
  Pipeline collectionReference(
    CollectionReference<DocumentData> collectionReference, {
    Map<String, Object?> rawOptions = const {},
  }) {
    _validateSameDatabase(
      _firestore,
      collectionReference.firestore,
      'collectionReference',
    );
    return _start('collection', [collectionReference], rawOptions: rawOptions);
  }

  /// Starts a Pipeline over the provided documents.
  ///
  /// Each of [documents] is a [DocumentReference] or a slash-separated
  /// document path, such as `'books/book1'`, read like [Firestore.doc] reads
  /// it.
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [Pipeline.rawStage]'s `options` do.
  ///
  /// Throws an [ArgumentError] when [documents] is empty, when an entry is
  /// neither a reference nor a path, when a path does not point to a
  /// document, or when a reference targets a different database than this
  /// Pipeline.
  Pipeline documents(
    Iterable<Object> documents, {
    Map<String, Object?> rawOptions = const {},
  }) {
    final refs = [
      for (final document in documents)
        switch (document) {
          String() => _firestore.doc(document),
          DocumentReference() => document,
          _ => throw ArgumentError.value(
            document,
            'documents',
            'Expected a DocumentReference or a document path.',
          ),
        },
    ];
    if (refs.isEmpty) {
      throw ArgumentError.value(documents, 'documents', 'Must not be empty.');
    }
    for (final ref in refs) {
      _validateSameDatabase(_firestore, ref.firestore, 'documents');
    }
    // Source stages name documents by their path relative to the database,
    // like the `collection` stage does, rather than by their full resource
    // name. The full name is only correct for references in a value position.
    return _start('documents', [
      for (final ref in refs) _PipelineProtoValue(_relativeReference(ref.path)),
    ], rawOptions: rawOptions);
  }

  /// Converts [query] into an equivalent Pipeline.
  ///
  /// [query] must be a [Query] or a [VectorQuery]. Its filters, projections,
  /// orderings, cursors, limit and offset are all translated into the
  /// corresponding Pipeline stages.
  ///
  /// Throws an [ArgumentError] when [query] targets a different database than
  /// this Pipeline.
  Pipeline createFrom(Object query) {
    switch (query) {
      case VectorQuery<Object?>():
        _validateSameDatabase(_firestore, query.query.firestore, 'query');
        return query._toPipeline(_firestore);
      case Query<Object?>():
        _validateSameDatabase(_firestore, query.firestore, 'query');
        return query._toPipeline(_firestore);
      default:
        throw ArgumentError.value(
          query,
          'query',
          'Expected a Query or a VectorQuery.',
        );
    }
  }

  Pipeline _start(
    String name,
    List<Object?> args, {
    required Map<String, Object?> rawOptions,
  }) {
    return Pipeline._(
      firestore: _firestore,
      stages: [_PipelineStage(name, args, _PipelineOptions(raw: rawOptions))],
    );
  }
}

/// A Firestore Pipeline operation.
@immutable
final class Pipeline {
  const Pipeline._({
    required this.firestore,
    required List<_PipelineStage> stages,
  }) : _stages = stages;

  /// The Firestore instance used to execute this Pipeline.
  final Firestore firestore;
  final List<_PipelineStage> _stages;

  /// Adds a raw backend Pipeline stage.
  ///
  /// Use this for preview stages or options not yet wrapped by this SDK.
  ///
  /// [args] are converted like the Node SDK's `rawStage` params: each is sent
  /// as is (a [List] as a literal array value), except a [Map]. A [Map] is
  /// sent as a literal map value, which may hold expressions, but a [List] or
  /// [Map] nested in it is sent as the [PipelineFunctions.array] or
  /// [PipelineFunctions.map] function that builds it, since the backend
  /// rejects expressions nested in a literal value at that depth. Wrap a
  /// nested collection in [constant] to send it as a literal value instead.
  ///
  /// [options] are the stage's options, keyed by the names the backend
  /// expects. A key may be a dot-separated path into a map option:
  /// `{'outer.inner': 1}` sends `outer: {inner: 1}`, and is merged with any
  /// other value set inside `outer`. Keys are applied in order, so a later
  /// key overwrites an earlier one it overlaps with.
  ///
  /// Throws an [ArgumentError] when a key of [options] has an empty segment,
  /// such as `''`, `'a.'` or `'a..b'`.
  Pipeline rawStage(
    String name,
    Iterable<Object?> args, {
    Map<String, Object?> options = const {},
  }) {
    return _append(
      _PipelineStage(name, [
        for (final arg in args) _rawStageArg(arg),
      ], _PipelineOptions(raw: options, rawName: 'options')),
    );
  }

  /// Adds the stage [name], as one of this SDK's typed stage methods does.
  ///
  /// Unlike [rawStage], [args] are sent as they are. [options] are the typed
  /// options of the stage, under their backend names, and [rawOptions] the
  /// caller's raw options, overlaid on them.
  Pipeline _stage(
    String name,
    List<Object?> args, {
    Map<String, Object?> options = const {},
    required Map<String, Object?> rawOptions,
  }) {
    return _append(
      _PipelineStage(
        name,
        args,
        _PipelineOptions(known: options, raw: rawOptions),
      ),
    );
  }

  /// Filters inputs using [condition].
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [rawStage]'s `options` do.
  Pipeline where(
    PipelineBooleanExpression condition, {
    Map<String, Object?> rawOptions = const {},
  }) {
    return _stage('where', [condition], rawOptions: rawOptions);
  }

  /// Selects or computes fields from the inputs.
  ///
  /// Entries may be [String] field names (read like [field]), [PipelineField]
  /// references, [PipelineExpression] instances, or
  /// [PipelineAliasedExpression] values.
  ///
  /// The selections are sent as a map keyed by the field they land on: a
  /// [String] is keyed by the string itself, a [PipelineField] by its
  /// [PipelineField.path] and an aliased expression by its alias, as in the
  /// Node SDK.
  ///
  /// Throws an [ArgumentError] when two [selections] land on the same field
  /// name or alias.
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [rawStage]'s `options` do.
  Pipeline select(
    Iterable<Object> selections, {
    Map<String, Object?> rawOptions = const {},
  }) {
    return _stage('select', [
      _projectionMap(selections),
    ], rawOptions: rawOptions);
  }

  /// Adds or overwrites fields on the inputs.
  ///
  /// Each expression is written to the field named by its alias, replacing
  /// any existing value. Like [select], the fields are sent to the backend as
  /// a single map keyed by alias.
  ///
  /// Throws an [ArgumentError] when two [fields] share an alias.
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [rawStage]'s `options` do.
  Pipeline addFields(
    Iterable<PipelineAliasedExpression> fields, {
    Map<String, Object?> rawOptions = const {},
  }) {
    return _stage('add_fields', [
      _projectionMap(fields, argumentName: 'fields'),
    ], rawOptions: rawOptions);
  }

  /// Aggregates inputs using aliased aggregate expressions.
  ///
  /// [groups] takes the same entries as [distinct], keyed as in [select].
  ///
  /// Throws an [ArgumentError] when two [accumulators], or two [groups], land
  /// on the same field name or alias.
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [rawStage]'s `options` do.
  Pipeline aggregate(
    Iterable<PipelineAliasedExpression> accumulators, {
    Iterable<Object> groups = const [],
    Map<String, Object?> rawOptions = const {},
  }) {
    final values = accumulators.toList();
    if (values.isEmpty) {
      throw ArgumentError.value(
        accumulators,
        'accumulators',
        'Must not be empty.',
      );
    }
    return _stage('aggregate', [
      _projectionMap(values, argumentName: 'accumulators'),
      _projectionMap(groups, argumentName: 'groups'),
    ], rawOptions: rawOptions);
  }

  /// Returns unique combinations of the provided grouping expressions.
  ///
  /// Entries may be [String] field names (read like [field]), [PipelineField]
  /// references, or [PipelineAliasedExpression] values, keyed as in [select].
  ///
  /// Throws an [ArgumentError] when two [groups] land on the same field name
  /// or alias.
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [rawStage]'s `options` do.
  Pipeline distinct(
    Iterable<Object> groups, {
    Map<String, Object?> rawOptions = const {},
  }) {
    final values = groups.toList();
    if (values.isEmpty) {
      throw ArgumentError.value(groups, 'groups', 'Must not be empty.');
    }
    return _stage('distinct', [
      _projectionMap(values, argumentName: 'groups'),
    ], rawOptions: rawOptions);
  }

  /// Removes fields from the inputs.
  ///
  /// Entries may be [String] field names, read like [field], or
  /// [PipelineField] references.
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [rawStage]'s `options` do.
  Pipeline removeFields(
    Iterable<Object> fields, {
    Map<String, Object?> rawOptions = const {},
  }) {
    return _stage('remove_fields', [
      for (final value in fields)
        if (value is String) field(value) else value,
    ], rawOptions: rawOptions);
  }

  /// Sorts inputs according to [orderings].
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [rawStage]'s `options` do.
  Pipeline sort(
    Iterable<PipelineOrdering> orderings, {
    Map<String, Object?> rawOptions = const {},
  }) {
    final values = orderings.toList();
    if (values.isEmpty) {
      throw ArgumentError.value(orderings, 'orderings', 'Must not be empty.');
    }
    return _stage('sort', values, rawOptions: rawOptions);
  }

  /// Skips the first [offset] inputs.
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [rawStage]'s `options` do.
  Pipeline offset(int offset, {Map<String, Object?> rawOptions = const {}}) {
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'Must be non-negative.');
    }
    return _stage('offset', [offset], rawOptions: rawOptions);
  }

  /// Limits the number of returned inputs to [limit].
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [rawStage]'s `options` do.
  Pipeline limit(int limit, {Map<String, Object?> rawOptions = const {}}) {
    if (limit < 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be non-negative.');
    }
    return _stage('limit', [limit], rawOptions: rawOptions);
  }

  /// Emits a document for each element of the array selected by [selectable].
  ///
  /// Each emitted document has the array element assigned to the selection's
  /// alias. [selectable] may be a [String] field name, a [PipelineField], or a
  /// [PipelineAliasedExpression] created with [PipelineExpression.as] when the
  /// element should land on a different field than the source array. A
  /// [String] field name, an alias and [indexField] are all read like [field].
  ///
  /// When [indexField] is given, the element's zero-based index is assigned to
  /// that field.
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [rawStage]'s `options` do, and takes precedence over [indexField].
  Pipeline unnest(
    Object selectable, {
    String? indexField,
    Map<String, Object?> rawOptions = const {},
  }) {
    final (expression, target) = _selectableParts(selectable);
    return _stage(
      'unnest',
      [expression, target],
      options: _compactOptions({
        'index_field': indexField == null ? null : field(indexField),
      }),
      rawOptions: rawOptions,
    );
  }

  /// Replaces each input document with the map produced by [expression].
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [rawStage]'s `options` do.
  Pipeline replaceWith(
    Object expression, {
    Map<String, Object?> rawOptions = const {},
  }) {
    return _stage('replace_with', [
      _fieldOrExpression(expression),
      'full_replace',
    ], rawOptions: rawOptions);
  }

  /// Performs a union with [pipeline], including duplicates.
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [rawStage]'s `options` do.
  ///
  /// Throws an [ArgumentError] when [pipeline] targets a different database
  /// than this Pipeline.
  Pipeline union(
    Pipeline pipeline, {
    Map<String, Object?> rawOptions = const {},
  }) {
    _validateSameDatabase(firestore, pipeline.firestore, 'pipeline');
    return _stage('union', [pipeline], rawOptions: rawOptions);
  }

  /// Samples a fixed number or percentage of documents from the input.
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [rawStage]'s `options` do.
  Pipeline sample({
    int? documents,
    double? percentage,
    Map<String, Object?> rawOptions = const {},
  }) {
    if ((documents == null) == (percentage == null)) {
      throw ArgumentError(
        'Exactly one of documents or percentage must be provided.',
      );
    }
    if (documents != null && documents < 0) {
      throw ArgumentError.value(
        documents,
        'documents',
        'Must be non-negative.',
      );
    }
    if (percentage != null && (percentage < 0 || percentage > 1)) {
      throw ArgumentError.value(
        percentage,
        'percentage',
        'Must be between 0 and 1.',
      );
    }

    // The backend takes the rate and the mode that interprets it.
    final (num rate, String mode) = documents != null
        ? (documents, 'documents')
        : (percentage!, 'percent');

    return _stage('sample', [rate, mode], rawOptions: rawOptions);
  }

  /// Performs vector nearest-neighbor search.
  ///
  /// [vectorField] is a field name, read like [field], or an expression.
  /// [queryVector] is a [VectorValue], a list of numbers, or an expression.
  /// [distanceResultField] is the field name, read like [field], that each
  /// result's distance is written to.
  ///
  /// [rawOptions] sets stage options this SDK does not wrap yet, as
  /// [rawStage]'s `options` do, and takes precedence over the typed options.
  Pipeline findNearest({
    required Object vectorField,
    required Object queryVector,
    required DistanceMeasure distanceMeasure,
    int? limit,
    String? distanceResultField,
    double? distanceThreshold,
    Map<String, Object?> rawOptions = const {},
  }) {
    return _findNearest(
      vectorField: vectorField is String ? field(vectorField) : vectorField,
      queryVector: queryVector,
      distanceMeasure: distanceMeasure,
      limit: limit,
      distanceField: distanceResultField == null
          ? null
          : field(distanceResultField),
      distanceThreshold: distanceThreshold,
      rawOptions: rawOptions,
    );
  }

  /// [findNearest], with the distance field already resolved, so that
  /// [VectorQuery] conversion can pass a [FieldPath] one.
  Pipeline _findNearest({
    required Object vectorField,
    required Object queryVector,
    required DistanceMeasure distanceMeasure,
    required int? limit,
    required PipelineField? distanceField,
    required double? distanceThreshold,
    Map<String, Object?> rawOptions = const {},
  }) {
    return _stage(
      'find_nearest',
      [
        vectorField,
        _vectorOrExpression(queryVector, 'queryVector'),
        distanceMeasure.value.toLowerCase(),
      ],
      options: _compactOptions({
        'limit': limit,
        'distance_field': distanceField,
        'distance_threshold': distanceThreshold,
      }),
      rawOptions: rawOptions,
    );
  }

  /// Adds a search stage.
  ///
  /// The search API is still evolving; [options] is passed through to the
  /// backend stage as encoded Pipeline values, keyed by the names the backend
  /// expects.
  ///
  /// [rawOptions] is overlaid on [options] the way [rawStage] reads its
  /// `options`, so its keys may be dot-separated paths.
  Pipeline search(
    Map<String, Object?> options, {
    Map<String, Object?> rawOptions = const {},
  }) {
    return _stage('search', const [], options: options, rawOptions: rawOptions);
  }

  /// Executes this Pipeline and returns the results.
  ///
  /// Pipelines require a Firestore **Enterprise edition** database. Executing
  /// against a Standard edition database throws a [FirestoreException] with
  /// [FirestoreClientErrorCode.unimplemented].
  ///
  /// Pass [readTime] to read the database as it was at a past timestamp. To
  /// read inside a transaction, use [Transaction.executePipeline] instead.
  ///
  /// Pass [explain] to ask the backend for planning stats, then read
  /// [PipelineSnapshot.explainStats]. [rawOptions] sets options this SDK does
  /// not wrap yet, keyed by the names the backend expects, and takes
  /// precedence over the typed options above. As in [rawStage]'s `options`, a
  /// key may be a dot-separated path into a map option, merged with the typed
  /// options: `explain` plus `{'explain_options.output_format': 'json'}` send
  /// a single `explain_options` map holding both.
  ///
  /// Throws an [ArgumentError] when a key of [rawOptions] has an empty
  /// segment, such as `''`, `'a.'` or `'a..b'`.
  ///
  /// ```dart
  /// final snapshot = await firestore
  ///     .pipeline()
  ///     .collection('books')
  ///     .execute(
  ///       explain: const PipelineExplainOptions(
  ///         mode: PipelineExplainMode.analyze,
  ///         outputFormat: PipelineExplainOutputFormat.text,
  ///       ),
  ///     );
  ///
  /// print(snapshot.explainStats?.text);
  /// ```
  Future<PipelineSnapshot> execute({
    Timestamp? readTime,
    PipelineIndexMode? indexMode,
    PipelineExplainOptions? explain,
    Map<String, Object?> rawOptions = const {},
  }) async {
    final result = await _execute(
      readTime: readTime,
      options: _executeOptions(
        indexMode: indexMode,
        explain: explain,
        rawOptions: rawOptions,
      ),
    );
    return result.result;
  }

  /// Builds the StructuredPipeline options, with [rawOptions] winning.
  static _PipelineOptions _executeOptions({
    required PipelineIndexMode? indexMode,
    required PipelineExplainOptions? explain,
    required Map<String, Object?> rawOptions,
  }) {
    return _PipelineOptions(
      known: _compactOptions({
        'index_mode': indexMode?.value,
        'explain_options': explain?._encoded,
      }),
      raw: rawOptions,
    );
  }

  /// Executes this Pipeline, optionally as part of a transaction.
  ///
  /// Returns the newly started transaction ID alongside the snapshot when
  /// [transactionOptions] asked the backend to start one, mirroring the
  /// readers behind [Transaction.getQuery].
  Future<_TransactionResult<PipelineSnapshot>> _execute({
    String? transactionId,
    Timestamp? readTime,
    firestore_v1.TransactionOptions? transactionOptions,
    _PipelineOptions options = const _PipelineOptions.none(),
  }) {
    final results = <PipelineResult>[];
    Timestamp? executionTime;
    String? newTransaction;
    ExplainStats? explainStats;

    // A chunk can carry `executionTime`, `explainStats` or a transaction ID
    // with no results at all, so "did the stream produce anything" cannot be
    // inferred from `results` alone.
    var hasProgress = false;

    return retryOnConnectionError(
      () async {
        results.clear();
        executionTime = null;
        newTransaction = null;
        explainStats = null;
        hasProgress = false;

        final response = await firestore._firestoreClient.v1((
          api,
          projectId,
        ) async {
          final request = firestore_v1.ExecutePipelineRequest(
            database: 'projects/$projectId/databases/${firestore.databaseId}',
            structuredPipeline: firestore_v1.StructuredPipeline(
              pipeline: _toProto(),
              options: options._toProto(firestore),
            ),
            transaction: transactionId.let(base64Decode),
            newTransaction: transactionOptions,
            readTime: readTime?._toProto().timestampValue,
          );
          return api.executePipeline(request);
        });

        await for (final chunk in response) {
          hasProgress = true;

          if (chunk.transaction.isNotEmpty) {
            newTransaction = base64Encode(chunk.transaction);
          }
          if (chunk.executionTime != null) {
            executionTime = Timestamp._fromProto(chunk.executionTime!);
          }
          if (chunk.explainStats case final stats?) {
            explainStats = ExplainStats._fromProto(stats);
          }

          for (final document in chunk.results) {
            results.add(PipelineResult._fromDocument(document, firestore));
          }
        }

        return _TransactionResult(
          transaction: newTransaction,
          result: PipelineSnapshot._(
            pipeline: this,
            results: List.unmodifiable(results),
            executionTime: executionTime,
            explainStats: explainStats,
          ),
        );
      },
      hasPartialProgress: () => hasProgress,
      // Inside a transaction the retry belongs to `Transaction._runTransaction`,
      // which restarts the whole transaction rather than one read.
      allowRetry: transactionId == null && transactionOptions == null,
    );
  }

  Pipeline _append(_PipelineStage stage) {
    return Pipeline._(firestore: firestore, stages: [..._stages, stage]);
  }

  firestore_v1.Pipeline _toProto() {
    return firestore_v1.Pipeline(
      stages: [for (final stage in _stages) stage._toProto(firestore)],
    );
  }
}

/// Translates the [Query] surface onto Pipeline stages.
///
/// Mirrors the Node SDK's `Query._pipeline()` so that a Pipeline built from a
/// Query returns the same documents the Query itself would.
extension _QueryToPipeline<T> on Query<T> {
  Pipeline _toPipeline(Firestore firestore) {
    final options = _queryOptions;
    final source = PipelineSource._(firestore);

    var pipeline = options.allDescendants
        ? source.collectionGroup(options.collectionId)
        : source.collection(
            options.parentPath._append(options.collectionId).relativeName,
          );

    for (final filter in options.filters) {
      pipeline = pipeline.where(_toPipelineBooleanExpression(filter));
    }

    final projections = options.projection?.fields ?? const [];
    if (projections.isNotEmpty) {
      // The projection already holds canonical field paths. Node passes them
      // back through field(), quoting a path such as `first-name` twice.
      pipeline = pipeline.select([
        for (final projection in projections)
          PipelineField._(projection.fieldPath),
      ]);
    }

    // Inequality fields are skipped here because `_toPipelineBooleanExpression`
    // has already emitted their existence checks.
    final existsConditions = [
      for (final fieldOrder in _implicitOrderBy(ignoreInequalityFields: true))
        field(fieldOrder.fieldPath).exists(),
    ];
    pipeline = pipeline.where(
      existsConditions.length == 1
          ? existsConditions.single
          : and(existsConditions),
    );

    final orderings = [
      for (final fieldOrder in _implicitOrderBy())
        PipelineOrdering._(
          fieldOrder.direction == _Direction.ascending
              ? 'ascending'
              : 'descending',
          field(fieldOrder.fieldPath),
        ),
    ];

    if (orderings.isNotEmpty) {
      // A `limitToLast` query sorts in reverse, takes the first N documents and
      // then restores the requested order.
      final reversed = options.limitType == LimitType.last;
      pipeline = pipeline.sort(reversed ? _reversed(orderings) : orderings);

      final startAt = options.startAt;
      if (startAt != null) {
        pipeline = pipeline.where(
          _cursorCondition(startAt, orderings, before: false),
        );
      }
      final endAt = options.endAt;
      if (endAt != null) {
        pipeline = pipeline.where(
          _cursorCondition(endAt, orderings, before: true),
        );
      }

      final limit = options.limit;
      if (limit != null) pipeline = pipeline.limit(limit);

      if (reversed) pipeline = pipeline.sort(orderings);
    }

    final offset = options.offset;
    if (offset != null && offset > 0) pipeline = pipeline.offset(offset);

    return pipeline;
  }

  /// Mirrors the backend's implicit ordering rules for this query.
  List<_FieldOrder> _implicitOrderBy({bool ignoreInequalityFields = false}) {
    final fieldOrders = _queryOptions.fieldOrders.toList();
    final seen = {for (final fieldOrder in fieldOrders) fieldOrder.fieldPath};

    // The implicit ordering always follows the last explicit order by.
    final lastDirection = fieldOrders.isEmpty
        ? _Direction.ascending
        : fieldOrders.last.direction;

    if (!ignoreInequalityFields) {
      // Inequality fields that are not explicitly ordered are ordered
      // lexicographically, with the document key sorted last.
      for (final inequalityField in _inequalityFilterFields()) {
        // The document key is always appended last, below.
        if (seen.contains(inequalityField) ||
            inequalityField == FieldPath.documentId) {
          continue;
        }
        seen.add(inequalityField);
        fieldOrders.add(
          _FieldOrder(fieldPath: inequalityField, direction: lastDirection),
        );
      }
    }

    if (!seen.contains(FieldPath.documentId)) {
      fieldOrders.add(
        _FieldOrder(fieldPath: FieldPath.documentId, direction: lastDirection),
      );
    }

    return fieldOrders;
  }

  /// The inequality filter fields of this query, sorted lexicographically.
  List<FieldPath> _inequalityFilterFields() {
    final fields = <FieldPath>{
      for (final filter in _queryOptions.filters)
        for (final subFilter in filter.flattenedFilters)
          if (subFilter.isInequalityFilter) subFilter.field,
    };

    return fields.toList()
      ..sort((a, b) => a._formattedName.compareTo(b._formattedName));
  }

  PipelineBooleanExpression _toPipelineBooleanExpression(
    _FilterInternal filter,
  ) {
    switch (filter) {
      case _FieldFilterInternal():
        return _fieldFilterToPipelineBooleanExpression(filter);
      case _CompositeFilterInternal():
        final conditions = [
          for (final subFilter in filter.filters)
            _toPipelineBooleanExpression(subFilter),
        ];
        if (conditions.length == 1) return conditions.single;
        return filter.isConjunction ? and(conditions) : or(conditions);
    }
  }

  PipelineBooleanExpression _fieldFilterToPipelineBooleanExpression(
    _FieldFilterInternal filter,
  ) {
    final target = field(filter.field);
    final value = _PipelineProtoValue(
      firestore._serializer.encodeValue(filter.value) ??
          firestore_v1.Value(nullValue: protobuf_v1.NullValue.nullValue),
    );

    // `notIn` matches absent fields on Enterprise databases, so unlike every
    // other operator it must not be paired with an existence check.
    if (filter.op == WhereFilter.notIn) {
      return target.notEqualAny(_protoArrayElements(value));
    }

    final condition = switch (filter.op) {
      WhereFilter.lessThan => target.lessThan(value),
      WhereFilter.lessThanOrEqual => target.lessThanOrEqual(value),
      WhereFilter.greaterThan => target.greaterThan(value),
      WhereFilter.greaterThanOrEqual => target.greaterThanOrEqual(value),
      WhereFilter.equal => target.equal(value),
      WhereFilter.notEqual => target.notEqual(value),
      WhereFilter.arrayContains => target.arrayContains(value),
      WhereFilter.isIn => target.equalAny(_protoArrayElements(value)),
      WhereFilter.arrayContainsAny => PipelineFunctions.arrayContainsAny(
        target,
        _protoArrayElements(value),
      ),
      WhereFilter.notIn => throw StateError('Handled above.'),
    };

    return and([target.exists(), condition]);
  }

  /// Unpacks an encoded array so each element keeps its own encoded value.
  List<PipelineExpression> _protoArrayElements(_PipelineProtoValue value) {
    final values = value.value.arrayValue?.values ?? const [];
    return [for (final element in values) _PipelineProtoValue(element)];
  }
}

List<PipelineOrdering> _reversed(List<PipelineOrdering> orderings) {
  return [
    for (final ordering in orderings)
      PipelineOrdering._(
        ordering._name == 'ascending' ? 'descending' : 'ascending',
        ordering._expression,
      ),
  ];
}

/// Rewrites a Query cursor as the equivalent Pipeline filter.
///
/// Cursors compare the ordering expressions lexicographically, so each bound
/// contributes either a strict comparison or an equality plus the condition for
/// the remaining bounds.
PipelineBooleanExpression _cursorCondition(
  _QueryCursor cursor,
  List<PipelineOrdering> orderings, {
  required bool before,
}) {
  final size = cursor.values.length;
  if (size == 0 || size > orderings.length) {
    throw ArgumentError.value(
      cursor,
      'cursor',
      'Cursor values must match the orderings of the query.',
    );
  }

  PipelineBooleanExpression compare(Object? expression, Object? value) {
    return before
        ? lessThan(expression, value)
        : greaterThan(expression, value);
  }

  var expression = orderings[size - 1]._expression;
  var value = _PipelineProtoValue(cursor.values[size - 1]);

  var condition = compare(expression, value);
  // An inclusive bound also matches the cursor value itself.
  if (before != cursor.before) {
    condition = or([condition, equal(expression, value)]);
  }

  for (var i = size - 2; i >= 0; i--) {
    expression = orderings[i]._expression;
    value = _PipelineProtoValue(cursor.values[i]);
    condition = or([
      compare(expression, value),
      and([equal(expression, value), condition]),
    ]);
  }

  return condition;
}

/// Translates the [VectorQuery] surface onto Pipeline stages.
extension _VectorQueryToPipeline<T> on VectorQuery<T> {
  Pipeline _toPipeline(Firestore firestore) {
    // Both fields are a String or a FieldPath; field() reads either.
    final vectorField = field(_options.vectorField);
    final distanceResultField = _options.distanceResultField;
    return _query
        ._toPipeline(firestore)
        .where(vectorField.exists())
        ._findNearest(
          vectorField: vectorField,
          queryVector: FieldValue.vector(_rawQueryVector),
          distanceMeasure: _options.distanceMeasure,
          limit: _options.limit,
          distanceField: distanceResultField == null
              ? null
              : field(distanceResultField),
          distanceThreshold: _options.distanceThreshold,
        );
  }
}

/// A Pipeline expression wrapping an already-encoded Firestore value.
final class _PipelineProtoValue extends PipelineExpression {
  const _PipelineProtoValue(this.value);

  final firestore_v1.Value value;

  @override
  firestore_v1.Value _toValue(Firestore firestore) => value;
}

/// A Pipeline execution result.
@immutable
final class PipelineResult {
  PipelineResult._({
    required DocumentData data,
    required this.name,
    required this.ref,
    required this.createTime,
    required this.updateTime,
  }) : _data = Map.unmodifiable(data);

  factory PipelineResult._fromDocument(
    firestore_v1.Document document,
    Firestore firestore,
  ) {
    final name = document.name.isEmpty ? null : document.name;
    final ref = name == null
        ? null
        : DocumentReference<DocumentData>._(
            firestore: firestore,
            path: _QualifiedResourcePath.fromSlashSeparatedString(name),
            converter: _jsonConverter,
          );

    return PipelineResult._(
      data: {
        for (final entry in document.fields.entries)
          entry.key: _decodePipelineResultValue(entry.value, firestore),
      },
      name: name,
      ref: ref,
      createTime: document.createTime.let(Timestamp._fromProto),
      updateTime: document.updateTime.let(Timestamp._fromProto),
    );
  }

  final DocumentData _data;

  /// The document name when returned by the backend.
  ///
  /// Projection stages may omit document metadata, in which case this is `null`.
  final String? name;

  /// The document reference when returned by the backend.
  ///
  /// Null when a projection stage dropped the document metadata.
  final DocumentReference<DocumentData>? ref;

  /// The document ID, when this result refers to a document.
  String? get id => ref?.id;

  /// The time the document was created.
  final Timestamp? createTime;

  /// The time the document was last updated.
  final Timestamp? updateTime;

  /// Returns the decoded result fields.
  ///
  /// The returned map is unmodifiable. Projection stages may drop every field,
  /// in which case this is empty rather than `null`.
  DocumentData data() => _data;

  /// Returns the decoded value at [field], or `null` when absent.
  ///
  /// [field] is a [String] or a [FieldPath], validated as in
  /// [DocumentSnapshot.get]. A dot-separated string such as `'metadata.lang'`
  /// reads a nested map field; use a [FieldPath] when a segment itself
  /// contains a dot. Returns `null` when any segment is missing or traverses
  /// a non-map value.
  Object? get(Object field) {
    Object? value = _data;
    for (final segment in FieldPath.from(field).segments) {
      if (value is! Map) return null;
      value = value[segment];
    }
    return value;
  }

  /// Whether [other] refers to the same document with the same fields.
  ///
  /// Mirrors the Node SDK's `isEqual`, which compares the reference and the
  /// fields only. Read times are deliberately excluded: the same document read
  /// twice is the same result.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PipelineResult &&
        other.ref == ref &&
        const DeepCollectionEquality().equals(other._data, _data);
  }

  @override
  int get hashCode {
    return Object.hash(ref, const DeepCollectionEquality().hash(_data));
  }
}

Object? _decodePipelineResultValue(
  firestore_v1.Value value,
  Firestore firestore,
) {
  final referenceValue = value.referenceValue;
  if (referenceValue != null &&
      referenceValue.isNotEmpty &&
      !_isDocumentReferenceValue(referenceValue)) {
    return referenceValue;
  }
  return firestore._serializer.decodeValue(value);
}

final _documentReferenceRegExp = RegExp(
  r'^projects/[^/]+/databases/[^/]+(?:/documents(?:/(.*))?)?$',
);

bool _isDocumentReferenceValue(String referenceValue) {
  final value = referenceValue.startsWith('/')
      ? referenceValue.substring(1)
      : referenceValue;
  final match = _documentReferenceRegExp.firstMatch(value);
  if (match == null) {
    return false;
  }
  final path = match.group(1);
  if (path == null || path.isEmpty) {
    return false;
  }
  return path.split('/').where((segment) => segment.isNotEmpty).length.isEven;
}

/// A snapshot returned by executing a Firestore Pipeline operation.
@immutable
final class PipelineSnapshot {
  const PipelineSnapshot._({
    required this.pipeline,
    required this.results,
    required this.executionTime,
    required this.explainStats,
  });

  /// The Pipeline that produced this snapshot.
  final Pipeline pipeline;

  /// The Pipeline results returned by the backend.
  final List<PipelineResult> results;

  /// The time at which the results are valid.
  final Timestamp? executionTime;

  /// Statistics about how the backend planned and executed this Pipeline.
  ///
  /// Null unless requested via [Pipeline.execute]'s `explain` option.
  final ExplainStats? explainStats;

  /// The number of results in this snapshot.
  int get size => results.length;

  /// Whether this snapshot contains no results.
  bool get empty => results.isEmpty;
}

/// Base class for Firestore Pipeline expressions.
@immutable
sealed class PipelineExpression {
  const PipelineExpression();

  firestore_v1.Value _toValue(Firestore firestore);

  /// Assigns [alias] to this expression for projection-style stages.
  PipelineAliasedExpression as(String alias) {
    return PipelineAliasedExpression._(this, alias);
  }

  /// Treats this expression as a boolean expression.
  PipelineBooleanExpression asBoolean() => _PipelineBooleanCastExpression(this);

  /// Creates an equality expression.
  PipelineBooleanExpression equal(Object? other) {
    return PipelineFunctions.equal(this, other);
  }

  /// Creates a not-equal expression.
  PipelineBooleanExpression notEqual(Object? other) {
    return PipelineFunctions.notEqual(this, other);
  }

  /// Creates a less-than expression.
  PipelineBooleanExpression lessThan(Object? other) {
    return PipelineFunctions.lessThan(this, other);
  }

  /// Creates a less-than-or-equal expression.
  PipelineBooleanExpression lessThanOrEqual(Object? other) {
    return PipelineFunctions.lessThanOrEqual(this, other);
  }

  /// Creates a greater-than expression.
  PipelineBooleanExpression greaterThan(Object? other) {
    return PipelineFunctions.greaterThan(this, other);
  }

  /// Creates a greater-than-or-equal expression.
  PipelineBooleanExpression greaterThanOrEqual(Object? other) {
    return PipelineFunctions.greaterThanOrEqual(this, other);
  }

  /// Adds [second] and any [others] to this expression.
  PipelineExpression add(
    Object? second, [
    Iterable<Object?> others = const [],
  ]) {
    return PipelineFunctions.add(this, second, others);
  }

  /// Creates a subtraction expression.
  PipelineExpression subtract(Object? other) {
    return PipelineFunctions.subtract(this, other);
  }

  /// Multiplies this expression by [second] and any [others].
  PipelineExpression multiply(
    Object? second, [
    Iterable<Object?> others = const [],
  ]) {
    return PipelineFunctions.multiply(this, second, others);
  }

  /// Creates a division expression.
  PipelineExpression divide(Object? other) {
    return PipelineFunctions.divide(this, other);
  }

  /// Returns the absolute value of this expression.
  PipelineExpression abs() => PipelineFunctions.abs(this);

  /// Returns the modulo of this expression and [other].
  PipelineExpression mod(Object? other) => PipelineFunctions.mod(this, other);

  /// Returns the ceiling of this expression.
  PipelineExpression ceil() => PipelineFunctions.ceil(this);

  /// Returns the floor of this expression.
  PipelineExpression floor() => PipelineFunctions.floor(this);

  /// Rounds this expression to [decimalPlaces] decimal places, or to the
  /// nearest integer when [decimalPlaces] is omitted.
  ///
  /// [decimalPlaces] may be a number or an expression.
  PipelineExpression round([Object? decimalPlaces]) {
    return PipelineFunctions.round(this, decimalPlaces);
  }

  /// Truncates this expression to [decimalPlaces] decimal places, or to an
  /// integer when [decimalPlaces] is omitted.
  ///
  /// [decimalPlaces] may be a number or an expression.
  PipelineExpression trunc([Object? decimalPlaces]) {
    return PipelineFunctions.trunc(this, decimalPlaces);
  }

  /// Returns the square root of this expression.
  PipelineExpression sqrt() => PipelineFunctions.sqrt(this);

  /// Raises this expression to the power of [exponent].
  PipelineExpression pow(Object? exponent) {
    return PipelineFunctions.pow(this, exponent);
  }

  /// Returns e raised to the power of this expression.
  PipelineExpression exp() => PipelineFunctions.exp(this);

  /// Returns the natural logarithm of this expression.
  PipelineExpression ln() => PipelineFunctions.ln(this);

  /// Returns the base-10 logarithm of this expression.
  PipelineExpression log10() => PipelineFunctions.log10(this);

  /// Returns the logarithm of this expression in [base].
  PipelineExpression log([Object? base]) {
    return PipelineFunctions.log(this, base);
  }

  /// Returns the largest of this expression and [others].
  PipelineExpression logicalMaximum(
    Object? second, [
    Iterable<Object?> others = const [],
  ]) {
    return PipelineFunctions.logicalMaximum(this, second, others);
  }

  /// Returns the smallest of this expression and [others].
  PipelineExpression logicalMinimum(
    Object? second, [
    Iterable<Object?> others = const [],
  ]) {
    return PipelineFunctions.logicalMinimum(this, second, others);
  }

  /// Creates a count aggregate from this expression.
  PipelineExpression count() => PipelineFunctions.count(this);

  /// Creates a count distinct aggregate from this expression.
  PipelineExpression countDistinct() => PipelineFunctions.countDistinct(this);

  /// Creates a sum aggregate from this expression.
  PipelineExpression sum() => PipelineFunctions.sum(this);

  /// Creates an average aggregate from this expression.
  PipelineExpression average() => PipelineFunctions.average(this);

  /// Creates a minimum aggregate from this expression.
  PipelineExpression minimum() => PipelineFunctions.minimum(this);

  /// Creates a maximum aggregate from this expression.
  PipelineExpression maximum() => PipelineFunctions.maximum(this);

  /// Creates a first aggregate from this expression.
  PipelineExpression first() => PipelineFunctions.first(this);

  /// Creates a last aggregate from this expression.
  PipelineExpression last() => PipelineFunctions.last(this);

  /// Creates an array aggregation from this expression.
  PipelineExpression arrayAgg() => PipelineFunctions.arrayAgg(this);

  /// Creates a distinct array aggregation from this expression.
  PipelineExpression arrayAggDistinct() {
    return PipelineFunctions.arrayAggDistinct(this);
  }

  /// Concatenates this array expression with [secondArray].
  PipelineExpression arrayConcat(Object? secondArray) {
    return PipelineFunctions.arrayConcat([this, secondArray]);
  }

  /// Concatenates this array expression with [otherArrays].
  PipelineExpression arrayConcatMultiple(Iterable<Object?> otherArrays) {
    return PipelineFunctions.arrayConcat([this, ...otherArrays]);
  }

  /// Checks if this array contains [element].
  PipelineBooleanExpression arrayContains(Object? element) {
    return PipelineFunctions.arrayContains(this, element);
  }

  /// Checks if this array contains all [values].
  ///
  /// [values] is a list of values or an array expression.
  PipelineBooleanExpression arrayContainsAll(Object? values) {
    return PipelineFunctions.arrayContainsAll(this, values);
  }

  /// Checks if this array contains all values from [arrayExpression].
  PipelineBooleanExpression arrayContainsAllFrom(Object? arrayExpression) {
    return PipelineFunctions.arrayContainsAll(this, arrayExpression);
  }

  /// Checks if this array contains any [values].
  ///
  /// [values] is a list of values or an array expression.
  PipelineBooleanExpression arrayContainsAny(Object? values) {
    return PipelineFunctions.arrayContainsAny(this, values);
  }

  /// Filters this array expression.
  PipelineExpression arrayFilter(
    String alias,
    PipelineBooleanExpression filter,
  ) {
    return PipelineFunctions.arrayFilter(this, alias, filter);
  }

  /// Returns the first element of this array expression.
  PipelineExpression arrayFirst() => PipelineFunctions.arrayFirst(this);

  /// Returns the first [n] elements of this array expression.
  PipelineExpression arrayFirstN(Object? n) =>
      PipelineFunctions.arrayFirstN(this, n);

  /// Returns the index of the first occurrence of [element].
  PipelineExpression arrayIndexOf(Object? element) {
    return PipelineFunctions.arrayIndexOf(this, element);
  }

  /// Returns all indexes of [element].
  PipelineExpression arrayIndexOfAll(Object? element) {
    return PipelineFunctions.arrayIndexOfAll(this, element);
  }

  /// Returns the last element of this array expression.
  PipelineExpression arrayLast() => PipelineFunctions.arrayLast(this);

  /// Returns the last [n] elements of this array expression.
  PipelineExpression arrayLastN(Object? n) =>
      PipelineFunctions.arrayLastN(this, n);

  /// Returns the last index of [element].
  PipelineExpression arrayLastIndexOf(Object? element) {
    return PipelineFunctions.arrayLastIndexOf(this, element);
  }

  /// Returns the length of this array expression.
  PipelineExpression arrayLength() => PipelineFunctions.arrayLength(this);

  /// Returns the element of this array expression at [index].
  PipelineExpression arrayGet(Object? index) {
    return PipelineFunctions.arrayGet(this, index);
  }

  /// Returns the maximum element of this array expression.
  PipelineExpression arrayMaximum() => PipelineFunctions.arrayMaximum(this);

  /// Returns the largest [n] elements of this array expression.
  PipelineExpression arrayMaximumN(Object? n) =>
      PipelineFunctions.arrayMaximumN(this, n);

  /// Returns the minimum element of this array expression.
  PipelineExpression arrayMinimum() => PipelineFunctions.arrayMinimum(this);

  /// Returns the smallest [n] elements of this array expression.
  PipelineExpression arrayMinimumN(Object? n) =>
      PipelineFunctions.arrayMinimumN(this, n);

  /// Reverses this array expression.
  PipelineExpression arrayReverse() => PipelineFunctions.arrayReverse(this);

  /// Returns [length] elements of this array expression starting at index
  /// [offset]; when [length] is omitted the slice runs to the end.
  PipelineExpression arraySlice(Object? offset, [Object? length]) {
    return PipelineFunctions.arraySlice(this, offset, length);
  }

  /// Returns the sum of numeric elements in this array expression.
  PipelineExpression arraySum() => PipelineFunctions.arraySum(this);

  /// Transforms this array expression.
  PipelineExpression arrayTransform(String elementAlias, Object? transform) {
    return PipelineFunctions.arrayTransform(this, elementAlias, transform);
  }

  /// Transforms this array expression with element and index aliases.
  PipelineExpression arrayTransformWithIndex(
    String elementAlias,
    String indexAlias,
    Object? transform,
  ) {
    return PipelineFunctions.arrayTransformWithIndex(
      this,
      elementAlias,
      indexAlias,
      transform,
    );
  }

  /// Checks if this expression exists.
  PipelineBooleanExpression exists() => PipelineFunctions.exists(this);

  /// Checks if this expression is absent.
  PipelineBooleanExpression isAbsent() => PipelineFunctions.isAbsent(this);

  /// Replaces absent values with [elseExpr].
  PipelineExpression ifAbsent(Object? elseExpr) {
    return PipelineFunctions.ifAbsent(this, elseExpr);
  }

  /// Replaces null values with [elseExpr].
  PipelineExpression ifNull(Object? elseExpr) {
    return PipelineFunctions.ifNull(this, elseExpr);
  }

  /// Returns the first of this expression and [others] that is present and
  /// non-null.
  PipelineExpression coalesce(
    Object? replacement, [
    Iterable<Object?> others = const [],
  ]) {
    return PipelineFunctions.coalesce(this, replacement, others);
  }

  /// Checks if this expression equals any value in [searchSpace].
  PipelineBooleanExpression equalAny(Object? searchSpace) {
    return PipelineFunctions.equalAny(this, searchSpace);
  }

  /// Checks if this expression equals no value in [searchSpace].
  PipelineBooleanExpression notEqualAny(Object? searchSpace) {
    return PipelineFunctions.notEqualAny(this, searchSpace);
  }

  /// Checks if this expression errors.
  PipelineBooleanExpression isError() => PipelineFunctions.isError(this);

  /// Replaces errors with [catchExpr].
  PipelineExpression ifError(Object? catchExpr) {
    return PipelineFunctions.ifError(this, catchExpr);
  }

  /// Returns the collection ID from this reference expression.
  PipelineExpression collectionId() => PipelineFunctions.collectionId(this);

  /// Returns the document ID from this reference expression.
  PipelineExpression documentId() => PipelineFunctions.documentId(this);

  /// Returns the parent reference from this reference expression.
  PipelineExpression parent() => PipelineFunctions.parent(this);

  /// Returns a reference slice from this reference expression.
  PipelineExpression referenceSlice(Object? offset, Object? length) {
    return PipelineFunctions.referenceSlice(this, offset, length);
  }

  /// Gets a map value by [key].
  PipelineExpression mapGet(Object? key) => PipelineFunctions.mapGet(this, key);

  /// Gets a value by [key] from this map expression.
  PipelineExpression getField(Object? key) {
    return PipelineFunctions.getField(this, key);
  }

  /// Gets a map value by literal [key].
  PipelineExpression mapGetLiteral(String key) => mapGet(key);

  /// Sets key/value pairs on this map expression.
  PipelineExpression mapSet(
    Object? key,
    Object? value, [
    Iterable<Object?> moreKeyValues = const [],
  ]) {
    return PipelineFunctions.mapSet(this, [key, value, ...moreKeyValues]);
  }

  /// Returns this map expression's entries.
  PipelineExpression mapEntries() => PipelineFunctions.mapEntries(this);

  /// Removes [key] from this map expression.
  ///
  /// [key] is the key itself (a [String] literal) or an expression producing
  /// it. Each call removes exactly one key, so chain calls to remove several:
  /// `field('address').mapRemove('city').mapRemove('zip')`.
  ///
  /// Throws an [ArgumentError] when [key] is an [Iterable].
  PipelineExpression mapRemove(Object? key) {
    return PipelineFunctions.mapRemove(this, key);
  }

  /// Merges this map expression with [maps].
  PipelineExpression mapMerge(Iterable<Object?> maps) {
    return PipelineFunctions.mapMerge([this, ...maps]);
  }

  /// Returns this map expression's keys.
  PipelineExpression mapKeys() => PipelineFunctions.mapKeys(this);

  /// Returns this map expression's values.
  PipelineExpression mapValues() => PipelineFunctions.mapValues(this);

  /// Joins this array expression with [delimiter].
  PipelineExpression join(Object? delimiter) =>
      PipelineFunctions.join(this, delimiter);

  /// Joins this array expression with literal [delimiter].
  PipelineExpression joinLiteral(String delimiter) => join(delimiter);

  /// Returns the byte length of this string/bytes expression.
  PipelineExpression byteLength() => PipelineFunctions.byteLength(this);

  /// Returns the character length of this string expression.
  PipelineExpression charLength() => PipelineFunctions.charLength(this);

  /// Returns the length of this expression.
  ///
  /// Unlike [charLength], this works on strings, bytes, arrays, maps and
  /// vectors.
  PipelineExpression length() => PipelineFunctions.length(this);

  /// Reverses this string or array expression.
  PipelineExpression reverse() => PipelineFunctions.reverse(this);

  /// Reverses the characters of this string expression.
  PipelineExpression stringReverse() => PipelineFunctions.stringReverse(this);

  /// Concatenates this string or array expression with [others].
  PipelineExpression concat(Iterable<Object?> others) {
    final values = others.toList();
    if (values.isEmpty) {
      throw ArgumentError.value(others, 'others', 'Must not be empty.');
    }
    return PipelineFunctions.concat(this, values.first, values.skip(1));
  }

  /// Concatenates this string expression with [others].
  PipelineExpression stringConcat(Iterable<Object?> others) {
    return PipelineFunctions.stringConcat([this, ...others]);
  }

  /// Converts this string expression to lowercase.
  ///
  /// Named for Dart's `String.toLowerCase()` rather than the Node SDK's
  /// `toLower`; the backend function is still `to_lower`.
  PipelineExpression toLowerCase() => PipelineFunctions.toLower(this);

  /// Converts this string expression to uppercase.
  ///
  /// Named for Dart's `String.toUpperCase()` rather than the Node SDK's
  /// `toUpper`; the backend function is still `to_upper`.
  PipelineExpression toUpperCase() => PipelineFunctions.toUpper(this);

  /// Trims this string expression.
  PipelineExpression trim([Object? valueToTrim]) {
    return PipelineFunctions.trim(this, valueToTrim);
  }

  /// Trims leading characters from this string expression.
  PipelineExpression ltrim([Object? valueToTrim]) {
    return PipelineFunctions.ltrim(this, valueToTrim);
  }

  /// Trims trailing characters from this string expression.
  PipelineExpression rtrim([Object? valueToTrim]) {
    return PipelineFunctions.rtrim(this, valueToTrim);
  }

  /// Splits this string expression with [delimiter].
  PipelineExpression split(Object? delimiter) =>
      PipelineFunctions.split(this, delimiter);

  /// Splits this string expression with literal [delimiter].
  PipelineExpression splitLiteral(String delimiter) => split(delimiter);

  /// Returns the index of [search] in this string expression.
  PipelineExpression stringIndexOf(Object? search) {
    return PipelineFunctions.stringIndexOf(this, search);
  }

  /// Repeats this string expression [repetitions] times.
  PipelineExpression stringRepeat(Object? repetitions) {
    return PipelineFunctions.stringRepeat(this, repetitions);
  }

  /// Replaces all occurrences of [find] with [replacement].
  PipelineExpression stringReplaceAll(Object? find, Object? replacement) {
    return PipelineFunctions.stringReplaceAll(this, find, replacement);
  }

  /// Replaces all occurrences of literal [find] with [replacement].
  PipelineExpression stringReplaceAllLiteral(String find, String replacement) {
    return stringReplaceAll(find, replacement);
  }

  /// Replaces one occurrence of [find] with [replacement].
  PipelineExpression stringReplaceOne(Object? find, Object? replacement) {
    return PipelineFunctions.stringReplaceOne(this, find, replacement);
  }

  /// Replaces one occurrence of literal [find] with [replacement].
  PipelineExpression stringReplaceOneLiteral(String find, String replacement) {
    return stringReplaceOne(find, replacement);
  }

  /// Extracts [length] characters of this string (or bytes) expression,
  /// starting at index [position].
  ///
  /// Unlike [String.substring], the second argument is a length, not an end
  /// index: `substring(2, 3)` returns three characters starting at index 2.
  /// When [length] is omitted the substring runs to the end of the input.
  PipelineExpression substring(Object? position, [Object? length]) {
    return PipelineFunctions.substring(this, position, length);
  }

  /// Extracts [length] characters of this string (or bytes) expression,
  /// starting at literal index [position].
  ///
  /// See [substring]: [length] is a count, not an end index, and when omitted
  /// the substring runs to the end of the input.
  PipelineExpression substringLiteral(int position, [int? length]) {
    return substring(position, length);
  }

  /// Checks if this string expression starts with [prefix].
  PipelineBooleanExpression startsWith(Object? prefix) {
    return PipelineFunctions.startsWith(this, prefix);
  }

  /// Checks if this string expression ends with [postfix].
  PipelineBooleanExpression endsWith(Object? postfix) {
    return PipelineFunctions.endsWith(this, postfix);
  }

  /// Performs a wildcard match.
  PipelineBooleanExpression like(Object? pattern) =>
      PipelineFunctions.like(this, pattern);

  /// Performs a regex contains check.
  PipelineBooleanExpression regexContains(Object? pattern) {
    return PipelineFunctions.regexContains(this, pattern);
  }

  /// Performs a regex match check.
  PipelineBooleanExpression regexMatch(Object? pattern) {
    return PipelineFunctions.regexMatch(this, pattern);
  }

  /// Returns the first regex match of [pattern].
  PipelineExpression regexFind(Object? pattern) {
    return PipelineFunctions.regexFind(this, pattern);
  }

  /// Returns all regex matches of [pattern].
  PipelineExpression regexFindAll(Object? pattern) {
    return PipelineFunctions.regexFindAll(this, pattern);
  }

  /// Checks if this string expression contains [substring].
  PipelineBooleanExpression stringContains(Object? substring) {
    return PipelineFunctions.stringContains(this, substring);
  }

  /// Truncates this timestamp expression.
  PipelineExpression timestampTruncate(
    Object? granularity, [
    Object? timezone,
  ]) {
    return PipelineFunctions.timestampTruncate(this, granularity, timezone);
  }

  /// Adds a timestamp duration to this expression.
  PipelineExpression timestampAdd(Object? unit, Object? amount) {
    return PipelineFunctions.timestampAdd(this, unit, amount);
  }

  /// Subtracts a timestamp duration from this expression.
  PipelineExpression timestampSubtract(Object? unit, Object? amount) {
    return PipelineFunctions.timestampSubtract(this, unit, amount);
  }

  /// Converts this timestamp expression to Unix micros.
  PipelineExpression timestampToUnixMicros() {
    return PipelineFunctions.timestampToUnixMicros(this);
  }

  /// Converts this timestamp expression to Unix millis.
  PipelineExpression timestampToUnixMillis() {
    return PipelineFunctions.timestampToUnixMillis(this);
  }

  /// Converts this timestamp expression to Unix seconds.
  PipelineExpression timestampToUnixSeconds() {
    return PipelineFunctions.timestampToUnixSeconds(this);
  }

  /// Interprets this expression as Unix micros and converts it to a timestamp.
  PipelineExpression unixMicrosToTimestamp() {
    return PipelineFunctions.unixMicrosToTimestamp(this);
  }

  /// Interprets this expression as Unix millis and converts it to a timestamp.
  PipelineExpression unixMillisToTimestamp() {
    return PipelineFunctions.unixMillisToTimestamp(this);
  }

  /// Interprets this expression as Unix seconds and converts it to a timestamp.
  PipelineExpression unixSecondsToTimestamp() {
    return PipelineFunctions.unixSecondsToTimestamp(this);
  }

  /// Returns the timestamp difference between this expression and [start].
  PipelineExpression timestampDiff(Object? start, Object? unit) {
    return PipelineFunctions.timestampDiff(this, start, unit);
  }

  /// Extracts [part] from this timestamp expression.
  PipelineExpression timestampExtract(Object? part, [Object? timezone]) {
    return PipelineFunctions.timestampExtract(this, part, timezone);
  }

  /// Returns the type of this expression.
  PipelineExpression type() => PipelineFunctions.type(this);

  /// Checks the backend type of this expression.
  PipelineBooleanExpression isType(Object? valueType) {
    return PipelineFunctions.isType(this, valueType);
  }

  /// Computes cosine distance between this vector and [other].
  ///
  /// [other] is a [VectorValue], a list of numbers, or an expression.
  PipelineExpression cosineDistance(Object? other) {
    return PipelineFunctions.cosineDistance(this, other);
  }

  /// Computes dot product between this vector and [other].
  ///
  /// [other] is a [VectorValue], a list of numbers, or an expression.
  PipelineExpression dotProduct(Object? other) {
    return PipelineFunctions.dotProduct(this, other);
  }

  /// Computes Euclidean distance between this vector and [other].
  ///
  /// [other] is a [VectorValue], a list of numbers, or an expression.
  PipelineExpression euclideanDistance(Object? other) {
    return PipelineFunctions.euclideanDistance(this, other);
  }

  /// Returns this vector expression's length.
  PipelineExpression vectorLength() => PipelineFunctions.vectorLength(this);

  /// Computes the distance in metres between this geo point and [location].
  PipelineExpression geoDistance(Object? location) {
    return PipelineFunctions.geoDistance(this, location);
  }

  /// Creates an ascending ordering for this expression.
  PipelineOrdering ascending() => PipelineOrdering._('ascending', this);

  /// Creates a descending ordering for this expression.
  PipelineOrdering descending() => PipelineOrdering._('descending', this);
}

/// A Pipeline boolean expression.
@immutable
sealed class PipelineBooleanExpression extends PipelineExpression {
  const PipelineBooleanExpression();

  /// Negates this boolean expression.
  PipelineBooleanExpression not() => PipelineFunctions.not(this);

  /// Counts the inputs for which this boolean expression is true.
  PipelineAggregateFunction countIf() => PipelineFunctions.countIf(this);

  /// Evaluates to [thenExpression] when true, and [elseExpression] otherwise.
  PipelineExpression conditional(
    Object? thenExpression,
    Object? elseExpression,
  ) {
    return PipelineFunctions.conditional(this, thenExpression, elseExpression);
  }
}

/// A Pipeline field reference.
///
/// Create one with [field] or [Expression.field].
@immutable
final class PipelineField extends PipelineExpression {
  /// Wraps [path], which must already be canonical: build it with
  /// [_canonicalFieldPath] or [FieldPath._formattedName].
  const PipelineField._(this.path);

  /// The field path referenced by this expression, in the canonical form sent
  /// to the backend.
  ///
  /// Segments are joined with dots, and a segment that is not a simple
  /// identifier is quoted with backticks: `field('address.city').path` is
  /// `address.city`, `field('first-name').path` is `` `first-name` `` and
  /// `field(FieldPath(['a.b'])).path` is `` `a.b` ``. Like the Node SDK's
  /// `Field.fieldName`, it is also the name [Pipeline.select],
  /// [Pipeline.distinct] and the `groups` of [Pipeline.aggregate] key this
  /// field by.
  final String path;

  @override
  firestore_v1.Value _toValue(Firestore firestore) {
    return firestore_v1.Value(fieldReferenceValue: path);
  }
}

/// A Pipeline expression with an alias.
@immutable
final class PipelineAliasedExpression extends PipelineExpression {
  const PipelineAliasedExpression._(this.expression, this.name);

  /// The expression being aliased.
  final PipelineExpression expression;

  /// The alias name.
  final String name;

  @override
  firestore_v1.Value _toValue(Firestore firestore) {
    return firestore_v1.Value(
      functionValue: firestore_v1.Function$(
        name: 'alias',
        args: [
          expression._toValue(firestore),
          firestore_v1.Value(stringValue: name),
        ],
      ),
    );
  }
}

/// A Pipeline ordering.
@immutable
final class PipelineOrdering {
  const PipelineOrdering._(this._name, this._expression);

  final String _name;
  final Object _expression;

  /// The expression this ordering sorts by.
  ///
  /// A field name passed to [ascending] or [descending] reads back as a
  /// [PipelineField].
  PipelineExpression get expr {
    return switch (_expression) {
      final PipelineExpression expression => expression,
      final value => constant(value),
    };
  }

  /// The sort direction: `'ascending'` or `'descending'`.
  String get direction => _name;

  firestore_v1.Value _toValue(Firestore firestore) {
    return firestore_v1.Value(
      mapValue: firestore_v1.MapValue(
        fields: {
          'expression': _encodePipelineValue(_expression, firestore),
          'direction': firestore_v1.Value(stringValue: _name),
        },
      ),
    );
  }
}

final class _PipelineConstant extends PipelineExpression {
  const _PipelineConstant(this.value);

  final Object? value;

  @override
  firestore_v1.Value _toValue(Firestore firestore) {
    return _encodeLiteralValue(value, firestore);
  }
}

final class _PipelineVariable extends PipelineExpression {
  const _PipelineVariable(this.name);

  final String name;

  @override
  firestore_v1.Value _toValue(Firestore firestore) {
    return firestore_v1.Value(variableReferenceValue: name);
  }
}

final class _PipelineFunctionExpression extends PipelineExpression {
  const _PipelineFunctionExpression(this.name, this.args, this.options);

  final String name;
  final List<Object?> args;
  final Map<String, Object?> options;

  @override
  firestore_v1.Value _toValue(Firestore firestore) {
    return firestore_v1.Value(
      functionValue: firestore_v1.Function$(
        name: name,
        args: [for (final arg in args) _encodePipelineValue(arg, firestore)],
        options: _encodeOptions(options, firestore),
      ),
    );
  }
}

final class _PipelineBooleanExpression extends PipelineBooleanExpression {
  const _PipelineBooleanExpression(this.name, this.args);

  final String name;
  final List<Object?> args;

  @override
  firestore_v1.Value _toValue(Firestore firestore) {
    return firestore_v1.Value(
      functionValue: firestore_v1.Function$(
        name: name,
        args: [for (final arg in args) _encodePipelineValue(arg, firestore)],
      ),
    );
  }
}

final class _PipelineBooleanCastExpression extends PipelineBooleanExpression {
  const _PipelineBooleanCastExpression(this.expression);

  final PipelineExpression expression;

  @override
  firestore_v1.Value _toValue(Firestore firestore) {
    return expression._toValue(firestore);
  }
}

final class _PipelineStage {
  const _PipelineStage(this.name, this.args, this.options);

  final String name;
  final List<Object?> args;
  final _PipelineOptions options;

  firestore_v1.Pipeline_Stage _toProto(Firestore firestore) {
    return firestore_v1.Pipeline_Stage(
      name: name,
      args: [for (final arg in args) _encodePipelineValue(arg, firestore)],
      options: options._toProto(firestore),
    );
  }
}

/// The options of a stage or of a Pipeline execution.
///
/// Mirrors the Node SDK's `OptionsUtil.getOptionsProto`. [known] holds the
/// options this SDK types, under their backend names. [raw] holds the
/// caller's raw options, which are overlaid on [known] one key at a time, in
/// order. A [raw] key is a dot-separated path: `'explain_options.mode'` sets
/// `mode` inside the `explain_options` map and keeps the map's other entries,
/// creating the map, or replacing a value that is not a map, on the way. A
/// key without a dot replaces the whole option. Segments are not unescaped,
/// so a backtick is part of the name.
@immutable
final class _PipelineOptions {
  /// Throws an [ArgumentError], naming the parameter [rawName], when a key of
  /// [raw] has an empty segment, which the Node SDK rejects too.
  _PipelineOptions({
    this.known = const {},
    Map<String, Object?> raw = const {},
    String rawName = 'rawOptions',
  }) : raw = _validateRawOptions(raw, rawName);

  const _PipelineOptions.none() : known = const {}, raw = const {};

  final Map<String, Object?> known;
  final Map<String, Object?> raw;

  static Map<String, Object?> _validateRawOptions(
    Map<String, Object?> raw,
    String name,
  ) {
    for (final key in raw.keys) {
      if (key.split('.').any((segment) => segment.isEmpty)) {
        throw ArgumentError.value(
          key,
          name,
          'Option keys must be dot-separated paths without empty segments.',
        );
      }
    }
    return raw;
  }

  Map<String, firestore_v1.Value> _toProto(Firestore firestore) {
    final result = _encodeOptions(known, firestore);
    for (final MapEntry(:key, :value) in raw.entries) {
      _setPath(result, key.split('.'), _encodePipelineValue(value, firestore));
    }
    return result;
  }

  /// Sets [value] at [path] inside [fields], descending into map values.
  static void _setPath(
    Map<String, firestore_v1.Value> fields,
    List<String> path,
    firestore_v1.Value value,
  ) {
    final [segment, ...rest] = path;
    if (rest.isEmpty) {
      fields[segment] = value;
      return;
    }
    final nested = {...?fields[segment]?.mapValue?.fields};
    _setPath(nested, rest, value);
    fields[segment] = firestore_v1.Value(
      mapValue: firestore_v1.MapValue(fields: nested),
    );
  }
}

Map<String, firestore_v1.Value> _encodeOptions(
  Map<String, Object?> options,
  Firestore firestore,
) {
  return {
    for (final entry in options.entries)
      entry.key: _encodePipelineValue(entry.value, firestore),
  };
}

firestore_v1.Value _encodePipelineValue(Object? value, Firestore firestore) {
  switch (value) {
    case PipelineOrdering():
      return value._toValue(firestore);
    case PipelineExpression():
      return value._toValue(firestore);
    case Pipeline():
      return firestore_v1.Value(pipelineValue: value._toProto());
    case PipelineValueType():
      return firestore_v1.Value(stringValue: value.value);
    case Uint8List():
      return _encodeLiteralValue(value, firestore);
    case Iterable():
      return firestore_v1.Value(
        arrayValue: firestore_v1.ArrayValue(
          values: [
            for (final item in value) _encodePipelineValue(item, firestore),
          ],
        ),
      );
    case Map():
      return firestore_v1.Value(
        mapValue: firestore_v1.MapValue(
          fields: {
            for (final entry in value.entries)
              entry.key.toString(): _encodePipelineValue(
                entry.value,
                firestore,
              ),
          },
        ),
      );
    case String():
      return firestore_v1.Value(stringValue: value);
    case DocumentReference():
      return firestore_v1.Value(referenceValue: value._formattedName);
    case CollectionReference():
      return _relativeReference(value.path);
    default:
      return _encodeLiteralValue(value, firestore);
  }
}

firestore_v1.Value _encodeLiteralValue(Object? value, Firestore firestore) {
  final encoded = firestore._serializer.encodeValue(value);
  if (encoded == null) {
    throw ArgumentError.value(value, 'value', 'Unsupported Pipeline value.');
  }
  return encoded;
}

/// Names a resource by its path relative to the database, as source stages do.
///
/// Mirrors the Node SDK, where `CollectionSource` and `DocumentsSource` both
/// encode a leading-slash path rather than a full resource name.
firestore_v1.Value _relativeReference(String path) {
  return firestore_v1.Value(
    referenceValue: path.startsWith('/') ? path : '/$path',
  );
}

/// Throws when [other] targets a different database than [target].
///
/// Pipeline stages that take a reference, query, or nested Pipeline can only
/// combine sources from a single database. Two instances can share a
/// [Firestore.databaseId] (`(default)` especially) while belonging to
/// different projects, so the project is compared too.
///
/// Projects are only compared when both are already known:
/// [Firestore.projectId] throws until the ID is discovered, and these are pure
/// builder methods that must keep working on an instance whose ID only
/// resolves on its first request.
void _validateSameDatabase(
  Firestore target,
  Firestore other,
  String name, {
  String targetDescription = 'Pipeline',
}) {
  final targetProject = target._knownProjectId;
  final otherProject = other._knownProjectId;
  final sameProject =
      targetProject == null ||
      otherProject == null ||
      targetProject == otherProject;

  if (sameProject && other.databaseId == target.databaseId) return;

  throw ArgumentError.value(
    _databaseLabel(otherProject, other.databaseId),
    name,
    'The database of this $name does not match the target database '
    '(${_databaseLabel(targetProject, target.databaseId)}) of this '
    '$targetDescription.',
  );
}

/// Names a database for an error message, omitting the project when unknown.
String _databaseLabel(String? projectId, String databaseId) {
  return projectId == null
      ? '"$databaseId"'
      : '"projects/$projectId/databases/$databaseId"';
}

List<Object?> _optionalArg(Object? value) {
  return value == null ? const [] : [value];
}

Map<String, Object?> _compactOptions(Map<String, Object?> options) {
  return Map.fromEntries(options.entries.where((entry) => entry.value != null));
}

/// Keys each selection's expression by the field name or alias it lands on.
///
/// Throws an [ArgumentError] on a repeated key instead of silently keeping the
/// last entry. A [String] or [PipelineField] lands on its own path, so it
/// collides with an alias of the same name, matching the Node SDK.
///
/// Like the Node SDK's `selectablesToObject`, a [String] is keyed by the
/// string itself and a [PipelineField] by its canonical [PipelineField.path]:
/// `select(['first-name', field('last name')])` keys `first-name` and
/// `` `last name` ``, both referencing their backtick-quoted path.
Map<String, Object?> _projectionMap(
  Iterable<Object> selections, {
  String argumentName = 'selections',
}) {
  final result = <String, Object?>{};
  for (final selection in selections) {
    final MapEntry(:key, :value) = _projectionEntry(selection);
    if (result.containsKey(key)) {
      throw ArgumentError("Duplicate alias or field '$key'.", argumentName);
    }
    result[key] = value;
  }
  return result;
}

/// Splits a selectable into the expression it computes and the field it lands
/// on.
///
/// A [String] or [PipelineField] lands on its own path, matching the Node SDK
/// where `Field._alias` is the field name. An alias is a field path, as in
/// Node's `field(alias)`.
///
/// Node rebuilds the field from `Field._alias`, its already-quoted name, so it
/// quotes a field such as `last name` twice. The field is reused as is here.
(Object expression, PipelineField target) _selectableParts(Object selectable) {
  return switch (selectable) {
    String() => (field(selectable), field(selectable)),
    PipelineField() => (selectable, selectable),
    PipelineAliasedExpression() => (
      selectable.expression,
      field(selectable.name),
    ),
    _ => throw ArgumentError.value(
      selectable,
      'selectable',
      'Expected a String, PipelineField, or PipelineAliasedExpression. '
          'Computed expressions must be aliased with as().',
    ),
  };
}

MapEntry<String, Object?> _projectionEntry(Object selection) {
  return switch (selection) {
    String() => MapEntry(selection, field(selection)),
    PipelineField() => MapEntry(selection.path, selection),
    PipelineAliasedExpression() => MapEntry(
      selection.name,
      selection.expression,
    ),
    PipelineExpression() => throw ArgumentError.value(
      selection,
      'selections',
      'Computed Pipeline expressions must be aliased before select().',
    ),
    _ => throw ArgumentError.value(
      selection,
      'selections',
      'Expected a String, PipelineField, or PipelineAliasedExpression.',
    ),
  };
}
