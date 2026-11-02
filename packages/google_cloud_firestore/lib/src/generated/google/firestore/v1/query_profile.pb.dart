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
// Generated from google/firestore/v1/query_profile.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/duration.pb.dart'
    as $1;
import 'package:protobuf/well_known_types/google/protobuf/struct.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Explain options for the query.
class ExplainOptions extends $pb.GeneratedMessage {
  factory ExplainOptions({
    $core.bool? analyze,
  }) {
    final result = ExplainOptions._();
    if (analyze != null) result.analyze = analyze;
    return result;
  }

  ExplainOptions._();

  factory ExplainOptions.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExplainOptions()..mergeFromBuffer(data, registry);
  factory ExplainOptions.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExplainOptions()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExplainOptions',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: ExplainOptions.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'analyze')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExplainOptions clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExplainOptions copyWith(void Function(ExplainOptions) updates) =>
      super.copyWith((message) => updates(message as ExplainOptions))
          as ExplainOptions;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ExplainOptions() / ExplainOptions.new instead')
  static ExplainOptions create() => ExplainOptions._();
  static $pb.GeneratedMessage $_createMessage() => ExplainOptions._();
  @$core.override
  ExplainOptions createEmptyInstance() => ExplainOptions._();
  @$core.pragma('dart2js:noInline')
  static ExplainOptions getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ExplainOptions>(
          ExplainOptions.$_createMessage);
  static ExplainOptions? _defaultInstance;

  /// Optional. Whether to execute this query.
  ///
  /// When false (the default), the query will be planned, returning only
  /// metrics from the planning stages.
  ///
  /// When true, the query will be planned and executed, returning the full
  /// query results along with both planning and execution stage metrics.
  @$pb.TagNumber(1)
  $core.bool get analyze => $_getBF(0);
  @$pb.TagNumber(1)
  set analyze($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAnalyze() => $_has(0);
  @$pb.TagNumber(1)
  void clearAnalyze() => $_clearField(1);
}

/// Explain metrics for the query.
class ExplainMetrics extends $pb.GeneratedMessage {
  factory ExplainMetrics({
    PlanSummary? planSummary,
    ExecutionStats? executionStats,
  }) {
    final result = ExplainMetrics._();
    if (planSummary != null) result.planSummary = planSummary;
    if (executionStats != null) result.executionStats = executionStats;
    return result;
  }

  ExplainMetrics._();

  factory ExplainMetrics.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExplainMetrics()..mergeFromBuffer(data, registry);
  factory ExplainMetrics.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExplainMetrics()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExplainMetrics',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: ExplainMetrics.$_createMessage)
    ..aOM<PlanSummary>(1, _omitFieldNames ? '' : 'planSummary',
        subBuilder: PlanSummary.$_createMessage)
    ..aOM<ExecutionStats>(2, _omitFieldNames ? '' : 'executionStats',
        subBuilder: ExecutionStats.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExplainMetrics clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExplainMetrics copyWith(void Function(ExplainMetrics) updates) =>
      super.copyWith((message) => updates(message as ExplainMetrics))
          as ExplainMetrics;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ExplainMetrics() / ExplainMetrics.new instead')
  static ExplainMetrics create() => ExplainMetrics._();
  static $pb.GeneratedMessage $_createMessage() => ExplainMetrics._();
  @$core.override
  ExplainMetrics createEmptyInstance() => ExplainMetrics._();
  @$core.pragma('dart2js:noInline')
  static ExplainMetrics getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ExplainMetrics>(
          ExplainMetrics.$_createMessage);
  static ExplainMetrics? _defaultInstance;

  /// Planning phase information for the query.
  @$pb.TagNumber(1)
  PlanSummary get planSummary => $_getN(0);
  @$pb.TagNumber(1)
  set planSummary(PlanSummary value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPlanSummary() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlanSummary() => $_clearField(1);
  @$pb.TagNumber(1)
  PlanSummary ensurePlanSummary() => $_ensure(0);

  /// Aggregated stats from the execution of the query. Only present when
  /// [ExplainOptions.analyze][google.firestore.v1.ExplainOptions.analyze] is set
  /// to true.
  @$pb.TagNumber(2)
  ExecutionStats get executionStats => $_getN(1);
  @$pb.TagNumber(2)
  set executionStats(ExecutionStats value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasExecutionStats() => $_has(1);
  @$pb.TagNumber(2)
  void clearExecutionStats() => $_clearField(2);
  @$pb.TagNumber(2)
  ExecutionStats ensureExecutionStats() => $_ensure(1);
}

/// Planning phase information for the query.
class PlanSummary extends $pb.GeneratedMessage {
  factory PlanSummary({
    $core.Iterable<$0.Struct>? indexesUsed,
  }) {
    final result = PlanSummary._();
    if (indexesUsed != null) result.indexesUsed.addAll(indexesUsed);
    return result;
  }

  PlanSummary._();

  factory PlanSummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlanSummary()..mergeFromBuffer(data, registry);
  factory PlanSummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlanSummary()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlanSummary',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: PlanSummary.$_createMessage)
    ..pPM<$0.Struct>(1, _omitFieldNames ? '' : 'indexesUsed',
        subBuilder: $0.Struct.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanSummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanSummary copyWith(void Function(PlanSummary) updates) =>
      super.copyWith((message) => updates(message as PlanSummary))
          as PlanSummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlanSummary() / PlanSummary.new instead')
  static PlanSummary create() => PlanSummary._();
  static $pb.GeneratedMessage $_createMessage() => PlanSummary._();
  @$core.override
  PlanSummary createEmptyInstance() => PlanSummary._();
  @$core.pragma('dart2js:noInline')
  static PlanSummary getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlanSummary>(
          PlanSummary.$_createMessage);
  static PlanSummary? _defaultInstance;

  /// The indexes selected for the query. For example:
  ///  [
  ///    {"query_scope": "Collection", "properties": "(foo ASC, __name__ ASC)"},
  ///    {"query_scope": "Collection", "properties": "(bar ASC, __name__ ASC)"}
  ///  ]
  @$pb.TagNumber(1)
  $pb.PbList<$0.Struct> get indexesUsed => $_getList(0);
}

/// Execution statistics for the query.
class ExecutionStats extends $pb.GeneratedMessage {
  factory ExecutionStats({
    $fixnum.Int64? resultsReturned,
    $1.Duration? executionDuration,
    $fixnum.Int64? readOperations,
    $0.Struct? debugStats,
  }) {
    final result = ExecutionStats._();
    if (resultsReturned != null) result.resultsReturned = resultsReturned;
    if (executionDuration != null) result.executionDuration = executionDuration;
    if (readOperations != null) result.readOperations = readOperations;
    if (debugStats != null) result.debugStats = debugStats;
    return result;
  }

  ExecutionStats._();

  factory ExecutionStats.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExecutionStats()..mergeFromBuffer(data, registry);
  factory ExecutionStats.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExecutionStats()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExecutionStats',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: ExecutionStats.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'resultsReturned')
    ..aOM<$1.Duration>(3, _omitFieldNames ? '' : 'executionDuration',
        subBuilder: $1.Duration.$_createMessage)
    ..aInt64(4, _omitFieldNames ? '' : 'readOperations')
    ..aOM<$0.Struct>(5, _omitFieldNames ? '' : 'debugStats',
        subBuilder: $0.Struct.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExecutionStats clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExecutionStats copyWith(void Function(ExecutionStats) updates) =>
      super.copyWith((message) => updates(message as ExecutionStats))
          as ExecutionStats;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ExecutionStats() / ExecutionStats.new instead')
  static ExecutionStats create() => ExecutionStats._();
  static $pb.GeneratedMessage $_createMessage() => ExecutionStats._();
  @$core.override
  ExecutionStats createEmptyInstance() => ExecutionStats._();
  @$core.pragma('dart2js:noInline')
  static ExecutionStats getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ExecutionStats>(
          ExecutionStats.$_createMessage);
  static ExecutionStats? _defaultInstance;

  /// Total number of results returned, including documents, projections,
  /// aggregation results, keys.
  @$pb.TagNumber(1)
  $fixnum.Int64 get resultsReturned => $_getI64(0);
  @$pb.TagNumber(1)
  set resultsReturned($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasResultsReturned() => $_has(0);
  @$pb.TagNumber(1)
  void clearResultsReturned() => $_clearField(1);

  /// Total time to execute the query in the backend.
  @$pb.TagNumber(3)
  $1.Duration get executionDuration => $_getN(1);
  @$pb.TagNumber(3)
  set executionDuration($1.Duration value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasExecutionDuration() => $_has(1);
  @$pb.TagNumber(3)
  void clearExecutionDuration() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.Duration ensureExecutionDuration() => $_ensure(1);

  /// Total billable read operations.
  @$pb.TagNumber(4)
  $fixnum.Int64 get readOperations => $_getI64(2);
  @$pb.TagNumber(4)
  set readOperations($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(4)
  $core.bool hasReadOperations() => $_has(2);
  @$pb.TagNumber(4)
  void clearReadOperations() => $_clearField(4);

  /// Debugging statistics from the execution of the query. Note that the
  /// debugging stats are subject to change as Firestore evolves. It could
  /// include:
  ///  {
  ///    "indexes_entries_scanned": "1000",
  ///    "documents_scanned": "20",
  ///    "billing_details" : {
  ///       "documents_billable": "20",
  ///       "index_entries_billable": "1000",
  ///       "min_query_cost": "0"
  ///    }
  ///  }
  @$pb.TagNumber(5)
  $0.Struct get debugStats => $_getN(3);
  @$pb.TagNumber(5)
  set debugStats($0.Struct value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasDebugStats() => $_has(3);
  @$pb.TagNumber(5)
  void clearDebugStats() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.Struct ensureDebugStats() => $_ensure(3);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
