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
// Generated from google/firestore/v1/pipeline.proto.

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

/// A Firestore query represented as an ordered list of operations / stages.
///
/// This is considered the top-level function which plans and executes a query.
/// It is logically equivalent to `query(stages, options)`, but prevents the
/// client from having to build a function wrapper.
class StructuredPipeline extends $pb.GeneratedMessage {
  factory StructuredPipeline({
    $0.Pipeline? pipeline,
    $core.Iterable<$core.MapEntry<$core.String, $0.Value>>? options,
  }) {
    final result = StructuredPipeline._();
    if (pipeline != null) result.pipeline = pipeline;
    if (options != null) result.options.addEntries(options);
    return result;
  }

  StructuredPipeline._();

  factory StructuredPipeline.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredPipeline()..mergeFromBuffer(data, registry);
  factory StructuredPipeline.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StructuredPipeline()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StructuredPipeline',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: StructuredPipeline.$_createMessage)
    ..aOM<$0.Pipeline>(1, _omitFieldNames ? '' : 'pipeline',
        subBuilder: $0.Pipeline.$_createMessage)
    ..m<$core.String, $0.Value>(2, _omitFieldNames ? '' : 'options',
        entryClassName: 'StructuredPipeline.OptionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: $0.Value.$_createMessage,
        valueDefaultOrMaker: $0.Value.getDefault,
        packageName: const $pb.PackageName('google.firestore.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredPipeline clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StructuredPipeline copyWith(void Function(StructuredPipeline) updates) =>
      super.copyWith((message) => updates(message as StructuredPipeline))
          as StructuredPipeline;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StructuredPipeline() / StructuredPipeline.new instead')
  static StructuredPipeline create() => StructuredPipeline._();
  static $pb.GeneratedMessage $_createMessage() => StructuredPipeline._();
  @$core.override
  StructuredPipeline createEmptyInstance() => StructuredPipeline._();
  @$core.pragma('dart2js:noInline')
  static StructuredPipeline getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StructuredPipeline>(
          StructuredPipeline.$_createMessage);
  static StructuredPipeline? _defaultInstance;

  /// Required. The pipeline query to execute.
  @$pb.TagNumber(1)
  $0.Pipeline get pipeline => $_getN(0);
  @$pb.TagNumber(1)
  set pipeline($0.Pipeline value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPipeline() => $_has(0);
  @$pb.TagNumber(1)
  void clearPipeline() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.Pipeline ensurePipeline() => $_ensure(0);

  /// Optional. Optional query-level arguments.
  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, $0.Value> get options => $_getMap(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
