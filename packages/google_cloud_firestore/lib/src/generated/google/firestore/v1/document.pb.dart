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
// Generated from google/firestore/v1/document.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/struct.pbenum.dart'
    as $2;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $0;

import '../../type/latlng.pb.dart' as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// A Firestore document.
///
/// Must not exceed 1 MiB - 4 bytes.
class Document extends $pb.GeneratedMessage {
  factory Document({
    $core.String? name,
    $core.Iterable<$core.MapEntry<$core.String, Value>>? fields,
    $0.Timestamp? createTime,
    $0.Timestamp? updateTime,
  }) {
    final result = Document._();
    if (name != null) result.name = name;
    if (fields != null) result.fields.addEntries(fields);
    if (createTime != null) result.createTime = createTime;
    if (updateTime != null) result.updateTime = updateTime;
    return result;
  }

  Document._();

  factory Document.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Document()..mergeFromBuffer(data, registry);
  factory Document.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Document()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Document',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: Document.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..m<$core.String, Value>(2, _omitFieldNames ? '' : 'fields',
        entryClassName: 'Document.FieldsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Value.$_createMessage,
        valueDefaultOrMaker: Value.getDefault,
        packageName: const $pb.PackageName('google.firestore.v1'))
    ..aOM<$0.Timestamp>(3, _omitFieldNames ? '' : 'createTime',
        subBuilder: $0.Timestamp.$_createMessage)
    ..aOM<$0.Timestamp>(4, _omitFieldNames ? '' : 'updateTime',
        subBuilder: $0.Timestamp.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Document clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Document copyWith(void Function(Document) updates) =>
      super.copyWith((message) => updates(message as Document)) as Document;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Document() / Document.new instead')
  static Document create() => Document._();
  static $pb.GeneratedMessage $_createMessage() => Document._();
  @$core.override
  Document createEmptyInstance() => Document._();
  @$core.pragma('dart2js:noInline')
  static Document getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Document>(Document.$_createMessage);
  static Document? _defaultInstance;

  /// The resource name of the document, for example
  /// `projects/{project_id}/databases/{database_id}/documents/{document_path}`.
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// The document's fields.
  ///
  /// The map keys represent field names.
  ///
  /// Field names matching the regular expression `__.*__` are reserved. Reserved
  /// field names are forbidden except in certain documented contexts. The field
  /// names, represented as UTF-8, must not exceed 1,500 bytes and cannot be
  /// empty.
  ///
  /// Field paths may be used in other contexts to refer to structured fields
  /// defined here. For `map_value`, the field path is represented by a
  /// dot-delimited (`.`) string of segments. Each segment is either a simple
  /// field name (defined below) or a quoted field name. For example, the
  /// structured field `"foo" : { map_value: { "x&y" : { string_value: "hello"
  /// }}}` would be represented by the field path `` foo.`x&y` ``.
  ///
  /// A simple field name contains only characters `a` to `z`, `A` to `Z`,
  /// `0` to `9`, or `_`, and must not start with `0` to `9`. For example,
  /// `foo_bar_17`.
  ///
  /// A quoted field name starts and ends with `` ` `` and
  /// may contain any character. Some characters, including `` ` ``, must be
  /// escaped using a `\`. For example, `` `x&y` `` represents `x&y` and
  /// `` `bak\`tik` `` represents `` bak`tik ``.
  @$pb.TagNumber(2)
  $pb.PbMap<$core.String, Value> get fields => $_getMap(1);

  /// Output only. The time at which the document was created.
  ///
  /// This value increases monotonically when a document is deleted then
  /// recreated. It can also be compared to values from other documents and
  /// the `read_time` of a query.
  @$pb.TagNumber(3)
  $0.Timestamp get createTime => $_getN(2);
  @$pb.TagNumber(3)
  set createTime($0.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCreateTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreateTime() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.Timestamp ensureCreateTime() => $_ensure(2);

  /// Output only. The time at which the document was last changed.
  ///
  /// This value is initially set to the `create_time` then increases
  /// monotonically with each change to the document. It can also be
  /// compared to values from other documents and the `read_time` of a query.
  @$pb.TagNumber(4)
  $0.Timestamp get updateTime => $_getN(3);
  @$pb.TagNumber(4)
  set updateTime($0.Timestamp value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasUpdateTime() => $_has(3);
  @$pb.TagNumber(4)
  void clearUpdateTime() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.Timestamp ensureUpdateTime() => $_ensure(3);
}

enum Value_ValueType {
  booleanValue,
  integerValue,
  doubleValue,
  referenceValue,
  mapValue,
  geoPointValue,
  arrayValue,
  timestampValue,
  nullValue,
  stringValue,
  bytesValue,
  fieldReferenceValue,
  functionValue,
  pipelineValue,
  variableReferenceValue,
  notSet
}

/// A message that can hold any of the supported value types.
class Value extends $pb.GeneratedMessage {
  factory Value({
    $core.bool? booleanValue,
    $fixnum.Int64? integerValue,
    $core.double? doubleValue,
    $core.String? referenceValue,
    MapValue? mapValue,
    $1.LatLng? geoPointValue,
    ArrayValue? arrayValue,
    $0.Timestamp? timestampValue,
    $2.NullValue? nullValue,
    $core.String? stringValue,
    $core.List<$core.int>? bytesValue,
    $core.String? fieldReferenceValue,
    Function_? functionValue,
    Pipeline? pipelineValue,
    $core.String? variableReferenceValue,
  }) {
    final result = Value._();
    if (booleanValue != null) result.booleanValue = booleanValue;
    if (integerValue != null) result.integerValue = integerValue;
    if (doubleValue != null) result.doubleValue = doubleValue;
    if (referenceValue != null) result.referenceValue = referenceValue;
    if (mapValue != null) result.mapValue = mapValue;
    if (geoPointValue != null) result.geoPointValue = geoPointValue;
    if (arrayValue != null) result.arrayValue = arrayValue;
    if (timestampValue != null) result.timestampValue = timestampValue;
    if (nullValue != null) result.nullValue = nullValue;
    if (stringValue != null) result.stringValue = stringValue;
    if (bytesValue != null) result.bytesValue = bytesValue;
    if (fieldReferenceValue != null)
      result.fieldReferenceValue = fieldReferenceValue;
    if (functionValue != null) result.functionValue = functionValue;
    if (pipelineValue != null) result.pipelineValue = pipelineValue;
    if (variableReferenceValue != null)
      result.variableReferenceValue = variableReferenceValue;
    return result;
  }

  Value._();

  factory Value.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Value()..mergeFromBuffer(data, registry);
  factory Value.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Value()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Value_ValueType> _Value_ValueTypeByTag = {
    1: Value_ValueType.booleanValue,
    2: Value_ValueType.integerValue,
    3: Value_ValueType.doubleValue,
    5: Value_ValueType.referenceValue,
    6: Value_ValueType.mapValue,
    8: Value_ValueType.geoPointValue,
    9: Value_ValueType.arrayValue,
    10: Value_ValueType.timestampValue,
    11: Value_ValueType.nullValue,
    17: Value_ValueType.stringValue,
    18: Value_ValueType.bytesValue,
    19: Value_ValueType.fieldReferenceValue,
    20: Value_ValueType.functionValue,
    21: Value_ValueType.pipelineValue,
    22: Value_ValueType.variableReferenceValue,
    0: Value_ValueType.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Value',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: Value.$_createMessage)
    ..oo(0, [1, 2, 3, 5, 6, 8, 9, 10, 11, 17, 18, 19, 20, 21, 22])
    ..aOB(1, _omitFieldNames ? '' : 'booleanValue')
    ..aInt64(2, _omitFieldNames ? '' : 'integerValue')
    ..aD(3, _omitFieldNames ? '' : 'doubleValue')
    ..aOS(5, _omitFieldNames ? '' : 'referenceValue')
    ..aOM<MapValue>(6, _omitFieldNames ? '' : 'mapValue',
        subBuilder: MapValue.$_createMessage)
    ..aOM<$1.LatLng>(8, _omitFieldNames ? '' : 'geoPointValue',
        subBuilder: $1.LatLng.$_createMessage)
    ..aOM<ArrayValue>(9, _omitFieldNames ? '' : 'arrayValue',
        subBuilder: ArrayValue.$_createMessage)
    ..aOM<$0.Timestamp>(10, _omitFieldNames ? '' : 'timestampValue',
        subBuilder: $0.Timestamp.$_createMessage)
    ..aE<$2.NullValue>(11, _omitFieldNames ? '' : 'nullValue',
        enumValues: $2.NullValue.values)
    ..aOS(17, _omitFieldNames ? '' : 'stringValue')
    ..a<$core.List<$core.int>>(
        18, _omitFieldNames ? '' : 'bytesValue', $pb.PbFieldType.OY)
    ..aOS(19, _omitFieldNames ? '' : 'fieldReferenceValue')
    ..aOM<Function_>(20, _omitFieldNames ? '' : 'functionValue',
        subBuilder: Function_.$_createMessage)
    ..aOM<Pipeline>(21, _omitFieldNames ? '' : 'pipelineValue',
        subBuilder: Pipeline.$_createMessage)
    ..aOS(22, _omitFieldNames ? '' : 'variableReferenceValue')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Value clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Value copyWith(void Function(Value) updates) =>
      super.copyWith((message) => updates(message as Value)) as Value;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Value() / Value.new instead')
  static Value create() => Value._();
  static $pb.GeneratedMessage $_createMessage() => Value._();
  @$core.override
  Value createEmptyInstance() => Value._();
  @$core.pragma('dart2js:noInline')
  static Value getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Value>(Value.$_createMessage);
  static Value? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  Value_ValueType whichValueType() => _Value_ValueTypeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  @$pb.TagNumber(20)
  @$pb.TagNumber(21)
  @$pb.TagNumber(22)
  void clearValueType() => $_clearField($_whichOneof(0));

  /// A boolean value.
  @$pb.TagNumber(1)
  $core.bool get booleanValue => $_getBF(0);
  @$pb.TagNumber(1)
  set booleanValue($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBooleanValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearBooleanValue() => $_clearField(1);

  /// An integer value.
  @$pb.TagNumber(2)
  $fixnum.Int64 get integerValue => $_getI64(1);
  @$pb.TagNumber(2)
  set integerValue($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIntegerValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearIntegerValue() => $_clearField(2);

  /// A double value.
  @$pb.TagNumber(3)
  $core.double get doubleValue => $_getN(2);
  @$pb.TagNumber(3)
  set doubleValue($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDoubleValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearDoubleValue() => $_clearField(3);

  /// A reference to a document. For example:
  /// `projects/{project_id}/databases/{database_id}/documents/{document_path}`.
  @$pb.TagNumber(5)
  $core.String get referenceValue => $_getSZ(3);
  @$pb.TagNumber(5)
  set referenceValue($core.String value) => $_setString(3, value);
  @$pb.TagNumber(5)
  $core.bool hasReferenceValue() => $_has(3);
  @$pb.TagNumber(5)
  void clearReferenceValue() => $_clearField(5);

  /// A map value.
  @$pb.TagNumber(6)
  MapValue get mapValue => $_getN(4);
  @$pb.TagNumber(6)
  set mapValue(MapValue value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasMapValue() => $_has(4);
  @$pb.TagNumber(6)
  void clearMapValue() => $_clearField(6);
  @$pb.TagNumber(6)
  MapValue ensureMapValue() => $_ensure(4);

  /// A geo point value representing a point on the surface of Earth.
  @$pb.TagNumber(8)
  $1.LatLng get geoPointValue => $_getN(5);
  @$pb.TagNumber(8)
  set geoPointValue($1.LatLng value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasGeoPointValue() => $_has(5);
  @$pb.TagNumber(8)
  void clearGeoPointValue() => $_clearField(8);
  @$pb.TagNumber(8)
  $1.LatLng ensureGeoPointValue() => $_ensure(5);

  /// An array value.
  ///
  /// Cannot directly contain another array value, though can contain a
  /// map which contains another array.
  @$pb.TagNumber(9)
  ArrayValue get arrayValue => $_getN(6);
  @$pb.TagNumber(9)
  set arrayValue(ArrayValue value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasArrayValue() => $_has(6);
  @$pb.TagNumber(9)
  void clearArrayValue() => $_clearField(9);
  @$pb.TagNumber(9)
  ArrayValue ensureArrayValue() => $_ensure(6);

  /// A timestamp value.
  ///
  /// Precise only to microseconds. When stored, any additional precision is
  /// rounded down.
  @$pb.TagNumber(10)
  $0.Timestamp get timestampValue => $_getN(7);
  @$pb.TagNumber(10)
  set timestampValue($0.Timestamp value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasTimestampValue() => $_has(7);
  @$pb.TagNumber(10)
  void clearTimestampValue() => $_clearField(10);
  @$pb.TagNumber(10)
  $0.Timestamp ensureTimestampValue() => $_ensure(7);

  /// A null value.
  @$pb.TagNumber(11)
  $2.NullValue get nullValue => $_getN(8);
  @$pb.TagNumber(11)
  set nullValue($2.NullValue value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasNullValue() => $_has(8);
  @$pb.TagNumber(11)
  void clearNullValue() => $_clearField(11);

  /// A string value.
  ///
  /// The string, represented as UTF-8, must not exceed 1 MiB - 89 bytes.
  /// Only the first 1,500 bytes of the UTF-8 representation are considered by
  /// queries.
  @$pb.TagNumber(17)
  $core.String get stringValue => $_getSZ(9);
  @$pb.TagNumber(17)
  set stringValue($core.String value) => $_setString(9, value);
  @$pb.TagNumber(17)
  $core.bool hasStringValue() => $_has(9);
  @$pb.TagNumber(17)
  void clearStringValue() => $_clearField(17);

  /// A bytes value.
  ///
  /// Must not exceed 1 MiB - 89 bytes.
  /// Only the first 1,500 bytes are considered by queries.
  @$pb.TagNumber(18)
  $core.List<$core.int> get bytesValue => $_getN(10);
  @$pb.TagNumber(18)
  set bytesValue($core.List<$core.int> value) => $_setBytes(10, value);
  @$pb.TagNumber(18)
  $core.bool hasBytesValue() => $_has(10);
  @$pb.TagNumber(18)
  void clearBytesValue() => $_clearField(18);

  /// Value which references a field.
  ///
  /// This is considered relative (vs absolute) since it only refers to a field
  /// and not a field within a particular document.
  ///
  /// **Requires:**
  ///
  /// * Must follow [field reference][FieldReference.field_path] limitations.
  ///
  /// * Not allowed to be used when writing documents.
  @$pb.TagNumber(19)
  $core.String get fieldReferenceValue => $_getSZ(11);
  @$pb.TagNumber(19)
  set fieldReferenceValue($core.String value) => $_setString(11, value);
  @$pb.TagNumber(19)
  $core.bool hasFieldReferenceValue() => $_has(11);
  @$pb.TagNumber(19)
  void clearFieldReferenceValue() => $_clearField(19);

  /// A value that represents an unevaluated expression.
  ///
  /// **Requires:**
  ///
  /// * Not allowed to be used when writing documents.
  @$pb.TagNumber(20)
  Function_ get functionValue => $_getN(12);
  @$pb.TagNumber(20)
  set functionValue(Function_ value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasFunctionValue() => $_has(12);
  @$pb.TagNumber(20)
  void clearFunctionValue() => $_clearField(20);
  @$pb.TagNumber(20)
  Function_ ensureFunctionValue() => $_ensure(12);

  /// A value that represents an unevaluated pipeline.
  ///
  /// **Requires:**
  ///
  /// * Not allowed to be used when writing documents.
  @$pb.TagNumber(21)
  Pipeline get pipelineValue => $_getN(13);
  @$pb.TagNumber(21)
  set pipelineValue(Pipeline value) => $_setField(21, value);
  @$pb.TagNumber(21)
  $core.bool hasPipelineValue() => $_has(13);
  @$pb.TagNumber(21)
  void clearPipelineValue() => $_clearField(21);
  @$pb.TagNumber(21)
  Pipeline ensurePipelineValue() => $_ensure(13);

  /// Pointer to a variable defined elsewhere in a pipeline.
  ///
  /// Unlike `field_reference_value` which references a field within a
  /// document, this refers to a variable, defined in a separate namespace than
  /// the fields of a document.
  @$pb.TagNumber(22)
  $core.String get variableReferenceValue => $_getSZ(14);
  @$pb.TagNumber(22)
  set variableReferenceValue($core.String value) => $_setString(14, value);
  @$pb.TagNumber(22)
  $core.bool hasVariableReferenceValue() => $_has(14);
  @$pb.TagNumber(22)
  void clearVariableReferenceValue() => $_clearField(22);
}

/// An array value.
class ArrayValue extends $pb.GeneratedMessage {
  factory ArrayValue({
    $core.Iterable<Value>? values,
  }) {
    final result = ArrayValue._();
    if (values != null) result.values.addAll(values);
    return result;
  }

  ArrayValue._();

  factory ArrayValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArrayValue()..mergeFromBuffer(data, registry);
  factory ArrayValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArrayValue()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArrayValue',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: ArrayValue.$_createMessage)
    ..pPM<Value>(1, _omitFieldNames ? '' : 'values',
        subBuilder: Value.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArrayValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArrayValue copyWith(void Function(ArrayValue) updates) =>
      super.copyWith((message) => updates(message as ArrayValue)) as ArrayValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ArrayValue() / ArrayValue.new instead')
  static ArrayValue create() => ArrayValue._();
  static $pb.GeneratedMessage $_createMessage() => ArrayValue._();
  @$core.override
  ArrayValue createEmptyInstance() => ArrayValue._();
  @$core.pragma('dart2js:noInline')
  static ArrayValue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArrayValue>(ArrayValue.$_createMessage);
  static ArrayValue? _defaultInstance;

  /// Values in the array.
  @$pb.TagNumber(1)
  $pb.PbList<Value> get values => $_getList(0);
}

/// A map value.
class MapValue extends $pb.GeneratedMessage {
  factory MapValue({
    $core.Iterable<$core.MapEntry<$core.String, Value>>? fields,
  }) {
    final result = MapValue._();
    if (fields != null) result.fields.addEntries(fields);
    return result;
  }

  MapValue._();

  factory MapValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MapValue()..mergeFromBuffer(data, registry);
  factory MapValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MapValue()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MapValue',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: MapValue.$_createMessage)
    ..m<$core.String, Value>(1, _omitFieldNames ? '' : 'fields',
        entryClassName: 'MapValue.FieldsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Value.$_createMessage,
        valueDefaultOrMaker: Value.getDefault,
        packageName: const $pb.PackageName('google.firestore.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MapValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MapValue copyWith(void Function(MapValue) updates) =>
      super.copyWith((message) => updates(message as MapValue)) as MapValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MapValue() / MapValue.new instead')
  static MapValue create() => MapValue._();
  static $pb.GeneratedMessage $_createMessage() => MapValue._();
  @$core.override
  MapValue createEmptyInstance() => MapValue._();
  @$core.pragma('dart2js:noInline')
  static MapValue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MapValue>(MapValue.$_createMessage);
  static MapValue? _defaultInstance;

  /// The map's fields.
  ///
  /// The map keys represent field names. Field names matching the regular
  /// expression `__.*__` are reserved. Reserved field names are forbidden except
  /// in certain documented contexts. The map keys, represented as UTF-8, must
  /// not exceed 1,500 bytes and cannot be empty.
  @$pb.TagNumber(1)
  $pb.PbMap<$core.String, Value> get fields => $_getMap(0);
}

/// Represents an unevaluated scalar expression.
///
/// For example, the expression `like(user_name, "%alice%")` is represented as:
///
/// ```
/// name: "like"
/// args { field_reference: "user_name" }
/// args { string_value: "%alice%" }
/// ```
class Function_ extends $pb.GeneratedMessage {
  factory Function_({
    $core.String? name,
    $core.Iterable<Value>? args,
    $core.Iterable<$core.MapEntry<$core.String, Value>>? options,
  }) {
    final result = Function_._();
    if (name != null) result.name = name;
    if (args != null) result.args.addAll(args);
    if (options != null) result.options.addEntries(options);
    return result;
  }

  Function_._();

  factory Function_.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Function_()..mergeFromBuffer(data, registry);
  factory Function_.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Function_()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Function',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: Function_.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..pPM<Value>(2, _omitFieldNames ? '' : 'args',
        subBuilder: Value.$_createMessage)
    ..m<$core.String, Value>(3, _omitFieldNames ? '' : 'options',
        entryClassName: 'Function.OptionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Value.$_createMessage,
        valueDefaultOrMaker: Value.getDefault,
        packageName: const $pb.PackageName('google.firestore.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Function_ clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Function_ copyWith(void Function(Function_) updates) =>
      super.copyWith((message) => updates(message as Function_)) as Function_;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Function_() / Function_.new instead')
  static Function_ create() => Function_._();
  static $pb.GeneratedMessage $_createMessage() => Function_._();
  @$core.override
  Function_ createEmptyInstance() => Function_._();
  @$core.pragma('dart2js:noInline')
  static Function_ getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Function_>(Function_.$_createMessage);
  static Function_? _defaultInstance;

  /// Required. The name of the function to evaluate.
  ///
  /// **Requires:**
  ///
  /// * must be in snake case (lower case with underscore separator).
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// Optional. Ordered list of arguments the given function expects.
  @$pb.TagNumber(2)
  $pb.PbList<Value> get args => $_getList(1);

  /// Optional. Optional named arguments that certain functions may support.
  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, Value> get options => $_getMap(2);
}

/// A single operation within a pipeline.
///
/// A stage is made up of a unique name, and a list of arguments. The exact
/// number of arguments & types is dependent on the stage type.
///
/// To give an example, the stage `filter(state = "MD")` would be encoded as:
///
/// ```
/// name: "filter"
/// args {
///   function_value {
///     name: "eq"
///     args { field_reference_value: "state" }
///     args { string_value: "MD" }
///   }
/// }
/// ```
///
/// See public documentation for the full list.
class Pipeline_Stage extends $pb.GeneratedMessage {
  factory Pipeline_Stage({
    $core.String? name,
    $core.Iterable<Value>? args,
    $core.Iterable<$core.MapEntry<$core.String, Value>>? options,
  }) {
    final result = Pipeline_Stage._();
    if (name != null) result.name = name;
    if (args != null) result.args.addAll(args);
    if (options != null) result.options.addEntries(options);
    return result;
  }

  Pipeline_Stage._();

  factory Pipeline_Stage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Pipeline_Stage()..mergeFromBuffer(data, registry);
  factory Pipeline_Stage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Pipeline_Stage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Pipeline.Stage',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: Pipeline_Stage.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..pPM<Value>(2, _omitFieldNames ? '' : 'args',
        subBuilder: Value.$_createMessage)
    ..m<$core.String, Value>(3, _omitFieldNames ? '' : 'options',
        entryClassName: 'Pipeline.Stage.OptionsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Value.$_createMessage,
        valueDefaultOrMaker: Value.getDefault,
        packageName: const $pb.PackageName('google.firestore.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Pipeline_Stage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Pipeline_Stage copyWith(void Function(Pipeline_Stage) updates) =>
      super.copyWith((message) => updates(message as Pipeline_Stage))
          as Pipeline_Stage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Pipeline_Stage() / Pipeline_Stage.new instead')
  static Pipeline_Stage create() => Pipeline_Stage._();
  static $pb.GeneratedMessage $_createMessage() => Pipeline_Stage._();
  @$core.override
  Pipeline_Stage createEmptyInstance() => Pipeline_Stage._();
  @$core.pragma('dart2js:noInline')
  static Pipeline_Stage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Pipeline_Stage>(
          Pipeline_Stage.$_createMessage);
  static Pipeline_Stage? _defaultInstance;

  /// Required. The name of the stage to evaluate.
  ///
  /// **Requires:**
  ///
  /// * must be in snake case (lower case with underscore separator).
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// Optional. Ordered list of arguments the given stage expects.
  @$pb.TagNumber(2)
  $pb.PbList<Value> get args => $_getList(1);

  /// Optional. Optional named arguments that certain functions may support.
  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, Value> get options => $_getMap(2);
}

/// A Firestore query represented as an ordered list of operations / stages.
class Pipeline extends $pb.GeneratedMessage {
  factory Pipeline({
    $core.Iterable<Pipeline_Stage>? stages,
  }) {
    final result = Pipeline._();
    if (stages != null) result.stages.addAll(stages);
    return result;
  }

  Pipeline._();

  factory Pipeline.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Pipeline()..mergeFromBuffer(data, registry);
  factory Pipeline.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Pipeline()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Pipeline',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: Pipeline.$_createMessage)
    ..pPM<Pipeline_Stage>(1, _omitFieldNames ? '' : 'stages',
        subBuilder: Pipeline_Stage.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Pipeline clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Pipeline copyWith(void Function(Pipeline) updates) =>
      super.copyWith((message) => updates(message as Pipeline)) as Pipeline;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Pipeline() / Pipeline.new instead')
  static Pipeline create() => Pipeline._();
  static $pb.GeneratedMessage $_createMessage() => Pipeline._();
  @$core.override
  Pipeline createEmptyInstance() => Pipeline._();
  @$core.pragma('dart2js:noInline')
  static Pipeline getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Pipeline>(Pipeline.$_createMessage);
  static Pipeline? _defaultInstance;

  /// Required. Ordered list of stages to evaluate.
  @$pb.TagNumber(1)
  $pb.PbList<Pipeline_Stage> get stages => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
