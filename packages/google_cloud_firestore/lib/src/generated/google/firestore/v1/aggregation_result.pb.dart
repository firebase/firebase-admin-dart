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
// Generated from google/firestore/v1/aggregation_result.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'document.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// The result of a single bucket from a Firestore aggregation query.
///
/// The keys of `aggregate_fields` are the same for all results in an aggregation
/// query, unlike document queries which can have different fields present for
/// each result.
class AggregationResult extends $pb.GeneratedMessage {
  factory AggregationResult({
    $core.Iterable<$core.MapEntry<$core.String, $0.Value>>? aggregateFields,
  }) {
    final result = AggregationResult._();
    if (aggregateFields != null)
      result.aggregateFields.addEntries(aggregateFields);
    return result;
  }

  AggregationResult._();

  factory AggregationResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AggregationResult()..mergeFromBuffer(data, registry);
  factory AggregationResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AggregationResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AggregationResult',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: AggregationResult.$_createMessage)
    ..m<$core.String, $0.Value>(2, _omitFieldNames ? '' : 'aggregateFields',
        entryClassName: 'AggregationResult.AggregateFieldsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: $0.Value.$_createMessage,
        valueDefaultOrMaker: $0.Value.getDefault,
        packageName: const $pb.PackageName('google.firestore.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AggregationResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AggregationResult copyWith(void Function(AggregationResult) updates) =>
      super.copyWith((message) => updates(message as AggregationResult))
          as AggregationResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AggregationResult() / AggregationResult.new instead')
  static AggregationResult create() => AggregationResult._();
  static $pb.GeneratedMessage $_createMessage() => AggregationResult._();
  @$core.override
  AggregationResult createEmptyInstance() => AggregationResult._();
  @$core.pragma('dart2js:noInline')
  static AggregationResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AggregationResult>(
          AggregationResult.$_createMessage);
  static AggregationResult? _defaultInstance;

  /// The result of the aggregation functions, ex: `COUNT(*) AS total_docs`.
  ///
  /// The key is the
  /// [alias][google.firestore.v1.StructuredAggregationQuery.Aggregation.alias]
  /// assigned to the aggregation function on input and the size of this map
  /// equals the number of aggregation functions in the query.
  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, $0.Value> get aggregateFields => $_getMap(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
