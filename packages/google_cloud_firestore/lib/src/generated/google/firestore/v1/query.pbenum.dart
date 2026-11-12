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

/// A sort direction.
class StructuredQuery_Direction extends $pb.ProtobufEnum {
  /// Unspecified.
  static const StructuredQuery_Direction DIRECTION_UNSPECIFIED =
      StructuredQuery_Direction._(
          0, _omitEnumNames ? '' : 'DIRECTION_UNSPECIFIED');

  /// Ascending.
  static const StructuredQuery_Direction ASCENDING =
      StructuredQuery_Direction._(1, _omitEnumNames ? '' : 'ASCENDING');

  /// Descending.
  static const StructuredQuery_Direction DESCENDING =
      StructuredQuery_Direction._(2, _omitEnumNames ? '' : 'DESCENDING');

  static const $core.List<StructuredQuery_Direction> values =
      <StructuredQuery_Direction>[
    DIRECTION_UNSPECIFIED,
    ASCENDING,
    DESCENDING,
  ];

  static final $core.List<StructuredQuery_Direction?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static StructuredQuery_Direction? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const StructuredQuery_Direction._(super.value, super.name);
}

/// A composite filter operator.
class StructuredQuery_CompositeFilter_Operator extends $pb.ProtobufEnum {
  /// Unspecified. This value must not be used.
  static const StructuredQuery_CompositeFilter_Operator OPERATOR_UNSPECIFIED =
      StructuredQuery_CompositeFilter_Operator._(
          0, _omitEnumNames ? '' : 'OPERATOR_UNSPECIFIED');

  /// Documents are required to satisfy all of the combined filters.
  static const StructuredQuery_CompositeFilter_Operator AND =
      StructuredQuery_CompositeFilter_Operator._(
          1, _omitEnumNames ? '' : 'AND');

  /// Documents are required to satisfy at least one of the combined filters.
  static const StructuredQuery_CompositeFilter_Operator OR =
      StructuredQuery_CompositeFilter_Operator._(2, _omitEnumNames ? '' : 'OR');

  static const $core.List<StructuredQuery_CompositeFilter_Operator> values =
      <StructuredQuery_CompositeFilter_Operator>[
    OPERATOR_UNSPECIFIED,
    AND,
    OR,
  ];

  static final $core.List<StructuredQuery_CompositeFilter_Operator?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static StructuredQuery_CompositeFilter_Operator? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const StructuredQuery_CompositeFilter_Operator._(super.value, super.name);
}

/// A field filter operator.
class StructuredQuery_FieldFilter_Operator extends $pb.ProtobufEnum {
  /// Unspecified. This value must not be used.
  static const StructuredQuery_FieldFilter_Operator OPERATOR_UNSPECIFIED =
      StructuredQuery_FieldFilter_Operator._(
          0, _omitEnumNames ? '' : 'OPERATOR_UNSPECIFIED');

  /// The given `field` is less than the given `value`.
  ///
  /// Requires:
  ///
  /// * That `field` come first in `order_by`.
  static const StructuredQuery_FieldFilter_Operator LESS_THAN =
      StructuredQuery_FieldFilter_Operator._(
          1, _omitEnumNames ? '' : 'LESS_THAN');

  /// The given `field` is less than or equal to the given `value`.
  ///
  /// Requires:
  ///
  /// * That `field` come first in `order_by`.
  static const StructuredQuery_FieldFilter_Operator LESS_THAN_OR_EQUAL =
      StructuredQuery_FieldFilter_Operator._(
          2, _omitEnumNames ? '' : 'LESS_THAN_OR_EQUAL');

  /// The given `field` is greater than the given `value`.
  ///
  /// Requires:
  ///
  /// * That `field` come first in `order_by`.
  static const StructuredQuery_FieldFilter_Operator GREATER_THAN =
      StructuredQuery_FieldFilter_Operator._(
          3, _omitEnumNames ? '' : 'GREATER_THAN');

  /// The given `field` is greater than or equal to the given `value`.
  ///
  /// Requires:
  ///
  /// * That `field` come first in `order_by`.
  static const StructuredQuery_FieldFilter_Operator GREATER_THAN_OR_EQUAL =
      StructuredQuery_FieldFilter_Operator._(
          4, _omitEnumNames ? '' : 'GREATER_THAN_OR_EQUAL');

  /// The given `field` is equal to the given `value`.
  static const StructuredQuery_FieldFilter_Operator EQUAL =
      StructuredQuery_FieldFilter_Operator._(5, _omitEnumNames ? '' : 'EQUAL');

  /// The given `field` is not equal to the given `value`.
  ///
  /// Requires:
  ///
  /// * No other `NOT_EQUAL`, `NOT_IN`, `IS_NOT_NULL`, or `IS_NOT_NAN`.
  /// * That `field` comes first in the `order_by`.
  static const StructuredQuery_FieldFilter_Operator NOT_EQUAL =
      StructuredQuery_FieldFilter_Operator._(
          6, _omitEnumNames ? '' : 'NOT_EQUAL');

  /// The given `field` is an array that contains the given `value`.
  static const StructuredQuery_FieldFilter_Operator ARRAY_CONTAINS =
      StructuredQuery_FieldFilter_Operator._(
          7, _omitEnumNames ? '' : 'ARRAY_CONTAINS');

  /// The given `field` is equal to at least one value in the given array.
  ///
  /// Requires:
  ///
  /// * That `value` is a non-empty `ArrayValue`, subject to disjunction
  ///   limits.
  /// * No `NOT_IN` filters in the same query.
  static const StructuredQuery_FieldFilter_Operator IN =
      StructuredQuery_FieldFilter_Operator._(8, _omitEnumNames ? '' : 'IN');

  /// The given `field` is an array that contains any of the values in the
  /// given array.
  ///
  /// Requires:
  ///
  /// * That `value` is a non-empty `ArrayValue`, subject to disjunction
  ///   limits.
  /// * No other `ARRAY_CONTAINS_ANY` filters within the same disjunction.
  /// * No `NOT_IN` filters in the same query.
  static const StructuredQuery_FieldFilter_Operator ARRAY_CONTAINS_ANY =
      StructuredQuery_FieldFilter_Operator._(
          9, _omitEnumNames ? '' : 'ARRAY_CONTAINS_ANY');

  /// The value of the `field` is not in the given array.
  ///
  /// Requires:
  ///
  /// * That `value` is a non-empty `ArrayValue` with at most 10 values.
  /// * No other `OR`, `IN`, `ARRAY_CONTAINS_ANY`, `NOT_IN`, `NOT_EQUAL`,
  ///   `IS_NOT_NULL`, or `IS_NOT_NAN`.
  /// * That `field` comes first in the `order_by`.
  static const StructuredQuery_FieldFilter_Operator NOT_IN =
      StructuredQuery_FieldFilter_Operator._(
          10, _omitEnumNames ? '' : 'NOT_IN');

  static const $core.List<StructuredQuery_FieldFilter_Operator> values =
      <StructuredQuery_FieldFilter_Operator>[
    OPERATOR_UNSPECIFIED,
    LESS_THAN,
    LESS_THAN_OR_EQUAL,
    GREATER_THAN,
    GREATER_THAN_OR_EQUAL,
    EQUAL,
    NOT_EQUAL,
    ARRAY_CONTAINS,
    IN,
    ARRAY_CONTAINS_ANY,
    NOT_IN,
  ];

  static final $core.List<StructuredQuery_FieldFilter_Operator?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 10);
  static StructuredQuery_FieldFilter_Operator? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const StructuredQuery_FieldFilter_Operator._(super.value, super.name);
}

/// A unary operator.
class StructuredQuery_UnaryFilter_Operator extends $pb.ProtobufEnum {
  /// Unspecified. This value must not be used.
  static const StructuredQuery_UnaryFilter_Operator OPERATOR_UNSPECIFIED =
      StructuredQuery_UnaryFilter_Operator._(
          0, _omitEnumNames ? '' : 'OPERATOR_UNSPECIFIED');

  /// The given `field` is equal to `NaN`.
  static const StructuredQuery_UnaryFilter_Operator IS_NAN =
      StructuredQuery_UnaryFilter_Operator._(2, _omitEnumNames ? '' : 'IS_NAN');

  /// The given `field` is equal to `NULL`.
  static const StructuredQuery_UnaryFilter_Operator IS_NULL =
      StructuredQuery_UnaryFilter_Operator._(
          3, _omitEnumNames ? '' : 'IS_NULL');

  /// The given `field` is not equal to `NaN`.
  ///
  /// Requires:
  ///
  /// * No other `NOT_EQUAL`, `NOT_IN`, `IS_NOT_NULL`, or `IS_NOT_NAN`.
  /// * That `field` comes first in the `order_by`.
  static const StructuredQuery_UnaryFilter_Operator IS_NOT_NAN =
      StructuredQuery_UnaryFilter_Operator._(
          4, _omitEnumNames ? '' : 'IS_NOT_NAN');

  /// The given `field` is not equal to `NULL`.
  ///
  /// Requires:
  ///
  /// * A single `NOT_EQUAL`, `NOT_IN`, `IS_NOT_NULL`, or `IS_NOT_NAN`.
  /// * That `field` comes first in the `order_by`.
  static const StructuredQuery_UnaryFilter_Operator IS_NOT_NULL =
      StructuredQuery_UnaryFilter_Operator._(
          5, _omitEnumNames ? '' : 'IS_NOT_NULL');

  static const $core.List<StructuredQuery_UnaryFilter_Operator> values =
      <StructuredQuery_UnaryFilter_Operator>[
    OPERATOR_UNSPECIFIED,
    IS_NAN,
    IS_NULL,
    IS_NOT_NAN,
    IS_NOT_NULL,
  ];

  static final $core.List<StructuredQuery_UnaryFilter_Operator?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static StructuredQuery_UnaryFilter_Operator? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const StructuredQuery_UnaryFilter_Operator._(super.value, super.name);
}

/// The distance measure to use when comparing vectors.
class StructuredQuery_FindNearest_DistanceMeasure extends $pb.ProtobufEnum {
  /// Should not be set.
  static const StructuredQuery_FindNearest_DistanceMeasure
      DISTANCE_MEASURE_UNSPECIFIED =
      StructuredQuery_FindNearest_DistanceMeasure._(
          0, _omitEnumNames ? '' : 'DISTANCE_MEASURE_UNSPECIFIED');

  /// Measures the EUCLIDEAN distance between the vectors. See
  /// [Euclidean](https://en.wikipedia.org/wiki/Euclidean_distance) to learn
  /// more. The resulting distance decreases the more similar two vectors
  /// are.
  static const StructuredQuery_FindNearest_DistanceMeasure EUCLIDEAN =
      StructuredQuery_FindNearest_DistanceMeasure._(
          1, _omitEnumNames ? '' : 'EUCLIDEAN');

  /// COSINE distance compares vectors based on the angle between them, which
  /// allows you to measure similarity that isn't based on the vectors
  /// magnitude. We recommend using DOT_PRODUCT with unit normalized vectors
  /// instead of COSINE distance, which is mathematically equivalent with
  /// better performance. See [Cosine
  /// Similarity](https://en.wikipedia.org/wiki/Cosine_similarity) to learn
  /// more about COSINE similarity and COSINE distance. The resulting
  /// COSINE distance decreases the more similar two vectors are.
  static const StructuredQuery_FindNearest_DistanceMeasure COSINE =
      StructuredQuery_FindNearest_DistanceMeasure._(
          2, _omitEnumNames ? '' : 'COSINE');

  /// Similar to cosine but is affected by the magnitude of the vectors. See
  /// [Dot Product](https://en.wikipedia.org/wiki/Dot_product) to learn more.
  /// The resulting distance increases the more similar two vectors are.
  static const StructuredQuery_FindNearest_DistanceMeasure DOT_PRODUCT =
      StructuredQuery_FindNearest_DistanceMeasure._(
          3, _omitEnumNames ? '' : 'DOT_PRODUCT');

  static const $core.List<StructuredQuery_FindNearest_DistanceMeasure> values =
      <StructuredQuery_FindNearest_DistanceMeasure>[
    DISTANCE_MEASURE_UNSPECIFIED,
    EUCLIDEAN,
    COSINE,
    DOT_PRODUCT,
  ];

  static final $core.List<StructuredQuery_FindNearest_DistanceMeasure?>
      _byValue = $pb.ProtobufEnum.$_initByValueList(values, 3);
  static StructuredQuery_FindNearest_DistanceMeasure? valueOf(
          $core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const StructuredQuery_FindNearest_DistanceMeasure._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
