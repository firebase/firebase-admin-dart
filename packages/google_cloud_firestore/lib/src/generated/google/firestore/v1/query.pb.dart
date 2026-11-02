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

// coverage:ignore-file

// This is a generated file - do not edit.
//
// Generated from google/firestore/v1/query.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/wrappers.pb.dart'
    as $0;

import 'document.pb.dart' as $1;
import 'query.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'query.pbenum.dart';

/// A selection of a collection, such as `messages as m1`.
class StructuredQuery_CollectionSelector extends $pb.GeneratedMessage {
  factory StructuredQuery_CollectionSelector({
    $core.String? collectionId,
    $core.bool? allDescendants,
  }) {
    final result = StructuredQuery_CollectionSelector._();
    if (collectionId != null) result.collectionId = collectionId;
    if (allDescendants != null) result.allDescendants = allDescendants;
    return result;
  }

  StructuredQuery_CollectionSelector._();

  factory StructuredQuery_CollectionSelector.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_CollectionSelector()..mergeFromBuffer(data, registry);
  factory StructuredQuery_CollectionSelector.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_CollectionSelector()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredQuery.CollectionSelector',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: StructuredQuery_CollectionSelector.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'collectionId')
    ..aOB(3, _omitFieldNames ? '' : 'allDescendants')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_CollectionSelector clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_CollectionSelector copyWith(
          void Function(StructuredQuery_CollectionSelector) updates) =>
      super.copyWith((message) =>
              updates(message as StructuredQuery_CollectionSelector))
          as StructuredQuery_CollectionSelector;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StructuredQuery_CollectionSelector() / StructuredQuery_CollectionSelector.new instead')
  static StructuredQuery_CollectionSelector create() =>
      StructuredQuery_CollectionSelector._();
  static $pb.GeneratedMessage $_createMessage() =>
      StructuredQuery_CollectionSelector._();
  @$core.override
  StructuredQuery_CollectionSelector createEmptyInstance() =>
      StructuredQuery_CollectionSelector._();
  @$core.pragma('dart2js:noInline')
  static StructuredQuery_CollectionSelector getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StructuredQuery_CollectionSelector>(
          StructuredQuery_CollectionSelector.$_createMessage);
  static StructuredQuery_CollectionSelector? _defaultInstance;

  /// The collection ID.
  /// When set, selects only collections with this ID.
  @$pb.TagNumber(2)
  $core.String get collectionId => $_getSZ(0);
  @$pb.TagNumber(2)
  set collectionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(2)
  $core.bool hasCollectionId() => $_has(0);
  @$pb.TagNumber(2)
  void clearCollectionId() => $_clearField(2);

  /// When false, selects only collections that are immediate children of
  /// the `parent` specified in the containing `RunQueryRequest`.
  /// When true, selects all descendant collections.
  @$pb.TagNumber(3)
  $core.bool get allDescendants => $_getBF(1);
  @$pb.TagNumber(3)
  set allDescendants($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(3)
  $core.bool hasAllDescendants() => $_has(1);
  @$pb.TagNumber(3)
  void clearAllDescendants() => $_clearField(3);
}

enum StructuredQuery_Filter_FilterType {
  compositeFilter,
  fieldFilter,
  unaryFilter,
  notSet
}

/// A filter.
class StructuredQuery_Filter extends $pb.GeneratedMessage {
  factory StructuredQuery_Filter({
    StructuredQuery_CompositeFilter? compositeFilter,
    StructuredQuery_FieldFilter? fieldFilter,
    StructuredQuery_UnaryFilter? unaryFilter,
  }) {
    final result = StructuredQuery_Filter._();
    if (compositeFilter != null) result.compositeFilter = compositeFilter;
    if (fieldFilter != null) result.fieldFilter = fieldFilter;
    if (unaryFilter != null) result.unaryFilter = unaryFilter;
    return result;
  }

  StructuredQuery_Filter._();

  factory StructuredQuery_Filter.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_Filter()..mergeFromBuffer(data, registry);
  factory StructuredQuery_Filter.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_Filter()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, StructuredQuery_Filter_FilterType>
      _StructuredQuery_Filter_FilterTypeByTag = {
    1: StructuredQuery_Filter_FilterType.compositeFilter,
    2: StructuredQuery_Filter_FilterType.fieldFilter,
    3: StructuredQuery_Filter_FilterType.unaryFilter,
    0: StructuredQuery_Filter_FilterType.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredQuery.Filter',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: StructuredQuery_Filter.$_createMessage)
    ..oo(0, [1, 2, 3])
    ..aOM<StructuredQuery_CompositeFilter>(
        1, _omitFieldNames ? '' : 'compositeFilter',
        subBuilder: StructuredQuery_CompositeFilter.$_createMessage)
    ..aOM<StructuredQuery_FieldFilter>(2, _omitFieldNames ? '' : 'fieldFilter',
        subBuilder: StructuredQuery_FieldFilter.$_createMessage)
    ..aOM<StructuredQuery_UnaryFilter>(3, _omitFieldNames ? '' : 'unaryFilter',
        subBuilder: StructuredQuery_UnaryFilter.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_Filter clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_Filter copyWith(
          void Function(StructuredQuery_Filter) updates) =>
      super.copyWith((message) => updates(message as StructuredQuery_Filter))
          as StructuredQuery_Filter;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StructuredQuery_Filter() / StructuredQuery_Filter.new instead')
  static StructuredQuery_Filter create() => StructuredQuery_Filter._();
  static $pb.GeneratedMessage $_createMessage() => StructuredQuery_Filter._();
  @$core.override
  StructuredQuery_Filter createEmptyInstance() => StructuredQuery_Filter._();
  @$core.pragma('dart2js:noInline')
  static StructuredQuery_Filter getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StructuredQuery_Filter>(
          StructuredQuery_Filter.$_createMessage);
  static StructuredQuery_Filter? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  StructuredQuery_Filter_FilterType whichFilterType() =>
      _StructuredQuery_Filter_FilterTypeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearFilterType() => $_clearField($_whichOneof(0));

  /// A composite filter.
  @$pb.TagNumber(1)
  StructuredQuery_CompositeFilter get compositeFilter => $_getN(0);
  @$pb.TagNumber(1)
  set compositeFilter(StructuredQuery_CompositeFilter value) =>
      $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCompositeFilter() => $_has(0);
  @$pb.TagNumber(1)
  void clearCompositeFilter() => $_clearField(1);
  @$pb.TagNumber(1)
  StructuredQuery_CompositeFilter ensureCompositeFilter() => $_ensure(0);

  /// A filter on a document field.
  @$pb.TagNumber(2)
  StructuredQuery_FieldFilter get fieldFilter => $_getN(1);
  @$pb.TagNumber(2)
  set fieldFilter(StructuredQuery_FieldFilter value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasFieldFilter() => $_has(1);
  @$pb.TagNumber(2)
  void clearFieldFilter() => $_clearField(2);
  @$pb.TagNumber(2)
  StructuredQuery_FieldFilter ensureFieldFilter() => $_ensure(1);

  /// A filter that takes exactly one argument.
  @$pb.TagNumber(3)
  StructuredQuery_UnaryFilter get unaryFilter => $_getN(2);
  @$pb.TagNumber(3)
  set unaryFilter(StructuredQuery_UnaryFilter value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasUnaryFilter() => $_has(2);
  @$pb.TagNumber(3)
  void clearUnaryFilter() => $_clearField(3);
  @$pb.TagNumber(3)
  StructuredQuery_UnaryFilter ensureUnaryFilter() => $_ensure(2);
}

/// A filter that merges multiple other filters using the given operator.
class StructuredQuery_CompositeFilter extends $pb.GeneratedMessage {
  factory StructuredQuery_CompositeFilter({
    StructuredQuery_CompositeFilter_Operator? op,
    $core.Iterable<StructuredQuery_Filter>? filters,
  }) {
    final result = StructuredQuery_CompositeFilter._();
    if (op != null) result.op = op;
    if (filters != null) result.filters.addAll(filters);
    return result;
  }

  StructuredQuery_CompositeFilter._();

  factory StructuredQuery_CompositeFilter.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_CompositeFilter()..mergeFromBuffer(data, registry);
  factory StructuredQuery_CompositeFilter.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_CompositeFilter()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredQuery.CompositeFilter',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: StructuredQuery_CompositeFilter.$_createMessage)
    ..aE<StructuredQuery_CompositeFilter_Operator>(
        1, _omitFieldNames ? '' : 'op',
        enumValues: StructuredQuery_CompositeFilter_Operator.values)
    ..pPM<StructuredQuery_Filter>(2, _omitFieldNames ? '' : 'filters',
        subBuilder: StructuredQuery_Filter.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_CompositeFilter clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_CompositeFilter copyWith(
          void Function(StructuredQuery_CompositeFilter) updates) =>
      super.copyWith(
              (message) => updates(message as StructuredQuery_CompositeFilter))
          as StructuredQuery_CompositeFilter;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StructuredQuery_CompositeFilter() / StructuredQuery_CompositeFilter.new instead')
  static StructuredQuery_CompositeFilter create() =>
      StructuredQuery_CompositeFilter._();
  static $pb.GeneratedMessage $_createMessage() =>
      StructuredQuery_CompositeFilter._();
  @$core.override
  StructuredQuery_CompositeFilter createEmptyInstance() =>
      StructuredQuery_CompositeFilter._();
  @$core.pragma('dart2js:noInline')
  static StructuredQuery_CompositeFilter getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StructuredQuery_CompositeFilter>(
          StructuredQuery_CompositeFilter.$_createMessage);
  static StructuredQuery_CompositeFilter? _defaultInstance;

  /// The operator for combining multiple filters.
  @$pb.TagNumber(1)
  StructuredQuery_CompositeFilter_Operator get op => $_getN(0);
  @$pb.TagNumber(1)
  set op(StructuredQuery_CompositeFilter_Operator value) =>
      $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasOp() => $_has(0);
  @$pb.TagNumber(1)
  void clearOp() => $_clearField(1);

  /// The list of filters to combine.
  ///
  /// Requires:
  ///
  /// * At least one filter is present.
  @$pb.TagNumber(2)
  $pb.PbList<StructuredQuery_Filter> get filters => $_getList(1);
}

/// A filter on a specific field.
class StructuredQuery_FieldFilter extends $pb.GeneratedMessage {
  factory StructuredQuery_FieldFilter({
    StructuredQuery_FieldReference? field_1,
    StructuredQuery_FieldFilter_Operator? op,
    $1.Value? value,
  }) {
    final result = StructuredQuery_FieldFilter._();
    if (field_1 != null) result.field_1 = field_1;
    if (op != null) result.op = op;
    if (value != null) result.value = value;
    return result;
  }

  StructuredQuery_FieldFilter._();

  factory StructuredQuery_FieldFilter.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_FieldFilter()..mergeFromBuffer(data, registry);
  factory StructuredQuery_FieldFilter.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_FieldFilter()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredQuery.FieldFilter',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: StructuredQuery_FieldFilter.$_createMessage)
    ..aOM<StructuredQuery_FieldReference>(1, _omitFieldNames ? '' : 'field',
        subBuilder: StructuredQuery_FieldReference.$_createMessage)
    ..aE<StructuredQuery_FieldFilter_Operator>(2, _omitFieldNames ? '' : 'op',
        enumValues: StructuredQuery_FieldFilter_Operator.values)
    ..aOM<$1.Value>(3, _omitFieldNames ? '' : 'value',
        subBuilder: $1.Value.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_FieldFilter clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_FieldFilter copyWith(
          void Function(StructuredQuery_FieldFilter) updates) =>
      super.copyWith(
              (message) => updates(message as StructuredQuery_FieldFilter))
          as StructuredQuery_FieldFilter;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StructuredQuery_FieldFilter() / StructuredQuery_FieldFilter.new instead')
  static StructuredQuery_FieldFilter create() =>
      StructuredQuery_FieldFilter._();
  static $pb.GeneratedMessage $_createMessage() =>
      StructuredQuery_FieldFilter._();
  @$core.override
  StructuredQuery_FieldFilter createEmptyInstance() =>
      StructuredQuery_FieldFilter._();
  @$core.pragma('dart2js:noInline')
  static StructuredQuery_FieldFilter getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StructuredQuery_FieldFilter>(
          StructuredQuery_FieldFilter.$_createMessage);
  static StructuredQuery_FieldFilter? _defaultInstance;

  /// The field to filter by.
  @$pb.TagNumber(1)
  StructuredQuery_FieldReference get field_1 => $_getN(0);
  @$pb.TagNumber(1)
  set field_1(StructuredQuery_FieldReference value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasField_1() => $_has(0);
  @$pb.TagNumber(1)
  void clearField_1() => $_clearField(1);
  @$pb.TagNumber(1)
  StructuredQuery_FieldReference ensureField_1() => $_ensure(0);

  /// The operator to filter by.
  @$pb.TagNumber(2)
  StructuredQuery_FieldFilter_Operator get op => $_getN(1);
  @$pb.TagNumber(2)
  set op(StructuredQuery_FieldFilter_Operator value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOp() => $_has(1);
  @$pb.TagNumber(2)
  void clearOp() => $_clearField(2);

  /// The value to compare to.
  @$pb.TagNumber(3)
  $1.Value get value => $_getN(2);
  @$pb.TagNumber(3)
  set value($1.Value value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearValue() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.Value ensureValue() => $_ensure(2);
}

enum StructuredQuery_UnaryFilter_OperandType { field_2, notSet }

/// A filter with a single operand.
class StructuredQuery_UnaryFilter extends $pb.GeneratedMessage {
  factory StructuredQuery_UnaryFilter({
    StructuredQuery_UnaryFilter_Operator? op,
    StructuredQuery_FieldReference? field_2,
  }) {
    final result = StructuredQuery_UnaryFilter._();
    if (op != null) result.op = op;
    if (field_2 != null) result.field_2 = field_2;
    return result;
  }

  StructuredQuery_UnaryFilter._();

  factory StructuredQuery_UnaryFilter.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_UnaryFilter()..mergeFromBuffer(data, registry);
  factory StructuredQuery_UnaryFilter.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_UnaryFilter()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, StructuredQuery_UnaryFilter_OperandType>
      _StructuredQuery_UnaryFilter_OperandTypeByTag = {
    2: StructuredQuery_UnaryFilter_OperandType.field_2,
    0: StructuredQuery_UnaryFilter_OperandType.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredQuery.UnaryFilter',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: StructuredQuery_UnaryFilter.$_createMessage)
    ..oo(0, [2])
    ..aE<StructuredQuery_UnaryFilter_Operator>(1, _omitFieldNames ? '' : 'op',
        enumValues: StructuredQuery_UnaryFilter_Operator.values)
    ..aOM<StructuredQuery_FieldReference>(2, _omitFieldNames ? '' : 'field',
        subBuilder: StructuredQuery_FieldReference.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_UnaryFilter clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_UnaryFilter copyWith(
          void Function(StructuredQuery_UnaryFilter) updates) =>
      super.copyWith(
              (message) => updates(message as StructuredQuery_UnaryFilter))
          as StructuredQuery_UnaryFilter;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StructuredQuery_UnaryFilter() / StructuredQuery_UnaryFilter.new instead')
  static StructuredQuery_UnaryFilter create() =>
      StructuredQuery_UnaryFilter._();
  static $pb.GeneratedMessage $_createMessage() =>
      StructuredQuery_UnaryFilter._();
  @$core.override
  StructuredQuery_UnaryFilter createEmptyInstance() =>
      StructuredQuery_UnaryFilter._();
  @$core.pragma('dart2js:noInline')
  static StructuredQuery_UnaryFilter getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StructuredQuery_UnaryFilter>(
          StructuredQuery_UnaryFilter.$_createMessage);
  static StructuredQuery_UnaryFilter? _defaultInstance;

  @$pb.TagNumber(2)
  StructuredQuery_UnaryFilter_OperandType whichOperandType() =>
      _StructuredQuery_UnaryFilter_OperandTypeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  void clearOperandType() => $_clearField($_whichOneof(0));

  /// The unary operator to apply.
  @$pb.TagNumber(1)
  StructuredQuery_UnaryFilter_Operator get op => $_getN(0);
  @$pb.TagNumber(1)
  set op(StructuredQuery_UnaryFilter_Operator value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasOp() => $_has(0);
  @$pb.TagNumber(1)
  void clearOp() => $_clearField(1);

  /// The field to which to apply the operator.
  @$pb.TagNumber(2)
  StructuredQuery_FieldReference get field_2 => $_getN(1);
  @$pb.TagNumber(2)
  set field_2(StructuredQuery_FieldReference value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasField_2() => $_has(1);
  @$pb.TagNumber(2)
  void clearField_2() => $_clearField(2);
  @$pb.TagNumber(2)
  StructuredQuery_FieldReference ensureField_2() => $_ensure(1);
}

/// An order on a field.
class StructuredQuery_Order extends $pb.GeneratedMessage {
  factory StructuredQuery_Order({
    StructuredQuery_FieldReference? field_1,
    StructuredQuery_Direction? direction,
  }) {
    final result = StructuredQuery_Order._();
    if (field_1 != null) result.field_1 = field_1;
    if (direction != null) result.direction = direction;
    return result;
  }

  StructuredQuery_Order._();

  factory StructuredQuery_Order.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_Order()..mergeFromBuffer(data, registry);
  factory StructuredQuery_Order.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_Order()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredQuery.Order',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: StructuredQuery_Order.$_createMessage)
    ..aOM<StructuredQuery_FieldReference>(1, _omitFieldNames ? '' : 'field',
        subBuilder: StructuredQuery_FieldReference.$_createMessage)
    ..aE<StructuredQuery_Direction>(2, _omitFieldNames ? '' : 'direction',
        enumValues: StructuredQuery_Direction.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_Order clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_Order copyWith(
          void Function(StructuredQuery_Order) updates) =>
      super.copyWith((message) => updates(message as StructuredQuery_Order))
          as StructuredQuery_Order;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StructuredQuery_Order() / StructuredQuery_Order.new instead')
  static StructuredQuery_Order create() => StructuredQuery_Order._();
  static $pb.GeneratedMessage $_createMessage() => StructuredQuery_Order._();
  @$core.override
  StructuredQuery_Order createEmptyInstance() => StructuredQuery_Order._();
  @$core.pragma('dart2js:noInline')
  static StructuredQuery_Order getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StructuredQuery_Order>(
          StructuredQuery_Order.$_createMessage);
  static StructuredQuery_Order? _defaultInstance;

  /// The field to order by.
  @$pb.TagNumber(1)
  StructuredQuery_FieldReference get field_1 => $_getN(0);
  @$pb.TagNumber(1)
  set field_1(StructuredQuery_FieldReference value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasField_1() => $_has(0);
  @$pb.TagNumber(1)
  void clearField_1() => $_clearField(1);
  @$pb.TagNumber(1)
  StructuredQuery_FieldReference ensureField_1() => $_ensure(0);

  /// The direction to order by. Defaults to `ASCENDING`.
  @$pb.TagNumber(2)
  StructuredQuery_Direction get direction => $_getN(1);
  @$pb.TagNumber(2)
  set direction(StructuredQuery_Direction value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasDirection() => $_has(1);
  @$pb.TagNumber(2)
  void clearDirection() => $_clearField(2);
}

/// A reference to a field in a document, ex: `stats.operations`.
class StructuredQuery_FieldReference extends $pb.GeneratedMessage {
  factory StructuredQuery_FieldReference({
    $core.String? fieldPath,
  }) {
    final result = StructuredQuery_FieldReference._();
    if (fieldPath != null) result.fieldPath = fieldPath;
    return result;
  }

  StructuredQuery_FieldReference._();

  factory StructuredQuery_FieldReference.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_FieldReference()..mergeFromBuffer(data, registry);
  factory StructuredQuery_FieldReference.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_FieldReference()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredQuery.FieldReference',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: StructuredQuery_FieldReference.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'fieldPath')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_FieldReference clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_FieldReference copyWith(
          void Function(StructuredQuery_FieldReference) updates) =>
      super.copyWith(
              (message) => updates(message as StructuredQuery_FieldReference))
          as StructuredQuery_FieldReference;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StructuredQuery_FieldReference() / StructuredQuery_FieldReference.new instead')
  static StructuredQuery_FieldReference create() =>
      StructuredQuery_FieldReference._();
  static $pb.GeneratedMessage $_createMessage() =>
      StructuredQuery_FieldReference._();
  @$core.override
  StructuredQuery_FieldReference createEmptyInstance() =>
      StructuredQuery_FieldReference._();
  @$core.pragma('dart2js:noInline')
  static StructuredQuery_FieldReference getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StructuredQuery_FieldReference>(
          StructuredQuery_FieldReference.$_createMessage);
  static StructuredQuery_FieldReference? _defaultInstance;

  /// A reference to a field in a document.
  ///
  /// Requires:
  ///
  /// * MUST be a dot-delimited (`.`) string of segments, where each segment
  /// conforms to [document field name][google.firestore.v1.Document.fields]
  /// limitations.
  @$pb.TagNumber(2)
  $core.String get fieldPath => $_getSZ(0);
  @$pb.TagNumber(2)
  set fieldPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(2)
  $core.bool hasFieldPath() => $_has(0);
  @$pb.TagNumber(2)
  void clearFieldPath() => $_clearField(2);
}

/// The projection of document's fields to return.
class StructuredQuery_Projection extends $pb.GeneratedMessage {
  factory StructuredQuery_Projection({
    $core.Iterable<StructuredQuery_FieldReference>? fields,
  }) {
    final result = StructuredQuery_Projection._();
    if (fields != null) result.fields.addAll(fields);
    return result;
  }

  StructuredQuery_Projection._();

  factory StructuredQuery_Projection.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_Projection()..mergeFromBuffer(data, registry);
  factory StructuredQuery_Projection.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_Projection()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredQuery.Projection',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: StructuredQuery_Projection.$_createMessage)
    ..pPM<StructuredQuery_FieldReference>(2, _omitFieldNames ? '' : 'fields',
        subBuilder: StructuredQuery_FieldReference.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_Projection clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_Projection copyWith(
          void Function(StructuredQuery_Projection) updates) =>
      super.copyWith(
              (message) => updates(message as StructuredQuery_Projection))
          as StructuredQuery_Projection;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StructuredQuery_Projection() / StructuredQuery_Projection.new instead')
  static StructuredQuery_Projection create() => StructuredQuery_Projection._();
  static $pb.GeneratedMessage $_createMessage() =>
      StructuredQuery_Projection._();
  @$core.override
  StructuredQuery_Projection createEmptyInstance() =>
      StructuredQuery_Projection._();
  @$core.pragma('dart2js:noInline')
  static StructuredQuery_Projection getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StructuredQuery_Projection>(
          StructuredQuery_Projection.$_createMessage);
  static StructuredQuery_Projection? _defaultInstance;

  /// The fields to return.
  ///
  /// If empty, all fields are returned. To only return the name
  /// of the document, use `['__name__']`.
  @$pb.TagNumber(2)
  $pb.PbList<StructuredQuery_FieldReference> get fields => $_getList(0);
}

/// Nearest Neighbors search config. The ordering provided by FindNearest
/// supersedes the order_by stage. If multiple documents have the same vector
/// distance, the returned document order is not guaranteed to be stable
/// between queries.
class StructuredQuery_FindNearest extends $pb.GeneratedMessage {
  factory StructuredQuery_FindNearest({
    StructuredQuery_FieldReference? vectorField,
    $1.Value? queryVector,
    StructuredQuery_FindNearest_DistanceMeasure? distanceMeasure,
    $0.Int32Value? limit,
    $core.String? distanceResultField,
    $0.DoubleValue? distanceThreshold,
  }) {
    final result = StructuredQuery_FindNearest._();
    if (vectorField != null) result.vectorField = vectorField;
    if (queryVector != null) result.queryVector = queryVector;
    if (distanceMeasure != null) result.distanceMeasure = distanceMeasure;
    if (limit != null) result.limit = limit;
    if (distanceResultField != null)
      result.distanceResultField = distanceResultField;
    if (distanceThreshold != null) result.distanceThreshold = distanceThreshold;
    return result;
  }

  StructuredQuery_FindNearest._();

  factory StructuredQuery_FindNearest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_FindNearest()..mergeFromBuffer(data, registry);
  factory StructuredQuery_FindNearest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery_FindNearest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredQuery.FindNearest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: StructuredQuery_FindNearest.$_createMessage)
    ..aOM<StructuredQuery_FieldReference>(
        1, _omitFieldNames ? '' : 'vectorField',
        subBuilder: StructuredQuery_FieldReference.$_createMessage)
    ..aOM<$1.Value>(2, _omitFieldNames ? '' : 'queryVector',
        subBuilder: $1.Value.$_createMessage)
    ..aE<StructuredQuery_FindNearest_DistanceMeasure>(
        3, _omitFieldNames ? '' : 'distanceMeasure',
        enumValues: StructuredQuery_FindNearest_DistanceMeasure.values)
    ..aOM<$0.Int32Value>(4, _omitFieldNames ? '' : 'limit',
        subBuilder: $0.Int32Value.$_createMessage)
    ..aOS(5, _omitFieldNames ? '' : 'distanceResultField')
    ..aOM<$0.DoubleValue>(6, _omitFieldNames ? '' : 'distanceThreshold',
        subBuilder: $0.DoubleValue.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_FindNearest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery_FindNearest copyWith(
          void Function(StructuredQuery_FindNearest) updates) =>
      super.copyWith(
              (message) => updates(message as StructuredQuery_FindNearest))
          as StructuredQuery_FindNearest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StructuredQuery_FindNearest() / StructuredQuery_FindNearest.new instead')
  static StructuredQuery_FindNearest create() =>
      StructuredQuery_FindNearest._();
  static $pb.GeneratedMessage $_createMessage() =>
      StructuredQuery_FindNearest._();
  @$core.override
  StructuredQuery_FindNearest createEmptyInstance() =>
      StructuredQuery_FindNearest._();
  @$core.pragma('dart2js:noInline')
  static StructuredQuery_FindNearest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StructuredQuery_FindNearest>(
          StructuredQuery_FindNearest.$_createMessage);
  static StructuredQuery_FindNearest? _defaultInstance;

  /// Required. An indexed vector field to search upon. Only documents which
  /// contain vectors whose dimensionality match the query_vector can be
  /// returned.
  @$pb.TagNumber(1)
  StructuredQuery_FieldReference get vectorField => $_getN(0);
  @$pb.TagNumber(1)
  set vectorField(StructuredQuery_FieldReference value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasVectorField() => $_has(0);
  @$pb.TagNumber(1)
  void clearVectorField() => $_clearField(1);
  @$pb.TagNumber(1)
  StructuredQuery_FieldReference ensureVectorField() => $_ensure(0);

  /// Required. The query vector that we are searching on. Must be a vector of
  /// no more than 2048 dimensions.
  @$pb.TagNumber(2)
  $1.Value get queryVector => $_getN(1);
  @$pb.TagNumber(2)
  set queryVector($1.Value value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasQueryVector() => $_has(1);
  @$pb.TagNumber(2)
  void clearQueryVector() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.Value ensureQueryVector() => $_ensure(1);

  /// Required. The distance measure to use, required.
  @$pb.TagNumber(3)
  StructuredQuery_FindNearest_DistanceMeasure get distanceMeasure => $_getN(2);
  @$pb.TagNumber(3)
  set distanceMeasure(StructuredQuery_FindNearest_DistanceMeasure value) =>
      $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDistanceMeasure() => $_has(2);
  @$pb.TagNumber(3)
  void clearDistanceMeasure() => $_clearField(3);

  /// Required. The number of nearest neighbors to return. Must be a positive
  /// integer of no more than 1000.
  @$pb.TagNumber(4)
  $0.Int32Value get limit => $_getN(3);
  @$pb.TagNumber(4)
  set limit($0.Int32Value value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasLimit() => $_has(3);
  @$pb.TagNumber(4)
  void clearLimit() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.Int32Value ensureLimit() => $_ensure(3);

  /// Optional. Optional name of the field to output the result of the vector
  /// distance calculation. Must conform to [document field
  /// name][google.firestore.v1.Document.fields] limitations.
  @$pb.TagNumber(5)
  $core.String get distanceResultField => $_getSZ(4);
  @$pb.TagNumber(5)
  set distanceResultField($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDistanceResultField() => $_has(4);
  @$pb.TagNumber(5)
  void clearDistanceResultField() => $_clearField(5);

  /// Optional. Option to specify a threshold for which no less similar
  /// documents will be returned. The behavior of the specified
  /// `distance_measure` will affect the meaning of the distance threshold.
  /// Since DOT_PRODUCT distances increase when the vectors are more similar,
  /// the comparison is inverted.
  ///
  /// * For EUCLIDEAN, COSINE: `WHERE distance <= distance_threshold`
  /// * For DOT_PRODUCT:       `WHERE distance >= distance_threshold`
  @$pb.TagNumber(6)
  $0.DoubleValue get distanceThreshold => $_getN(5);
  @$pb.TagNumber(6)
  set distanceThreshold($0.DoubleValue value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasDistanceThreshold() => $_has(5);
  @$pb.TagNumber(6)
  void clearDistanceThreshold() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.DoubleValue ensureDistanceThreshold() => $_ensure(5);
}

/// A Firestore query.
///
/// The query stages are executed in the following order:
/// 1. from
/// 2. where
/// 3. select
/// 4. order_by + start_at + end_at
/// 5. offset
/// 6. limit
/// 7. find_nearest
class StructuredQuery extends $pb.GeneratedMessage {
  factory StructuredQuery({
    StructuredQuery_Projection? select,
    $core.Iterable<StructuredQuery_CollectionSelector>? from,
    StructuredQuery_Filter? where,
    $core.Iterable<StructuredQuery_Order>? orderBy,
    $0.Int32Value? limit,
    $core.int? offset,
    Cursor? startAt,
    Cursor? endAt,
    StructuredQuery_FindNearest? findNearest,
  }) {
    final result = StructuredQuery._();
    if (select != null) result.select = select;
    if (from != null) result.from.addAll(from);
    if (where != null) result.where = where;
    if (orderBy != null) result.orderBy.addAll(orderBy);
    if (limit != null) result.limit = limit;
    if (offset != null) result.offset = offset;
    if (startAt != null) result.startAt = startAt;
    if (endAt != null) result.endAt = endAt;
    if (findNearest != null) result.findNearest = findNearest;
    return result;
  }

  StructuredQuery._();

  factory StructuredQuery.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery()..mergeFromBuffer(data, registry);
  factory StructuredQuery.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredQuery()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredQuery',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: StructuredQuery.$_createMessage)
    ..aOM<StructuredQuery_Projection>(1, _omitFieldNames ? '' : 'select',
        subBuilder: StructuredQuery_Projection.$_createMessage)
    ..pPM<StructuredQuery_CollectionSelector>(2, _omitFieldNames ? '' : 'from',
        subBuilder: StructuredQuery_CollectionSelector.$_createMessage)
    ..aOM<StructuredQuery_Filter>(3, _omitFieldNames ? '' : 'where',
        subBuilder: StructuredQuery_Filter.$_createMessage)
    ..pPM<StructuredQuery_Order>(4, _omitFieldNames ? '' : 'orderBy',
        subBuilder: StructuredQuery_Order.$_createMessage)
    ..aOM<$0.Int32Value>(5, _omitFieldNames ? '' : 'limit',
        subBuilder: $0.Int32Value.$_createMessage)
    ..aI(6, _omitFieldNames ? '' : 'offset')
    ..aOM<Cursor>(7, _omitFieldNames ? '' : 'startAt',
        subBuilder: Cursor.$_createMessage)
    ..aOM<Cursor>(8, _omitFieldNames ? '' : 'endAt',
        subBuilder: Cursor.$_createMessage)
    ..aOM<StructuredQuery_FindNearest>(9, _omitFieldNames ? '' : 'findNearest',
        subBuilder: StructuredQuery_FindNearest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredQuery copyWith(void Function(StructuredQuery) updates) =>
      super.copyWith((message) => updates(message as StructuredQuery))
          as StructuredQuery;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StructuredQuery() / StructuredQuery.new instead')
  static StructuredQuery create() => StructuredQuery._();
  static $pb.GeneratedMessage $_createMessage() => StructuredQuery._();
  @$core.override
  StructuredQuery createEmptyInstance() => StructuredQuery._();
  @$core.pragma('dart2js:noInline')
  static StructuredQuery getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StructuredQuery>(
          StructuredQuery.$_createMessage);
  static StructuredQuery? _defaultInstance;

  /// Optional sub-set of the fields to return.
  ///
  /// This acts as a [DocumentMask][google.firestore.v1.DocumentMask] over the
  /// documents returned from a query. When not set, assumes that the caller
  /// wants all fields returned.
  @$pb.TagNumber(1)
  StructuredQuery_Projection get select => $_getN(0);
  @$pb.TagNumber(1)
  set select(StructuredQuery_Projection value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSelect() => $_has(0);
  @$pb.TagNumber(1)
  void clearSelect() => $_clearField(1);
  @$pb.TagNumber(1)
  StructuredQuery_Projection ensureSelect() => $_ensure(0);

  /// The collections to query.
  @$pb.TagNumber(2)
  $pb.PbList<StructuredQuery_CollectionSelector> get from => $_getList(1);

  /// The filter to apply.
  @$pb.TagNumber(3)
  StructuredQuery_Filter get where => $_getN(2);
  @$pb.TagNumber(3)
  set where(StructuredQuery_Filter value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasWhere() => $_has(2);
  @$pb.TagNumber(3)
  void clearWhere() => $_clearField(3);
  @$pb.TagNumber(3)
  StructuredQuery_Filter ensureWhere() => $_ensure(2);

  /// The order to apply to the query results.
  ///
  /// Callers can provide a full ordering, a partial ordering, or no ordering at
  /// all. While Firestore will always respect the provided order, the behavior
  /// for queries without a full ordering is different per database edition:
  ///
  /// In Standard edition, Firestore guarantees a stable ordering through the
  /// following rules:
  ///
  ///  * The `order_by` is required to reference all fields used with an
  ///    inequality filter.
  ///  * All fields that are required to be in the `order_by` but are not already
  ///    present are appended in lexicographical ordering of the field name.
  ///  * If an order on `__name__` is not specified, it is appended by default.
  ///
  /// Fields are appended with the same sort direction as the last order
  /// specified, or 'ASCENDING' if no order was specified. For example:
  ///
  ///  * `ORDER BY a` becomes `ORDER BY a ASC, __name__ ASC`
  ///  * `ORDER BY a DESC` becomes `ORDER BY a DESC, __name__ DESC`
  ///  * `WHERE a > 1` becomes `WHERE a > 1 ORDER BY a ASC, __name__ ASC`
  ///  * `WHERE __name__ > ... AND a > 1` becomes
  ///     `WHERE __name__ > ... AND a > 1 ORDER BY a ASC, __name__ ASC`
  ///
  /// In Enterprise edition, Firestore does not guarantee a stable ordering.
  /// Instead it will pick the most efficient ordering based on the indexes
  /// available at the time of query execution. This will result in a different
  /// ordering for queries that are otherwise identical. To ensure a stable
  /// ordering, always include a unique field in the `order_by` clause, such as
  /// `__name__`.
  @$pb.TagNumber(4)
  $pb.PbList<StructuredQuery_Order> get orderBy => $_getList(3);

  /// The maximum number of results to return.
  ///
  /// Applies after all other constraints.
  ///
  /// Requires:
  ///
  /// * The value must be greater than or equal to zero if specified.
  @$pb.TagNumber(5)
  $0.Int32Value get limit => $_getN(4);
  @$pb.TagNumber(5)
  set limit($0.Int32Value value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasLimit() => $_has(4);
  @$pb.TagNumber(5)
  void clearLimit() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.Int32Value ensureLimit() => $_ensure(4);

  /// The number of documents to skip before returning the first result.
  ///
  /// This applies after the constraints specified by the `WHERE`, `START AT`, &
  /// `END AT` but before the `LIMIT` clause.
  ///
  /// Requires:
  ///
  /// * The value must be greater than or equal to zero if specified.
  @$pb.TagNumber(6)
  $core.int get offset => $_getIZ(5);
  @$pb.TagNumber(6)
  set offset($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasOffset() => $_has(5);
  @$pb.TagNumber(6)
  void clearOffset() => $_clearField(6);

  /// A potential prefix of a position in the result set to start the query at.
  ///
  /// The ordering of the result set is based on the `ORDER BY` clause of the
  /// original query.
  ///
  /// ```
  /// SELECT * FROM k WHERE a = 1 AND b > 2 ORDER BY b ASC, __name__ ASC;
  /// ```
  ///
  /// This query's results are ordered by `(b ASC, __name__ ASC)`.
  ///
  /// Cursors can reference either the full ordering or a prefix of the location,
  /// though it cannot reference more fields than what are in the provided
  /// `ORDER BY`.
  ///
  /// Continuing off the example above, attaching the following start cursors
  /// will have varying impact:
  ///
  /// - `START BEFORE (2, /k/123)`: start the query right before `a = 1 AND
  ///    b > 2 AND __name__ > /k/123`.
  /// - `START AFTER (10)`: start the query right after `a = 1 AND b > 10`.
  ///
  /// Unlike `OFFSET` which requires scanning over the first N results to skip,
  /// a start cursor allows the query to begin at a logical position. This
  /// position is not required to match an actual result, it will scan forward
  /// from this position to find the next document.
  ///
  /// Requires:
  ///
  /// * The number of values cannot be greater than the number of fields
  ///   specified in the `ORDER BY` clause.
  @$pb.TagNumber(7)
  Cursor get startAt => $_getN(6);
  @$pb.TagNumber(7)
  set startAt(Cursor value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasStartAt() => $_has(6);
  @$pb.TagNumber(7)
  void clearStartAt() => $_clearField(7);
  @$pb.TagNumber(7)
  Cursor ensureStartAt() => $_ensure(6);

  /// A potential prefix of a position in the result set to end the query at.
  ///
  /// This is similar to `START_AT` but with it controlling the end position
  /// rather than the start position.
  ///
  /// Requires:
  ///
  /// * The number of values cannot be greater than the number of fields
  ///   specified in the `ORDER BY` clause.
  @$pb.TagNumber(8)
  Cursor get endAt => $_getN(7);
  @$pb.TagNumber(8)
  set endAt(Cursor value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasEndAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearEndAt() => $_clearField(8);
  @$pb.TagNumber(8)
  Cursor ensureEndAt() => $_ensure(7);

  /// Optional. A potential nearest neighbors search.
  ///
  /// Applies after all other filters and ordering.
  ///
  /// Finds the closest vector embeddings to the given query vector.
  @$pb.TagNumber(9)
  StructuredQuery_FindNearest get findNearest => $_getN(8);
  @$pb.TagNumber(9)
  set findNearest(StructuredQuery_FindNearest value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasFindNearest() => $_has(8);
  @$pb.TagNumber(9)
  void clearFindNearest() => $_clearField(9);
  @$pb.TagNumber(9)
  StructuredQuery_FindNearest ensureFindNearest() => $_ensure(8);
}

/// Count of documents that match the query.
///
/// The `COUNT(*)` aggregation function operates on the entire document
/// so it does not require a field reference.
class StructuredAggregationQuery_Aggregation_Count
    extends $pb.GeneratedMessage {
  factory StructuredAggregationQuery_Aggregation_Count({
    $0.Int64Value? upTo,
  }) {
    final result = StructuredAggregationQuery_Aggregation_Count._();
    if (upTo != null) result.upTo = upTo;
    return result;
  }

  StructuredAggregationQuery_Aggregation_Count._();

  factory StructuredAggregationQuery_Aggregation_Count.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredAggregationQuery_Aggregation_Count()
        ..mergeFromBuffer(data, registry);
  factory StructuredAggregationQuery_Aggregation_Count.fromJson(
          $core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredAggregationQuery_Aggregation_Count()
        ..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredAggregationQuery.Aggregation.Count',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance:
          StructuredAggregationQuery_Aggregation_Count.$_createMessage)
    ..aOM<$0.Int64Value>(1, _omitFieldNames ? '' : 'upTo',
        subBuilder: $0.Int64Value.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredAggregationQuery_Aggregation_Count clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredAggregationQuery_Aggregation_Count copyWith(
          void Function(StructuredAggregationQuery_Aggregation_Count)
              updates) =>
      super.copyWith((message) =>
              updates(message as StructuredAggregationQuery_Aggregation_Count))
          as StructuredAggregationQuery_Aggregation_Count;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StructuredAggregationQuery_Aggregation_Count() / StructuredAggregationQuery_Aggregation_Count.new instead')
  static StructuredAggregationQuery_Aggregation_Count create() =>
      StructuredAggregationQuery_Aggregation_Count._();
  static $pb.GeneratedMessage $_createMessage() =>
      StructuredAggregationQuery_Aggregation_Count._();
  @$core.override
  StructuredAggregationQuery_Aggregation_Count createEmptyInstance() =>
      StructuredAggregationQuery_Aggregation_Count._();
  @$core.pragma('dart2js:noInline')
  static StructuredAggregationQuery_Aggregation_Count getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
              StructuredAggregationQuery_Aggregation_Count>(
          StructuredAggregationQuery_Aggregation_Count.$_createMessage);
  static StructuredAggregationQuery_Aggregation_Count? _defaultInstance;

  /// Optional. Optional constraint on the maximum number of documents to
  /// count.
  ///
  /// This provides a way to set an upper bound on the number of documents
  /// to scan, limiting latency, and cost.
  ///
  /// Unspecified is interpreted as no bound.
  ///
  /// High-Level Example:
  ///
  /// ```
  /// AGGREGATE COUNT_UP_TO(1000) OVER ( SELECT * FROM k );
  /// ```
  ///
  /// Requires:
  ///
  /// * Must be greater than zero when present.
  @$pb.TagNumber(1)
  $0.Int64Value get upTo => $_getN(0);
  @$pb.TagNumber(1)
  set upTo($0.Int64Value value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUpTo() => $_has(0);
  @$pb.TagNumber(1)
  void clearUpTo() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.Int64Value ensureUpTo() => $_ensure(0);
}

/// Sum of the values of the requested field.
///
/// * Only numeric values will be aggregated. All non-numeric values
/// including `NULL` are skipped.
///
/// * If the aggregated values contain `NaN`, returns `NaN`. Infinity math
/// follows IEEE-754 standards.
///
/// * If the aggregated value set is empty, returns 0.
///
/// * Returns a 64-bit integer if all aggregated numbers are integers and the
/// sum result does not overflow. Otherwise, the result is returned as a
/// double. Note that even if all the aggregated values are integers, the
/// result is returned as a double if it cannot fit within a 64-bit signed
/// integer. When this occurs, the returned value will lose precision.
///
/// * When underflow occurs, floating-point aggregation is non-deterministic.
/// This means that running the same query repeatedly without any changes to
/// the underlying values could produce slightly different results each
/// time. In those cases, values should be stored as integers over
/// floating-point numbers.
class StructuredAggregationQuery_Aggregation_Sum extends $pb.GeneratedMessage {
  factory StructuredAggregationQuery_Aggregation_Sum({
    StructuredQuery_FieldReference? field_1,
  }) {
    final result = StructuredAggregationQuery_Aggregation_Sum._();
    if (field_1 != null) result.field_1 = field_1;
    return result;
  }

  StructuredAggregationQuery_Aggregation_Sum._();

  factory StructuredAggregationQuery_Aggregation_Sum.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredAggregationQuery_Aggregation_Sum()
        ..mergeFromBuffer(data, registry);
  factory StructuredAggregationQuery_Aggregation_Sum.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredAggregationQuery_Aggregation_Sum()
        ..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredAggregationQuery.Aggregation.Sum',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance:
          StructuredAggregationQuery_Aggregation_Sum.$_createMessage)
    ..aOM<StructuredQuery_FieldReference>(1, _omitFieldNames ? '' : 'field',
        subBuilder: StructuredQuery_FieldReference.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredAggregationQuery_Aggregation_Sum clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredAggregationQuery_Aggregation_Sum copyWith(
          void Function(StructuredAggregationQuery_Aggregation_Sum) updates) =>
      super.copyWith((message) =>
              updates(message as StructuredAggregationQuery_Aggregation_Sum))
          as StructuredAggregationQuery_Aggregation_Sum;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StructuredAggregationQuery_Aggregation_Sum() / StructuredAggregationQuery_Aggregation_Sum.new instead')
  static StructuredAggregationQuery_Aggregation_Sum create() =>
      StructuredAggregationQuery_Aggregation_Sum._();
  static $pb.GeneratedMessage $_createMessage() =>
      StructuredAggregationQuery_Aggregation_Sum._();
  @$core.override
  StructuredAggregationQuery_Aggregation_Sum createEmptyInstance() =>
      StructuredAggregationQuery_Aggregation_Sum._();
  @$core.pragma('dart2js:noInline')
  static StructuredAggregationQuery_Aggregation_Sum getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
              StructuredAggregationQuery_Aggregation_Sum>(
          StructuredAggregationQuery_Aggregation_Sum.$_createMessage);
  static StructuredAggregationQuery_Aggregation_Sum? _defaultInstance;

  /// The field to aggregate on.
  @$pb.TagNumber(1)
  StructuredQuery_FieldReference get field_1 => $_getN(0);
  @$pb.TagNumber(1)
  set field_1(StructuredQuery_FieldReference value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasField_1() => $_has(0);
  @$pb.TagNumber(1)
  void clearField_1() => $_clearField(1);
  @$pb.TagNumber(1)
  StructuredQuery_FieldReference ensureField_1() => $_ensure(0);
}

/// Average of the values of the requested field.
///
/// * Only numeric values will be aggregated. All non-numeric values
/// including `NULL` are skipped.
///
/// * If the aggregated values contain `NaN`, returns `NaN`. Infinity math
/// follows IEEE-754 standards.
///
/// * If the aggregated value set is empty, returns `NULL`.
///
/// * Always returns the result as a double.
class StructuredAggregationQuery_Aggregation_Avg extends $pb.GeneratedMessage {
  factory StructuredAggregationQuery_Aggregation_Avg({
    StructuredQuery_FieldReference? field_1,
  }) {
    final result = StructuredAggregationQuery_Aggregation_Avg._();
    if (field_1 != null) result.field_1 = field_1;
    return result;
  }

  StructuredAggregationQuery_Aggregation_Avg._();

  factory StructuredAggregationQuery_Aggregation_Avg.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredAggregationQuery_Aggregation_Avg()
        ..mergeFromBuffer(data, registry);
  factory StructuredAggregationQuery_Aggregation_Avg.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredAggregationQuery_Aggregation_Avg()
        ..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredAggregationQuery.Aggregation.Avg',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance:
          StructuredAggregationQuery_Aggregation_Avg.$_createMessage)
    ..aOM<StructuredQuery_FieldReference>(1, _omitFieldNames ? '' : 'field',
        subBuilder: StructuredQuery_FieldReference.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredAggregationQuery_Aggregation_Avg clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredAggregationQuery_Aggregation_Avg copyWith(
          void Function(StructuredAggregationQuery_Aggregation_Avg) updates) =>
      super.copyWith((message) =>
              updates(message as StructuredAggregationQuery_Aggregation_Avg))
          as StructuredAggregationQuery_Aggregation_Avg;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StructuredAggregationQuery_Aggregation_Avg() / StructuredAggregationQuery_Aggregation_Avg.new instead')
  static StructuredAggregationQuery_Aggregation_Avg create() =>
      StructuredAggregationQuery_Aggregation_Avg._();
  static $pb.GeneratedMessage $_createMessage() =>
      StructuredAggregationQuery_Aggregation_Avg._();
  @$core.override
  StructuredAggregationQuery_Aggregation_Avg createEmptyInstance() =>
      StructuredAggregationQuery_Aggregation_Avg._();
  @$core.pragma('dart2js:noInline')
  static StructuredAggregationQuery_Aggregation_Avg getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
              StructuredAggregationQuery_Aggregation_Avg>(
          StructuredAggregationQuery_Aggregation_Avg.$_createMessage);
  static StructuredAggregationQuery_Aggregation_Avg? _defaultInstance;

  /// The field to aggregate on.
  @$pb.TagNumber(1)
  StructuredQuery_FieldReference get field_1 => $_getN(0);
  @$pb.TagNumber(1)
  set field_1(StructuredQuery_FieldReference value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasField_1() => $_has(0);
  @$pb.TagNumber(1)
  void clearField_1() => $_clearField(1);
  @$pb.TagNumber(1)
  StructuredQuery_FieldReference ensureField_1() => $_ensure(0);
}

enum StructuredAggregationQuery_Aggregation_Operator { count, sum, avg, notSet }

/// Defines an aggregation that produces a single result.
class StructuredAggregationQuery_Aggregation extends $pb.GeneratedMessage {
  factory StructuredAggregationQuery_Aggregation({
    StructuredAggregationQuery_Aggregation_Count? count,
    StructuredAggregationQuery_Aggregation_Sum? sum,
    StructuredAggregationQuery_Aggregation_Avg? avg,
    $core.String? alias,
  }) {
    final result = StructuredAggregationQuery_Aggregation._();
    if (count != null) result.count = count;
    if (sum != null) result.sum = sum;
    if (avg != null) result.avg = avg;
    if (alias != null) result.alias = alias;
    return result;
  }

  StructuredAggregationQuery_Aggregation._();

  factory StructuredAggregationQuery_Aggregation.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredAggregationQuery_Aggregation()..mergeFromBuffer(data, registry);
  factory StructuredAggregationQuery_Aggregation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredAggregationQuery_Aggregation()..mergeFromJson(json, registry);

  static const $core
      .Map<$core.int, StructuredAggregationQuery_Aggregation_Operator>
      _StructuredAggregationQuery_Aggregation_OperatorByTag = {
    1: StructuredAggregationQuery_Aggregation_Operator.count,
    2: StructuredAggregationQuery_Aggregation_Operator.sum,
    3: StructuredAggregationQuery_Aggregation_Operator.avg,
    0: StructuredAggregationQuery_Aggregation_Operator.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredAggregationQuery.Aggregation',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance:
          StructuredAggregationQuery_Aggregation.$_createMessage)
    ..oo(0, [1, 2, 3])
    ..aOM<StructuredAggregationQuery_Aggregation_Count>(
        1, _omitFieldNames ? '' : 'count',
        subBuilder:
            StructuredAggregationQuery_Aggregation_Count.$_createMessage)
    ..aOM<StructuredAggregationQuery_Aggregation_Sum>(
        2, _omitFieldNames ? '' : 'sum',
        subBuilder: StructuredAggregationQuery_Aggregation_Sum.$_createMessage)
    ..aOM<StructuredAggregationQuery_Aggregation_Avg>(
        3, _omitFieldNames ? '' : 'avg',
        subBuilder: StructuredAggregationQuery_Aggregation_Avg.$_createMessage)
    ..aOS(7, _omitFieldNames ? '' : 'alias')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredAggregationQuery_Aggregation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredAggregationQuery_Aggregation copyWith(
          void Function(StructuredAggregationQuery_Aggregation) updates) =>
      super.copyWith((message) =>
              updates(message as StructuredAggregationQuery_Aggregation))
          as StructuredAggregationQuery_Aggregation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StructuredAggregationQuery_Aggregation() / StructuredAggregationQuery_Aggregation.new instead')
  static StructuredAggregationQuery_Aggregation create() =>
      StructuredAggregationQuery_Aggregation._();
  static $pb.GeneratedMessage $_createMessage() =>
      StructuredAggregationQuery_Aggregation._();
  @$core.override
  StructuredAggregationQuery_Aggregation createEmptyInstance() =>
      StructuredAggregationQuery_Aggregation._();
  @$core.pragma('dart2js:noInline')
  static StructuredAggregationQuery_Aggregation getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
              StructuredAggregationQuery_Aggregation>(
          StructuredAggregationQuery_Aggregation.$_createMessage);
  static StructuredAggregationQuery_Aggregation? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  StructuredAggregationQuery_Aggregation_Operator whichOperator() =>
      _StructuredAggregationQuery_Aggregation_OperatorByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearOperator() => $_clearField($_whichOneof(0));

  /// Count aggregator.
  @$pb.TagNumber(1)
  StructuredAggregationQuery_Aggregation_Count get count => $_getN(0);
  @$pb.TagNumber(1)
  set count(StructuredAggregationQuery_Aggregation_Count value) =>
      $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearCount() => $_clearField(1);
  @$pb.TagNumber(1)
  StructuredAggregationQuery_Aggregation_Count ensureCount() => $_ensure(0);

  /// Sum aggregator.
  @$pb.TagNumber(2)
  StructuredAggregationQuery_Aggregation_Sum get sum => $_getN(1);
  @$pb.TagNumber(2)
  set sum(StructuredAggregationQuery_Aggregation_Sum value) =>
      $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSum() => $_has(1);
  @$pb.TagNumber(2)
  void clearSum() => $_clearField(2);
  @$pb.TagNumber(2)
  StructuredAggregationQuery_Aggregation_Sum ensureSum() => $_ensure(1);

  /// Average aggregator.
  @$pb.TagNumber(3)
  StructuredAggregationQuery_Aggregation_Avg get avg => $_getN(2);
  @$pb.TagNumber(3)
  set avg(StructuredAggregationQuery_Aggregation_Avg value) =>
      $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAvg() => $_has(2);
  @$pb.TagNumber(3)
  void clearAvg() => $_clearField(3);
  @$pb.TagNumber(3)
  StructuredAggregationQuery_Aggregation_Avg ensureAvg() => $_ensure(2);

  /// Optional. Optional name of the field to store the result of the
  /// aggregation into.
  ///
  /// If not provided, Firestore will pick a default name following the format
  /// `field_<incremental_id++>`. For example:
  ///
  /// ```
  /// AGGREGATE
  ///   COUNT_UP_TO(1) AS count_up_to_1,
  ///   COUNT_UP_TO(2),
  ///   COUNT_UP_TO(3) AS count_up_to_3,
  ///   COUNT(*)
  /// OVER (
  ///   ...
  /// );
  /// ```
  ///
  /// becomes:
  ///
  /// ```
  /// AGGREGATE
  ///   COUNT_UP_TO(1) AS count_up_to_1,
  ///   COUNT_UP_TO(2) AS field_1,
  ///   COUNT_UP_TO(3) AS count_up_to_3,
  ///   COUNT(*) AS field_2
  /// OVER (
  ///   ...
  /// );
  /// ```
  ///
  /// Requires:
  ///
  /// * Must be unique across all aggregation aliases.
  /// * Conform to [document field name][google.firestore.v1.Document.fields]
  /// limitations.
  @$pb.TagNumber(7)
  $core.String get alias => $_getSZ(3);
  @$pb.TagNumber(7)
  set alias($core.String value) => $_setString(3, value);
  @$pb.TagNumber(7)
  $core.bool hasAlias() => $_has(3);
  @$pb.TagNumber(7)
  void clearAlias() => $_clearField(7);
}

enum StructuredAggregationQuery_QueryType { structuredQuery, notSet }

/// Firestore query for running an aggregation over a
/// [StructuredQuery][google.firestore.v1.StructuredQuery].
class StructuredAggregationQuery extends $pb.GeneratedMessage {
  factory StructuredAggregationQuery({
    StructuredQuery? structuredQuery,
    $core.Iterable<StructuredAggregationQuery_Aggregation>? aggregations,
  }) {
    final result = StructuredAggregationQuery._();
    if (structuredQuery != null) result.structuredQuery = structuredQuery;
    if (aggregations != null) result.aggregations.addAll(aggregations);
    return result;
  }

  StructuredAggregationQuery._();

  factory StructuredAggregationQuery.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredAggregationQuery()..mergeFromBuffer(data, registry);
  factory StructuredAggregationQuery.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredAggregationQuery()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, StructuredAggregationQuery_QueryType>
      _StructuredAggregationQuery_QueryTypeByTag = {
    1: StructuredAggregationQuery_QueryType.structuredQuery,
    0: StructuredAggregationQuery_QueryType.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredAggregationQuery',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: StructuredAggregationQuery.$_createMessage)
    ..oo(0, [1])
    ..aOM<StructuredQuery>(1, _omitFieldNames ? '' : 'structuredQuery',
        subBuilder: StructuredQuery.$_createMessage)
    ..pPM<StructuredAggregationQuery_Aggregation>(
        3, _omitFieldNames ? '' : 'aggregations',
        subBuilder: StructuredAggregationQuery_Aggregation.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredAggregationQuery clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredAggregationQuery copyWith(
          void Function(StructuredAggregationQuery) updates) =>
      super.copyWith(
              (message) => updates(message as StructuredAggregationQuery))
          as StructuredAggregationQuery;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StructuredAggregationQuery() / StructuredAggregationQuery.new instead')
  static StructuredAggregationQuery create() => StructuredAggregationQuery._();
  static $pb.GeneratedMessage $_createMessage() =>
      StructuredAggregationQuery._();
  @$core.override
  StructuredAggregationQuery createEmptyInstance() =>
      StructuredAggregationQuery._();
  @$core.pragma('dart2js:noInline')
  static StructuredAggregationQuery getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StructuredAggregationQuery>(
          StructuredAggregationQuery.$_createMessage);
  static StructuredAggregationQuery? _defaultInstance;

  @$pb.TagNumber(1)
  StructuredAggregationQuery_QueryType whichQueryType() =>
      _StructuredAggregationQuery_QueryTypeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  void clearQueryType() => $_clearField($_whichOneof(0));

  /// Nested structured query.
  @$pb.TagNumber(1)
  StructuredQuery get structuredQuery => $_getN(0);
  @$pb.TagNumber(1)
  set structuredQuery(StructuredQuery value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStructuredQuery() => $_has(0);
  @$pb.TagNumber(1)
  void clearStructuredQuery() => $_clearField(1);
  @$pb.TagNumber(1)
  StructuredQuery ensureStructuredQuery() => $_ensure(0);

  /// Optional. Series of aggregations to apply over the results of the
  /// `structured_query`.
  ///
  /// Requires:
  ///
  /// * A minimum of one and maximum of five aggregations per query.
  @$pb.TagNumber(3)
  $pb.PbList<StructuredAggregationQuery_Aggregation> get aggregations =>
      $_getList(1);
}

/// A position in a query result set.
class Cursor extends $pb.GeneratedMessage {
  factory Cursor({
    $core.Iterable<$1.Value>? values,
    $core.bool? before,
  }) {
    final result = Cursor._();
    if (values != null) result.values.addAll(values);
    if (before != null) result.before = before;
    return result;
  }

  Cursor._();

  factory Cursor.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Cursor()..mergeFromBuffer(data, registry);
  factory Cursor.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Cursor()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Cursor',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: Cursor.$_createMessage)
    ..pPM<$1.Value>(1, _omitFieldNames ? '' : 'values',
        subBuilder: $1.Value.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'before')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Cursor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Cursor copyWith(void Function(Cursor) updates) =>
      super.copyWith((message) => updates(message as Cursor)) as Cursor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Cursor() / Cursor.new instead')
  static Cursor create() => Cursor._();
  static $pb.GeneratedMessage $_createMessage() => Cursor._();
  @$core.override
  Cursor createEmptyInstance() => Cursor._();
  @$core.pragma('dart2js:noInline')
  static Cursor getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Cursor>(Cursor.$_createMessage);
  static Cursor? _defaultInstance;

  /// The values that represent a position, in the order they appear in
  /// the order by clause of a query.
  ///
  /// Can contain fewer values than specified in the order by clause.
  @$pb.TagNumber(1)
  $pb.PbList<$1.Value> get values => $_getList(0);

  /// If the position is just before or just after the given values, relative
  /// to the sort order defined by the query.
  @$pb.TagNumber(2)
  $core.bool get before => $_getBF(1);
  @$pb.TagNumber(2)
  set before($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBefore() => $_has(1);
  @$pb.TagNumber(2)
  void clearBefore() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
