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
// Generated from google/firestore/v1/write.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $2;

import 'bloom_filter.pb.dart' as $3;
import 'common.pb.dart' as $1;
import 'document.pb.dart' as $0;
import 'write.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'write.pbenum.dart';

enum Write_Operation { update, delete, transform, notSet }

/// A write on a document.
class Write extends $pb.GeneratedMessage {
  factory Write({
    $0.Document? update,
    $core.String? delete,
    $1.DocumentMask? updateMask,
    $1.Precondition? currentDocument,
    DocumentTransform? transform,
    $core.Iterable<DocumentTransform_FieldTransform>? updateTransforms,
  }) {
    final result = Write._();
    if (update != null) result.update = update;
    if (delete != null) result.delete = delete;
    if (updateMask != null) result.updateMask = updateMask;
    if (currentDocument != null) result.currentDocument = currentDocument;
    if (transform != null) result.transform = transform;
    if (updateTransforms != null)
      result.updateTransforms.addAll(updateTransforms);
    return result;
  }

  Write._();

  factory Write.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Write()..mergeFromBuffer(data, registry);
  factory Write.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Write()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Write_Operation> _Write_OperationByTag = {
    1: Write_Operation.update,
    2: Write_Operation.delete,
    6: Write_Operation.transform,
    0: Write_Operation.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Write',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: Write.$_createMessage)
    ..oo(0, [1, 2, 6])
    ..aOM<$0.Document>(1, _omitFieldNames ? '' : 'update',
        subBuilder: $0.Document.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'delete')
    ..aOM<$1.DocumentMask>(3, _omitFieldNames ? '' : 'updateMask',
        subBuilder: $1.DocumentMask.$_createMessage)
    ..aOM<$1.Precondition>(4, _omitFieldNames ? '' : 'currentDocument',
        subBuilder: $1.Precondition.$_createMessage)
    ..aOM<DocumentTransform>(6, _omitFieldNames ? '' : 'transform',
        subBuilder: DocumentTransform.$_createMessage)
    ..pPM<DocumentTransform_FieldTransform>(
        7, _omitFieldNames ? '' : 'updateTransforms',
        subBuilder: DocumentTransform_FieldTransform.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Write clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Write copyWith(void Function(Write) updates) =>
      super.copyWith((message) => updates(message as Write)) as Write;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Write() / Write.new instead')
  static Write create() => Write._();
  static $pb.GeneratedMessage $_createMessage() => Write._();
  @$core.override
  Write createEmptyInstance() => Write._();
  @$core.pragma('dart2js:noInline')
  static Write getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Write>(Write.$_createMessage);
  static Write? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(6)
  Write_Operation whichOperation() => _Write_OperationByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(6)
  void clearOperation() => $_clearField($_whichOneof(0));

  /// A document to write.
  @$pb.TagNumber(1)
  $0.Document get update => $_getN(0);
  @$pb.TagNumber(1)
  set update($0.Document value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUpdate() => $_has(0);
  @$pb.TagNumber(1)
  void clearUpdate() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.Document ensureUpdate() => $_ensure(0);

  /// A document name to delete. In the format:
  /// `projects/{project_id}/databases/{database_id}/documents/{document_path}`.
  @$pb.TagNumber(2)
  $core.String get delete => $_getSZ(1);
  @$pb.TagNumber(2)
  set delete($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDelete() => $_has(1);
  @$pb.TagNumber(2)
  void clearDelete() => $_clearField(2);

  /// The fields to update in this write.
  ///
  /// This field can be set only when the operation is `update`.
  /// If the mask is not set for an `update` and the document exists, any
  /// existing data will be overwritten.
  /// If the mask is set and the document on the server has fields not covered by
  /// the mask, they are left unchanged.
  /// Fields referenced in the mask, but not present in the input document, are
  /// deleted from the document on the server.
  /// The field paths in this mask must not contain a reserved field name.
  @$pb.TagNumber(3)
  $1.DocumentMask get updateMask => $_getN(2);
  @$pb.TagNumber(3)
  set updateMask($1.DocumentMask value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasUpdateMask() => $_has(2);
  @$pb.TagNumber(3)
  void clearUpdateMask() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.DocumentMask ensureUpdateMask() => $_ensure(2);

  /// An optional precondition on the document.
  ///
  /// The write will fail if this is set and not met by the target document.
  @$pb.TagNumber(4)
  $1.Precondition get currentDocument => $_getN(3);
  @$pb.TagNumber(4)
  set currentDocument($1.Precondition value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCurrentDocument() => $_has(3);
  @$pb.TagNumber(4)
  void clearCurrentDocument() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.Precondition ensureCurrentDocument() => $_ensure(3);

  /// Applies a transformation to a document.
  @$pb.TagNumber(6)
  DocumentTransform get transform => $_getN(4);
  @$pb.TagNumber(6)
  set transform(DocumentTransform value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasTransform() => $_has(4);
  @$pb.TagNumber(6)
  void clearTransform() => $_clearField(6);
  @$pb.TagNumber(6)
  DocumentTransform ensureTransform() => $_ensure(4);

  /// The transforms to perform after update.
  ///
  /// This field can be set only when the operation is `update`. If present, this
  /// write is equivalent to performing `update` and `transform` to the same
  /// document atomically and in order.
  @$pb.TagNumber(7)
  $pb.PbList<DocumentTransform_FieldTransform> get updateTransforms =>
      $_getList(5);
}

enum DocumentTransform_FieldTransform_TransformType {
  setToServerValue,
  increment,
  maximum,
  minimum,
  appendMissingElements,
  removeAllFromArray,
  notSet
}

/// A transformation of a field of the document.
class DocumentTransform_FieldTransform extends $pb.GeneratedMessage {
  factory DocumentTransform_FieldTransform({
    $core.String? fieldPath,
    DocumentTransform_FieldTransform_ServerValue? setToServerValue,
    $0.Value? increment,
    $0.Value? maximum,
    $0.Value? minimum,
    $0.ArrayValue? appendMissingElements,
    $0.ArrayValue? removeAllFromArray,
  }) {
    final result = DocumentTransform_FieldTransform._();
    if (fieldPath != null) result.fieldPath = fieldPath;
    if (setToServerValue != null) result.setToServerValue = setToServerValue;
    if (increment != null) result.increment = increment;
    if (maximum != null) result.maximum = maximum;
    if (minimum != null) result.minimum = minimum;
    if (appendMissingElements != null)
      result.appendMissingElements = appendMissingElements;
    if (removeAllFromArray != null)
      result.removeAllFromArray = removeAllFromArray;
    return result;
  }

  DocumentTransform_FieldTransform._();

  factory DocumentTransform_FieldTransform.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocumentTransform_FieldTransform()..mergeFromBuffer(data, registry);
  factory DocumentTransform_FieldTransform.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocumentTransform_FieldTransform()..mergeFromJson(json, registry);

  static const $core
      .Map<$core.int, DocumentTransform_FieldTransform_TransformType>
      _DocumentTransform_FieldTransform_TransformTypeByTag = {
    2: DocumentTransform_FieldTransform_TransformType.setToServerValue,
    3: DocumentTransform_FieldTransform_TransformType.increment,
    4: DocumentTransform_FieldTransform_TransformType.maximum,
    5: DocumentTransform_FieldTransform_TransformType.minimum,
    6: DocumentTransform_FieldTransform_TransformType.appendMissingElements,
    7: DocumentTransform_FieldTransform_TransformType.removeAllFromArray,
    0: DocumentTransform_FieldTransform_TransformType.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DocumentTransform.FieldTransform',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: DocumentTransform_FieldTransform.$_createMessage)
    ..oo(0, [2, 3, 4, 5, 6, 7])
    ..aOS(1, _omitFieldNames ? '' : 'fieldPath')
    ..aE<DocumentTransform_FieldTransform_ServerValue>(
        2, _omitFieldNames ? '' : 'setToServerValue',
        enumValues: DocumentTransform_FieldTransform_ServerValue.values)
    ..aOM<$0.Value>(3, _omitFieldNames ? '' : 'increment',
        subBuilder: $0.Value.$_createMessage)
    ..aOM<$0.Value>(4, _omitFieldNames ? '' : 'maximum',
        subBuilder: $0.Value.$_createMessage)
    ..aOM<$0.Value>(5, _omitFieldNames ? '' : 'minimum',
        subBuilder: $0.Value.$_createMessage)
    ..aOM<$0.ArrayValue>(6, _omitFieldNames ? '' : 'appendMissingElements',
        subBuilder: $0.ArrayValue.$_createMessage)
    ..aOM<$0.ArrayValue>(7, _omitFieldNames ? '' : 'removeAllFromArray',
        subBuilder: $0.ArrayValue.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocumentTransform_FieldTransform clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocumentTransform_FieldTransform copyWith(
          void Function(DocumentTransform_FieldTransform) updates) =>
      super.copyWith(
              (message) => updates(message as DocumentTransform_FieldTransform))
          as DocumentTransform_FieldTransform;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DocumentTransform_FieldTransform() / DocumentTransform_FieldTransform.new instead')
  static DocumentTransform_FieldTransform create() =>
      DocumentTransform_FieldTransform._();
  static $pb.GeneratedMessage $_createMessage() =>
      DocumentTransform_FieldTransform._();
  @$core.override
  DocumentTransform_FieldTransform createEmptyInstance() =>
      DocumentTransform_FieldTransform._();
  @$core.pragma('dart2js:noInline')
  static DocumentTransform_FieldTransform getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DocumentTransform_FieldTransform>(
          DocumentTransform_FieldTransform.$_createMessage);
  static DocumentTransform_FieldTransform? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  DocumentTransform_FieldTransform_TransformType whichTransformType() =>
      _DocumentTransform_FieldTransform_TransformTypeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  void clearTransformType() => $_clearField($_whichOneof(0));

  /// The path of the field. See
  /// [Document.fields][google.firestore.v1.Document.fields] for the field path
  /// syntax reference.
  @$pb.TagNumber(1)
  $core.String get fieldPath => $_getSZ(0);
  @$pb.TagNumber(1)
  set fieldPath($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFieldPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearFieldPath() => $_clearField(1);

  /// Sets the field to the given server value.
  @$pb.TagNumber(2)
  DocumentTransform_FieldTransform_ServerValue get setToServerValue =>
      $_getN(1);
  @$pb.TagNumber(2)
  set setToServerValue(DocumentTransform_FieldTransform_ServerValue value) =>
      $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSetToServerValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearSetToServerValue() => $_clearField(2);

  /// Adds the given value to the field's current value.
  ///
  /// This must be an integer or a double value.
  /// If the field is not an integer or double, or if the field does not yet
  /// exist, the transformation will set the field to the given value.
  /// If either of the given value or the current field value are doubles,
  /// both values will be interpreted as doubles. Double arithmetic and
  /// representation of double values follow IEEE 754 semantics.
  /// If there is positive/negative integer overflow, the field is resolved
  /// to the largest magnitude positive/negative integer.
  @$pb.TagNumber(3)
  $0.Value get increment => $_getN(2);
  @$pb.TagNumber(3)
  set increment($0.Value value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasIncrement() => $_has(2);
  @$pb.TagNumber(3)
  void clearIncrement() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.Value ensureIncrement() => $_ensure(2);

  /// Sets the field to the maximum of its current value and the given value.
  ///
  /// This must be an integer or a double value.
  /// If the field is not an integer or double, or if the field does not yet
  /// exist, the transformation will set the field to the given value.
  /// If a maximum operation is applied where the field and the input value
  /// are of mixed types (that is - one is an integer and one is a double)
  /// the field takes on the type of the larger operand. If the operands are
  /// equivalent (e.g. 3 and 3.0), the field does not change.
  /// 0, 0.0, and -0.0 are all zero. The maximum of a zero stored value and
  /// zero input value is always the stored value.
  /// The maximum of any numeric value x and NaN is NaN.
  @$pb.TagNumber(4)
  $0.Value get maximum => $_getN(3);
  @$pb.TagNumber(4)
  set maximum($0.Value value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasMaximum() => $_has(3);
  @$pb.TagNumber(4)
  void clearMaximum() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.Value ensureMaximum() => $_ensure(3);

  /// Sets the field to the minimum of its current value and the given value.
  ///
  /// This must be an integer or a double value.
  /// If the field is not an integer or double, or if the field does not yet
  /// exist, the transformation will set the field to the input value.
  /// If a minimum operation is applied where the field and the input value
  /// are of mixed types (that is - one is an integer and one is a double)
  /// the field takes on the type of the smaller operand. If the operands are
  /// equivalent (e.g. 3 and 3.0), the field does not change.
  /// 0, 0.0, and -0.0 are all zero. The minimum of a zero stored value and
  /// zero input value is always the stored value.
  /// The minimum of any numeric value x and NaN is NaN.
  @$pb.TagNumber(5)
  $0.Value get minimum => $_getN(4);
  @$pb.TagNumber(5)
  set minimum($0.Value value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasMinimum() => $_has(4);
  @$pb.TagNumber(5)
  void clearMinimum() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.Value ensureMinimum() => $_ensure(4);

  /// Append the given elements in order if they are not already present in
  /// the current field value.
  /// If the field is not an array, or if the field does not yet exist, it is
  /// first set to the empty array.
  ///
  /// Equivalent numbers of different types (e.g. 3L and 3.0) are
  /// considered equal when checking if a value is missing.
  /// NaN is equal to NaN, and Null is equal to Null.
  /// If the input contains multiple equivalent values, only the first will
  /// be considered.
  ///
  /// The corresponding transform_result will be the null value.
  @$pb.TagNumber(6)
  $0.ArrayValue get appendMissingElements => $_getN(5);
  @$pb.TagNumber(6)
  set appendMissingElements($0.ArrayValue value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasAppendMissingElements() => $_has(5);
  @$pb.TagNumber(6)
  void clearAppendMissingElements() => $_clearField(6);
  @$pb.TagNumber(6)
  $0.ArrayValue ensureAppendMissingElements() => $_ensure(5);

  /// Remove all of the given elements from the array in the field.
  /// If the field is not an array, or if the field does not yet exist, it is
  /// set to the empty array.
  ///
  /// Equivalent numbers of the different types (e.g. 3L and 3.0) are
  /// considered equal when deciding whether an element should be removed.
  /// NaN is equal to NaN, and Null is equal to Null.
  /// This will remove all equivalent values if there are duplicates.
  ///
  /// The corresponding transform_result will be the null value.
  @$pb.TagNumber(7)
  $0.ArrayValue get removeAllFromArray => $_getN(6);
  @$pb.TagNumber(7)
  set removeAllFromArray($0.ArrayValue value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasRemoveAllFromArray() => $_has(6);
  @$pb.TagNumber(7)
  void clearRemoveAllFromArray() => $_clearField(7);
  @$pb.TagNumber(7)
  $0.ArrayValue ensureRemoveAllFromArray() => $_ensure(6);
}

/// A transformation of a document.
class DocumentTransform extends $pb.GeneratedMessage {
  factory DocumentTransform({
    $core.String? document,
    $core.Iterable<DocumentTransform_FieldTransform>? fieldTransforms,
  }) {
    final result = DocumentTransform._();
    if (document != null) result.document = document;
    if (fieldTransforms != null) result.fieldTransforms.addAll(fieldTransforms);
    return result;
  }

  DocumentTransform._();

  factory DocumentTransform.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocumentTransform()..mergeFromBuffer(data, registry);
  factory DocumentTransform.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocumentTransform()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DocumentTransform',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: DocumentTransform.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'document')
    ..pPM<DocumentTransform_FieldTransform>(
        2, _omitFieldNames ? '' : 'fieldTransforms',
        subBuilder: DocumentTransform_FieldTransform.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocumentTransform clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocumentTransform copyWith(void Function(DocumentTransform) updates) =>
      super.copyWith((message) => updates(message as DocumentTransform))
          as DocumentTransform;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DocumentTransform() / DocumentTransform.new instead')
  static DocumentTransform create() => DocumentTransform._();
  static $pb.GeneratedMessage $_createMessage() => DocumentTransform._();
  @$core.override
  DocumentTransform createEmptyInstance() => DocumentTransform._();
  @$core.pragma('dart2js:noInline')
  static DocumentTransform getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DocumentTransform>(
          DocumentTransform.$_createMessage);
  static DocumentTransform? _defaultInstance;

  /// The name of the document to transform.
  @$pb.TagNumber(1)
  $core.String get document => $_getSZ(0);
  @$pb.TagNumber(1)
  set document($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDocument() => $_has(0);
  @$pb.TagNumber(1)
  void clearDocument() => $_clearField(1);

  /// The list of transformations to apply to the fields of the document, in
  /// order.
  /// This must not be empty.
  @$pb.TagNumber(2)
  $pb.PbList<DocumentTransform_FieldTransform> get fieldTransforms =>
      $_getList(1);
}

/// The result of applying a write.
class WriteResult extends $pb.GeneratedMessage {
  factory WriteResult({
    $2.Timestamp? updateTime,
    $core.Iterable<$0.Value>? transformResults,
  }) {
    final result = WriteResult._();
    if (updateTime != null) result.updateTime = updateTime;
    if (transformResults != null)
      result.transformResults.addAll(transformResults);
    return result;
  }

  WriteResult._();

  factory WriteResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteResult()..mergeFromBuffer(data, registry);
  factory WriteResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteResult()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WriteResult',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: WriteResult.$_createMessage)
    ..aOM<$2.Timestamp>(1, _omitFieldNames ? '' : 'updateTime',
        subBuilder: $2.Timestamp.$_createMessage)
    ..pPM<$0.Value>(2, _omitFieldNames ? '' : 'transformResults',
        subBuilder: $0.Value.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteResult copyWith(void Function(WriteResult) updates) =>
      super.copyWith((message) => updates(message as WriteResult))
          as WriteResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WriteResult() / WriteResult.new instead')
  static WriteResult create() => WriteResult._();
  static $pb.GeneratedMessage $_createMessage() => WriteResult._();
  @$core.override
  WriteResult createEmptyInstance() => WriteResult._();
  @$core.pragma('dart2js:noInline')
  static WriteResult getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WriteResult>(
          WriteResult.$_createMessage);
  static WriteResult? _defaultInstance;

  /// The last update time of the document after applying the write. Not set
  /// after a `delete`.
  ///
  /// If the write did not actually change the document, this will be the
  /// previous update_time.
  @$pb.TagNumber(1)
  $2.Timestamp get updateTime => $_getN(0);
  @$pb.TagNumber(1)
  set updateTime($2.Timestamp value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUpdateTime() => $_has(0);
  @$pb.TagNumber(1)
  void clearUpdateTime() => $_clearField(1);
  @$pb.TagNumber(1)
  $2.Timestamp ensureUpdateTime() => $_ensure(0);

  /// The results of applying each
  /// [DocumentTransform.FieldTransform][google.firestore.v1.DocumentTransform.FieldTransform],
  /// in the same order.
  @$pb.TagNumber(2)
  $pb.PbList<$0.Value> get transformResults => $_getList(1);
}

/// A [Document][google.firestore.v1.Document] has changed.
///
/// May be the result of multiple [writes][google.firestore.v1.Write], including
/// deletes, that ultimately resulted in a new value for the
/// [Document][google.firestore.v1.Document].
///
/// Multiple [DocumentChange][google.firestore.v1.DocumentChange] messages may be
/// returned for the same logical change, if multiple targets are affected.
class DocumentChange extends $pb.GeneratedMessage {
  factory DocumentChange({
    $0.Document? document,
    $core.Iterable<$core.int>? targetIds,
    $core.Iterable<$core.int>? removedTargetIds,
  }) {
    final result = DocumentChange._();
    if (document != null) result.document = document;
    if (targetIds != null) result.targetIds.addAll(targetIds);
    if (removedTargetIds != null)
      result.removedTargetIds.addAll(removedTargetIds);
    return result;
  }

  DocumentChange._();

  factory DocumentChange.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocumentChange()..mergeFromBuffer(data, registry);
  factory DocumentChange.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocumentChange()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DocumentChange',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: DocumentChange.$_createMessage)
    ..aOM<$0.Document>(1, _omitFieldNames ? '' : 'document',
        subBuilder: $0.Document.$_createMessage)
    ..p<$core.int>(5, _omitFieldNames ? '' : 'targetIds', $pb.PbFieldType.K3)
    ..p<$core.int>(
        6, _omitFieldNames ? '' : 'removedTargetIds', $pb.PbFieldType.K3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocumentChange clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocumentChange copyWith(void Function(DocumentChange) updates) =>
      super.copyWith((message) => updates(message as DocumentChange))
          as DocumentChange;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DocumentChange() / DocumentChange.new instead')
  static DocumentChange create() => DocumentChange._();
  static $pb.GeneratedMessage $_createMessage() => DocumentChange._();
  @$core.override
  DocumentChange createEmptyInstance() => DocumentChange._();
  @$core.pragma('dart2js:noInline')
  static DocumentChange getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DocumentChange>(
          DocumentChange.$_createMessage);
  static DocumentChange? _defaultInstance;

  /// The new state of the [Document][google.firestore.v1.Document].
  ///
  /// If `mask` is set, contains only fields that were updated or added.
  @$pb.TagNumber(1)
  $0.Document get document => $_getN(0);
  @$pb.TagNumber(1)
  set document($0.Document value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDocument() => $_has(0);
  @$pb.TagNumber(1)
  void clearDocument() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.Document ensureDocument() => $_ensure(0);

  /// A set of target IDs of targets that match this document.
  @$pb.TagNumber(5)
  $pb.PbList<$core.int> get targetIds => $_getList(1);

  /// A set of target IDs for targets that no longer match this document.
  @$pb.TagNumber(6)
  $pb.PbList<$core.int> get removedTargetIds => $_getList(2);
}

/// A [Document][google.firestore.v1.Document] has been deleted.
///
/// May be the result of multiple [writes][google.firestore.v1.Write], including
/// updates, the last of which deleted the
/// [Document][google.firestore.v1.Document].
///
/// Multiple [DocumentDelete][google.firestore.v1.DocumentDelete] messages may be
/// returned for the same logical delete, if multiple targets are affected.
class DocumentDelete extends $pb.GeneratedMessage {
  factory DocumentDelete({
    $core.String? document,
    $2.Timestamp? readTime,
    $core.Iterable<$core.int>? removedTargetIds,
  }) {
    final result = DocumentDelete._();
    if (document != null) result.document = document;
    if (readTime != null) result.readTime = readTime;
    if (removedTargetIds != null)
      result.removedTargetIds.addAll(removedTargetIds);
    return result;
  }

  DocumentDelete._();

  factory DocumentDelete.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocumentDelete()..mergeFromBuffer(data, registry);
  factory DocumentDelete.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocumentDelete()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DocumentDelete',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: DocumentDelete.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'document')
    ..aOM<$2.Timestamp>(4, _omitFieldNames ? '' : 'readTime',
        subBuilder: $2.Timestamp.$_createMessage)
    ..p<$core.int>(
        6, _omitFieldNames ? '' : 'removedTargetIds', $pb.PbFieldType.K3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocumentDelete clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocumentDelete copyWith(void Function(DocumentDelete) updates) =>
      super.copyWith((message) => updates(message as DocumentDelete))
          as DocumentDelete;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DocumentDelete() / DocumentDelete.new instead')
  static DocumentDelete create() => DocumentDelete._();
  static $pb.GeneratedMessage $_createMessage() => DocumentDelete._();
  @$core.override
  DocumentDelete createEmptyInstance() => DocumentDelete._();
  @$core.pragma('dart2js:noInline')
  static DocumentDelete getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DocumentDelete>(
          DocumentDelete.$_createMessage);
  static DocumentDelete? _defaultInstance;

  /// The resource name of the [Document][google.firestore.v1.Document] that was
  /// deleted.
  @$pb.TagNumber(1)
  $core.String get document => $_getSZ(0);
  @$pb.TagNumber(1)
  set document($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDocument() => $_has(0);
  @$pb.TagNumber(1)
  void clearDocument() => $_clearField(1);

  /// The read timestamp at which the delete was observed.
  ///
  /// Greater or equal to the `commit_time` of the delete.
  @$pb.TagNumber(4)
  $2.Timestamp get readTime => $_getN(1);
  @$pb.TagNumber(4)
  set readTime($2.Timestamp value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasReadTime() => $_has(1);
  @$pb.TagNumber(4)
  void clearReadTime() => $_clearField(4);
  @$pb.TagNumber(4)
  $2.Timestamp ensureReadTime() => $_ensure(1);

  /// A set of target IDs for targets that previously matched this entity.
  @$pb.TagNumber(6)
  $pb.PbList<$core.int> get removedTargetIds => $_getList(2);
}

/// A [Document][google.firestore.v1.Document] has been removed from the view of
/// the targets.
///
/// Sent if the document is no longer relevant to a target and is out of view.
/// Can be sent instead of a DocumentDelete or a DocumentChange if the server
/// can not send the new value of the document.
///
/// Multiple [DocumentRemove][google.firestore.v1.DocumentRemove] messages may be
/// returned for the same logical write or delete, if multiple targets are
/// affected.
class DocumentRemove extends $pb.GeneratedMessage {
  factory DocumentRemove({
    $core.String? document,
    $core.Iterable<$core.int>? removedTargetIds,
    $2.Timestamp? readTime,
  }) {
    final result = DocumentRemove._();
    if (document != null) result.document = document;
    if (removedTargetIds != null)
      result.removedTargetIds.addAll(removedTargetIds);
    if (readTime != null) result.readTime = readTime;
    return result;
  }

  DocumentRemove._();

  factory DocumentRemove.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocumentRemove()..mergeFromBuffer(data, registry);
  factory DocumentRemove.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocumentRemove()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DocumentRemove',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: DocumentRemove.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'document')
    ..p<$core.int>(
        2, _omitFieldNames ? '' : 'removedTargetIds', $pb.PbFieldType.K3)
    ..aOM<$2.Timestamp>(4, _omitFieldNames ? '' : 'readTime',
        subBuilder: $2.Timestamp.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocumentRemove clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocumentRemove copyWith(void Function(DocumentRemove) updates) =>
      super.copyWith((message) => updates(message as DocumentRemove))
          as DocumentRemove;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DocumentRemove() / DocumentRemove.new instead')
  static DocumentRemove create() => DocumentRemove._();
  static $pb.GeneratedMessage $_createMessage() => DocumentRemove._();
  @$core.override
  DocumentRemove createEmptyInstance() => DocumentRemove._();
  @$core.pragma('dart2js:noInline')
  static DocumentRemove getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DocumentRemove>(
          DocumentRemove.$_createMessage);
  static DocumentRemove? _defaultInstance;

  /// The resource name of the [Document][google.firestore.v1.Document] that has
  /// gone out of view.
  @$pb.TagNumber(1)
  $core.String get document => $_getSZ(0);
  @$pb.TagNumber(1)
  set document($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDocument() => $_has(0);
  @$pb.TagNumber(1)
  void clearDocument() => $_clearField(1);

  /// A set of target IDs for targets that previously matched this document.
  @$pb.TagNumber(2)
  $pb.PbList<$core.int> get removedTargetIds => $_getList(1);

  /// The read timestamp at which the remove was observed.
  ///
  /// Greater or equal to the `commit_time` of the change/delete/remove.
  @$pb.TagNumber(4)
  $2.Timestamp get readTime => $_getN(2);
  @$pb.TagNumber(4)
  set readTime($2.Timestamp value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasReadTime() => $_has(2);
  @$pb.TagNumber(4)
  void clearReadTime() => $_clearField(4);
  @$pb.TagNumber(4)
  $2.Timestamp ensureReadTime() => $_ensure(2);
}

/// A digest of all the documents that match a given target.
class ExistenceFilter extends $pb.GeneratedMessage {
  factory ExistenceFilter({
    $core.int? targetId,
    $core.int? count,
    $3.BloomFilter? unchangedNames,
  }) {
    final result = ExistenceFilter._();
    if (targetId != null) result.targetId = targetId;
    if (count != null) result.count = count;
    if (unchangedNames != null) result.unchangedNames = unchangedNames;
    return result;
  }

  ExistenceFilter._();

  factory ExistenceFilter.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExistenceFilter()..mergeFromBuffer(data, registry);
  factory ExistenceFilter.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExistenceFilter()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExistenceFilter',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: ExistenceFilter.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'targetId')
    ..aI(2, _omitFieldNames ? '' : 'count')
    ..aOM<$3.BloomFilter>(3, _omitFieldNames ? '' : 'unchangedNames',
        subBuilder: $3.BloomFilter.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExistenceFilter clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExistenceFilter copyWith(void Function(ExistenceFilter) updates) =>
      super.copyWith((message) => updates(message as ExistenceFilter))
          as ExistenceFilter;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ExistenceFilter() / ExistenceFilter.new instead')
  static ExistenceFilter create() => ExistenceFilter._();
  static $pb.GeneratedMessage $_createMessage() => ExistenceFilter._();
  @$core.override
  ExistenceFilter createEmptyInstance() => ExistenceFilter._();
  @$core.pragma('dart2js:noInline')
  static ExistenceFilter getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ExistenceFilter>(
          ExistenceFilter.$_createMessage);
  static ExistenceFilter? _defaultInstance;

  /// The target ID to which this filter applies.
  @$pb.TagNumber(1)
  $core.int get targetId => $_getIZ(0);
  @$pb.TagNumber(1)
  set targetId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTargetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTargetId() => $_clearField(1);

  /// The total count of documents that match
  /// [target_id][google.firestore.v1.ExistenceFilter.target_id].
  ///
  /// If different from the count of documents in the client that match, the
  /// client must manually determine which documents no longer match the target.
  ///
  /// The client can use the `unchanged_names` bloom filter to assist with
  /// this determination by testing ALL the document names against the filter;
  /// if the document name is NOT in the filter, it means the document no
  /// longer matches the target.
  @$pb.TagNumber(2)
  $core.int get count => $_getIZ(1);
  @$pb.TagNumber(2)
  set count($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearCount() => $_clearField(2);

  /// A bloom filter that, despite its name, contains the UTF-8 byte encodings of
  /// the resource names of ALL the documents that match
  /// [target_id][google.firestore.v1.ExistenceFilter.target_id], in the form
  /// `projects/{project_id}/databases/{database_id}/documents/{document_path}`.
  ///
  /// This bloom filter may be omitted at the server's discretion, such as if it
  /// is deemed that the client will not make use of it or if it is too
  /// computationally expensive to calculate or transmit. Clients must gracefully
  /// handle this field being absent by falling back to the logic used before
  /// this field existed; that is, re-add the target without a resume token to
  /// figure out which documents in the client's cache are out of sync.
  @$pb.TagNumber(3)
  $3.BloomFilter get unchangedNames => $_getN(2);
  @$pb.TagNumber(3)
  set unchangedNames($3.BloomFilter value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasUnchangedNames() => $_has(2);
  @$pb.TagNumber(3)
  void clearUnchangedNames() => $_clearField(3);
  @$pb.TagNumber(3)
  $3.BloomFilter ensureUnchangedNames() => $_ensure(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
