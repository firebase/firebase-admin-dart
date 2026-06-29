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
PipelineField field(String fieldPath) => PipelineField._(fieldPath);

/// Creates a constant expression for Firestore Pipeline operations.
PipelineExpression constant(Object? value) => _PipelineConstant(value);

/// Creates a variable reference expression for Firestore Pipeline operations.
PipelineExpression variable(String name) => _PipelineVariable(name);

/// FlutterFire-style entry points for building Pipeline expressions.
abstract final class Expression {
  /// Creates a field reference expression.
  static PipelineField field(String fieldPath) => PipelineField._(fieldPath);

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
  static PipelineExpression raw(
    String name,
    Iterable<Object?> args, {
    Map<String, Object?> options = const {},
  }) {
    return pipelineFunction(name, args, options: options);
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
enum PipelineValueType {
  /// Null values.
  nullValue('null'),

  /// Boolean values.
  boolean('boolean'),

  /// Any numeric value.
  number('number'),

  /// Integer numeric values.
  int64('int64'),

  /// Double numeric values.
  double('double'),

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
  vector('vector');

  const PipelineValueType(this.value);

  /// The backend type name.
  final String value;
}

/// Creates a raw Pipeline function expression.
PipelineExpression pipelineFunction(
  String name,
  Iterable<Object?> args, {
  Map<String, Object?> options = const {},
}) {
  return _PipelineFunctionExpression(name, args.toList(), options);
}

/// Creates an equality expression.
PipelineBooleanExpression equal(Object? left, Object? right) {
  return _comparison('equal', left, right);
}

/// Creates a not-equal expression.
PipelineBooleanExpression notEqual(Object? left, Object? right) {
  return _comparison('not_equal', left, right);
}

/// Creates a less-than expression.
PipelineBooleanExpression lessThan(Object? left, Object? right) {
  return _comparison('less_than', left, right);
}

/// Creates a less-than-or-equal expression.
PipelineBooleanExpression lessThanOrEqual(Object? left, Object? right) {
  return _comparison('less_than_or_equal', left, right);
}

/// Creates a greater-than expression.
PipelineBooleanExpression greaterThan(Object? left, Object? right) {
  return _comparison('greater_than', left, right);
}

/// Creates a greater-than-or-equal expression.
PipelineBooleanExpression greaterThanOrEqual(Object? left, Object? right) {
  return _comparison('greater_than_or_equal', left, right);
}

PipelineBooleanExpression _comparison(
  String name,
  Object? left,
  Object? right,
) {
  return _PipelineBooleanExpression(name, [
    if (left is String) field(left) else left,
    right,
  ]);
}

/// Creates a logical AND expression.
PipelineBooleanExpression and(Iterable<PipelineBooleanExpression> expressions) {
  return _PipelineBooleanExpression('and', expressions.toList());
}

/// Creates a logical OR expression.
PipelineBooleanExpression or(Iterable<PipelineBooleanExpression> expressions) {
  return _PipelineBooleanExpression('or', expressions.toList());
}

/// Creates a logical NOT expression.
PipelineBooleanExpression not(PipelineBooleanExpression expression) {
  return _PipelineBooleanExpression('not', [expression]);
}

/// Returns the current document as a Pipeline expression.
PipelineExpression currentDocument() => PipelineFunctions.currentDocument();

/// Convenience wrappers for the Firestore Pipeline function catalog.
///
/// These helpers encode to the backend function names documented in the
/// Firestore Pipeline functions reference. String arguments are encoded as
/// string literals; use [field] when you want to reference a document field.
abstract final class PipelineFunctions {
  static PipelineExpression _expr(String name, Iterable<Object?> args) {
    return pipelineFunction(name, args);
  }

  static PipelineBooleanExpression _bool(String name, Iterable<Object?> args) {
    return _PipelineBooleanExpression(name, args.toList());
  }

  /// Creates a raw Pipeline function expression.
  static PipelineExpression raw(String name, Iterable<Object?> args) {
    return _expr(name, args);
  }

  /// COUNT aggregate function.
  static PipelineExpression count([Object? expression]) {
    return _expr('count', _optionalArg(expression));
  }

  /// COUNT_IF aggregate function.
  static PipelineExpression countIf(Object? expression) {
    return _expr('count_if', [expression]);
  }

  /// COUNT_DISTINCT aggregate function.
  static PipelineExpression countDistinct(Object? expression) {
    return _expr('count_distinct', [expression]);
  }

  /// SUM function.
  static PipelineExpression sum(Object? expression) {
    return _expr('sum', [expression]);
  }

  /// AVERAGE aggregate function.
  static PipelineExpression average(Object? expression) {
    return _expr('average', [expression]);
  }

  /// MINIMUM function.
  static PipelineExpression minimum(Object? first, [Object? second]) {
    return _expr('minimum', [first, ..._optionalArg(second)]);
  }

  /// MAXIMUM function.
  static PipelineExpression maximum(Object? first, [Object? second]) {
    return _expr('maximum', [first, ..._optionalArg(second)]);
  }

  /// FIRST aggregate function.
  static PipelineExpression first(Object? expression) {
    return _expr('first', [expression]);
  }

  /// LAST aggregate function.
  static PipelineExpression last(Object? expression) {
    return _expr('last', [expression]);
  }

  /// ARRAY_AGG aggregate function.
  static PipelineExpression arrayAgg(Object? expression) {
    return _expr('array_agg', [expression]);
  }

  /// ARRAY_AGG_DISTINCT aggregate function.
  static PipelineExpression arrayAggDistinct(Object? expression) {
    return _expr('array_agg_distinct', [expression]);
  }

  /// ABS arithmetic function.
  static PipelineExpression abs(Object? value) => _expr('abs', [value]);

  /// ADD arithmetic function.
  static PipelineExpression add(Object? left, Object? right) {
    return _expr('add', [left, right]);
  }

  /// SUBTRACT arithmetic function.
  static PipelineExpression subtract(Object? left, Object? right) {
    return _expr('subtract', [left, right]);
  }

  /// MULTIPLY arithmetic function.
  static PipelineExpression multiply(Object? left, Object? right) {
    return _expr('multiply', [left, right]);
  }

  /// DIVIDE arithmetic function.
  static PipelineExpression divide(Object? left, Object? right) {
    return _expr('divide', [left, right]);
  }

  /// MOD arithmetic function.
  static PipelineExpression mod(Object? left, Object? right) {
    return _expr('mod', [left, right]);
  }

  /// CEIL arithmetic function.
  static PipelineExpression ceil(Object? value) => _expr('ceil', [value]);

  /// FLOOR arithmetic function.
  static PipelineExpression floor(Object? value) => _expr('floor', [value]);

  /// ROUND arithmetic function.
  static PipelineExpression round(Object? value) => _expr('round', [value]);

  /// TRUNC arithmetic function.
  static PipelineExpression trunc(Object? value) => _expr('trunc', [value]);

  /// POW arithmetic function.
  static PipelineExpression pow(Object? base, Object? exponent) {
    return _expr('pow', [base, exponent]);
  }

  /// SQRT arithmetic function.
  static PipelineExpression sqrt(Object? value) => _expr('sqrt', [value]);

  /// EXP arithmetic function.
  static PipelineExpression exp(Object? exponent) => _expr('exp', [exponent]);

  /// LN arithmetic function.
  static PipelineExpression ln(Object? value) => _expr('ln', [value]);

  /// LOG arithmetic function.
  static PipelineExpression log(Object? number, [Object? base]) {
    return _expr('log', [number, ..._optionalArg(base)]);
  }

  /// LOG10 arithmetic function.
  static PipelineExpression log10(Object? value) => _expr('log10', [value]);

  /// RAND arithmetic function.
  static PipelineExpression rand() => _expr('rand', const []);

  /// ARRAY construction function.
  static PipelineExpression array(Iterable<Object?> values) {
    return _expr('array', values);
  }

  /// ARRAY_CONCAT function.
  static PipelineExpression arrayConcat(Iterable<Object?> arrays) {
    return _expr('array_concat', arrays);
  }

  /// ARRAY_CONTAINS function.
  static PipelineBooleanExpression arrayContains(Object? array, Object? value) {
    return _bool('array_contains', [array, value]);
  }

  /// ARRAY_CONTAINS_ALL function.
  static PipelineBooleanExpression arrayContainsAll(
    Object? array,
    Object? searchValues,
  ) {
    return _bool('array_contains_all', [array, searchValues]);
  }

  /// ARRAY_CONTAINS_ANY function.
  static PipelineBooleanExpression arrayContainsAny(
    Object? array,
    Object? searchValues,
  ) {
    return _bool('array_contains_any', [array, searchValues]);
  }

  /// ARRAY_FILTER function.
  static PipelineExpression arrayFilter(
    Object? array,
    String variableName,
    Object? predicate,
  ) {
    return _expr('array_filter', [array, variableName, predicate]);
  }

  /// ARRAY_GET function.
  static PipelineExpression arrayGet(Object? array, Object? index) {
    return _expr('array_get', [array, index]);
  }

  /// ARRAY_LENGTH function.
  static PipelineExpression arrayLength(Object? array) {
    return _expr('array_length', [array]);
  }

  /// ARRAY_REVERSE function.
  static PipelineExpression arrayReverse(Object? array) {
    return _expr('array_reverse', [array]);
  }

  /// ARRAY_FIRST function.
  static PipelineExpression arrayFirst(Object? array) {
    return _expr('array_first', [array]);
  }

  /// ARRAY_FIRST_N function.
  static PipelineExpression arrayFirstN(Object? array, Object? n) {
    return _expr('array_first_n', [array, n]);
  }

  /// ARRAY_INDEX_OF function.
  static PipelineExpression arrayIndexOf(Object? array, Object? value) {
    return _expr('array_index_of', [array, value, 'first']);
  }

  /// ARRAY_INDEX_OF_ALL function.
  static PipelineExpression arrayIndexOfAll(Object? array, Object? value) {
    return _expr('array_index_of_all', [array, value]);
  }

  /// ARRAY_LAST function.
  static PipelineExpression arrayLast(Object? array) {
    return _expr('array_last', [array]);
  }

  /// ARRAY_LAST_N function.
  static PipelineExpression arrayLastN(Object? array, Object? n) {
    return _expr('array_last_n', [array, n]);
  }

  /// ARRAY_LAST_INDEX_OF function.
  static PipelineExpression arrayLastIndexOf(Object? array, Object? value) {
    return _expr('array_index_of', [array, value, 'last']);
  }

  /// ARRAY_SLICE function.
  static PipelineExpression arraySlice(
    Object? array,
    Object? offset,
    Object? length,
  ) {
    return _expr('array_slice', [array, offset, length]);
  }

  /// ARRAY_TRANSFORM function.
  static PipelineExpression arrayTransform(
    Object? array,
    String variableName,
    Object? expression, [
    String? indexVariableName,
  ]) {
    return indexVariableName == null
        ? _expr('array_transform', [array, variableName, expression])
        : _expr('array_transform', [
            array,
            variableName,
            indexVariableName,
            expression,
          ]);
  }

  /// MAXIMUM_N array function.
  static PipelineExpression maximumN(Object? array, Object? n) {
    return _expr('maximum_n', [array, n]);
  }

  /// MINIMUM_N array function.
  static PipelineExpression minimumN(Object? array, Object? n) {
    return _expr('minimum_n', [array, n]);
  }

  /// JOIN function.
  static PipelineExpression join(Object? array, [Object? separator]) {
    return _expr('join', [array, ..._optionalArg(separator)]);
  }

  /// EQUAL comparison function.
  static PipelineBooleanExpression equal(Object? left, Object? right) {
    return _bool('equal', [left, right]);
  }

  /// GREATER_THAN comparison function.
  static PipelineBooleanExpression greaterThan(Object? left, Object? right) {
    return _bool('greater_than', [left, right]);
  }

  /// GREATER_THAN_OR_EQUAL comparison function.
  static PipelineBooleanExpression greaterThanOrEqual(
    Object? left,
    Object? right,
  ) {
    return _bool('greater_than_or_equal', [left, right]);
  }

  /// LESS_THAN comparison function.
  static PipelineBooleanExpression lessThan(Object? left, Object? right) {
    return _bool('less_than', [left, right]);
  }

  /// LESS_THAN_OR_EQUAL comparison function.
  static PipelineBooleanExpression lessThanOrEqual(
    Object? left,
    Object? right,
  ) {
    return _bool('less_than_or_equal', [left, right]);
  }

  /// NOT_EQUAL comparison function.
  static PipelineBooleanExpression notEqual(Object? left, Object? right) {
    return _bool('not_equal', [left, right]);
  }

  /// CMP comparison function.
  static PipelineExpression cmp(Object? left, Object? right) {
    return _expr('cmp', [left, right]);
  }

  /// EXISTS debugging function.
  static PipelineBooleanExpression exists(Object? value) {
    return _bool('exists', [value]);
  }

  /// IS_ABSENT debugging function.
  static PipelineBooleanExpression isAbsent(Object? value) {
    return _bool('is_absent', [value]);
  }

  /// IF_ABSENT debugging function.
  static PipelineExpression ifAbsent(Object? value, Object? replacement) {
    return _expr('if_absent', [value, replacement]);
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
    return _expr('collection_id', [reference]);
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
    return _expr('reference_slice', [reference, offset, length]);
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
  static PipelineExpression ifNull(Object? expression, Object? replacement) {
    return _expr('if_null', [expression, replacement]);
  }

  /// SWITCH_ON logical function.
  static PipelineExpression switchOn(Iterable<Object?> cases) {
    return _expr('switch_on', cases);
  }

  /// EQUAL_ANY logical function.
  static PipelineBooleanExpression equalAny(
    Object? value,
    Object? searchSpace,
  ) {
    return _bool('equal_any', [value, searchSpace]);
  }

  /// NOT_EQUAL_ANY logical function.
  static PipelineBooleanExpression notEqualAny(
    Object? value,
    Object? searchSpace,
  ) {
    return _bool('not_equal_any', [value, searchSpace]);
  }

  /// MAP construction function.
  static PipelineExpression map(Iterable<Object?> keyValues) {
    return _expr('map', keyValues);
  }

  /// MAP_GET function.
  static PipelineExpression mapGet(Object? map, Object? key) {
    return _expr('map_get', [map, key]);
  }

  /// MAP_SET function.
  static PipelineExpression mapSet(Object? map, Iterable<Object?> keyValues) {
    return _expr('map_set', [map, ...keyValues]);
  }

  /// MAP_REMOVE function.
  static PipelineExpression mapRemove(Object? map, Iterable<Object?> keys) {
    return _expr('map_remove', [map, ...keys]);
  }

  /// MAP_MERGE function.
  static PipelineExpression mapMerge(Iterable<Object?> maps) {
    return _expr('map_merge', maps);
  }

  /// CURRENT_DOCUMENT function.
  static PipelineExpression currentDocument() {
    return _expr('current_document', const []);
  }

  /// MAP_KEYS function.
  static PipelineExpression mapKeys(Object? map) => _expr('map_keys', [map]);

  /// MAP_VALUES function.
  static PipelineExpression mapValues(Object? map) {
    return _expr('map_values', [map]);
  }

  /// MAP_ENTRIES function.
  static PipelineExpression mapEntries(Object? map) {
    return _expr('map_entries', [map]);
  }

  /// BYTE_LENGTH string function.
  static PipelineExpression byteLength(Object? value) {
    return _expr('byte_length', [value]);
  }

  /// CHAR_LENGTH string function.
  static PipelineExpression charLength(Object? value) {
    return _expr('char_length', [value]);
  }

  /// STARTS_WITH string function.
  static PipelineBooleanExpression startsWith(Object? value, Object? prefix) {
    return _bool('starts_with', [value, prefix]);
  }

  /// ENDS_WITH string function.
  static PipelineBooleanExpression endsWith(Object? value, Object? postfix) {
    return _bool('ends_with', [value, postfix]);
  }

  /// LIKE string function.
  static PipelineBooleanExpression like(Object? value, Object? pattern) {
    return _bool('like', [value, pattern]);
  }

  /// REGEX_CONTAINS string function.
  static PipelineBooleanExpression regexContains(
    Object? value,
    Object? pattern,
  ) {
    return _bool('regex_contains', [value, pattern]);
  }

  /// REGEX_MATCH string function.
  static PipelineBooleanExpression regexMatch(Object? value, Object? pattern) {
    return _bool('regex_match', [value, pattern]);
  }

  /// REGEX_FIND string function.
  static PipelineExpression regexFind(Object? value, Object? pattern) {
    return _expr('regex_find', [value, pattern]);
  }

  /// REGEX_FIND_ALL string function.
  static PipelineExpression regexFindAll(Object? value, Object? pattern) {
    return _expr('regex_find_all', [value, pattern]);
  }

  /// STRING_CONCAT string function.
  static PipelineExpression stringConcat(Iterable<Object?> values) {
    return _expr('string_concat', values);
  }

  /// STRING_CONTAINS string function.
  static PipelineBooleanExpression stringContains(
    Object? value,
    Object? substring,
  ) {
    return _bool('string_contains', [value, substring]);
  }

  /// STRING_INDEX_OF string function.
  static PipelineExpression stringIndexOf(Object? value, Object? substring) {
    return _expr('string_index_of', [value, substring]);
  }

  /// TO_UPPER string function.
  static PipelineExpression toUpper(Object? value) {
    return _expr('to_upper', [value]);
  }

  /// TO_LOWER string function.
  static PipelineExpression toLower(Object? value) {
    return _expr('to_lower', [value]);
  }

  /// SUBSTRING string function.
  static PipelineExpression substring(
    Object? value,
    Object? offset, [
    Object? length,
  ]) {
    return _expr('substring', [value, offset, ..._optionalArg(length)]);
  }

  /// STRING_REVERSE string function.
  static PipelineExpression stringReverse(Object? value) {
    return _expr('string_reverse', [value]);
  }

  /// STRING_REPEAT string function.
  static PipelineExpression stringRepeat(Object? value, Object? count) {
    return _expr('string_repeat', [value, count]);
  }

  /// STRING_REPLACE_ALL string function.
  static PipelineExpression stringReplaceAll(
    Object? value,
    Object? from,
    Object? to,
  ) {
    return _expr('string_replace_all', [value, from, to]);
  }

  /// STRING_REPLACE_ONE string function.
  static PipelineExpression stringReplaceOne(
    Object? value,
    Object? from,
    Object? to,
  ) {
    return _expr('string_replace_one', [value, from, to]);
  }

  /// TRIM string function.
  static PipelineExpression trim(Object? value, [Object? characters]) {
    return _expr('trim', [value, ..._optionalArg(characters)]);
  }

  /// LTRIM string function.
  static PipelineExpression ltrim(Object? value, [Object? characters]) {
    return _expr('ltrim', [value, ..._optionalArg(characters)]);
  }

  /// RTRIM string function.
  static PipelineExpression rtrim(Object? value, [Object? characters]) {
    return _expr('rtrim', [value, ..._optionalArg(characters)]);
  }

  /// SPLIT string function.
  static PipelineExpression split(Object? input, [Object? delimiter]) {
    return _expr('split', [input, ..._optionalArg(delimiter)]);
  }

  /// CURRENT_TIMESTAMP function.
  static PipelineExpression currentTimestamp() {
    return _expr('current_timestamp', const []);
  }

  /// TIMESTAMP_TRUNC function.
  static PipelineExpression timestampTrunc(
    Object? timestamp,
    Object? granularity, [
    Object? timezone,
  ]) {
    return _expr('timestamp_trunc', [
      timestamp,
      granularity,
      ..._optionalArg(timezone),
    ]);
  }

  /// UNIX_MICROS_TO_TIMESTAMP function.
  static PipelineExpression unixMicrosToTimestamp(Object? input) {
    return _expr('unix_micros_to_timestamp', [input]);
  }

  /// UNIX_MILLIS_TO_TIMESTAMP function.
  static PipelineExpression unixMillisToTimestamp(Object? input) {
    return _expr('unix_millis_to_timestamp', [input]);
  }

  /// UNIX_SECONDS_TO_TIMESTAMP function.
  static PipelineExpression unixSecondsToTimestamp(Object? input) {
    return _expr('unix_seconds_to_timestamp', [input]);
  }

  /// TIMESTAMP_ADD function.
  static PipelineExpression timestampAdd(
    Object? timestamp,
    Object? unit,
    Object? amount,
  ) {
    return _expr('timestamp_add', [timestamp, unit, amount]);
  }

  /// TIMESTAMP_SUBTRACT function.
  static PipelineExpression timestampSubtract(
    Object? timestamp,
    Object? unit,
    Object? amount,
  ) {
    return _expr('timestamp_subtract', [timestamp, unit, amount]);
  }

  /// TIMESTAMP_TO_UNIX_MICROS function.
  static PipelineExpression timestampToUnixMicros(Object? input) {
    return _expr('timestamp_to_unix_micros', [input]);
  }

  /// TIMESTAMP_TO_UNIX_MILLIS function.
  static PipelineExpression timestampToUnixMillis(Object? input) {
    return _expr('timestamp_to_unix_millis', [input]);
  }

  /// TIMESTAMP_TO_UNIX_SECONDS function.
  static PipelineExpression timestampToUnixSeconds(Object? input) {
    return _expr('timestamp_to_unix_seconds', [input]);
  }

  /// TIMESTAMP_DIFF function.
  static PipelineExpression timestampDiff(
    Object? end,
    Object? start,
    Object? unit,
  ) {
    return _expr('timestamp_diff', [end, start, unit]);
  }

  /// TIMESTAMP_EXTRACT function.
  static PipelineExpression timestampExtract(
    Object? timestamp,
    Object? part, [
    Object? timezone,
  ]) {
    return _expr('timestamp_extract', [
      timestamp,
      part,
      ..._optionalArg(timezone),
    ]);
  }

  /// TYPE function.
  static PipelineExpression type(Object? input) => _expr('type', [input]);

  /// IS_TYPE function.
  static PipelineBooleanExpression isType(Object? input, Object? type) {
    return _bool('is_type', [input, type]);
  }

  /// COSINE_DISTANCE vector function.
  static PipelineExpression cosineDistance(Object? left, Object? right) {
    return _expr('cosine_distance', [left, right]);
  }

  /// DOT_PRODUCT vector function.
  static PipelineExpression dotProduct(Object? left, Object? right) {
    return _expr('dot_product', [left, right]);
  }

  /// EUCLIDEAN_DISTANCE vector function.
  static PipelineExpression euclideanDistance(Object? left, Object? right) {
    return _expr('euclidean_distance', [left, right]);
  }

  /// VECTOR_LENGTH vector function.
  static PipelineExpression vectorLength(Object? vector) {
    return _expr('vector_length', [vector]);
  }
}

/// Creates an ascending Pipeline ordering.
PipelineOrdering ascending(Object expression) {
  return PipelineOrdering._('ascending', expression);
}

/// Creates a descending Pipeline ordering.
PipelineOrdering descending(Object expression) {
  return PipelineOrdering._('descending', expression);
}

/// The starting point for constructing Firestore Pipeline operations.
@immutable
final class PipelineSource {
  const PipelineSource._(this._firestore);

  final Firestore _firestore;

  /// Starts a Pipeline over documents in the collection at [collectionPath].
  Pipeline collection(String collectionPath) {
    _validateResourcePath('collectionPath', collectionPath);
    return collectionReference(_firestore.collection(collectionPath));
  }

  /// Starts a Pipeline over every collection with [collectionId].
  Pipeline collectionGroup(String collectionId) {
    if (collectionId.contains('/')) {
      throw ArgumentError(
        'Invalid collectionId "$collectionId". Collection IDs must not contain "/".',
      );
    }
    return _start('collection_group', [collectionId]);
  }

  /// Starts a Pipeline over every document in the database.
  Pipeline database() => _start('database', const []);

  /// Starts a Pipeline over the provided collection reference.
  Pipeline collectionReference(
    CollectionReference<DocumentData> collectionReference,
  ) {
    return _start('collection', [collectionReference]);
  }

  /// Starts a Pipeline over the provided document references.
  Pipeline documents(Iterable<DocumentReference<dynamic>> documents) {
    final refs = documents.toList();
    if (refs.isEmpty) {
      throw ArgumentError.value(documents, 'documents', 'Must not be empty.');
    }
    return _start('documents', refs);
  }

  Pipeline _start(String name, List<Object?> args) {
    return Pipeline._(
      firestore: _firestore,
      stages: [_PipelineStage(name, args)],
    );
  }
}

/// A Firestore Pipeline operation.
@immutable
final class Pipeline {
  const Pipeline._({
    required this.firestore,
    required List<_PipelineStage> stages,
    Map<String, Object?> options = const {},
  }) : _stages = stages,
       _options = options;

  /// The Firestore instance used to execute this Pipeline.
  final Firestore firestore;
  final List<_PipelineStage> _stages;
  final Map<String, Object?> _options;

  /// Adds a raw backend Pipeline stage.
  ///
  /// Use this for preview stages or options not yet wrapped by this SDK.
  Pipeline rawStage(
    String name,
    Iterable<Object?> args, {
    Map<String, Object?> options = const {},
  }) {
    return _append(_PipelineStage(name, args.toList(), options));
  }

  /// Filters inputs using [condition].
  Pipeline where(PipelineBooleanExpression condition) {
    return rawStage('where', [condition]);
  }

  /// Selects or computes fields from the inputs.
  ///
  /// Entries may be [String] field names, [PipelineField] references,
  /// [PipelineExpression] instances, or [PipelineAliasedExpression] values.
  Pipeline select(Iterable<Object> selections) {
    return rawStage('select', [_projectionMap(selections)]);
  }

  /// Adds or overwrites fields on the inputs.
  Pipeline addFields(Iterable<PipelineAliasedExpression> fields) {
    return rawStage('add_fields', fields);
  }

  /// Aggregates inputs using aliased aggregate expressions.
  Pipeline aggregate(
    Iterable<PipelineAliasedExpression> accumulators, {
    Iterable<Object> groups = const [],
  }) {
    final values = accumulators.toList();
    if (values.isEmpty) {
      throw ArgumentError.value(
        accumulators,
        'accumulators',
        'Must not be empty.',
      );
    }
    return rawStage('aggregate', [
      _projectionMap(values),
      _projectionMap(groups),
    ]);
  }

  /// Returns unique combinations of the provided grouping expressions.
  Pipeline distinct(Iterable<Object> groups) {
    final values = groups.toList();
    if (values.isEmpty) {
      throw ArgumentError.value(groups, 'groups', 'Must not be empty.');
    }
    return rawStage('distinct', [
      for (final group in values)
        if (group is String) field(group) else group,
    ]);
  }

  /// Removes fields from the inputs.
  Pipeline removeFields(Iterable<Object> fields) {
    return rawStage('remove_fields', [
      for (final value in fields)
        if (value is String) field(value) else value,
    ]);
  }

  /// Sorts inputs according to [orderings].
  Pipeline sort(Iterable<PipelineOrdering> orderings) {
    final values = orderings.toList();
    if (values.isEmpty) {
      throw ArgumentError.value(orderings, 'orderings', 'Must not be empty.');
    }
    return rawStage('sort', values);
  }

  /// Skips the first [offset] inputs.
  Pipeline offset(int offset) {
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'Must be non-negative.');
    }
    return rawStage('offset', [offset]);
  }

  /// Limits the number of returned inputs to [limit].
  Pipeline limit(int limit) {
    if (limit < 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be non-negative.');
    }
    return rawStage('limit', [limit]);
  }

  /// Emits a document for each element in [expression].
  Pipeline unnest(Object expression, {String? indexField}) {
    return rawStage('unnest', [
      if (expression is String) field(expression) else expression,
    ], options: _compactOptions({'index_field': indexField}));
  }

  /// Replaces each input document with [expression].
  Pipeline replaceWith(Object expression) {
    return rawStage('replace_with', [
      if (expression is String) field(expression) else expression,
    ]);
  }

  /// Performs a union with [pipeline], including duplicates.
  Pipeline union(Pipeline pipeline) {
    return rawStage('union', [pipeline]);
  }

  /// Samples a fixed number or percentage of documents from the input.
  Pipeline sample({int? documents, double? percentage}) {
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
    return rawStage(
      'sample',
      const [],
      options: _compactOptions({
        'documents': documents,
        'percentage': percentage,
      }),
    );
  }

  /// Performs vector nearest-neighbor search.
  Pipeline findNearest({
    required Object vectorField,
    required Object queryVector,
    required DistanceMeasure distanceMeasure,
    int? limit,
    String? distanceResultField,
    double? distanceThreshold,
  }) {
    return rawStage(
      'find_nearest',
      [
        if (vectorField is String) field(vectorField) else vectorField,
        queryVector,
        distanceMeasure.value.toLowerCase(),
      ],
      options: _compactOptions({
        'limit': limit,
        'distance_field': distanceResultField == null
            ? null
            : field(distanceResultField),
        'distance_threshold': distanceThreshold,
      }),
    );
  }

  /// Adds a search stage.
  ///
  /// The search API is still evolving; [options] is passed through to the
  /// backend stage as encoded Pipeline values.
  Pipeline search(Map<String, Object?> options) {
    return rawStage('search', const [], options: options);
  }

  /// Returns a copy of this Pipeline with query-level [options].
  Pipeline withOptions(Map<String, Object?> options) {
    return Pipeline._(
      firestore: firestore,
      stages: _stages,
      options: {..._options, ...options},
    );
  }

  /// Executes this Pipeline and returns the results.
  Future<PipelineSnapshot> execute({
    String? transaction,
    Timestamp? readTime,
  }) async {
    if (transaction != null && readTime != null) {
      throw ArgumentError(
        'Only one of transaction or readTime can be provided.',
      );
    }

    final response = await firestore._firestoreClient.v1((
      api,
      projectId,
    ) async {
      final request = firestore_v1.ExecutePipelineRequest(
        database: 'projects/$projectId/databases/${firestore.databaseId}',
        structuredPipeline: firestore_v1.StructuredPipeline(
          pipeline: _toProto(),
          options: _encodeOptions(_options, firestore),
        ),
        transaction: transaction.let(base64Decode),
        readTime: readTime?._toProto().timestampValue,
      );
      return api.executePipeline(request);
    });

    final results = <PipelineResult>[];
    Timestamp? executionTime;
    String? newTransaction;
    firestore_v1.ExplainStats? explainStats;

    await for (final chunk in response) {
      if (chunk.transaction.isNotEmpty) {
        newTransaction = base64Encode(chunk.transaction);
      }
      if (chunk.executionTime != null) {
        executionTime = Timestamp._fromProto(chunk.executionTime!);
      }
      if (chunk.explainStats != null) {
        explainStats = chunk.explainStats;
      }

      for (final document in chunk.results) {
        results.add(PipelineResult._fromDocument(document, firestore));
      }
    }

    return PipelineSnapshot._(
      results: results,
      executionTime: executionTime,
      transaction: newTransaction,
      explainStats: explainStats,
    );
  }

  Pipeline _append(_PipelineStage stage) {
    return Pipeline._(
      firestore: firestore,
      stages: [..._stages, stage],
      options: _options,
    );
  }

  firestore_v1.Pipeline _toProto() {
    return firestore_v1.Pipeline(
      stages: [for (final stage in _stages) stage._toProto(firestore)],
    );
  }
}

/// A Pipeline execution result.
@immutable
final class PipelineResult {
  const PipelineResult._({
    required DocumentData data,
    required this.name,
    required this.document,
    required this.createTime,
    required this.updateTime,
  }) : _data = data;

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
      document: ref,
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
  final DocumentReference<DocumentData>? document;

  /// The time the document was created.
  final Timestamp? createTime;

  /// The time the document was last updated.
  final Timestamp? updateTime;

  /// Returns the decoded result fields.
  DocumentData? data() => Map.unmodifiable(_data);

  /// Returns the decoded value at [fieldName], or `null` when absent.
  Object? get(String fieldName) => _data[fieldName];
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
    required this.results,
    required this.executionTime,
    required this.transaction,
    required this.explainStats,
  });

  /// The Pipeline results returned by the backend.
  final List<PipelineResult> results;

  /// FlutterFire-style alias for [results].
  List<PipelineResult> get result => results;

  /// The time at which the results are valid.
  final Timestamp? executionTime;

  /// A newly-created transaction ID, when requested by the backend.
  final String? transaction;

  /// Raw explain stats returned by the generated Firestore API model.
  final firestore_v1.ExplainStats? explainStats;

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
  PipelineAliasedExpression alias(String alias) {
    return PipelineAliasedExpression._(this, alias);
  }

  /// Assigns [alias] to this expression for projection-style stages.
  PipelineAliasedExpression as(String alias) => this.alias(alias);

  /// Treats this expression as a boolean expression.
  PipelineBooleanExpression asBoolean() => _PipelineBooleanCastExpression(this);

  /// Creates an equality expression.
  PipelineBooleanExpression equal(Object? other) {
    return _PipelineBooleanExpression('equal', [this, other]);
  }

  /// Creates an equality expression against a literal value.
  PipelineBooleanExpression equalValue(Object? value) => equal(value);

  /// Creates a not-equal expression.
  PipelineBooleanExpression notEqual(Object? other) {
    return _PipelineBooleanExpression('not_equal', [this, other]);
  }

  /// Creates a not-equal expression against a literal value.
  PipelineBooleanExpression notEqualValue(Object? value) => notEqual(value);

  /// Creates a less-than expression.
  PipelineBooleanExpression lessThan(Object? other) {
    return _PipelineBooleanExpression('less_than', [this, other]);
  }

  /// Creates a less-than expression against a literal value.
  PipelineBooleanExpression lessThanValue(Object? value) => lessThan(value);

  /// Creates a less-than-or-equal expression.
  PipelineBooleanExpression lessThanOrEqual(Object? other) {
    return _PipelineBooleanExpression('less_than_or_equal', [this, other]);
  }

  /// Creates a less-than-or-equal expression against a literal value.
  PipelineBooleanExpression lessThanOrEqualValue(Object? value) {
    return lessThanOrEqual(value);
  }

  /// Creates a greater-than expression.
  PipelineBooleanExpression greaterThan(Object? other) {
    return _PipelineBooleanExpression('greater_than', [this, other]);
  }

  /// Creates a greater-than expression against a literal value.
  PipelineBooleanExpression greaterThanValue(Object? value) =>
      greaterThan(value);

  /// Creates a greater-than-or-equal expression.
  PipelineBooleanExpression greaterThanOrEqual(Object? other) {
    return _PipelineBooleanExpression('greater_than_or_equal', [this, other]);
  }

  /// Creates a greater-than-or-equal expression against a literal value.
  PipelineBooleanExpression greaterThanOrEqualValue(Object? value) {
    return greaterThanOrEqual(value);
  }

  /// Creates an addition expression.
  PipelineExpression add(Object? other) {
    return _PipelineFunctionExpression('add', [this, other], const {});
  }

  /// Adds a numeric literal to this expression.
  PipelineExpression addNumber(num other) => add(other);

  /// Creates a subtraction expression.
  PipelineExpression subtract(Object? other) {
    return _PipelineFunctionExpression('subtract', [this, other], const {});
  }

  /// Subtracts a numeric literal from this expression.
  PipelineExpression subtractNumber(num other) => subtract(other);

  /// Creates a multiplication expression.
  PipelineExpression multiply(Object? other) {
    return _PipelineFunctionExpression('multiply', [this, other], const {});
  }

  /// Multiplies this expression by a numeric literal.
  PipelineExpression multiplyNumber(num other) => multiply(other);

  /// Creates a division expression.
  PipelineExpression divide(Object? other) {
    return _PipelineFunctionExpression('divide', [this, other], const {});
  }

  /// Divides this expression by a numeric literal.
  PipelineExpression divideNumber(num other) => divide(other);

  /// Returns the absolute value of this expression.
  PipelineExpression abs() => PipelineFunctions.abs(this);

  /// Returns the modulo of this expression and [other].
  PipelineExpression modulo(Object? other) =>
      PipelineFunctions.mod(this, other);

  /// Returns the modulo of this expression and a numeric literal.
  PipelineExpression moduloNumber(num other) => modulo(other);

  /// Returns the ceiling of this expression.
  PipelineExpression ceil() => PipelineFunctions.ceil(this);

  /// Returns the floor of this expression.
  PipelineExpression floor() => PipelineFunctions.floor(this);

  /// Returns the rounded value of this expression.
  PipelineExpression round() => PipelineFunctions.round(this);

  /// Truncates this expression.
  PipelineExpression trunc([Object? decimals]) {
    return decimals == null
        ? PipelineFunctions.trunc(this)
        : PipelineFunctions.raw('trunc', [this, decimals]);
  }

  /// Returns the square root of this expression.
  PipelineExpression sqrt() => PipelineFunctions.sqrt(this);

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
  PipelineBooleanExpression arrayContainsValue(Object? element) {
    return PipelineFunctions.arrayContains(this, element);
  }

  /// Checks if this array contains [element].
  PipelineBooleanExpression arrayContainsElement(Object? element) {
    return PipelineFunctions.arrayContains(this, element);
  }

  /// Checks if this array contains all [values].
  PipelineBooleanExpression arrayContainsAll(Iterable<Object?> values) {
    return PipelineFunctions.arrayContainsAll(
      this,
      PipelineFunctions.array(values),
    );
  }

  /// Checks if this array contains all values from [arrayExpression].
  PipelineBooleanExpression arrayContainsAllFrom(Object? arrayExpression) {
    return PipelineFunctions.arrayContainsAll(this, arrayExpression);
  }

  /// Checks if this array contains any [values].
  PipelineBooleanExpression arrayContainsAny(Iterable<Object?> values) {
    return PipelineFunctions.arrayContainsAny(
      this,
      PipelineFunctions.array(values),
    );
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

  /// Returns the index of [element].
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

  /// Returns the maximum element of this array expression.
  PipelineExpression arrayMaximum() => PipelineFunctions.maximum(this);

  /// Returns the largest [n] elements of this array expression.
  PipelineExpression arrayMaximumN(Object? n) =>
      PipelineFunctions.maximumN(this, n);

  /// Returns the minimum element of this array expression.
  PipelineExpression arrayMinimum() => PipelineFunctions.minimum(this);

  /// Returns the smallest [n] elements of this array expression.
  PipelineExpression arrayMinimumN(Object? n) =>
      PipelineFunctions.minimumN(this, n);

  /// Reverses this array expression.
  PipelineExpression arrayReverse() => PipelineFunctions.arrayReverse(this);

  /// Returns a slice of this array expression.
  PipelineExpression arraySlice(Object? offset, [Object? length]) {
    return length == null
        ? PipelineFunctions.raw('array_slice', [this, offset])
        : PipelineFunctions.arraySlice(this, offset, length);
  }

  /// Returns the sum of numeric elements in this array expression.
  PipelineExpression arraySum() => PipelineFunctions.sum(this);

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
    return PipelineFunctions.arrayTransform(
      this,
      elementAlias,
      transform,
      indexAlias,
    );
  }

  /// Checks if this expression exists.
  PipelineBooleanExpression exists() => PipelineFunctions.exists(this);

  /// Checks if this expression is absent.
  PipelineBooleanExpression isAbsent() => PipelineFunctions.isAbsent(this);

  /// Replaces absent values with [elseValue].
  PipelineExpression ifAbsentValue(Object? elseValue) {
    return PipelineFunctions.ifAbsent(this, elseValue);
  }

  /// Replaces absent values with [elseExpr].
  PipelineExpression ifAbsent(Object? elseExpr) {
    return PipelineFunctions.ifAbsent(this, elseExpr);
  }

  /// Checks if this expression errors.
  PipelineBooleanExpression isError() => PipelineFunctions.isError(this);

  /// Replaces errors with [catchValue].
  PipelineExpression ifErrorValue(Object? catchValue) {
    return PipelineFunctions.ifError(this, catchValue);
  }

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

  /// Removes [keys] from this map expression.
  PipelineExpression mapRemove(Iterable<Object?> keys) {
    return PipelineFunctions.mapRemove(this, keys);
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
  PipelineExpression length() => PipelineFunctions.charLength(this);

  /// Concatenates this string expression with [others].
  PipelineExpression concat(Iterable<Object?> others) {
    return PipelineFunctions.stringConcat([this, ...others]);
  }

  /// Converts this string expression to lowercase.
  PipelineExpression toLowerCase() => PipelineFunctions.toLower(this);

  /// Converts this string expression to uppercase.
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

  /// Extracts a substring from this string expression.
  PipelineExpression substring(Object? start, Object? end) {
    return PipelineFunctions.substring(this, start, end);
  }

  /// Extracts a substring from this string expression.
  PipelineExpression substringLiteral(int start, int end) {
    return substring(start, end);
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
  PipelineExpression timestampTrunc(Object? granularity, [Object? timezone]) {
    return PipelineFunctions.timestampTrunc(this, granularity, timezone);
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
  PipelineExpression cosineDistance(Object? other) {
    return PipelineFunctions.cosineDistance(this, other);
  }

  /// Computes dot product between this vector and [other].
  PipelineExpression dotProduct(Object? other) {
    return PipelineFunctions.dotProduct(this, other);
  }

  /// Computes Euclidean distance between this vector and [other].
  PipelineExpression euclideanDistance(Object? other) {
    return PipelineFunctions.euclideanDistance(this, other);
  }

  /// Returns this vector expression's length.
  PipelineExpression vectorLength() => PipelineFunctions.vectorLength(this);

  /// Creates an ascending ordering for this expression.
  PipelineOrdering ascending() => PipelineOrdering._('ascending', this);

  /// Creates a descending ordering for this expression.
  PipelineOrdering descending() => PipelineOrdering._('descending', this);
}

/// A Pipeline boolean expression.
@immutable
sealed class PipelineBooleanExpression extends PipelineExpression {
  const PipelineBooleanExpression();
}

/// A Pipeline field reference.
@immutable
final class PipelineField extends PipelineExpression {
  const PipelineField._(this.path);

  /// The field path referenced by this expression.
  final String path;

  /// Creates an ascending ordering for this field.
  @override
  PipelineOrdering ascending() => PipelineOrdering._('ascending', this);

  /// Creates a descending ordering for this field.
  @override
  PipelineOrdering descending() => PipelineOrdering._('descending', this);

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
  const _PipelineStage(this.name, this.args, [this.options = const {}]);

  final String name;
  final List<Object?> args;
  final Map<String, Object?> options;

  firestore_v1.Pipeline_Stage _toProto(Firestore firestore) {
    return firestore_v1.Pipeline_Stage(
      name: name,
      args: [for (final arg in args) _encodePipelineValue(arg, firestore)],
      options: _encodeOptions(options, firestore),
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
      return firestore_v1.Value(referenceValue: '/${value.path}');
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

List<Object?> _optionalArg(Object? value) {
  return value == null ? const [] : [value];
}

Map<String, Object?> _compactOptions(Map<String, Object?> options) {
  return Map.fromEntries(options.entries.where((entry) => entry.value != null));
}

Map<String, Object?> _projectionMap(Iterable<Object> selections) {
  return Map.fromEntries(selections.map(_projectionEntry));
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
