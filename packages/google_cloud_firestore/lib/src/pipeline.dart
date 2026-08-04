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
  return _PipelineBooleanExpression(name, [_fieldOrExpression(left), right]);
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

/// Returns the relevance score assigned by a preceding search stage.
PipelineExpression score() => PipelineFunctions.score();

/// Creates an expression matching documents against the query string [rquery].
PipelineBooleanExpression documentMatches(Object? rquery) {
  return PipelineFunctions.documentMatches(rquery);
}

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

  /// MINIMUM function.
  static PipelineExpression minimum(Object? fieldName, [Object? second]) {
    return _expr('minimum', [
      _fieldOrExpression(fieldName),
      ..._optionalArg(second),
    ]);
  }

  /// MAXIMUM function.
  static PipelineExpression maximum(Object? fieldName, [Object? second]) {
    return _expr('maximum', [
      _fieldOrExpression(fieldName),
      ..._optionalArg(second),
    ]);
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
  static PipelineExpression add(Object? left, Object? right) {
    return _expr('add', [_fieldOrExpression(left), right]);
  }

  /// SUBTRACT arithmetic function.
  static PipelineExpression subtract(Object? left, Object? right) {
    return _expr('subtract', [_fieldOrExpression(left), right]);
  }

  /// MULTIPLY arithmetic function.
  static PipelineExpression multiply(Object? left, Object? right) {
    return _expr('multiply', [_fieldOrExpression(left), right]);
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
  static PipelineExpression round(Object? fieldName, [Object? decimalPlaces]) {
    return _expr('round', [
      _fieldOrExpression(fieldName),
      ..._optionalArg(decimalPlaces),
    ]);
  }

  /// TRUNC arithmetic function.
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
  static PipelineBooleanExpression arrayContainsAll(
    Object? array,
    Object? searchValues,
  ) {
    return _bool('array_contains_all', [
      _fieldOrExpression(array),
      searchValues,
    ]);
  }

  /// ARRAY_CONTAINS_ANY function.
  static PipelineBooleanExpression arrayContainsAny(
    Object? array,
    Object? searchValues,
  ) {
    return _bool('array_contains_any', [
      _fieldOrExpression(array),
      searchValues,
    ]);
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
  static PipelineExpression arraySlice(
    Object? array,
    Object? offset,
    Object? length,
  ) {
    return _expr('array_slice', [_fieldOrExpression(array), offset, length]);
  }

  /// ARRAY_TRANSFORM function.
  static PipelineExpression arrayTransform(
    Object? array,
    String variableName,
    Object? expression, [
    String? indexVariableName,
  ]) {
    final target = _fieldOrExpression(array);
    return indexVariableName == null
        ? _expr('array_transform', [target, variableName, expression])
        : _expr('array_transform', [
            target,
            variableName,
            indexVariableName,
            expression,
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

  /// JOIN function.
  static PipelineExpression join(Object? array, [Object? separator]) {
    return _expr('join', [
      _fieldOrExpression(array),
      ..._optionalArg(separator),
    ]);
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
  static PipelineBooleanExpression equalAny(
    Object? fieldName,
    Object? searchSpace,
  ) {
    return _bool('equal_any', [_fieldOrExpression(fieldName), searchSpace]);
  }

  /// NOT_EQUAL_ANY logical function.
  static PipelineBooleanExpression notEqualAny(
    Object? fieldName,
    Object? searchSpace,
  ) {
    return _bool('not_equal_any', [_fieldOrExpression(fieldName), searchSpace]);
  }

  /// MAP construction function.
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
  static PipelineExpression mapRemove(Object? map, Iterable<Object?> keys) {
    return _expr('map_remove', [_fieldOrExpression(map), ...keys]);
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
  static PipelineExpression substring(
    Object? fieldName,
    Object? offset, [
    Object? length,
  ]) {
    return _expr('substring', [
      _fieldOrExpression(fieldName),
      offset,
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
  static PipelineExpression split(Object? fieldName, [Object? delimiter]) {
    return _expr('split', [
      _fieldOrExpression(fieldName),
      ..._optionalArg(delimiter),
    ]);
  }

  /// CURRENT_TIMESTAMP function.
  static PipelineExpression currentTimestamp() {
    return _expr('current_timestamp', const []);
  }

  /// TIMESTAMP_TRUNC function.
  static PipelineExpression timestampTrunc(
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
  static PipelineExpression cosineDistance(Object? left, Object? right) {
    return _expr('cosine_distance', [_fieldOrExpression(left), right]);
  }

  /// DOT_PRODUCT vector function.
  static PipelineExpression dotProduct(Object? left, Object? right) {
    return _expr('dot_product', [_fieldOrExpression(left), right]);
  }

  /// EUCLIDEAN_DISTANCE vector function.
  static PipelineExpression euclideanDistance(Object? left, Object? right) {
    return _expr('euclidean_distance', [_fieldOrExpression(left), right]);
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
        _validateSameDatabase(query.query.firestore);
        return query._toPipeline(_firestore);
      case Query<Object?>():
        _validateSameDatabase(query.firestore);
        return query._toPipeline(_firestore);
      default:
        throw ArgumentError.value(
          query,
          'query',
          'Expected a Query or a VectorQuery.',
        );
    }
  }

  void _validateSameDatabase(Firestore queryFirestore) {
    if (queryFirestore.databaseId == _firestore.databaseId) return;

    throw ArgumentError.value(
      queryFirestore.databaseId,
      'query',
      'The database of this query does not match the target database '
          '("${_firestore.databaseId}") of this Pipeline.',
    );
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
      pipeline = pipeline.select([
        for (final projection in projections) field(projection.fieldPath),
      ]);
    }

    // Inequality fields are skipped here because `_toPipelineBooleanExpression`
    // has already emitted their existence checks.
    final existsConditions = [
      for (final fieldOrder in _implicitOrderBy(ignoreInequalityFields: true))
        field(fieldOrder.fieldPath._formattedName).exists(),
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
          field(fieldOrder.fieldPath._formattedName),
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
    final target = field(filter.field._formattedName);
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
      WhereFilter.arrayContains => target.arrayContainsElement(value),
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
        ? _comparison('less_than', expression, value)
        : _comparison('greater_than', expression, value);
  }

  PipelineBooleanExpression equals(Object? expression, Object? value) {
    return _comparison('equal', expression, value);
  }

  var expression = orderings[size - 1]._expression;
  var value = _PipelineProtoValue(cursor.values[size - 1]);

  var condition = compare(expression, value);
  // An inclusive bound also matches the cursor value itself.
  if (before != cursor.before) {
    condition = or([condition, equals(expression, value)]);
  }

  for (var i = size - 2; i >= 0; i--) {
    expression = orderings[i]._expression;
    value = _PipelineProtoValue(cursor.values[i]);
    condition = or([
      compare(expression, value),
      and([equals(expression, value), condition]),
    ]);
  }

  return condition;
}

/// Translates the [VectorQuery] surface onto Pipeline stages.
extension _VectorQueryToPipeline<T> on VectorQuery<T> {
  Pipeline _toPipeline(Firestore firestore) {
    final vectorField = _rawVectorField;
    return _query
        ._toPipeline(firestore)
        .where(field(vectorField).exists())
        .findNearest(
          vectorField: field(vectorField),
          queryVector: FieldValue.vector(_rawQueryVector),
          distanceMeasure: _options.distanceMeasure,
          limit: _options.limit,
          distanceResultField: _rawDistanceResultField,
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

  /// Returns the element of this array expression at [index].
  PipelineExpression arrayGet(Object? index) {
    return PipelineFunctions.arrayGet(this, index);
  }

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
  PipelineExpression charLength() => PipelineFunctions.charLength(this);

  /// Returns the length of this expression.
  ///
  /// Unlike [charLength], this works on strings, bytes, arrays, maps and
  /// vectors.
  PipelineExpression length() => PipelineFunctions.length(this);

  /// Reverses this string or array expression.
  PipelineExpression reverse() => PipelineFunctions.reverse(this);

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
