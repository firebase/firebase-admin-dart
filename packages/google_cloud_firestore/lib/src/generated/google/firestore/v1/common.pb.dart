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
// Generated from google/firestore/v1/common.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $0;

import 'common.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'common.pbenum.dart';

/// A set of field paths on a document.
/// Used to restrict a get or update operation on a document to a subset of its
/// fields.
/// This is different from standard field masks, as this is always scoped to a
/// [Document][google.firestore.v1.Document], and takes in account the dynamic
/// nature of [Value][google.firestore.v1.Value].
class DocumentMask extends $pb.GeneratedMessage {
  factory DocumentMask({
    $core.Iterable<$core.String>? fieldPaths,
  }) {
    final result = DocumentMask._();
    if (fieldPaths != null) result.fieldPaths.addAll(fieldPaths);
    return result;
  }

  DocumentMask._();

  factory DocumentMask.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocumentMask()..mergeFromBuffer(data, registry);
  factory DocumentMask.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DocumentMask()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DocumentMask',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: DocumentMask.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'fieldPaths')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocumentMask clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DocumentMask copyWith(void Function(DocumentMask) updates) =>
      super.copyWith((message) => updates(message as DocumentMask))
          as DocumentMask;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DocumentMask() / DocumentMask.new instead')
  static DocumentMask create() => DocumentMask._();
  static $pb.GeneratedMessage $_createMessage() => DocumentMask._();
  @$core.override
  DocumentMask createEmptyInstance() => DocumentMask._();
  @$core.pragma('dart2js:noInline')
  static DocumentMask getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DocumentMask>(
          DocumentMask.$_createMessage);
  static DocumentMask? _defaultInstance;

  /// The list of field paths in the mask. See
  /// [Document.fields][google.firestore.v1.Document.fields] for a field path
  /// syntax reference.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get fieldPaths => $_getList(0);
}

enum Precondition_ConditionType { exists, updateTime, notSet }

/// A precondition on a document, used for conditional operations.
class Precondition extends $pb.GeneratedMessage {
  factory Precondition({
    $core.bool? exists,
    $0.Timestamp? updateTime,
  }) {
    final result = Precondition._();
    if (exists != null) result.exists = exists;
    if (updateTime != null) result.updateTime = updateTime;
    return result;
  }

  Precondition._();

  factory Precondition.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Precondition()..mergeFromBuffer(data, registry);
  factory Precondition.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Precondition()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Precondition_ConditionType>
      _Precondition_ConditionTypeByTag = {
    1: Precondition_ConditionType.exists,
    2: Precondition_ConditionType.updateTime,
    0: Precondition_ConditionType.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Precondition',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: Precondition.$_createMessage)
    ..oo(0, [1, 2])
    ..aOB(1, _omitFieldNames ? '' : 'exists')
    ..aOM<$0.Timestamp>(2, _omitFieldNames ? '' : 'updateTime',
        subBuilder: $0.Timestamp.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Precondition clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Precondition copyWith(void Function(Precondition) updates) =>
      super.copyWith((message) => updates(message as Precondition))
          as Precondition;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Precondition() / Precondition.new instead')
  static Precondition create() => Precondition._();
  static $pb.GeneratedMessage $_createMessage() => Precondition._();
  @$core.override
  Precondition createEmptyInstance() => Precondition._();
  @$core.pragma('dart2js:noInline')
  static Precondition getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Precondition>(
          Precondition.$_createMessage);
  static Precondition? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  Precondition_ConditionType whichConditionType() =>
      _Precondition_ConditionTypeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearConditionType() => $_clearField($_whichOneof(0));

  /// When set to `true`, the target document must exist.
  /// When set to `false`, the target document must not exist.
  @$pb.TagNumber(1)
  $core.bool get exists => $_getBF(0);
  @$pb.TagNumber(1)
  set exists($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasExists() => $_has(0);
  @$pb.TagNumber(1)
  void clearExists() => $_clearField(1);

  /// When set, the target document must exist and have been last updated at
  /// that time. Timestamp must be microsecond aligned.
  @$pb.TagNumber(2)
  $0.Timestamp get updateTime => $_getN(1);
  @$pb.TagNumber(2)
  set updateTime($0.Timestamp value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasUpdateTime() => $_has(1);
  @$pb.TagNumber(2)
  void clearUpdateTime() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.Timestamp ensureUpdateTime() => $_ensure(1);
}

/// Options for a transaction that can be used to read and write documents.
class TransactionOptions_ReadWrite extends $pb.GeneratedMessage {
  factory TransactionOptions_ReadWrite({
    $core.List<$core.int>? retryTransaction,
    TransactionOptions_ConcurrencyMode? concurrencyMode,
  }) {
    final result = TransactionOptions_ReadWrite._();
    if (retryTransaction != null) result.retryTransaction = retryTransaction;
    if (concurrencyMode != null) result.concurrencyMode = concurrencyMode;
    return result;
  }

  TransactionOptions_ReadWrite._();

  factory TransactionOptions_ReadWrite.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransactionOptions_ReadWrite()..mergeFromBuffer(data, registry);
  factory TransactionOptions_ReadWrite.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransactionOptions_ReadWrite()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransactionOptions.ReadWrite',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: TransactionOptions_ReadWrite.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'retryTransaction', $pb.PbFieldType.OY)
    ..aE<TransactionOptions_ConcurrencyMode>(
        2, _omitFieldNames ? '' : 'concurrencyMode',
        enumValues: TransactionOptions_ConcurrencyMode.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionOptions_ReadWrite clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionOptions_ReadWrite copyWith(
          void Function(TransactionOptions_ReadWrite) updates) =>
      super.copyWith(
              (message) => updates(message as TransactionOptions_ReadWrite))
          as TransactionOptions_ReadWrite;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TransactionOptions_ReadWrite() / TransactionOptions_ReadWrite.new instead')
  static TransactionOptions_ReadWrite create() =>
      TransactionOptions_ReadWrite._();
  static $pb.GeneratedMessage $_createMessage() =>
      TransactionOptions_ReadWrite._();
  @$core.override
  TransactionOptions_ReadWrite createEmptyInstance() =>
      TransactionOptions_ReadWrite._();
  @$core.pragma('dart2js:noInline')
  static TransactionOptions_ReadWrite getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransactionOptions_ReadWrite>(
          TransactionOptions_ReadWrite.$_createMessage);
  static TransactionOptions_ReadWrite? _defaultInstance;

  /// An optional transaction to retry.
  @$pb.TagNumber(1)
  $core.List<$core.int> get retryTransaction => $_getN(0);
  @$pb.TagNumber(1)
  set retryTransaction($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRetryTransaction() => $_has(0);
  @$pb.TagNumber(1)
  void clearRetryTransaction() => $_clearField(1);

  /// Optional. The concurrency control mode to use for this transaction.
  ///
  /// A database is able to use different concurrency modes for different
  /// transactions simultaneously.
  ///
  /// 3rd party auth requests are only allowed to create optimistic
  /// read-write transactions and must specify that here even if the
  /// database-level setting is already configured to optimistic.
  @$pb.TagNumber(2)
  TransactionOptions_ConcurrencyMode get concurrencyMode => $_getN(1);
  @$pb.TagNumber(2)
  set concurrencyMode(TransactionOptions_ConcurrencyMode value) =>
      $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasConcurrencyMode() => $_has(1);
  @$pb.TagNumber(2)
  void clearConcurrencyMode() => $_clearField(2);
}

enum TransactionOptions_ReadOnly_ConsistencySelector { readTime, notSet }

/// Options for a transaction that can only be used to read documents.
class TransactionOptions_ReadOnly extends $pb.GeneratedMessage {
  factory TransactionOptions_ReadOnly({
    $0.Timestamp? readTime,
  }) {
    final result = TransactionOptions_ReadOnly._();
    if (readTime != null) result.readTime = readTime;
    return result;
  }

  TransactionOptions_ReadOnly._();

  factory TransactionOptions_ReadOnly.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransactionOptions_ReadOnly()..mergeFromBuffer(data, registry);
  factory TransactionOptions_ReadOnly.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransactionOptions_ReadOnly()..mergeFromJson(json, registry);

  static const $core
      .Map<$core.int, TransactionOptions_ReadOnly_ConsistencySelector>
      _TransactionOptions_ReadOnly_ConsistencySelectorByTag = {
    2: TransactionOptions_ReadOnly_ConsistencySelector.readTime,
    0: TransactionOptions_ReadOnly_ConsistencySelector.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransactionOptions.ReadOnly',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: TransactionOptions_ReadOnly.$_createMessage)
    ..oo(0, [2])
    ..aOM<$0.Timestamp>(2, _omitFieldNames ? '' : 'readTime',
        subBuilder: $0.Timestamp.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionOptions_ReadOnly clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionOptions_ReadOnly copyWith(
          void Function(TransactionOptions_ReadOnly) updates) =>
      super.copyWith(
              (message) => updates(message as TransactionOptions_ReadOnly))
          as TransactionOptions_ReadOnly;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TransactionOptions_ReadOnly() / TransactionOptions_ReadOnly.new instead')
  static TransactionOptions_ReadOnly create() =>
      TransactionOptions_ReadOnly._();
  static $pb.GeneratedMessage $_createMessage() =>
      TransactionOptions_ReadOnly._();
  @$core.override
  TransactionOptions_ReadOnly createEmptyInstance() =>
      TransactionOptions_ReadOnly._();
  @$core.pragma('dart2js:noInline')
  static TransactionOptions_ReadOnly getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransactionOptions_ReadOnly>(
          TransactionOptions_ReadOnly.$_createMessage);
  static TransactionOptions_ReadOnly? _defaultInstance;

  @$pb.TagNumber(2)
  TransactionOptions_ReadOnly_ConsistencySelector whichConsistencySelector() =>
      _TransactionOptions_ReadOnly_ConsistencySelectorByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  void clearConsistencySelector() => $_clearField($_whichOneof(0));

  /// Reads documents at the given time.
  ///
  /// This must be a microsecond precision timestamp within the past one
  /// hour, or if Point-in-Time Recovery is enabled, can additionally be a
  /// whole minute timestamp within the past 7 days.
  @$pb.TagNumber(2)
  $0.Timestamp get readTime => $_getN(0);
  @$pb.TagNumber(2)
  set readTime($0.Timestamp value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasReadTime() => $_has(0);
  @$pb.TagNumber(2)
  void clearReadTime() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.Timestamp ensureReadTime() => $_ensure(0);
}

enum TransactionOptions_Mode { readOnly, readWrite, notSet }

/// Options for creating a new transaction.
class TransactionOptions extends $pb.GeneratedMessage {
  factory TransactionOptions({
    TransactionOptions_ReadOnly? readOnly,
    TransactionOptions_ReadWrite? readWrite,
  }) {
    final result = TransactionOptions._();
    if (readOnly != null) result.readOnly = readOnly;
    if (readWrite != null) result.readWrite = readWrite;
    return result;
  }

  TransactionOptions._();

  factory TransactionOptions.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransactionOptions()..mergeFromBuffer(data, registry);
  factory TransactionOptions.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransactionOptions()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, TransactionOptions_Mode>
      _TransactionOptions_ModeByTag = {
    2: TransactionOptions_Mode.readOnly,
    3: TransactionOptions_Mode.readWrite,
    0: TransactionOptions_Mode.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransactionOptions',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: TransactionOptions.$_createMessage)
    ..oo(0, [2, 3])
    ..aOM<TransactionOptions_ReadOnly>(2, _omitFieldNames ? '' : 'readOnly',
        subBuilder: TransactionOptions_ReadOnly.$_createMessage)
    ..aOM<TransactionOptions_ReadWrite>(3, _omitFieldNames ? '' : 'readWrite',
        subBuilder: TransactionOptions_ReadWrite.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionOptions clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransactionOptions copyWith(void Function(TransactionOptions) updates) =>
      super.copyWith((message) => updates(message as TransactionOptions))
          as TransactionOptions;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TransactionOptions() / TransactionOptions.new instead')
  static TransactionOptions create() => TransactionOptions._();
  static $pb.GeneratedMessage $_createMessage() => TransactionOptions._();
  @$core.override
  TransactionOptions createEmptyInstance() => TransactionOptions._();
  @$core.pragma('dart2js:noInline')
  static TransactionOptions getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransactionOptions>(
          TransactionOptions.$_createMessage);
  static TransactionOptions? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  TransactionOptions_Mode whichMode() =>
      _TransactionOptions_ModeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearMode() => $_clearField($_whichOneof(0));

  /// The transaction can only be used for read operations.
  @$pb.TagNumber(2)
  TransactionOptions_ReadOnly get readOnly => $_getN(0);
  @$pb.TagNumber(2)
  set readOnly(TransactionOptions_ReadOnly value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasReadOnly() => $_has(0);
  @$pb.TagNumber(2)
  void clearReadOnly() => $_clearField(2);
  @$pb.TagNumber(2)
  TransactionOptions_ReadOnly ensureReadOnly() => $_ensure(0);

  /// The transaction can be used for both read and write operations.
  @$pb.TagNumber(3)
  TransactionOptions_ReadWrite get readWrite => $_getN(1);
  @$pb.TagNumber(3)
  set readWrite(TransactionOptions_ReadWrite value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasReadWrite() => $_has(1);
  @$pb.TagNumber(3)
  void clearReadWrite() => $_clearField(3);
  @$pb.TagNumber(3)
  TransactionOptions_ReadWrite ensureReadWrite() => $_ensure(1);
}

/// Options for a server request.
class RequestOptions extends $pb.GeneratedMessage {
  factory RequestOptions({
    $core.Iterable<$core.String>? requestTags,
  }) {
    final result = RequestOptions._();
    if (requestTags != null) result.requestTags.addAll(requestTags);
    return result;
  }

  RequestOptions._();

  factory RequestOptions.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RequestOptions()..mergeFromBuffer(data, registry);
  factory RequestOptions.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RequestOptions()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RequestOptions',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: RequestOptions.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'requestTags')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestOptions clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestOptions copyWith(void Function(RequestOptions) updates) =>
      super.copyWith((message) => updates(message as RequestOptions))
          as RequestOptions;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RequestOptions() / RequestOptions.new instead')
  static RequestOptions create() => RequestOptions._();
  static $pb.GeneratedMessage $_createMessage() => RequestOptions._();
  @$core.override
  RequestOptions createEmptyInstance() => RequestOptions._();
  @$core.pragma('dart2js:noInline')
  static RequestOptions getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RequestOptions>(
          RequestOptions.$_createMessage);
  static RequestOptions? _defaultInstance;

  /// The request tags for the request.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get requestTags => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
