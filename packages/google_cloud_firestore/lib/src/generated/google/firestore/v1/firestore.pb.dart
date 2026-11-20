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
// Generated from google/firestore/v1/firestore.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $4;
import 'package:protobuf/well_known_types/google/protobuf/wrappers.pb.dart'
    as $11;

import '../../rpc/status.pb.dart' as $12;
import 'aggregation_result.pb.dart' as $10;
import 'common.pb.dart' as $3;
import 'document.pb.dart' as $1;
import 'explain_stats.pb.dart' as $9;
import 'firestore.pbenum.dart';
import 'pipeline.pb.dart' as $8;
import 'query.pb.dart' as $6;
import 'query_profile.pb.dart' as $7;
import 'write.pb.dart' as $5;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'firestore.pbenum.dart';

enum GetDocumentRequest_ConsistencySelector { transaction, readTime, notSet }

/// The request for
/// [Firestore.GetDocument][google.firestore.v1.Firestore.GetDocument].
class GetDocumentRequest extends $pb.GeneratedMessage {
  factory GetDocumentRequest({
    $core.String? name,
    $3.DocumentMask? mask,
    $core.List<$core.int>? transaction,
    $4.Timestamp? readTime,
    $3.RequestOptions? requestOptions,
  }) {
    final result = GetDocumentRequest._();
    if (name != null) result.name = name;
    if (mask != null) result.mask = mask;
    if (transaction != null) result.transaction = transaction;
    if (readTime != null) result.readTime = readTime;
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  GetDocumentRequest._();

  factory GetDocumentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetDocumentRequest()..mergeFromBuffer(data, registry);
  factory GetDocumentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetDocumentRequest()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, GetDocumentRequest_ConsistencySelector>
      _GetDocumentRequest_ConsistencySelectorByTag = {
    3: GetDocumentRequest_ConsistencySelector.transaction,
    5: GetDocumentRequest_ConsistencySelector.readTime,
    0: GetDocumentRequest_ConsistencySelector.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetDocumentRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: GetDocumentRequest.$_createMessage)
    ..oo(0, [3, 5])
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOM<$3.DocumentMask>(2, _omitFieldNames ? '' : 'mask',
        subBuilder: $3.DocumentMask.$_createMessage)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'transaction', $pb.PbFieldType.OY)
    ..aOM<$4.Timestamp>(5, _omitFieldNames ? '' : 'readTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..aOM<$3.RequestOptions>(10, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetDocumentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetDocumentRequest copyWith(void Function(GetDocumentRequest) updates) =>
      super.copyWith((message) => updates(message as GetDocumentRequest))
          as GetDocumentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetDocumentRequest() / GetDocumentRequest.new instead')
  static GetDocumentRequest create() => GetDocumentRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetDocumentRequest._();
  @$core.override
  GetDocumentRequest createEmptyInstance() => GetDocumentRequest._();
  @$core.pragma('dart2js:noInline')
  static GetDocumentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetDocumentRequest>(
          GetDocumentRequest.$_createMessage);
  static GetDocumentRequest? _defaultInstance;

  @$pb.TagNumber(3)
  @$pb.TagNumber(5)
  GetDocumentRequest_ConsistencySelector whichConsistencySelector() =>
      _GetDocumentRequest_ConsistencySelectorByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(3)
  @$pb.TagNumber(5)
  void clearConsistencySelector() => $_clearField($_whichOneof(0));

  /// Required. The resource name of the Document to get. In the format:
  /// `projects/{project_id}/databases/{database_id}/documents/{document_path}`.
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// The fields to return. If not set, returns all fields.
  ///
  /// If the document has a field that is not present in this mask, that field
  /// will not be returned in the response.
  @$pb.TagNumber(2)
  $3.DocumentMask get mask => $_getN(1);
  @$pb.TagNumber(2)
  set mask($3.DocumentMask value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasMask() => $_has(1);
  @$pb.TagNumber(2)
  void clearMask() => $_clearField(2);
  @$pb.TagNumber(2)
  $3.DocumentMask ensureMask() => $_ensure(1);

  /// Reads the document in a transaction.
  @$pb.TagNumber(3)
  $core.List<$core.int> get transaction => $_getN(2);
  @$pb.TagNumber(3)
  set transaction($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTransaction() => $_has(2);
  @$pb.TagNumber(3)
  void clearTransaction() => $_clearField(3);

  /// Reads the version of the document at the given time.
  ///
  /// This must be a microsecond precision timestamp within the past one hour,
  /// or if Point-in-Time Recovery is enabled, can additionally be a whole
  /// minute timestamp within the past 7 days.
  @$pb.TagNumber(5)
  $4.Timestamp get readTime => $_getN(3);
  @$pb.TagNumber(5)
  set readTime($4.Timestamp value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasReadTime() => $_has(3);
  @$pb.TagNumber(5)
  void clearReadTime() => $_clearField(5);
  @$pb.TagNumber(5)
  $4.Timestamp ensureReadTime() => $_ensure(3);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(10)
  $3.RequestOptions get requestOptions => $_getN(4);
  @$pb.TagNumber(10)
  set requestOptions($3.RequestOptions value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasRequestOptions() => $_has(4);
  @$pb.TagNumber(10)
  void clearRequestOptions() => $_clearField(10);
  @$pb.TagNumber(10)
  $3.RequestOptions ensureRequestOptions() => $_ensure(4);
}

enum ListDocumentsRequest_ConsistencySelector { transaction, readTime, notSet }

/// The request for
/// [Firestore.ListDocuments][google.firestore.v1.Firestore.ListDocuments].
class ListDocumentsRequest extends $pb.GeneratedMessage {
  factory ListDocumentsRequest({
    $core.String? parent,
    $core.String? collectionId,
    $core.int? pageSize,
    $core.String? pageToken,
    $core.String? orderBy,
    $3.DocumentMask? mask,
    $core.List<$core.int>? transaction,
    $4.Timestamp? readTime,
    $core.bool? showMissing,
    $3.RequestOptions? requestOptions,
  }) {
    final result = ListDocumentsRequest._();
    if (parent != null) result.parent = parent;
    if (collectionId != null) result.collectionId = collectionId;
    if (pageSize != null) result.pageSize = pageSize;
    if (pageToken != null) result.pageToken = pageToken;
    if (orderBy != null) result.orderBy = orderBy;
    if (mask != null) result.mask = mask;
    if (transaction != null) result.transaction = transaction;
    if (readTime != null) result.readTime = readTime;
    if (showMissing != null) result.showMissing = showMissing;
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  ListDocumentsRequest._();

  factory ListDocumentsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListDocumentsRequest()..mergeFromBuffer(data, registry);
  factory ListDocumentsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListDocumentsRequest()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ListDocumentsRequest_ConsistencySelector>
      _ListDocumentsRequest_ConsistencySelectorByTag = {
    8: ListDocumentsRequest_ConsistencySelector.transaction,
    10: ListDocumentsRequest_ConsistencySelector.readTime,
    0: ListDocumentsRequest_ConsistencySelector.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListDocumentsRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: ListDocumentsRequest.$_createMessage)
    ..oo(0, [8, 10])
    ..aOS(1, _omitFieldNames ? '' : 'parent')
    ..aOS(2, _omitFieldNames ? '' : 'collectionId')
    ..aI(3, _omitFieldNames ? '' : 'pageSize')
    ..aOS(4, _omitFieldNames ? '' : 'pageToken')
    ..aOS(6, _omitFieldNames ? '' : 'orderBy')
    ..aOM<$3.DocumentMask>(7, _omitFieldNames ? '' : 'mask',
        subBuilder: $3.DocumentMask.$_createMessage)
    ..a<$core.List<$core.int>>(
        8, _omitFieldNames ? '' : 'transaction', $pb.PbFieldType.OY)
    ..aOM<$4.Timestamp>(10, _omitFieldNames ? '' : 'readTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..aOB(12, _omitFieldNames ? '' : 'showMissing')
    ..aOM<$3.RequestOptions>(13, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDocumentsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDocumentsRequest copyWith(void Function(ListDocumentsRequest) updates) =>
      super.copyWith((message) => updates(message as ListDocumentsRequest))
          as ListDocumentsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListDocumentsRequest() / ListDocumentsRequest.new instead')
  static ListDocumentsRequest create() => ListDocumentsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListDocumentsRequest._();
  @$core.override
  ListDocumentsRequest createEmptyInstance() => ListDocumentsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListDocumentsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListDocumentsRequest>(
          ListDocumentsRequest.$_createMessage);
  static ListDocumentsRequest? _defaultInstance;

  @$pb.TagNumber(8)
  @$pb.TagNumber(10)
  ListDocumentsRequest_ConsistencySelector whichConsistencySelector() =>
      _ListDocumentsRequest_ConsistencySelectorByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(8)
  @$pb.TagNumber(10)
  void clearConsistencySelector() => $_clearField($_whichOneof(0));

  /// Required. The parent resource name. In the format:
  /// `projects/{project_id}/databases/{database_id}/documents` or
  /// `projects/{project_id}/databases/{database_id}/documents/{document_path}`.
  ///
  /// For example:
  /// `projects/my-project/databases/my-database/documents` or
  /// `projects/my-project/databases/my-database/documents/chatrooms/my-chatroom`
  @$pb.TagNumber(1)
  $core.String get parent => $_getSZ(0);
  @$pb.TagNumber(1)
  set parent($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasParent() => $_has(0);
  @$pb.TagNumber(1)
  void clearParent() => $_clearField(1);

  /// Optional. The collection ID, relative to `parent`, to list.
  ///
  /// For example: `chatrooms` or `messages`.
  ///
  /// This is optional, and when not provided, Firestore will list documents
  /// from all collections under the provided `parent`.
  @$pb.TagNumber(2)
  $core.String get collectionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set collectionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCollectionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearCollectionId() => $_clearField(2);

  /// Optional. The maximum number of documents to return in a single response.
  ///
  /// Firestore may return fewer than this value.
  @$pb.TagNumber(3)
  $core.int get pageSize => $_getIZ(2);
  @$pb.TagNumber(3)
  set pageSize($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPageSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearPageSize() => $_clearField(3);

  /// Optional. A page token, received from a previous `ListDocuments` response.
  ///
  /// Provide this to retrieve the subsequent page. When paginating, all other
  /// parameters (with the exception of `page_size`) must match the values set
  /// in the request that generated the page token.
  @$pb.TagNumber(4)
  $core.String get pageToken => $_getSZ(3);
  @$pb.TagNumber(4)
  set pageToken($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPageToken() => $_has(3);
  @$pb.TagNumber(4)
  void clearPageToken() => $_clearField(4);

  /// Optional. The optional ordering of the documents to return.
  ///
  /// For example: `priority desc, __name__ desc`.
  ///
  /// This mirrors the [`ORDER BY`][google.firestore.v1.StructuredQuery.order_by]
  /// used in Firestore queries but in a string representation. When absent,
  /// documents are ordered based on `__name__ ASC`.
  @$pb.TagNumber(6)
  $core.String get orderBy => $_getSZ(4);
  @$pb.TagNumber(6)
  set orderBy($core.String value) => $_setString(4, value);
  @$pb.TagNumber(6)
  $core.bool hasOrderBy() => $_has(4);
  @$pb.TagNumber(6)
  void clearOrderBy() => $_clearField(6);

  /// Optional. The fields to return. If not set, returns all fields.
  ///
  /// If a document has a field that is not present in this mask, that field
  /// will not be returned in the response.
  @$pb.TagNumber(7)
  $3.DocumentMask get mask => $_getN(5);
  @$pb.TagNumber(7)
  set mask($3.DocumentMask value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasMask() => $_has(5);
  @$pb.TagNumber(7)
  void clearMask() => $_clearField(7);
  @$pb.TagNumber(7)
  $3.DocumentMask ensureMask() => $_ensure(5);

  /// Perform the read as part of an already active transaction.
  @$pb.TagNumber(8)
  $core.List<$core.int> get transaction => $_getN(6);
  @$pb.TagNumber(8)
  set transaction($core.List<$core.int> value) => $_setBytes(6, value);
  @$pb.TagNumber(8)
  $core.bool hasTransaction() => $_has(6);
  @$pb.TagNumber(8)
  void clearTransaction() => $_clearField(8);

  /// Perform the read at the provided time.
  ///
  /// This must be a microsecond precision timestamp within the past one hour,
  /// or if Point-in-Time Recovery is enabled, can additionally be a whole
  /// minute timestamp within the past 7 days.
  @$pb.TagNumber(10)
  $4.Timestamp get readTime => $_getN(7);
  @$pb.TagNumber(10)
  set readTime($4.Timestamp value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasReadTime() => $_has(7);
  @$pb.TagNumber(10)
  void clearReadTime() => $_clearField(10);
  @$pb.TagNumber(10)
  $4.Timestamp ensureReadTime() => $_ensure(7);

  /// If the list should show missing documents.
  ///
  /// A document is missing if it does not exist, but there are sub-documents
  /// nested underneath it. When true, such missing documents will be returned
  /// with a key but will not have fields,
  /// [`create_time`][google.firestore.v1.Document.create_time], or
  /// [`update_time`][google.firestore.v1.Document.update_time] set.
  ///
  /// Requests with `show_missing` may not specify `where` or `order_by`.
  @$pb.TagNumber(12)
  $core.bool get showMissing => $_getBF(8);
  @$pb.TagNumber(12)
  set showMissing($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(12)
  $core.bool hasShowMissing() => $_has(8);
  @$pb.TagNumber(12)
  void clearShowMissing() => $_clearField(12);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(13)
  $3.RequestOptions get requestOptions => $_getN(9);
  @$pb.TagNumber(13)
  set requestOptions($3.RequestOptions value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasRequestOptions() => $_has(9);
  @$pb.TagNumber(13)
  void clearRequestOptions() => $_clearField(13);
  @$pb.TagNumber(13)
  $3.RequestOptions ensureRequestOptions() => $_ensure(9);
}

/// The response for
/// [Firestore.ListDocuments][google.firestore.v1.Firestore.ListDocuments].
class ListDocumentsResponse extends $pb.GeneratedMessage {
  factory ListDocumentsResponse({
    $core.Iterable<$1.Document>? documents,
    $core.String? nextPageToken,
  }) {
    final result = ListDocumentsResponse._();
    if (documents != null) result.documents.addAll(documents);
    if (nextPageToken != null) result.nextPageToken = nextPageToken;
    return result;
  }

  ListDocumentsResponse._();

  factory ListDocumentsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListDocumentsResponse()..mergeFromBuffer(data, registry);
  factory ListDocumentsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListDocumentsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListDocumentsResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: ListDocumentsResponse.$_createMessage)
    ..pPM<$1.Document>(1, _omitFieldNames ? '' : 'documents',
        subBuilder: $1.Document.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'nextPageToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDocumentsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDocumentsResponse copyWith(
          void Function(ListDocumentsResponse) updates) =>
      super.copyWith((message) => updates(message as ListDocumentsResponse))
          as ListDocumentsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListDocumentsResponse() / ListDocumentsResponse.new instead')
  static ListDocumentsResponse create() => ListDocumentsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListDocumentsResponse._();
  @$core.override
  ListDocumentsResponse createEmptyInstance() => ListDocumentsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListDocumentsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListDocumentsResponse>(
          ListDocumentsResponse.$_createMessage);
  static ListDocumentsResponse? _defaultInstance;

  /// The Documents found.
  @$pb.TagNumber(1)
  $pb.PbList<$1.Document> get documents => $_getList(0);

  /// A token to retrieve the next page of documents.
  ///
  /// If this field is omitted, there are no subsequent pages.
  @$pb.TagNumber(2)
  $core.String get nextPageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set nextPageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNextPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextPageToken() => $_clearField(2);
}

/// The request for
/// [Firestore.CreateDocument][google.firestore.v1.Firestore.CreateDocument].
class CreateDocumentRequest extends $pb.GeneratedMessage {
  factory CreateDocumentRequest({
    $core.String? parent,
    $core.String? collectionId,
    $core.String? documentId,
    $1.Document? document,
    $3.DocumentMask? mask,
    $3.RequestOptions? requestOptions,
  }) {
    final result = CreateDocumentRequest._();
    if (parent != null) result.parent = parent;
    if (collectionId != null) result.collectionId = collectionId;
    if (documentId != null) result.documentId = documentId;
    if (document != null) result.document = document;
    if (mask != null) result.mask = mask;
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  CreateDocumentRequest._();

  factory CreateDocumentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateDocumentRequest()..mergeFromBuffer(data, registry);
  factory CreateDocumentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CreateDocumentRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateDocumentRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: CreateDocumentRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'parent')
    ..aOS(2, _omitFieldNames ? '' : 'collectionId')
    ..aOS(3, _omitFieldNames ? '' : 'documentId')
    ..aOM<$1.Document>(4, _omitFieldNames ? '' : 'document',
        subBuilder: $1.Document.$_createMessage)
    ..aOM<$3.DocumentMask>(5, _omitFieldNames ? '' : 'mask',
        subBuilder: $3.DocumentMask.$_createMessage)
    ..aOM<$3.RequestOptions>(6, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDocumentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateDocumentRequest copyWith(
          void Function(CreateDocumentRequest) updates) =>
      super.copyWith((message) => updates(message as CreateDocumentRequest))
          as CreateDocumentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CreateDocumentRequest() / CreateDocumentRequest.new instead')
  static CreateDocumentRequest create() => CreateDocumentRequest._();
  static $pb.GeneratedMessage $_createMessage() => CreateDocumentRequest._();
  @$core.override
  CreateDocumentRequest createEmptyInstance() => CreateDocumentRequest._();
  @$core.pragma('dart2js:noInline')
  static CreateDocumentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateDocumentRequest>(
          CreateDocumentRequest.$_createMessage);
  static CreateDocumentRequest? _defaultInstance;

  /// Required. The parent resource. For example:
  /// `projects/{project_id}/databases/{database_id}/documents` or
  /// `projects/{project_id}/databases/{database_id}/documents/chatrooms/{chatroom_id}`
  @$pb.TagNumber(1)
  $core.String get parent => $_getSZ(0);
  @$pb.TagNumber(1)
  set parent($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasParent() => $_has(0);
  @$pb.TagNumber(1)
  void clearParent() => $_clearField(1);

  /// Required. The collection ID, relative to `parent`, to list. For example:
  /// `chatrooms`.
  @$pb.TagNumber(2)
  $core.String get collectionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set collectionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCollectionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearCollectionId() => $_clearField(2);

  /// The client-assigned document ID to use for this document.
  ///
  /// Optional. If not specified, an ID will be assigned by the service.
  @$pb.TagNumber(3)
  $core.String get documentId => $_getSZ(2);
  @$pb.TagNumber(3)
  set documentId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDocumentId() => $_has(2);
  @$pb.TagNumber(3)
  void clearDocumentId() => $_clearField(3);

  /// Required. The document to create. `name` must not be set.
  @$pb.TagNumber(4)
  $1.Document get document => $_getN(3);
  @$pb.TagNumber(4)
  set document($1.Document value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasDocument() => $_has(3);
  @$pb.TagNumber(4)
  void clearDocument() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.Document ensureDocument() => $_ensure(3);

  /// The fields to return. If not set, returns all fields.
  ///
  /// If the document has a field that is not present in this mask, that field
  /// will not be returned in the response.
  @$pb.TagNumber(5)
  $3.DocumentMask get mask => $_getN(4);
  @$pb.TagNumber(5)
  set mask($3.DocumentMask value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasMask() => $_has(4);
  @$pb.TagNumber(5)
  void clearMask() => $_clearField(5);
  @$pb.TagNumber(5)
  $3.DocumentMask ensureMask() => $_ensure(4);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(6)
  $3.RequestOptions get requestOptions => $_getN(5);
  @$pb.TagNumber(6)
  set requestOptions($3.RequestOptions value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasRequestOptions() => $_has(5);
  @$pb.TagNumber(6)
  void clearRequestOptions() => $_clearField(6);
  @$pb.TagNumber(6)
  $3.RequestOptions ensureRequestOptions() => $_ensure(5);
}

/// The request for
/// [Firestore.UpdateDocument][google.firestore.v1.Firestore.UpdateDocument].
class UpdateDocumentRequest extends $pb.GeneratedMessage {
  factory UpdateDocumentRequest({
    $1.Document? document,
    $3.DocumentMask? updateMask,
    $3.DocumentMask? mask,
    $3.Precondition? currentDocument,
    $3.RequestOptions? requestOptions,
  }) {
    final result = UpdateDocumentRequest._();
    if (document != null) result.document = document;
    if (updateMask != null) result.updateMask = updateMask;
    if (mask != null) result.mask = mask;
    if (currentDocument != null) result.currentDocument = currentDocument;
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  UpdateDocumentRequest._();

  factory UpdateDocumentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateDocumentRequest()..mergeFromBuffer(data, registry);
  factory UpdateDocumentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UpdateDocumentRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateDocumentRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: UpdateDocumentRequest.$_createMessage)
    ..aOM<$1.Document>(1, _omitFieldNames ? '' : 'document',
        subBuilder: $1.Document.$_createMessage)
    ..aOM<$3.DocumentMask>(2, _omitFieldNames ? '' : 'updateMask',
        subBuilder: $3.DocumentMask.$_createMessage)
    ..aOM<$3.DocumentMask>(3, _omitFieldNames ? '' : 'mask',
        subBuilder: $3.DocumentMask.$_createMessage)
    ..aOM<$3.Precondition>(4, _omitFieldNames ? '' : 'currentDocument',
        subBuilder: $3.Precondition.$_createMessage)
    ..aOM<$3.RequestOptions>(5, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateDocumentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateDocumentRequest copyWith(
          void Function(UpdateDocumentRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateDocumentRequest))
          as UpdateDocumentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use UpdateDocumentRequest() / UpdateDocumentRequest.new instead')
  static UpdateDocumentRequest create() => UpdateDocumentRequest._();
  static $pb.GeneratedMessage $_createMessage() => UpdateDocumentRequest._();
  @$core.override
  UpdateDocumentRequest createEmptyInstance() => UpdateDocumentRequest._();
  @$core.pragma('dart2js:noInline')
  static UpdateDocumentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateDocumentRequest>(
          UpdateDocumentRequest.$_createMessage);
  static UpdateDocumentRequest? _defaultInstance;

  /// Required. The updated document.
  /// Creates the document if it does not already exist.
  @$pb.TagNumber(1)
  $1.Document get document => $_getN(0);
  @$pb.TagNumber(1)
  set document($1.Document value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDocument() => $_has(0);
  @$pb.TagNumber(1)
  void clearDocument() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Document ensureDocument() => $_ensure(0);

  /// The fields to update.
  /// None of the field paths in the mask may contain a reserved name.
  ///
  /// If the document exists on the server and has fields not referenced in the
  /// mask, they are left unchanged.
  /// Fields referenced in the mask, but not present in the input document, are
  /// deleted from the document on the server.
  @$pb.TagNumber(2)
  $3.DocumentMask get updateMask => $_getN(1);
  @$pb.TagNumber(2)
  set updateMask($3.DocumentMask value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasUpdateMask() => $_has(1);
  @$pb.TagNumber(2)
  void clearUpdateMask() => $_clearField(2);
  @$pb.TagNumber(2)
  $3.DocumentMask ensureUpdateMask() => $_ensure(1);

  /// The fields to return. If not set, returns all fields.
  ///
  /// If the document has a field that is not present in this mask, that field
  /// will not be returned in the response.
  @$pb.TagNumber(3)
  $3.DocumentMask get mask => $_getN(2);
  @$pb.TagNumber(3)
  set mask($3.DocumentMask value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasMask() => $_has(2);
  @$pb.TagNumber(3)
  void clearMask() => $_clearField(3);
  @$pb.TagNumber(3)
  $3.DocumentMask ensureMask() => $_ensure(2);

  /// An optional precondition on the document.
  /// The request will fail if this is set and not met by the target document.
  @$pb.TagNumber(4)
  $3.Precondition get currentDocument => $_getN(3);
  @$pb.TagNumber(4)
  set currentDocument($3.Precondition value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCurrentDocument() => $_has(3);
  @$pb.TagNumber(4)
  void clearCurrentDocument() => $_clearField(4);
  @$pb.TagNumber(4)
  $3.Precondition ensureCurrentDocument() => $_ensure(3);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(5)
  $3.RequestOptions get requestOptions => $_getN(4);
  @$pb.TagNumber(5)
  set requestOptions($3.RequestOptions value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRequestOptions() => $_has(4);
  @$pb.TagNumber(5)
  void clearRequestOptions() => $_clearField(5);
  @$pb.TagNumber(5)
  $3.RequestOptions ensureRequestOptions() => $_ensure(4);
}

/// The request for
/// [Firestore.DeleteDocument][google.firestore.v1.Firestore.DeleteDocument].
class DeleteDocumentRequest extends $pb.GeneratedMessage {
  factory DeleteDocumentRequest({
    $core.String? name,
    $3.Precondition? currentDocument,
    $3.RequestOptions? requestOptions,
  }) {
    final result = DeleteDocumentRequest._();
    if (name != null) result.name = name;
    if (currentDocument != null) result.currentDocument = currentDocument;
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  DeleteDocumentRequest._();

  factory DeleteDocumentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteDocumentRequest()..mergeFromBuffer(data, registry);
  factory DeleteDocumentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteDocumentRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteDocumentRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: DeleteDocumentRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOM<$3.Precondition>(2, _omitFieldNames ? '' : 'currentDocument',
        subBuilder: $3.Precondition.$_createMessage)
    ..aOM<$3.RequestOptions>(3, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteDocumentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteDocumentRequest copyWith(
          void Function(DeleteDocumentRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteDocumentRequest))
          as DeleteDocumentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DeleteDocumentRequest() / DeleteDocumentRequest.new instead')
  static DeleteDocumentRequest create() => DeleteDocumentRequest._();
  static $pb.GeneratedMessage $_createMessage() => DeleteDocumentRequest._();
  @$core.override
  DeleteDocumentRequest createEmptyInstance() => DeleteDocumentRequest._();
  @$core.pragma('dart2js:noInline')
  static DeleteDocumentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteDocumentRequest>(
          DeleteDocumentRequest.$_createMessage);
  static DeleteDocumentRequest? _defaultInstance;

  /// Required. The resource name of the Document to delete. In the format:
  /// `projects/{project_id}/databases/{database_id}/documents/{document_path}`.
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// An optional precondition on the document.
  /// The request will fail if this is set and not met by the target document.
  @$pb.TagNumber(2)
  $3.Precondition get currentDocument => $_getN(1);
  @$pb.TagNumber(2)
  set currentDocument($3.Precondition value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCurrentDocument() => $_has(1);
  @$pb.TagNumber(2)
  void clearCurrentDocument() => $_clearField(2);
  @$pb.TagNumber(2)
  $3.Precondition ensureCurrentDocument() => $_ensure(1);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(3)
  $3.RequestOptions get requestOptions => $_getN(2);
  @$pb.TagNumber(3)
  set requestOptions($3.RequestOptions value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRequestOptions() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequestOptions() => $_clearField(3);
  @$pb.TagNumber(3)
  $3.RequestOptions ensureRequestOptions() => $_ensure(2);
}

enum BatchGetDocumentsRequest_ConsistencySelector {
  transaction,
  newTransaction,
  readTime,
  notSet
}

/// The request for
/// [Firestore.BatchGetDocuments][google.firestore.v1.Firestore.BatchGetDocuments].
class BatchGetDocumentsRequest extends $pb.GeneratedMessage {
  factory BatchGetDocumentsRequest({
    $core.String? database,
    $core.Iterable<$core.String>? documents,
    $3.DocumentMask? mask,
    $core.List<$core.int>? transaction,
    $3.TransactionOptions? newTransaction,
    $4.Timestamp? readTime,
    $3.RequestOptions? requestOptions,
  }) {
    final result = BatchGetDocumentsRequest._();
    if (database != null) result.database = database;
    if (documents != null) result.documents.addAll(documents);
    if (mask != null) result.mask = mask;
    if (transaction != null) result.transaction = transaction;
    if (newTransaction != null) result.newTransaction = newTransaction;
    if (readTime != null) result.readTime = readTime;
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  BatchGetDocumentsRequest._();

  factory BatchGetDocumentsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BatchGetDocumentsRequest()..mergeFromBuffer(data, registry);
  factory BatchGetDocumentsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BatchGetDocumentsRequest()..mergeFromJson(json, registry);

  static const $core
      .Map<$core.int, BatchGetDocumentsRequest_ConsistencySelector>
      _BatchGetDocumentsRequest_ConsistencySelectorByTag = {
    4: BatchGetDocumentsRequest_ConsistencySelector.transaction,
    5: BatchGetDocumentsRequest_ConsistencySelector.newTransaction,
    7: BatchGetDocumentsRequest_ConsistencySelector.readTime,
    0: BatchGetDocumentsRequest_ConsistencySelector.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BatchGetDocumentsRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: BatchGetDocumentsRequest.$_createMessage)
    ..oo(0, [4, 5, 7])
    ..aOS(1, _omitFieldNames ? '' : 'database')
    ..pPS(2, _omitFieldNames ? '' : 'documents')
    ..aOM<$3.DocumentMask>(3, _omitFieldNames ? '' : 'mask',
        subBuilder: $3.DocumentMask.$_createMessage)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'transaction', $pb.PbFieldType.OY)
    ..aOM<$3.TransactionOptions>(5, _omitFieldNames ? '' : 'newTransaction',
        subBuilder: $3.TransactionOptions.$_createMessage)
    ..aOM<$4.Timestamp>(7, _omitFieldNames ? '' : 'readTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..aOM<$3.RequestOptions>(8, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchGetDocumentsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchGetDocumentsRequest copyWith(
          void Function(BatchGetDocumentsRequest) updates) =>
      super.copyWith((message) => updates(message as BatchGetDocumentsRequest))
          as BatchGetDocumentsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use BatchGetDocumentsRequest() / BatchGetDocumentsRequest.new instead')
  static BatchGetDocumentsRequest create() => BatchGetDocumentsRequest._();
  static $pb.GeneratedMessage $_createMessage() => BatchGetDocumentsRequest._();
  @$core.override
  BatchGetDocumentsRequest createEmptyInstance() =>
      BatchGetDocumentsRequest._();
  @$core.pragma('dart2js:noInline')
  static BatchGetDocumentsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BatchGetDocumentsRequest>(
          BatchGetDocumentsRequest.$_createMessage);
  static BatchGetDocumentsRequest? _defaultInstance;

  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(7)
  BatchGetDocumentsRequest_ConsistencySelector whichConsistencySelector() =>
      _BatchGetDocumentsRequest_ConsistencySelectorByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(7)
  void clearConsistencySelector() => $_clearField($_whichOneof(0));

  /// Required. The database name. In the format:
  /// `projects/{project_id}/databases/{database_id}`.
  @$pb.TagNumber(1)
  $core.String get database => $_getSZ(0);
  @$pb.TagNumber(1)
  set database($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDatabase() => $_has(0);
  @$pb.TagNumber(1)
  void clearDatabase() => $_clearField(1);

  /// The names of the documents to retrieve. In the format:
  /// `projects/{project_id}/databases/{database_id}/documents/{document_path}`.
  /// The request will fail if any of the document is not a child resource of the
  /// given `database`. Duplicate names will be elided.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get documents => $_getList(1);

  /// The fields to return. If not set, returns all fields.
  ///
  /// If a document has a field that is not present in this mask, that field will
  /// not be returned in the response.
  @$pb.TagNumber(3)
  $3.DocumentMask get mask => $_getN(2);
  @$pb.TagNumber(3)
  set mask($3.DocumentMask value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasMask() => $_has(2);
  @$pb.TagNumber(3)
  void clearMask() => $_clearField(3);
  @$pb.TagNumber(3)
  $3.DocumentMask ensureMask() => $_ensure(2);

  /// Reads documents in a transaction.
  @$pb.TagNumber(4)
  $core.List<$core.int> get transaction => $_getN(3);
  @$pb.TagNumber(4)
  set transaction($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTransaction() => $_has(3);
  @$pb.TagNumber(4)
  void clearTransaction() => $_clearField(4);

  /// Starts a new transaction and reads the documents.
  /// Defaults to a read-only transaction.
  /// The new transaction ID will be returned as the first response in the
  /// stream.
  @$pb.TagNumber(5)
  $3.TransactionOptions get newTransaction => $_getN(4);
  @$pb.TagNumber(5)
  set newTransaction($3.TransactionOptions value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasNewTransaction() => $_has(4);
  @$pb.TagNumber(5)
  void clearNewTransaction() => $_clearField(5);
  @$pb.TagNumber(5)
  $3.TransactionOptions ensureNewTransaction() => $_ensure(4);

  /// Reads documents as they were at the given time.
  ///
  /// This must be a microsecond precision timestamp within the past one hour,
  /// or if Point-in-Time Recovery is enabled, can additionally be a whole
  /// minute timestamp within the past 7 days.
  @$pb.TagNumber(7)
  $4.Timestamp get readTime => $_getN(5);
  @$pb.TagNumber(7)
  set readTime($4.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasReadTime() => $_has(5);
  @$pb.TagNumber(7)
  void clearReadTime() => $_clearField(7);
  @$pb.TagNumber(7)
  $4.Timestamp ensureReadTime() => $_ensure(5);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(8)
  $3.RequestOptions get requestOptions => $_getN(6);
  @$pb.TagNumber(8)
  set requestOptions($3.RequestOptions value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasRequestOptions() => $_has(6);
  @$pb.TagNumber(8)
  void clearRequestOptions() => $_clearField(8);
  @$pb.TagNumber(8)
  $3.RequestOptions ensureRequestOptions() => $_ensure(6);
}

enum BatchGetDocumentsResponse_Result { found, missing, notSet }

/// The streamed response for
/// [Firestore.BatchGetDocuments][google.firestore.v1.Firestore.BatchGetDocuments].
class BatchGetDocumentsResponse extends $pb.GeneratedMessage {
  factory BatchGetDocumentsResponse({
    $1.Document? found,
    $core.String? missing,
    $core.List<$core.int>? transaction,
    $4.Timestamp? readTime,
  }) {
    final result = BatchGetDocumentsResponse._();
    if (found != null) result.found = found;
    if (missing != null) result.missing = missing;
    if (transaction != null) result.transaction = transaction;
    if (readTime != null) result.readTime = readTime;
    return result;
  }

  BatchGetDocumentsResponse._();

  factory BatchGetDocumentsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BatchGetDocumentsResponse()..mergeFromBuffer(data, registry);
  factory BatchGetDocumentsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BatchGetDocumentsResponse()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, BatchGetDocumentsResponse_Result>
      _BatchGetDocumentsResponse_ResultByTag = {
    1: BatchGetDocumentsResponse_Result.found,
    2: BatchGetDocumentsResponse_Result.missing,
    0: BatchGetDocumentsResponse_Result.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BatchGetDocumentsResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: BatchGetDocumentsResponse.$_createMessage)
    ..oo(0, [1, 2])
    ..aOM<$1.Document>(1, _omitFieldNames ? '' : 'found',
        subBuilder: $1.Document.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'missing')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'transaction', $pb.PbFieldType.OY)
    ..aOM<$4.Timestamp>(4, _omitFieldNames ? '' : 'readTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchGetDocumentsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchGetDocumentsResponse copyWith(
          void Function(BatchGetDocumentsResponse) updates) =>
      super.copyWith((message) => updates(message as BatchGetDocumentsResponse))
          as BatchGetDocumentsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use BatchGetDocumentsResponse() / BatchGetDocumentsResponse.new instead')
  static BatchGetDocumentsResponse create() => BatchGetDocumentsResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      BatchGetDocumentsResponse._();
  @$core.override
  BatchGetDocumentsResponse createEmptyInstance() =>
      BatchGetDocumentsResponse._();
  @$core.pragma('dart2js:noInline')
  static BatchGetDocumentsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BatchGetDocumentsResponse>(
          BatchGetDocumentsResponse.$_createMessage);
  static BatchGetDocumentsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  BatchGetDocumentsResponse_Result whichResult() =>
      _BatchGetDocumentsResponse_ResultByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  void clearResult() => $_clearField($_whichOneof(0));

  /// A document that was requested.
  @$pb.TagNumber(1)
  $1.Document get found => $_getN(0);
  @$pb.TagNumber(1)
  set found($1.Document value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFound() => $_has(0);
  @$pb.TagNumber(1)
  void clearFound() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Document ensureFound() => $_ensure(0);

  /// A document name that was requested but does not exist. In the format:
  /// `projects/{project_id}/databases/{database_id}/documents/{document_path}`.
  @$pb.TagNumber(2)
  $core.String get missing => $_getSZ(1);
  @$pb.TagNumber(2)
  set missing($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMissing() => $_has(1);
  @$pb.TagNumber(2)
  void clearMissing() => $_clearField(2);

  /// The transaction that was started as part of this request.
  /// Will only be set in the first response, and only if
  /// [BatchGetDocumentsRequest.new_transaction][google.firestore.v1.BatchGetDocumentsRequest.new_transaction]
  /// was set in the request.
  @$pb.TagNumber(3)
  $core.List<$core.int> get transaction => $_getN(2);
  @$pb.TagNumber(3)
  set transaction($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTransaction() => $_has(2);
  @$pb.TagNumber(3)
  void clearTransaction() => $_clearField(3);

  /// The time at which the document was read.
  /// This may be monotically increasing, in this case the previous documents in
  /// the result stream are guaranteed not to have changed between their
  /// read_time and this one.
  @$pb.TagNumber(4)
  $4.Timestamp get readTime => $_getN(3);
  @$pb.TagNumber(4)
  set readTime($4.Timestamp value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasReadTime() => $_has(3);
  @$pb.TagNumber(4)
  void clearReadTime() => $_clearField(4);
  @$pb.TagNumber(4)
  $4.Timestamp ensureReadTime() => $_ensure(3);
}

/// The request for
/// [Firestore.BeginTransaction][google.firestore.v1.Firestore.BeginTransaction].
class BeginTransactionRequest extends $pb.GeneratedMessage {
  factory BeginTransactionRequest({
    $core.String? database,
    $3.TransactionOptions? options,
    $3.RequestOptions? requestOptions,
  }) {
    final result = BeginTransactionRequest._();
    if (database != null) result.database = database;
    if (options != null) result.options = options;
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  BeginTransactionRequest._();

  factory BeginTransactionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BeginTransactionRequest()..mergeFromBuffer(data, registry);
  factory BeginTransactionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BeginTransactionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeginTransactionRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: BeginTransactionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'database')
    ..aOM<$3.TransactionOptions>(2, _omitFieldNames ? '' : 'options',
        subBuilder: $3.TransactionOptions.$_createMessage)
    ..aOM<$3.RequestOptions>(3, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginTransactionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginTransactionRequest copyWith(
          void Function(BeginTransactionRequest) updates) =>
      super.copyWith((message) => updates(message as BeginTransactionRequest))
          as BeginTransactionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use BeginTransactionRequest() / BeginTransactionRequest.new instead')
  static BeginTransactionRequest create() => BeginTransactionRequest._();
  static $pb.GeneratedMessage $_createMessage() => BeginTransactionRequest._();
  @$core.override
  BeginTransactionRequest createEmptyInstance() => BeginTransactionRequest._();
  @$core.pragma('dart2js:noInline')
  static BeginTransactionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeginTransactionRequest>(
          BeginTransactionRequest.$_createMessage);
  static BeginTransactionRequest? _defaultInstance;

  /// Required. The database name. In the format:
  /// `projects/{project_id}/databases/{database_id}`.
  @$pb.TagNumber(1)
  $core.String get database => $_getSZ(0);
  @$pb.TagNumber(1)
  set database($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDatabase() => $_has(0);
  @$pb.TagNumber(1)
  void clearDatabase() => $_clearField(1);

  /// The options for the transaction.
  /// Defaults to a read-write transaction.
  @$pb.TagNumber(2)
  $3.TransactionOptions get options => $_getN(1);
  @$pb.TagNumber(2)
  set options($3.TransactionOptions value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOptions() => $_has(1);
  @$pb.TagNumber(2)
  void clearOptions() => $_clearField(2);
  @$pb.TagNumber(2)
  $3.TransactionOptions ensureOptions() => $_ensure(1);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(3)
  $3.RequestOptions get requestOptions => $_getN(2);
  @$pb.TagNumber(3)
  set requestOptions($3.RequestOptions value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRequestOptions() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequestOptions() => $_clearField(3);
  @$pb.TagNumber(3)
  $3.RequestOptions ensureRequestOptions() => $_ensure(2);
}

/// The response for
/// [Firestore.BeginTransaction][google.firestore.v1.Firestore.BeginTransaction].
class BeginTransactionResponse extends $pb.GeneratedMessage {
  factory BeginTransactionResponse({
    $core.List<$core.int>? transaction,
  }) {
    final result = BeginTransactionResponse._();
    if (transaction != null) result.transaction = transaction;
    return result;
  }

  BeginTransactionResponse._();

  factory BeginTransactionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BeginTransactionResponse()..mergeFromBuffer(data, registry);
  factory BeginTransactionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BeginTransactionResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeginTransactionResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: BeginTransactionResponse.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'transaction', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginTransactionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginTransactionResponse copyWith(
          void Function(BeginTransactionResponse) updates) =>
      super.copyWith((message) => updates(message as BeginTransactionResponse))
          as BeginTransactionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use BeginTransactionResponse() / BeginTransactionResponse.new instead')
  static BeginTransactionResponse create() => BeginTransactionResponse._();
  static $pb.GeneratedMessage $_createMessage() => BeginTransactionResponse._();
  @$core.override
  BeginTransactionResponse createEmptyInstance() =>
      BeginTransactionResponse._();
  @$core.pragma('dart2js:noInline')
  static BeginTransactionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeginTransactionResponse>(
          BeginTransactionResponse.$_createMessage);
  static BeginTransactionResponse? _defaultInstance;

  /// The transaction that was started.
  @$pb.TagNumber(1)
  $core.List<$core.int> get transaction => $_getN(0);
  @$pb.TagNumber(1)
  set transaction($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransaction() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransaction() => $_clearField(1);
}

/// The request for [Firestore.Commit][google.firestore.v1.Firestore.Commit].
class CommitRequest extends $pb.GeneratedMessage {
  factory CommitRequest({
    $core.String? database,
    $core.Iterable<$5.Write>? writes,
    $core.List<$core.int>? transaction,
    $3.RequestOptions? requestOptions,
  }) {
    final result = CommitRequest._();
    if (database != null) result.database = database;
    if (writes != null) result.writes.addAll(writes);
    if (transaction != null) result.transaction = transaction;
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  CommitRequest._();

  factory CommitRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommitRequest()..mergeFromBuffer(data, registry);
  factory CommitRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommitRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommitRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: CommitRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'database')
    ..pPM<$5.Write>(2, _omitFieldNames ? '' : 'writes',
        subBuilder: $5.Write.$_createMessage)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'transaction', $pb.PbFieldType.OY)
    ..aOM<$3.RequestOptions>(4, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommitRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommitRequest copyWith(void Function(CommitRequest) updates) =>
      super.copyWith((message) => updates(message as CommitRequest))
          as CommitRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommitRequest() / CommitRequest.new instead')
  static CommitRequest create() => CommitRequest._();
  static $pb.GeneratedMessage $_createMessage() => CommitRequest._();
  @$core.override
  CommitRequest createEmptyInstance() => CommitRequest._();
  @$core.pragma('dart2js:noInline')
  static CommitRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CommitRequest>(
          CommitRequest.$_createMessage);
  static CommitRequest? _defaultInstance;

  /// Required. The database name. In the format:
  /// `projects/{project_id}/databases/{database_id}`.
  @$pb.TagNumber(1)
  $core.String get database => $_getSZ(0);
  @$pb.TagNumber(1)
  set database($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDatabase() => $_has(0);
  @$pb.TagNumber(1)
  void clearDatabase() => $_clearField(1);

  /// The writes to apply.
  ///
  /// Always executed atomically and in order.
  @$pb.TagNumber(2)
  $pb.PbList<$5.Write> get writes => $_getList(1);

  /// If set, applies all writes in this transaction, and commits it.
  @$pb.TagNumber(3)
  $core.List<$core.int> get transaction => $_getN(2);
  @$pb.TagNumber(3)
  set transaction($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTransaction() => $_has(2);
  @$pb.TagNumber(3)
  void clearTransaction() => $_clearField(3);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(4)
  $3.RequestOptions get requestOptions => $_getN(3);
  @$pb.TagNumber(4)
  set requestOptions($3.RequestOptions value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRequestOptions() => $_has(3);
  @$pb.TagNumber(4)
  void clearRequestOptions() => $_clearField(4);
  @$pb.TagNumber(4)
  $3.RequestOptions ensureRequestOptions() => $_ensure(3);
}

/// The response for [Firestore.Commit][google.firestore.v1.Firestore.Commit].
class CommitResponse extends $pb.GeneratedMessage {
  factory CommitResponse({
    $core.Iterable<$5.WriteResult>? writeResults,
    $4.Timestamp? commitTime,
  }) {
    final result = CommitResponse._();
    if (writeResults != null) result.writeResults.addAll(writeResults);
    if (commitTime != null) result.commitTime = commitTime;
    return result;
  }

  CommitResponse._();

  factory CommitResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommitResponse()..mergeFromBuffer(data, registry);
  factory CommitResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CommitResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommitResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: CommitResponse.$_createMessage)
    ..pPM<$5.WriteResult>(1, _omitFieldNames ? '' : 'writeResults',
        subBuilder: $5.WriteResult.$_createMessage)
    ..aOM<$4.Timestamp>(2, _omitFieldNames ? '' : 'commitTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommitResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommitResponse copyWith(void Function(CommitResponse) updates) =>
      super.copyWith((message) => updates(message as CommitResponse))
          as CommitResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CommitResponse() / CommitResponse.new instead')
  static CommitResponse create() => CommitResponse._();
  static $pb.GeneratedMessage $_createMessage() => CommitResponse._();
  @$core.override
  CommitResponse createEmptyInstance() => CommitResponse._();
  @$core.pragma('dart2js:noInline')
  static CommitResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CommitResponse>(
          CommitResponse.$_createMessage);
  static CommitResponse? _defaultInstance;

  /// The result of applying the writes.
  ///
  /// This i-th write result corresponds to the i-th write in the
  /// request.
  @$pb.TagNumber(1)
  $pb.PbList<$5.WriteResult> get writeResults => $_getList(0);

  /// The time at which the commit occurred. Any read with an equal or greater
  /// `read_time` is guaranteed to see the effects of the commit.
  @$pb.TagNumber(2)
  $4.Timestamp get commitTime => $_getN(1);
  @$pb.TagNumber(2)
  set commitTime($4.Timestamp value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCommitTime() => $_has(1);
  @$pb.TagNumber(2)
  void clearCommitTime() => $_clearField(2);
  @$pb.TagNumber(2)
  $4.Timestamp ensureCommitTime() => $_ensure(1);
}

/// The request for [Firestore.Rollback][google.firestore.v1.Firestore.Rollback].
class RollbackRequest extends $pb.GeneratedMessage {
  factory RollbackRequest({
    $core.String? database,
    $core.List<$core.int>? transaction,
    $3.RequestOptions? requestOptions,
  }) {
    final result = RollbackRequest._();
    if (database != null) result.database = database;
    if (transaction != null) result.transaction = transaction;
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  RollbackRequest._();

  factory RollbackRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RollbackRequest()..mergeFromBuffer(data, registry);
  factory RollbackRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RollbackRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RollbackRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: RollbackRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'database')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'transaction', $pb.PbFieldType.OY)
    ..aOM<$3.RequestOptions>(3, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RollbackRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RollbackRequest copyWith(void Function(RollbackRequest) updates) =>
      super.copyWith((message) => updates(message as RollbackRequest))
          as RollbackRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RollbackRequest() / RollbackRequest.new instead')
  static RollbackRequest create() => RollbackRequest._();
  static $pb.GeneratedMessage $_createMessage() => RollbackRequest._();
  @$core.override
  RollbackRequest createEmptyInstance() => RollbackRequest._();
  @$core.pragma('dart2js:noInline')
  static RollbackRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RollbackRequest>(
          RollbackRequest.$_createMessage);
  static RollbackRequest? _defaultInstance;

  /// Required. The database name. In the format:
  /// `projects/{project_id}/databases/{database_id}`.
  @$pb.TagNumber(1)
  $core.String get database => $_getSZ(0);
  @$pb.TagNumber(1)
  set database($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDatabase() => $_has(0);
  @$pb.TagNumber(1)
  void clearDatabase() => $_clearField(1);

  /// Required. The transaction to roll back.
  @$pb.TagNumber(2)
  $core.List<$core.int> get transaction => $_getN(1);
  @$pb.TagNumber(2)
  set transaction($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTransaction() => $_has(1);
  @$pb.TagNumber(2)
  void clearTransaction() => $_clearField(2);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(3)
  $3.RequestOptions get requestOptions => $_getN(2);
  @$pb.TagNumber(3)
  set requestOptions($3.RequestOptions value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRequestOptions() => $_has(2);
  @$pb.TagNumber(3)
  void clearRequestOptions() => $_clearField(3);
  @$pb.TagNumber(3)
  $3.RequestOptions ensureRequestOptions() => $_ensure(2);
}

enum RunQueryRequest_QueryType { structuredQuery, notSet }

enum RunQueryRequest_ConsistencySelector {
  transaction,
  newTransaction,
  readTime,
  notSet
}

/// The request for [Firestore.RunQuery][google.firestore.v1.Firestore.RunQuery].
class RunQueryRequest extends $pb.GeneratedMessage {
  factory RunQueryRequest({
    $core.String? parent,
    $6.StructuredQuery? structuredQuery,
    $core.List<$core.int>? transaction,
    $3.TransactionOptions? newTransaction,
    $4.Timestamp? readTime,
    $7.ExplainOptions? explainOptions,
    $3.RequestOptions? requestOptions,
  }) {
    final result = RunQueryRequest._();
    if (parent != null) result.parent = parent;
    if (structuredQuery != null) result.structuredQuery = structuredQuery;
    if (transaction != null) result.transaction = transaction;
    if (newTransaction != null) result.newTransaction = newTransaction;
    if (readTime != null) result.readTime = readTime;
    if (explainOptions != null) result.explainOptions = explainOptions;
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  RunQueryRequest._();

  factory RunQueryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RunQueryRequest()..mergeFromBuffer(data, registry);
  factory RunQueryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RunQueryRequest()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, RunQueryRequest_QueryType>
      _RunQueryRequest_QueryTypeByTag = {
    2: RunQueryRequest_QueryType.structuredQuery,
    0: RunQueryRequest_QueryType.notSet
  };
  static const $core.Map<$core.int, RunQueryRequest_ConsistencySelector>
      _RunQueryRequest_ConsistencySelectorByTag = {
    5: RunQueryRequest_ConsistencySelector.transaction,
    6: RunQueryRequest_ConsistencySelector.newTransaction,
    7: RunQueryRequest_ConsistencySelector.readTime,
    0: RunQueryRequest_ConsistencySelector.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RunQueryRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: RunQueryRequest.$_createMessage)
    ..oo(0, [2])
    ..oo(1, [5, 6, 7])
    ..aOS(1, _omitFieldNames ? '' : 'parent')
    ..aOM<$6.StructuredQuery>(2, _omitFieldNames ? '' : 'structuredQuery',
        subBuilder: $6.StructuredQuery.$_createMessage)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'transaction', $pb.PbFieldType.OY)
    ..aOM<$3.TransactionOptions>(6, _omitFieldNames ? '' : 'newTransaction',
        subBuilder: $3.TransactionOptions.$_createMessage)
    ..aOM<$4.Timestamp>(7, _omitFieldNames ? '' : 'readTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..aOM<$7.ExplainOptions>(10, _omitFieldNames ? '' : 'explainOptions',
        subBuilder: $7.ExplainOptions.$_createMessage)
    ..aOM<$3.RequestOptions>(11, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunQueryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunQueryRequest copyWith(void Function(RunQueryRequest) updates) =>
      super.copyWith((message) => updates(message as RunQueryRequest))
          as RunQueryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RunQueryRequest() / RunQueryRequest.new instead')
  static RunQueryRequest create() => RunQueryRequest._();
  static $pb.GeneratedMessage $_createMessage() => RunQueryRequest._();
  @$core.override
  RunQueryRequest createEmptyInstance() => RunQueryRequest._();
  @$core.pragma('dart2js:noInline')
  static RunQueryRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RunQueryRequest>(
          RunQueryRequest.$_createMessage);
  static RunQueryRequest? _defaultInstance;

  @$pb.TagNumber(2)
  RunQueryRequest_QueryType whichQueryType() =>
      _RunQueryRequest_QueryTypeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  void clearQueryType() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  RunQueryRequest_ConsistencySelector whichConsistencySelector() =>
      _RunQueryRequest_ConsistencySelectorByTag[$_whichOneof(1)]!;
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  void clearConsistencySelector() => $_clearField($_whichOneof(1));

  /// Required. The parent resource name. In the format:
  /// `projects/{project_id}/databases/{database_id}/documents` or
  /// `projects/{project_id}/databases/{database_id}/documents/{document_path}`.
  /// For example:
  /// `projects/my-project/databases/my-database/documents` or
  /// `projects/my-project/databases/my-database/documents/chatrooms/my-chatroom`
  @$pb.TagNumber(1)
  $core.String get parent => $_getSZ(0);
  @$pb.TagNumber(1)
  set parent($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasParent() => $_has(0);
  @$pb.TagNumber(1)
  void clearParent() => $_clearField(1);

  /// A structured query.
  @$pb.TagNumber(2)
  $6.StructuredQuery get structuredQuery => $_getN(1);
  @$pb.TagNumber(2)
  set structuredQuery($6.StructuredQuery value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStructuredQuery() => $_has(1);
  @$pb.TagNumber(2)
  void clearStructuredQuery() => $_clearField(2);
  @$pb.TagNumber(2)
  $6.StructuredQuery ensureStructuredQuery() => $_ensure(1);

  /// Run the query within an already active transaction.
  ///
  /// The value here is the opaque transaction ID to execute the query in.
  @$pb.TagNumber(5)
  $core.List<$core.int> get transaction => $_getN(2);
  @$pb.TagNumber(5)
  set transaction($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(5)
  $core.bool hasTransaction() => $_has(2);
  @$pb.TagNumber(5)
  void clearTransaction() => $_clearField(5);

  /// Starts a new transaction and reads the documents.
  /// Defaults to a read-only transaction.
  /// The new transaction ID will be returned as the first response in the
  /// stream.
  @$pb.TagNumber(6)
  $3.TransactionOptions get newTransaction => $_getN(3);
  @$pb.TagNumber(6)
  set newTransaction($3.TransactionOptions value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasNewTransaction() => $_has(3);
  @$pb.TagNumber(6)
  void clearNewTransaction() => $_clearField(6);
  @$pb.TagNumber(6)
  $3.TransactionOptions ensureNewTransaction() => $_ensure(3);

  /// Reads documents as they were at the given time.
  ///
  /// This must be a microsecond precision timestamp within the past one hour,
  /// or if Point-in-Time Recovery is enabled, can additionally be a whole
  /// minute timestamp within the past 7 days.
  @$pb.TagNumber(7)
  $4.Timestamp get readTime => $_getN(4);
  @$pb.TagNumber(7)
  set readTime($4.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasReadTime() => $_has(4);
  @$pb.TagNumber(7)
  void clearReadTime() => $_clearField(7);
  @$pb.TagNumber(7)
  $4.Timestamp ensureReadTime() => $_ensure(4);

  /// Optional. Explain options for the query. If set, additional query
  /// statistics will be returned. If not, only query results will be returned.
  @$pb.TagNumber(10)
  $7.ExplainOptions get explainOptions => $_getN(5);
  @$pb.TagNumber(10)
  set explainOptions($7.ExplainOptions value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasExplainOptions() => $_has(5);
  @$pb.TagNumber(10)
  void clearExplainOptions() => $_clearField(10);
  @$pb.TagNumber(10)
  $7.ExplainOptions ensureExplainOptions() => $_ensure(5);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(11)
  $3.RequestOptions get requestOptions => $_getN(6);
  @$pb.TagNumber(11)
  set requestOptions($3.RequestOptions value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasRequestOptions() => $_has(6);
  @$pb.TagNumber(11)
  void clearRequestOptions() => $_clearField(11);
  @$pb.TagNumber(11)
  $3.RequestOptions ensureRequestOptions() => $_ensure(6);
}

enum RunQueryResponse_ContinuationSelector { done, notSet }

/// The response for
/// [Firestore.RunQuery][google.firestore.v1.Firestore.RunQuery].
class RunQueryResponse extends $pb.GeneratedMessage {
  factory RunQueryResponse({
    $1.Document? document,
    $core.List<$core.int>? transaction,
    $4.Timestamp? readTime,
    $core.int? skippedResults,
    $core.bool? done,
    $7.ExplainMetrics? explainMetrics,
  }) {
    final result = RunQueryResponse._();
    if (document != null) result.document = document;
    if (transaction != null) result.transaction = transaction;
    if (readTime != null) result.readTime = readTime;
    if (skippedResults != null) result.skippedResults = skippedResults;
    if (done != null) result.done = done;
    if (explainMetrics != null) result.explainMetrics = explainMetrics;
    return result;
  }

  RunQueryResponse._();

  factory RunQueryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RunQueryResponse()..mergeFromBuffer(data, registry);
  factory RunQueryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RunQueryResponse()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, RunQueryResponse_ContinuationSelector>
      _RunQueryResponse_ContinuationSelectorByTag = {
    6: RunQueryResponse_ContinuationSelector.done,
    0: RunQueryResponse_ContinuationSelector.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RunQueryResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: RunQueryResponse.$_createMessage)
    ..oo(0, [6])
    ..aOM<$1.Document>(1, _omitFieldNames ? '' : 'document',
        subBuilder: $1.Document.$_createMessage)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'transaction', $pb.PbFieldType.OY)
    ..aOM<$4.Timestamp>(3, _omitFieldNames ? '' : 'readTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..aI(4, _omitFieldNames ? '' : 'skippedResults')
    ..aOB(6, _omitFieldNames ? '' : 'done')
    ..aOM<$7.ExplainMetrics>(11, _omitFieldNames ? '' : 'explainMetrics',
        subBuilder: $7.ExplainMetrics.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunQueryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunQueryResponse copyWith(void Function(RunQueryResponse) updates) =>
      super.copyWith((message) => updates(message as RunQueryResponse))
          as RunQueryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RunQueryResponse() / RunQueryResponse.new instead')
  static RunQueryResponse create() => RunQueryResponse._();
  static $pb.GeneratedMessage $_createMessage() => RunQueryResponse._();
  @$core.override
  RunQueryResponse createEmptyInstance() => RunQueryResponse._();
  @$core.pragma('dart2js:noInline')
  static RunQueryResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RunQueryResponse>(
          RunQueryResponse.$_createMessage);
  static RunQueryResponse? _defaultInstance;

  @$pb.TagNumber(6)
  RunQueryResponse_ContinuationSelector whichContinuationSelector() =>
      _RunQueryResponse_ContinuationSelectorByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(6)
  void clearContinuationSelector() => $_clearField($_whichOneof(0));

  /// A query result, not set when reporting partial progress.
  @$pb.TagNumber(1)
  $1.Document get document => $_getN(0);
  @$pb.TagNumber(1)
  set document($1.Document value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDocument() => $_has(0);
  @$pb.TagNumber(1)
  void clearDocument() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Document ensureDocument() => $_ensure(0);

  /// The transaction that was started as part of this request.
  /// Can only be set in the first response, and only if
  /// [RunQueryRequest.new_transaction][google.firestore.v1.RunQueryRequest.new_transaction]
  /// was set in the request. If set, no other fields will be set in this
  /// response.
  @$pb.TagNumber(2)
  $core.List<$core.int> get transaction => $_getN(1);
  @$pb.TagNumber(2)
  set transaction($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTransaction() => $_has(1);
  @$pb.TagNumber(2)
  void clearTransaction() => $_clearField(2);

  /// The time at which the document was read. This may be monotonically
  /// increasing; in this case, the previous documents in the result stream are
  /// guaranteed not to have changed between their `read_time` and this one.
  ///
  /// If the query returns no results, a response with `read_time` and no
  /// `document` will be sent, and this represents the time at which the query
  /// was run.
  @$pb.TagNumber(3)
  $4.Timestamp get readTime => $_getN(2);
  @$pb.TagNumber(3)
  set readTime($4.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasReadTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearReadTime() => $_clearField(3);
  @$pb.TagNumber(3)
  $4.Timestamp ensureReadTime() => $_ensure(2);

  /// The number of results that have been skipped due to an offset between
  /// the last response and the current response.
  @$pb.TagNumber(4)
  $core.int get skippedResults => $_getIZ(3);
  @$pb.TagNumber(4)
  set skippedResults($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSkippedResults() => $_has(3);
  @$pb.TagNumber(4)
  void clearSkippedResults() => $_clearField(4);

  /// If present, Firestore has completely finished the request and no more
  /// documents will be returned.
  @$pb.TagNumber(6)
  $core.bool get done => $_getBF(4);
  @$pb.TagNumber(6)
  set done($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(6)
  $core.bool hasDone() => $_has(4);
  @$pb.TagNumber(6)
  void clearDone() => $_clearField(6);

  /// Query explain metrics. This is only present when the
  /// [RunQueryRequest.explain_options][google.firestore.v1.RunQueryRequest.explain_options]
  /// is provided, and it is sent only once with the last response in the stream.
  @$pb.TagNumber(11)
  $7.ExplainMetrics get explainMetrics => $_getN(5);
  @$pb.TagNumber(11)
  set explainMetrics($7.ExplainMetrics value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasExplainMetrics() => $_has(5);
  @$pb.TagNumber(11)
  void clearExplainMetrics() => $_clearField(11);
  @$pb.TagNumber(11)
  $7.ExplainMetrics ensureExplainMetrics() => $_ensure(5);
}

enum ExecutePipelineRequest_PipelineType { structuredPipeline, notSet }

enum ExecutePipelineRequest_ConsistencySelector {
  transaction,
  newTransaction,
  readTime,
  notSet
}

/// The request for
/// [Firestore.ExecutePipeline][google.firestore.v1.Firestore.ExecutePipeline].
class ExecutePipelineRequest extends $pb.GeneratedMessage {
  factory ExecutePipelineRequest({
    $core.String? database,
    $8.StructuredPipeline? structuredPipeline,
    $core.List<$core.int>? transaction,
    $3.TransactionOptions? newTransaction,
    $4.Timestamp? readTime,
    $core.bool? autoCommitTransaction,
    $3.RequestOptions? requestOptions,
  }) {
    final result = ExecutePipelineRequest._();
    if (database != null) result.database = database;
    if (structuredPipeline != null)
      result.structuredPipeline = structuredPipeline;
    if (transaction != null) result.transaction = transaction;
    if (newTransaction != null) result.newTransaction = newTransaction;
    if (readTime != null) result.readTime = readTime;
    if (autoCommitTransaction != null)
      result.autoCommitTransaction = autoCommitTransaction;
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  ExecutePipelineRequest._();

  factory ExecutePipelineRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExecutePipelineRequest()..mergeFromBuffer(data, registry);
  factory ExecutePipelineRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExecutePipelineRequest()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ExecutePipelineRequest_PipelineType>
      _ExecutePipelineRequest_PipelineTypeByTag = {
    2: ExecutePipelineRequest_PipelineType.structuredPipeline,
    0: ExecutePipelineRequest_PipelineType.notSet
  };
  static const $core.Map<$core.int, ExecutePipelineRequest_ConsistencySelector>
      _ExecutePipelineRequest_ConsistencySelectorByTag = {
    5: ExecutePipelineRequest_ConsistencySelector.transaction,
    6: ExecutePipelineRequest_ConsistencySelector.newTransaction,
    7: ExecutePipelineRequest_ConsistencySelector.readTime,
    0: ExecutePipelineRequest_ConsistencySelector.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExecutePipelineRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: ExecutePipelineRequest.$_createMessage)
    ..oo(0, [2])
    ..oo(1, [5, 6, 7])
    ..aOS(1, _omitFieldNames ? '' : 'database')
    ..aOM<$8.StructuredPipeline>(2, _omitFieldNames ? '' : 'structuredPipeline',
        subBuilder: $8.StructuredPipeline.$_createMessage)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'transaction', $pb.PbFieldType.OY)
    ..aOM<$3.TransactionOptions>(6, _omitFieldNames ? '' : 'newTransaction',
        subBuilder: $3.TransactionOptions.$_createMessage)
    ..aOM<$4.Timestamp>(7, _omitFieldNames ? '' : 'readTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..aOB(9, _omitFieldNames ? '' : 'autoCommitTransaction')
    ..aOM<$3.RequestOptions>(10, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExecutePipelineRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExecutePipelineRequest copyWith(
          void Function(ExecutePipelineRequest) updates) =>
      super.copyWith((message) => updates(message as ExecutePipelineRequest))
          as ExecutePipelineRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ExecutePipelineRequest() / ExecutePipelineRequest.new instead')
  static ExecutePipelineRequest create() => ExecutePipelineRequest._();
  static $pb.GeneratedMessage $_createMessage() => ExecutePipelineRequest._();
  @$core.override
  ExecutePipelineRequest createEmptyInstance() => ExecutePipelineRequest._();
  @$core.pragma('dart2js:noInline')
  static ExecutePipelineRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExecutePipelineRequest>(
          ExecutePipelineRequest.$_createMessage);
  static ExecutePipelineRequest? _defaultInstance;

  @$pb.TagNumber(2)
  ExecutePipelineRequest_PipelineType whichPipelineType() =>
      _ExecutePipelineRequest_PipelineTypeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  void clearPipelineType() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  ExecutePipelineRequest_ConsistencySelector whichConsistencySelector() =>
      _ExecutePipelineRequest_ConsistencySelectorByTag[$_whichOneof(1)]!;
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  void clearConsistencySelector() => $_clearField($_whichOneof(1));

  /// Required. Database identifier, in the form
  /// `projects/{project}/databases/{database}`.
  @$pb.TagNumber(1)
  $core.String get database => $_getSZ(0);
  @$pb.TagNumber(1)
  set database($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDatabase() => $_has(0);
  @$pb.TagNumber(1)
  void clearDatabase() => $_clearField(1);

  /// A pipelined operation.
  @$pb.TagNumber(2)
  $8.StructuredPipeline get structuredPipeline => $_getN(1);
  @$pb.TagNumber(2)
  set structuredPipeline($8.StructuredPipeline value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStructuredPipeline() => $_has(1);
  @$pb.TagNumber(2)
  void clearStructuredPipeline() => $_clearField(2);
  @$pb.TagNumber(2)
  $8.StructuredPipeline ensureStructuredPipeline() => $_ensure(1);

  /// Run the query within an already active transaction.
  ///
  /// The value here is the opaque transaction ID to execute the query in.
  @$pb.TagNumber(5)
  $core.List<$core.int> get transaction => $_getN(2);
  @$pb.TagNumber(5)
  set transaction($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(5)
  $core.bool hasTransaction() => $_has(2);
  @$pb.TagNumber(5)
  void clearTransaction() => $_clearField(5);

  /// Execute the pipeline in a new transaction.
  ///
  /// The identifier of the newly created transaction will be returned in the
  /// first response on the stream. This defaults to a read-only transaction.
  @$pb.TagNumber(6)
  $3.TransactionOptions get newTransaction => $_getN(3);
  @$pb.TagNumber(6)
  set newTransaction($3.TransactionOptions value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasNewTransaction() => $_has(3);
  @$pb.TagNumber(6)
  void clearNewTransaction() => $_clearField(6);
  @$pb.TagNumber(6)
  $3.TransactionOptions ensureNewTransaction() => $_ensure(3);

  /// Execute the pipeline in a snapshot transaction at the given time.
  ///
  /// This must be a microsecond precision timestamp within the past one hour,
  /// or if Point-in-Time Recovery is enabled, can additionally be a whole
  /// minute timestamp within the past 7 days.
  @$pb.TagNumber(7)
  $4.Timestamp get readTime => $_getN(4);
  @$pb.TagNumber(7)
  set readTime($4.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasReadTime() => $_has(4);
  @$pb.TagNumber(7)
  void clearReadTime() => $_clearField(7);
  @$pb.TagNumber(7)
  $4.Timestamp ensureReadTime() => $_ensure(4);

  /// Optional. Automatically commits the transaction after the pipeline has been
  /// executed. Only permitted in combination with `transaction` or
  /// `new_transaction`.
  @$pb.TagNumber(9)
  $core.bool get autoCommitTransaction => $_getBF(5);
  @$pb.TagNumber(9)
  set autoCommitTransaction($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(9)
  $core.bool hasAutoCommitTransaction() => $_has(5);
  @$pb.TagNumber(9)
  void clearAutoCommitTransaction() => $_clearField(9);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(10)
  $3.RequestOptions get requestOptions => $_getN(6);
  @$pb.TagNumber(10)
  set requestOptions($3.RequestOptions value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasRequestOptions() => $_has(6);
  @$pb.TagNumber(10)
  void clearRequestOptions() => $_clearField(10);
  @$pb.TagNumber(10)
  $3.RequestOptions ensureRequestOptions() => $_ensure(6);
}

/// The response for [Firestore.Execute][].
class ExecutePipelineResponse extends $pb.GeneratedMessage {
  factory ExecutePipelineResponse({
    $core.List<$core.int>? transaction,
    $core.Iterable<$1.Document>? results,
    $4.Timestamp? executionTime,
    $9.ExplainStats? explainStats,
  }) {
    final result = ExecutePipelineResponse._();
    if (transaction != null) result.transaction = transaction;
    if (results != null) result.results.addAll(results);
    if (executionTime != null) result.executionTime = executionTime;
    if (explainStats != null) result.explainStats = explainStats;
    return result;
  }

  ExecutePipelineResponse._();

  factory ExecutePipelineResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExecutePipelineResponse()..mergeFromBuffer(data, registry);
  factory ExecutePipelineResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ExecutePipelineResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ExecutePipelineResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: ExecutePipelineResponse.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'transaction', $pb.PbFieldType.OY)
    ..pPM<$1.Document>(2, _omitFieldNames ? '' : 'results',
        subBuilder: $1.Document.$_createMessage)
    ..aOM<$4.Timestamp>(3, _omitFieldNames ? '' : 'executionTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..aOM<$9.ExplainStats>(4, _omitFieldNames ? '' : 'explainStats',
        subBuilder: $9.ExplainStats.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExecutePipelineResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ExecutePipelineResponse copyWith(
          void Function(ExecutePipelineResponse) updates) =>
      super.copyWith((message) => updates(message as ExecutePipelineResponse))
          as ExecutePipelineResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ExecutePipelineResponse() / ExecutePipelineResponse.new instead')
  static ExecutePipelineResponse create() => ExecutePipelineResponse._();
  static $pb.GeneratedMessage $_createMessage() => ExecutePipelineResponse._();
  @$core.override
  ExecutePipelineResponse createEmptyInstance() => ExecutePipelineResponse._();
  @$core.pragma('dart2js:noInline')
  static ExecutePipelineResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ExecutePipelineResponse>(
          ExecutePipelineResponse.$_createMessage);
  static ExecutePipelineResponse? _defaultInstance;

  /// Newly created transaction identifier.
  ///
  /// This field is only specified as part of the first response from the server,
  /// alongside the `results` field when the original request specified
  /// [ExecuteRequest.new_transaction][].
  @$pb.TagNumber(1)
  $core.List<$core.int> get transaction => $_getN(0);
  @$pb.TagNumber(1)
  set transaction($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransaction() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransaction() => $_clearField(1);

  /// An ordered batch of results returned executing a pipeline.
  ///
  /// The batch size is variable, and can even be zero for when only a partial
  /// progress message is returned.
  ///
  /// The fields present in the returned documents are only those that were
  /// explicitly requested in the pipeline, this includes those like
  /// [`__name__`][google.firestore.v1.Document.name] and
  /// [`__update_time__`][google.firestore.v1.Document.update_time]. This is
  /// explicitly a divergence from `Firestore.RunQuery` / `Firestore.GetDocument`
  /// RPCs which always return such fields even when they are not specified in
  /// the [`mask`][google.firestore.v1.DocumentMask].
  @$pb.TagNumber(2)
  $pb.PbList<$1.Document> get results => $_getList(1);

  /// The time at which the results are valid.
  ///
  /// This is a (not strictly) monotonically increasing value across multiple
  /// responses in the same stream. The API guarantees that all previously
  /// returned results are still valid at the latest `execution_time`. This
  /// allows the API consumer to treat the query if it ran at the latest
  /// `execution_time` returned.
  ///
  /// If the query returns no results, a response with `execution_time` and no
  /// `results` will be sent, and this represents the time at which the operation
  /// was run.
  @$pb.TagNumber(3)
  $4.Timestamp get executionTime => $_getN(2);
  @$pb.TagNumber(3)
  set executionTime($4.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasExecutionTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearExecutionTime() => $_clearField(3);
  @$pb.TagNumber(3)
  $4.Timestamp ensureExecutionTime() => $_ensure(2);

  /// Query explain stats.
  ///
  /// This is present on the **last** response if the request configured explain
  /// to run in 'analyze' or 'explain' mode in the pipeline options. If the query
  /// does not return any results, a response with `explain_stats` and no
  /// `results` will still be sent.
  @$pb.TagNumber(4)
  $9.ExplainStats get explainStats => $_getN(3);
  @$pb.TagNumber(4)
  set explainStats($9.ExplainStats value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasExplainStats() => $_has(3);
  @$pb.TagNumber(4)
  void clearExplainStats() => $_clearField(4);
  @$pb.TagNumber(4)
  $9.ExplainStats ensureExplainStats() => $_ensure(3);
}

enum RunAggregationQueryRequest_QueryType { structuredAggregationQuery, notSet }

enum RunAggregationQueryRequest_ConsistencySelector {
  transaction,
  newTransaction,
  readTime,
  notSet
}

/// The request for
/// [Firestore.RunAggregationQuery][google.firestore.v1.Firestore.RunAggregationQuery].
class RunAggregationQueryRequest extends $pb.GeneratedMessage {
  factory RunAggregationQueryRequest({
    $core.String? parent,
    $6.StructuredAggregationQuery? structuredAggregationQuery,
    $core.List<$core.int>? transaction,
    $3.TransactionOptions? newTransaction,
    $4.Timestamp? readTime,
    $7.ExplainOptions? explainOptions,
    $3.RequestOptions? requestOptions,
  }) {
    final result = RunAggregationQueryRequest._();
    if (parent != null) result.parent = parent;
    if (structuredAggregationQuery != null)
      result.structuredAggregationQuery = structuredAggregationQuery;
    if (transaction != null) result.transaction = transaction;
    if (newTransaction != null) result.newTransaction = newTransaction;
    if (readTime != null) result.readTime = readTime;
    if (explainOptions != null) result.explainOptions = explainOptions;
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  RunAggregationQueryRequest._();

  factory RunAggregationQueryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RunAggregationQueryRequest()..mergeFromBuffer(data, registry);
  factory RunAggregationQueryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RunAggregationQueryRequest()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, RunAggregationQueryRequest_QueryType>
      _RunAggregationQueryRequest_QueryTypeByTag = {
    2: RunAggregationQueryRequest_QueryType.structuredAggregationQuery,
    0: RunAggregationQueryRequest_QueryType.notSet
  };
  static const $core
      .Map<$core.int, RunAggregationQueryRequest_ConsistencySelector>
      _RunAggregationQueryRequest_ConsistencySelectorByTag = {
    4: RunAggregationQueryRequest_ConsistencySelector.transaction,
    5: RunAggregationQueryRequest_ConsistencySelector.newTransaction,
    6: RunAggregationQueryRequest_ConsistencySelector.readTime,
    0: RunAggregationQueryRequest_ConsistencySelector.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RunAggregationQueryRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: RunAggregationQueryRequest.$_createMessage)
    ..oo(0, [2])
    ..oo(1, [4, 5, 6])
    ..aOS(1, _omitFieldNames ? '' : 'parent')
    ..aOM<$6.StructuredAggregationQuery>(
        2, _omitFieldNames ? '' : 'structuredAggregationQuery',
        subBuilder: $6.StructuredAggregationQuery.$_createMessage)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'transaction', $pb.PbFieldType.OY)
    ..aOM<$3.TransactionOptions>(5, _omitFieldNames ? '' : 'newTransaction',
        subBuilder: $3.TransactionOptions.$_createMessage)
    ..aOM<$4.Timestamp>(6, _omitFieldNames ? '' : 'readTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..aOM<$7.ExplainOptions>(8, _omitFieldNames ? '' : 'explainOptions',
        subBuilder: $7.ExplainOptions.$_createMessage)
    ..aOM<$3.RequestOptions>(9, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunAggregationQueryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunAggregationQueryRequest copyWith(
          void Function(RunAggregationQueryRequest) updates) =>
      super.copyWith(
              (message) => updates(message as RunAggregationQueryRequest))
          as RunAggregationQueryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RunAggregationQueryRequest() / RunAggregationQueryRequest.new instead')
  static RunAggregationQueryRequest create() => RunAggregationQueryRequest._();
  static $pb.GeneratedMessage $_createMessage() =>
      RunAggregationQueryRequest._();
  @$core.override
  RunAggregationQueryRequest createEmptyInstance() =>
      RunAggregationQueryRequest._();
  @$core.pragma('dart2js:noInline')
  static RunAggregationQueryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RunAggregationQueryRequest>(
          RunAggregationQueryRequest.$_createMessage);
  static RunAggregationQueryRequest? _defaultInstance;

  @$pb.TagNumber(2)
  RunAggregationQueryRequest_QueryType whichQueryType() =>
      _RunAggregationQueryRequest_QueryTypeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  void clearQueryType() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  RunAggregationQueryRequest_ConsistencySelector whichConsistencySelector() =>
      _RunAggregationQueryRequest_ConsistencySelectorByTag[$_whichOneof(1)]!;
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  void clearConsistencySelector() => $_clearField($_whichOneof(1));

  /// Required. The parent resource name. In the format:
  /// `projects/{project_id}/databases/{database_id}/documents` or
  /// `projects/{project_id}/databases/{database_id}/documents/{document_path}`.
  /// For example:
  /// `projects/my-project/databases/my-database/documents` or
  /// `projects/my-project/databases/my-database/documents/chatrooms/my-chatroom`
  @$pb.TagNumber(1)
  $core.String get parent => $_getSZ(0);
  @$pb.TagNumber(1)
  set parent($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasParent() => $_has(0);
  @$pb.TagNumber(1)
  void clearParent() => $_clearField(1);

  /// An aggregation query.
  @$pb.TagNumber(2)
  $6.StructuredAggregationQuery get structuredAggregationQuery => $_getN(1);
  @$pb.TagNumber(2)
  set structuredAggregationQuery($6.StructuredAggregationQuery value) =>
      $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStructuredAggregationQuery() => $_has(1);
  @$pb.TagNumber(2)
  void clearStructuredAggregationQuery() => $_clearField(2);
  @$pb.TagNumber(2)
  $6.StructuredAggregationQuery ensureStructuredAggregationQuery() =>
      $_ensure(1);

  /// Run the aggregation within an already active transaction.
  ///
  /// The value here is the opaque transaction ID to execute the query in.
  @$pb.TagNumber(4)
  $core.List<$core.int> get transaction => $_getN(2);
  @$pb.TagNumber(4)
  set transaction($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(4)
  $core.bool hasTransaction() => $_has(2);
  @$pb.TagNumber(4)
  void clearTransaction() => $_clearField(4);

  /// Starts a new transaction as part of the query, defaulting to read-only.
  ///
  /// The new transaction ID will be returned as the first response in the
  /// stream.
  @$pb.TagNumber(5)
  $3.TransactionOptions get newTransaction => $_getN(3);
  @$pb.TagNumber(5)
  set newTransaction($3.TransactionOptions value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasNewTransaction() => $_has(3);
  @$pb.TagNumber(5)
  void clearNewTransaction() => $_clearField(5);
  @$pb.TagNumber(5)
  $3.TransactionOptions ensureNewTransaction() => $_ensure(3);

  /// Executes the query at the given timestamp.
  ///
  /// This must be a microsecond precision timestamp within the past one hour,
  /// or if Point-in-Time Recovery is enabled, can additionally be a whole
  /// minute timestamp within the past 7 days.
  @$pb.TagNumber(6)
  $4.Timestamp get readTime => $_getN(4);
  @$pb.TagNumber(6)
  set readTime($4.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasReadTime() => $_has(4);
  @$pb.TagNumber(6)
  void clearReadTime() => $_clearField(6);
  @$pb.TagNumber(6)
  $4.Timestamp ensureReadTime() => $_ensure(4);

  /// Optional. Explain options for the query. If set, additional query
  /// statistics will be returned. If not, only query results will be returned.
  @$pb.TagNumber(8)
  $7.ExplainOptions get explainOptions => $_getN(5);
  @$pb.TagNumber(8)
  set explainOptions($7.ExplainOptions value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasExplainOptions() => $_has(5);
  @$pb.TagNumber(8)
  void clearExplainOptions() => $_clearField(8);
  @$pb.TagNumber(8)
  $7.ExplainOptions ensureExplainOptions() => $_ensure(5);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(9)
  $3.RequestOptions get requestOptions => $_getN(6);
  @$pb.TagNumber(9)
  set requestOptions($3.RequestOptions value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasRequestOptions() => $_has(6);
  @$pb.TagNumber(9)
  void clearRequestOptions() => $_clearField(9);
  @$pb.TagNumber(9)
  $3.RequestOptions ensureRequestOptions() => $_ensure(6);
}

/// The response for
/// [Firestore.RunAggregationQuery][google.firestore.v1.Firestore.RunAggregationQuery].
class RunAggregationQueryResponse extends $pb.GeneratedMessage {
  factory RunAggregationQueryResponse({
    $10.AggregationResult? result,
    $core.List<$core.int>? transaction,
    $4.Timestamp? readTime,
    $7.ExplainMetrics? explainMetrics,
  }) {
    final result$ = RunAggregationQueryResponse._();
    if (result != null) result$.result = result;
    if (transaction != null) result$.transaction = transaction;
    if (readTime != null) result$.readTime = readTime;
    if (explainMetrics != null) result$.explainMetrics = explainMetrics;
    return result$;
  }

  RunAggregationQueryResponse._();

  factory RunAggregationQueryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RunAggregationQueryResponse()..mergeFromBuffer(data, registry);
  factory RunAggregationQueryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RunAggregationQueryResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RunAggregationQueryResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: RunAggregationQueryResponse.$_createMessage)
    ..aOM<$10.AggregationResult>(1, _omitFieldNames ? '' : 'result',
        subBuilder: $10.AggregationResult.$_createMessage)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'transaction', $pb.PbFieldType.OY)
    ..aOM<$4.Timestamp>(3, _omitFieldNames ? '' : 'readTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..aOM<$7.ExplainMetrics>(10, _omitFieldNames ? '' : 'explainMetrics',
        subBuilder: $7.ExplainMetrics.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunAggregationQueryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RunAggregationQueryResponse copyWith(
          void Function(RunAggregationQueryResponse) updates) =>
      super.copyWith(
              (message) => updates(message as RunAggregationQueryResponse))
          as RunAggregationQueryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RunAggregationQueryResponse() / RunAggregationQueryResponse.new instead')
  static RunAggregationQueryResponse create() =>
      RunAggregationQueryResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      RunAggregationQueryResponse._();
  @$core.override
  RunAggregationQueryResponse createEmptyInstance() =>
      RunAggregationQueryResponse._();
  @$core.pragma('dart2js:noInline')
  static RunAggregationQueryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RunAggregationQueryResponse>(
          RunAggregationQueryResponse.$_createMessage);
  static RunAggregationQueryResponse? _defaultInstance;

  /// A single aggregation result.
  ///
  /// Not present when reporting partial progress.
  @$pb.TagNumber(1)
  $10.AggregationResult get result => $_getN(0);
  @$pb.TagNumber(1)
  set result($10.AggregationResult value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasResult() => $_has(0);
  @$pb.TagNumber(1)
  void clearResult() => $_clearField(1);
  @$pb.TagNumber(1)
  $10.AggregationResult ensureResult() => $_ensure(0);

  /// The transaction that was started as part of this request.
  ///
  /// Only present on the first response when the request requested to start
  /// a new transaction.
  @$pb.TagNumber(2)
  $core.List<$core.int> get transaction => $_getN(1);
  @$pb.TagNumber(2)
  set transaction($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTransaction() => $_has(1);
  @$pb.TagNumber(2)
  void clearTransaction() => $_clearField(2);

  /// The time at which the aggregate result was computed. This is always
  /// monotonically increasing; in this case, the previous AggregationResult in
  /// the result stream are guaranteed not to have changed between their
  /// `read_time` and this one.
  ///
  /// If the query returns no results, a response with `read_time` and no
  /// `result` will be sent, and this represents the time at which the query
  /// was run.
  @$pb.TagNumber(3)
  $4.Timestamp get readTime => $_getN(2);
  @$pb.TagNumber(3)
  set readTime($4.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasReadTime() => $_has(2);
  @$pb.TagNumber(3)
  void clearReadTime() => $_clearField(3);
  @$pb.TagNumber(3)
  $4.Timestamp ensureReadTime() => $_ensure(2);

  /// Query explain metrics. This is only present when the
  /// [RunAggregationQueryRequest.explain_options][google.firestore.v1.RunAggregationQueryRequest.explain_options]
  /// is provided, and it is sent only once with the last response in the stream.
  @$pb.TagNumber(10)
  $7.ExplainMetrics get explainMetrics => $_getN(3);
  @$pb.TagNumber(10)
  set explainMetrics($7.ExplainMetrics value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasExplainMetrics() => $_has(3);
  @$pb.TagNumber(10)
  void clearExplainMetrics() => $_clearField(10);
  @$pb.TagNumber(10)
  $7.ExplainMetrics ensureExplainMetrics() => $_ensure(3);
}

enum PartitionQueryRequest_QueryType { structuredQuery, notSet }

enum PartitionQueryRequest_ConsistencySelector { readTime, notSet }

/// The request for
/// [Firestore.PartitionQuery][google.firestore.v1.Firestore.PartitionQuery].
class PartitionQueryRequest extends $pb.GeneratedMessage {
  factory PartitionQueryRequest({
    $core.String? parent,
    $6.StructuredQuery? structuredQuery,
    $fixnum.Int64? partitionCount,
    $core.String? pageToken,
    $core.int? pageSize,
    $4.Timestamp? readTime,
    $3.RequestOptions? requestOptions,
  }) {
    final result = PartitionQueryRequest._();
    if (parent != null) result.parent = parent;
    if (structuredQuery != null) result.structuredQuery = structuredQuery;
    if (partitionCount != null) result.partitionCount = partitionCount;
    if (pageToken != null) result.pageToken = pageToken;
    if (pageSize != null) result.pageSize = pageSize;
    if (readTime != null) result.readTime = readTime;
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  PartitionQueryRequest._();

  factory PartitionQueryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PartitionQueryRequest()..mergeFromBuffer(data, registry);
  factory PartitionQueryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PartitionQueryRequest()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, PartitionQueryRequest_QueryType>
      _PartitionQueryRequest_QueryTypeByTag = {
    2: PartitionQueryRequest_QueryType.structuredQuery,
    0: PartitionQueryRequest_QueryType.notSet
  };
  static const $core.Map<$core.int, PartitionQueryRequest_ConsistencySelector>
      _PartitionQueryRequest_ConsistencySelectorByTag = {
    6: PartitionQueryRequest_ConsistencySelector.readTime,
    0: PartitionQueryRequest_ConsistencySelector.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PartitionQueryRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: PartitionQueryRequest.$_createMessage)
    ..oo(0, [2])
    ..oo(1, [6])
    ..aOS(1, _omitFieldNames ? '' : 'parent')
    ..aOM<$6.StructuredQuery>(2, _omitFieldNames ? '' : 'structuredQuery',
        subBuilder: $6.StructuredQuery.$_createMessage)
    ..aInt64(3, _omitFieldNames ? '' : 'partitionCount')
    ..aOS(4, _omitFieldNames ? '' : 'pageToken')
    ..aI(5, _omitFieldNames ? '' : 'pageSize')
    ..aOM<$4.Timestamp>(6, _omitFieldNames ? '' : 'readTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..aOM<$3.RequestOptions>(7, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PartitionQueryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PartitionQueryRequest copyWith(
          void Function(PartitionQueryRequest) updates) =>
      super.copyWith((message) => updates(message as PartitionQueryRequest))
          as PartitionQueryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PartitionQueryRequest() / PartitionQueryRequest.new instead')
  static PartitionQueryRequest create() => PartitionQueryRequest._();
  static $pb.GeneratedMessage $_createMessage() => PartitionQueryRequest._();
  @$core.override
  PartitionQueryRequest createEmptyInstance() => PartitionQueryRequest._();
  @$core.pragma('dart2js:noInline')
  static PartitionQueryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PartitionQueryRequest>(
          PartitionQueryRequest.$_createMessage);
  static PartitionQueryRequest? _defaultInstance;

  @$pb.TagNumber(2)
  PartitionQueryRequest_QueryType whichQueryType() =>
      _PartitionQueryRequest_QueryTypeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  void clearQueryType() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(6)
  PartitionQueryRequest_ConsistencySelector whichConsistencySelector() =>
      _PartitionQueryRequest_ConsistencySelectorByTag[$_whichOneof(1)]!;
  @$pb.TagNumber(6)
  void clearConsistencySelector() => $_clearField($_whichOneof(1));

  /// Required. The parent resource name. In the format:
  /// `projects/{project_id}/databases/{database_id}/documents`.
  /// Document resource names are not supported; only database resource names
  /// can be specified.
  @$pb.TagNumber(1)
  $core.String get parent => $_getSZ(0);
  @$pb.TagNumber(1)
  set parent($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasParent() => $_has(0);
  @$pb.TagNumber(1)
  void clearParent() => $_clearField(1);

  /// A structured query.
  /// Query must specify collection with all descendants and be ordered by name
  /// ascending. Other filters, order bys, limits, offsets, and start/end
  /// cursors are not supported.
  @$pb.TagNumber(2)
  $6.StructuredQuery get structuredQuery => $_getN(1);
  @$pb.TagNumber(2)
  set structuredQuery($6.StructuredQuery value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStructuredQuery() => $_has(1);
  @$pb.TagNumber(2)
  void clearStructuredQuery() => $_clearField(2);
  @$pb.TagNumber(2)
  $6.StructuredQuery ensureStructuredQuery() => $_ensure(1);

  /// The desired maximum number of partition points.
  /// The partitions may be returned across multiple pages of results.
  /// The number must be positive. The actual number of partitions
  /// returned may be fewer.
  ///
  /// For example, this may be set to one fewer than the number of parallel
  /// queries to be run, or in running a data pipeline job, one fewer than the
  /// number of workers or compute instances available.
  @$pb.TagNumber(3)
  $fixnum.Int64 get partitionCount => $_getI64(2);
  @$pb.TagNumber(3)
  set partitionCount($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPartitionCount() => $_has(2);
  @$pb.TagNumber(3)
  void clearPartitionCount() => $_clearField(3);

  /// The `next_page_token` value returned from a previous call to
  /// PartitionQuery that may be used to get an additional set of results.
  /// There are no ordering guarantees between sets of results. Thus, using
  /// multiple sets of results will require merging the different result sets.
  ///
  /// For example, two subsequent calls using a page_token may return:
  ///
  ///  * cursor B, cursor M, cursor Q
  ///  * cursor A, cursor U, cursor W
  ///
  /// To obtain a complete result set ordered with respect to the results of the
  /// query supplied to PartitionQuery, the results sets should be merged:
  /// cursor A, cursor B, cursor M, cursor Q, cursor U, cursor W
  @$pb.TagNumber(4)
  $core.String get pageToken => $_getSZ(3);
  @$pb.TagNumber(4)
  set pageToken($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPageToken() => $_has(3);
  @$pb.TagNumber(4)
  void clearPageToken() => $_clearField(4);

  /// The maximum number of partitions to return in this call, subject to
  /// `partition_count`.
  ///
  /// For example, if `partition_count` = 10 and `page_size` = 8, the first call
  /// to PartitionQuery will return up to 8 partitions and a `next_page_token`
  /// if more results exist. A second call to PartitionQuery will return up to
  /// 2 partitions, to complete the total of 10 specified in `partition_count`.
  @$pb.TagNumber(5)
  $core.int get pageSize => $_getIZ(4);
  @$pb.TagNumber(5)
  set pageSize($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPageSize() => $_has(4);
  @$pb.TagNumber(5)
  void clearPageSize() => $_clearField(5);

  /// Reads documents as they were at the given time.
  ///
  /// This must be a microsecond precision timestamp within the past one hour,
  /// or if Point-in-Time Recovery is enabled, can additionally be a whole
  /// minute timestamp within the past 7 days.
  @$pb.TagNumber(6)
  $4.Timestamp get readTime => $_getN(5);
  @$pb.TagNumber(6)
  set readTime($4.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasReadTime() => $_has(5);
  @$pb.TagNumber(6)
  void clearReadTime() => $_clearField(6);
  @$pb.TagNumber(6)
  $4.Timestamp ensureReadTime() => $_ensure(5);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(7)
  $3.RequestOptions get requestOptions => $_getN(6);
  @$pb.TagNumber(7)
  set requestOptions($3.RequestOptions value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasRequestOptions() => $_has(6);
  @$pb.TagNumber(7)
  void clearRequestOptions() => $_clearField(7);
  @$pb.TagNumber(7)
  $3.RequestOptions ensureRequestOptions() => $_ensure(6);
}

/// The response for
/// [Firestore.PartitionQuery][google.firestore.v1.Firestore.PartitionQuery].
class PartitionQueryResponse extends $pb.GeneratedMessage {
  factory PartitionQueryResponse({
    $core.Iterable<$6.Cursor>? partitions,
    $core.String? nextPageToken,
  }) {
    final result = PartitionQueryResponse._();
    if (partitions != null) result.partitions.addAll(partitions);
    if (nextPageToken != null) result.nextPageToken = nextPageToken;
    return result;
  }

  PartitionQueryResponse._();

  factory PartitionQueryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PartitionQueryResponse()..mergeFromBuffer(data, registry);
  factory PartitionQueryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PartitionQueryResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PartitionQueryResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: PartitionQueryResponse.$_createMessage)
    ..pPM<$6.Cursor>(1, _omitFieldNames ? '' : 'partitions',
        subBuilder: $6.Cursor.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'nextPageToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PartitionQueryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PartitionQueryResponse copyWith(
          void Function(PartitionQueryResponse) updates) =>
      super.copyWith((message) => updates(message as PartitionQueryResponse))
          as PartitionQueryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PartitionQueryResponse() / PartitionQueryResponse.new instead')
  static PartitionQueryResponse create() => PartitionQueryResponse._();
  static $pb.GeneratedMessage $_createMessage() => PartitionQueryResponse._();
  @$core.override
  PartitionQueryResponse createEmptyInstance() => PartitionQueryResponse._();
  @$core.pragma('dart2js:noInline')
  static PartitionQueryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PartitionQueryResponse>(
          PartitionQueryResponse.$_createMessage);
  static PartitionQueryResponse? _defaultInstance;

  /// Partition results.
  /// Each partition is a split point that can be used by RunQuery as a starting
  /// or end point for the query results. The RunQuery requests must be made with
  /// the same query supplied to this PartitionQuery request. The partition
  /// cursors will be ordered according to same ordering as the results of the
  /// query supplied to PartitionQuery.
  ///
  /// For example, if a PartitionQuery request returns partition cursors A and B,
  /// running the following three queries will return the entire result set of
  /// the original query:
  ///
  ///  * query, end_at A
  ///  * query, start_at A, end_at B
  ///  * query, start_at B
  ///
  /// An empty result may indicate that the query has too few results to be
  /// partitioned, or that the query is not yet supported for partitioning.
  @$pb.TagNumber(1)
  $pb.PbList<$6.Cursor> get partitions => $_getList(0);

  /// A page token that may be used to request an additional set of results, up
  /// to the number specified by `partition_count` in the PartitionQuery request.
  /// If blank, there are no more results.
  @$pb.TagNumber(2)
  $core.String get nextPageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set nextPageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNextPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextPageToken() => $_clearField(2);
}

/// The request for [Firestore.Write][google.firestore.v1.Firestore.Write].
///
/// The first request creates a stream, or resumes an existing one from a token.
///
/// When creating a new stream, the server replies with a response containing
/// only an ID and a token, to use in the next request.
///
/// When resuming a stream, the server first streams any responses later than the
/// given token, then a response containing only an up-to-date token, to use in
/// the next request.
class WriteRequest extends $pb.GeneratedMessage {
  factory WriteRequest({
    $core.String? database,
    $core.String? streamId,
    $core.Iterable<$5.Write>? writes,
    $core.List<$core.int>? streamToken,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? labels,
    $3.RequestOptions? requestOptions,
  }) {
    final result = WriteRequest._();
    if (database != null) result.database = database;
    if (streamId != null) result.streamId = streamId;
    if (writes != null) result.writes.addAll(writes);
    if (streamToken != null) result.streamToken = streamToken;
    if (labels != null) result.labels.addEntries(labels);
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  WriteRequest._();

  factory WriteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteRequest()..mergeFromBuffer(data, registry);
  factory WriteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WriteRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: WriteRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'database')
    ..aOS(2, _omitFieldNames ? '' : 'streamId')
    ..pPM<$5.Write>(3, _omitFieldNames ? '' : 'writes',
        subBuilder: $5.Write.$_createMessage)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'streamToken', $pb.PbFieldType.OY)
    ..m<$core.String, $core.String>(5, _omitFieldNames ? '' : 'labels',
        entryClassName: 'WriteRequest.LabelsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('google.firestore.v1'))
    ..aOM<$3.RequestOptions>(6, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteRequest copyWith(void Function(WriteRequest) updates) =>
      super.copyWith((message) => updates(message as WriteRequest))
          as WriteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WriteRequest() / WriteRequest.new instead')
  static WriteRequest create() => WriteRequest._();
  static $pb.GeneratedMessage $_createMessage() => WriteRequest._();
  @$core.override
  WriteRequest createEmptyInstance() => WriteRequest._();
  @$core.pragma('dart2js:noInline')
  static WriteRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WriteRequest>(
          WriteRequest.$_createMessage);
  static WriteRequest? _defaultInstance;

  /// Required. The database name. In the format:
  /// `projects/{project_id}/databases/{database_id}`.
  /// This is only required in the first message.
  @$pb.TagNumber(1)
  $core.String get database => $_getSZ(0);
  @$pb.TagNumber(1)
  set database($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDatabase() => $_has(0);
  @$pb.TagNumber(1)
  void clearDatabase() => $_clearField(1);

  /// The ID of the write stream to resume.
  /// This may only be set in the first message. When left empty, a new write
  /// stream will be created.
  @$pb.TagNumber(2)
  $core.String get streamId => $_getSZ(1);
  @$pb.TagNumber(2)
  set streamId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStreamId() => $_has(1);
  @$pb.TagNumber(2)
  void clearStreamId() => $_clearField(2);

  /// The writes to apply.
  ///
  /// Always executed atomically and in order.
  /// This must be empty on the first request.
  /// This may be empty on the last request.
  /// This must not be empty on all other requests.
  @$pb.TagNumber(3)
  $pb.PbList<$5.Write> get writes => $_getList(2);

  /// A stream token that was previously sent by the server.
  ///
  /// The client should set this field to the token from the most recent
  /// [WriteResponse][google.firestore.v1.WriteResponse] it has received. This
  /// acknowledges that the client has received responses up to this token. After
  /// sending this token, earlier tokens may not be used anymore.
  ///
  /// The server may close the stream if there are too many unacknowledged
  /// responses.
  ///
  /// Leave this field unset when creating a new stream. To resume a stream at
  /// a specific point, set this field and the `stream_id` field.
  ///
  /// Leave this field unset when creating a new stream.
  @$pb.TagNumber(4)
  $core.List<$core.int> get streamToken => $_getN(3);
  @$pb.TagNumber(4)
  set streamToken($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStreamToken() => $_has(3);
  @$pb.TagNumber(4)
  void clearStreamToken() => $_clearField(4);

  /// Labels associated with this write request.
  @$pb.TagNumber(5)
  $pb.PbMap<$core.String, $core.String> get labels => $_getMap(4);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(6)
  $3.RequestOptions get requestOptions => $_getN(5);
  @$pb.TagNumber(6)
  set requestOptions($3.RequestOptions value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasRequestOptions() => $_has(5);
  @$pb.TagNumber(6)
  void clearRequestOptions() => $_clearField(6);
  @$pb.TagNumber(6)
  $3.RequestOptions ensureRequestOptions() => $_ensure(5);
}

/// The response for [Firestore.Write][google.firestore.v1.Firestore.Write].
class WriteResponse extends $pb.GeneratedMessage {
  factory WriteResponse({
    $core.String? streamId,
    $core.List<$core.int>? streamToken,
    $core.Iterable<$5.WriteResult>? writeResults,
    $4.Timestamp? commitTime,
  }) {
    final result = WriteResponse._();
    if (streamId != null) result.streamId = streamId;
    if (streamToken != null) result.streamToken = streamToken;
    if (writeResults != null) result.writeResults.addAll(writeResults);
    if (commitTime != null) result.commitTime = commitTime;
    return result;
  }

  WriteResponse._();

  factory WriteResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteResponse()..mergeFromBuffer(data, registry);
  factory WriteResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WriteResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: WriteResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'streamId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'streamToken', $pb.PbFieldType.OY)
    ..pPM<$5.WriteResult>(3, _omitFieldNames ? '' : 'writeResults',
        subBuilder: $5.WriteResult.$_createMessage)
    ..aOM<$4.Timestamp>(4, _omitFieldNames ? '' : 'commitTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteResponse copyWith(void Function(WriteResponse) updates) =>
      super.copyWith((message) => updates(message as WriteResponse))
          as WriteResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WriteResponse() / WriteResponse.new instead')
  static WriteResponse create() => WriteResponse._();
  static $pb.GeneratedMessage $_createMessage() => WriteResponse._();
  @$core.override
  WriteResponse createEmptyInstance() => WriteResponse._();
  @$core.pragma('dart2js:noInline')
  static WriteResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WriteResponse>(
          WriteResponse.$_createMessage);
  static WriteResponse? _defaultInstance;

  /// The ID of the stream.
  /// Only set on the first message, when a new stream was created.
  @$pb.TagNumber(1)
  $core.String get streamId => $_getSZ(0);
  @$pb.TagNumber(1)
  set streamId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStreamId() => $_has(0);
  @$pb.TagNumber(1)
  void clearStreamId() => $_clearField(1);

  /// A token that represents the position of this response in the stream.
  /// This can be used by a client to resume the stream at this point.
  ///
  /// This field is always set.
  @$pb.TagNumber(2)
  $core.List<$core.int> get streamToken => $_getN(1);
  @$pb.TagNumber(2)
  set streamToken($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStreamToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearStreamToken() => $_clearField(2);

  /// The result of applying the writes.
  ///
  /// This i-th write result corresponds to the i-th write in the
  /// request.
  @$pb.TagNumber(3)
  $pb.PbList<$5.WriteResult> get writeResults => $_getList(2);

  /// The time at which the commit occurred. Any read with an equal or greater
  /// `read_time` is guaranteed to see the effects of the write.
  @$pb.TagNumber(4)
  $4.Timestamp get commitTime => $_getN(3);
  @$pb.TagNumber(4)
  set commitTime($4.Timestamp value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCommitTime() => $_has(3);
  @$pb.TagNumber(4)
  void clearCommitTime() => $_clearField(4);
  @$pb.TagNumber(4)
  $4.Timestamp ensureCommitTime() => $_ensure(3);
}

enum ListenRequest_TargetChange { addTarget, removeTarget, notSet }

/// A request for [Firestore.Listen][google.firestore.v1.Firestore.Listen]
class ListenRequest extends $pb.GeneratedMessage {
  factory ListenRequest({
    $core.String? database,
    Target? addTarget,
    $core.int? removeTarget,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? labels,
    $3.RequestOptions? requestOptions,
  }) {
    final result = ListenRequest._();
    if (database != null) result.database = database;
    if (addTarget != null) result.addTarget = addTarget;
    if (removeTarget != null) result.removeTarget = removeTarget;
    if (labels != null) result.labels.addEntries(labels);
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  ListenRequest._();

  factory ListenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListenRequest()..mergeFromBuffer(data, registry);
  factory ListenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListenRequest()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ListenRequest_TargetChange>
      _ListenRequest_TargetChangeByTag = {
    2: ListenRequest_TargetChange.addTarget,
    3: ListenRequest_TargetChange.removeTarget,
    0: ListenRequest_TargetChange.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListenRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: ListenRequest.$_createMessage)
    ..oo(0, [2, 3])
    ..aOS(1, _omitFieldNames ? '' : 'database')
    ..aOM<Target>(2, _omitFieldNames ? '' : 'addTarget',
        subBuilder: Target.$_createMessage)
    ..aI(3, _omitFieldNames ? '' : 'removeTarget')
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'labels',
        entryClassName: 'ListenRequest.LabelsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('google.firestore.v1'))
    ..aOM<$3.RequestOptions>(5, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListenRequest copyWith(void Function(ListenRequest) updates) =>
      super.copyWith((message) => updates(message as ListenRequest))
          as ListenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListenRequest() / ListenRequest.new instead')
  static ListenRequest create() => ListenRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListenRequest._();
  @$core.override
  ListenRequest createEmptyInstance() => ListenRequest._();
  @$core.pragma('dart2js:noInline')
  static ListenRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListenRequest>(
          ListenRequest.$_createMessage);
  static ListenRequest? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  ListenRequest_TargetChange whichTargetChange() =>
      _ListenRequest_TargetChangeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearTargetChange() => $_clearField($_whichOneof(0));

  /// Required. The database name. In the format:
  /// `projects/{project_id}/databases/{database_id}`.
  @$pb.TagNumber(1)
  $core.String get database => $_getSZ(0);
  @$pb.TagNumber(1)
  set database($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDatabase() => $_has(0);
  @$pb.TagNumber(1)
  void clearDatabase() => $_clearField(1);

  /// A target to add to this stream.
  @$pb.TagNumber(2)
  Target get addTarget => $_getN(1);
  @$pb.TagNumber(2)
  set addTarget(Target value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAddTarget() => $_has(1);
  @$pb.TagNumber(2)
  void clearAddTarget() => $_clearField(2);
  @$pb.TagNumber(2)
  Target ensureAddTarget() => $_ensure(1);

  /// The ID of a target to remove from this stream.
  @$pb.TagNumber(3)
  $core.int get removeTarget => $_getIZ(2);
  @$pb.TagNumber(3)
  set removeTarget($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRemoveTarget() => $_has(2);
  @$pb.TagNumber(3)
  void clearRemoveTarget() => $_clearField(3);

  /// Labels associated with this target change.
  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.String> get labels => $_getMap(3);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(5)
  $3.RequestOptions get requestOptions => $_getN(4);
  @$pb.TagNumber(5)
  set requestOptions($3.RequestOptions value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRequestOptions() => $_has(4);
  @$pb.TagNumber(5)
  void clearRequestOptions() => $_clearField(5);
  @$pb.TagNumber(5)
  $3.RequestOptions ensureRequestOptions() => $_ensure(4);
}

enum ListenResponse_ResponseType {
  targetChange,
  documentChange,
  documentDelete,
  filter,
  documentRemove,
  notSet
}

/// The response for [Firestore.Listen][google.firestore.v1.Firestore.Listen].
class ListenResponse extends $pb.GeneratedMessage {
  factory ListenResponse({
    TargetChange? targetChange,
    $5.DocumentChange? documentChange,
    $5.DocumentDelete? documentDelete,
    $5.ExistenceFilter? filter,
    $5.DocumentRemove? documentRemove,
  }) {
    final result = ListenResponse._();
    if (targetChange != null) result.targetChange = targetChange;
    if (documentChange != null) result.documentChange = documentChange;
    if (documentDelete != null) result.documentDelete = documentDelete;
    if (filter != null) result.filter = filter;
    if (documentRemove != null) result.documentRemove = documentRemove;
    return result;
  }

  ListenResponse._();

  factory ListenResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListenResponse()..mergeFromBuffer(data, registry);
  factory ListenResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListenResponse()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ListenResponse_ResponseType>
      _ListenResponse_ResponseTypeByTag = {
    2: ListenResponse_ResponseType.targetChange,
    3: ListenResponse_ResponseType.documentChange,
    4: ListenResponse_ResponseType.documentDelete,
    5: ListenResponse_ResponseType.filter,
    6: ListenResponse_ResponseType.documentRemove,
    0: ListenResponse_ResponseType.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListenResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: ListenResponse.$_createMessage)
    ..oo(0, [2, 3, 4, 5, 6])
    ..aOM<TargetChange>(2, _omitFieldNames ? '' : 'targetChange',
        subBuilder: TargetChange.$_createMessage)
    ..aOM<$5.DocumentChange>(3, _omitFieldNames ? '' : 'documentChange',
        subBuilder: $5.DocumentChange.$_createMessage)
    ..aOM<$5.DocumentDelete>(4, _omitFieldNames ? '' : 'documentDelete',
        subBuilder: $5.DocumentDelete.$_createMessage)
    ..aOM<$5.ExistenceFilter>(5, _omitFieldNames ? '' : 'filter',
        subBuilder: $5.ExistenceFilter.$_createMessage)
    ..aOM<$5.DocumentRemove>(6, _omitFieldNames ? '' : 'documentRemove',
        subBuilder: $5.DocumentRemove.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListenResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListenResponse copyWith(void Function(ListenResponse) updates) =>
      super.copyWith((message) => updates(message as ListenResponse))
          as ListenResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListenResponse() / ListenResponse.new instead')
  static ListenResponse create() => ListenResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListenResponse._();
  @$core.override
  ListenResponse createEmptyInstance() => ListenResponse._();
  @$core.pragma('dart2js:noInline')
  static ListenResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListenResponse>(
          ListenResponse.$_createMessage);
  static ListenResponse? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  ListenResponse_ResponseType whichResponseType() =>
      _ListenResponse_ResponseTypeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  void clearResponseType() => $_clearField($_whichOneof(0));

  /// Targets have changed.
  @$pb.TagNumber(2)
  TargetChange get targetChange => $_getN(0);
  @$pb.TagNumber(2)
  set targetChange(TargetChange value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasTargetChange() => $_has(0);
  @$pb.TagNumber(2)
  void clearTargetChange() => $_clearField(2);
  @$pb.TagNumber(2)
  TargetChange ensureTargetChange() => $_ensure(0);

  /// A [Document][google.firestore.v1.Document] has changed.
  @$pb.TagNumber(3)
  $5.DocumentChange get documentChange => $_getN(1);
  @$pb.TagNumber(3)
  set documentChange($5.DocumentChange value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDocumentChange() => $_has(1);
  @$pb.TagNumber(3)
  void clearDocumentChange() => $_clearField(3);
  @$pb.TagNumber(3)
  $5.DocumentChange ensureDocumentChange() => $_ensure(1);

  /// A [Document][google.firestore.v1.Document] has been deleted.
  @$pb.TagNumber(4)
  $5.DocumentDelete get documentDelete => $_getN(2);
  @$pb.TagNumber(4)
  set documentDelete($5.DocumentDelete value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasDocumentDelete() => $_has(2);
  @$pb.TagNumber(4)
  void clearDocumentDelete() => $_clearField(4);
  @$pb.TagNumber(4)
  $5.DocumentDelete ensureDocumentDelete() => $_ensure(2);

  /// A filter to apply to the set of documents previously returned for the
  /// given target.
  ///
  /// Returned when documents may have been removed from the given target, but
  /// the exact documents are unknown.
  @$pb.TagNumber(5)
  $5.ExistenceFilter get filter => $_getN(3);
  @$pb.TagNumber(5)
  set filter($5.ExistenceFilter value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasFilter() => $_has(3);
  @$pb.TagNumber(5)
  void clearFilter() => $_clearField(5);
  @$pb.TagNumber(5)
  $5.ExistenceFilter ensureFilter() => $_ensure(3);

  /// A [Document][google.firestore.v1.Document] has been removed from a target
  /// (because it is no longer relevant to that target).
  @$pb.TagNumber(6)
  $5.DocumentRemove get documentRemove => $_getN(4);
  @$pb.TagNumber(6)
  set documentRemove($5.DocumentRemove value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasDocumentRemove() => $_has(4);
  @$pb.TagNumber(6)
  void clearDocumentRemove() => $_clearField(6);
  @$pb.TagNumber(6)
  $5.DocumentRemove ensureDocumentRemove() => $_ensure(4);
}

/// A target specified by a set of documents names.
class Target_DocumentsTarget extends $pb.GeneratedMessage {
  factory Target_DocumentsTarget({
    $core.Iterable<$core.String>? documents,
  }) {
    final result = Target_DocumentsTarget._();
    if (documents != null) result.documents.addAll(documents);
    return result;
  }

  Target_DocumentsTarget._();

  factory Target_DocumentsTarget.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Target_DocumentsTarget()..mergeFromBuffer(data, registry);
  factory Target_DocumentsTarget.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Target_DocumentsTarget()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Target.DocumentsTarget',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: Target_DocumentsTarget.$_createMessage)
    ..pPS(2, _omitFieldNames ? '' : 'documents')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Target_DocumentsTarget clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Target_DocumentsTarget copyWith(
          void Function(Target_DocumentsTarget) updates) =>
      super.copyWith((message) => updates(message as Target_DocumentsTarget))
          as Target_DocumentsTarget;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use Target_DocumentsTarget() / Target_DocumentsTarget.new instead')
  static Target_DocumentsTarget create() => Target_DocumentsTarget._();
  static $pb.GeneratedMessage $_createMessage() => Target_DocumentsTarget._();
  @$core.override
  Target_DocumentsTarget createEmptyInstance() => Target_DocumentsTarget._();
  @$core.pragma('dart2js:noInline')
  static Target_DocumentsTarget getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Target_DocumentsTarget>(
          Target_DocumentsTarget.$_createMessage);
  static Target_DocumentsTarget? _defaultInstance;

  /// The names of the documents to retrieve. In the format:
  /// `projects/{project_id}/databases/{database_id}/documents/{document_path}`.
  /// The request will fail if any of the document is not a child resource of
  /// the given `database`. Duplicate names will be elided.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get documents => $_getList(0);
}

enum Target_QueryTarget_QueryType { structuredQuery, notSet }

/// A target specified by a query.
class Target_QueryTarget extends $pb.GeneratedMessage {
  factory Target_QueryTarget({
    $core.String? parent,
    $6.StructuredQuery? structuredQuery,
  }) {
    final result = Target_QueryTarget._();
    if (parent != null) result.parent = parent;
    if (structuredQuery != null) result.structuredQuery = structuredQuery;
    return result;
  }

  Target_QueryTarget._();

  factory Target_QueryTarget.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Target_QueryTarget()..mergeFromBuffer(data, registry);
  factory Target_QueryTarget.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Target_QueryTarget()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Target_QueryTarget_QueryType>
      _Target_QueryTarget_QueryTypeByTag = {
    2: Target_QueryTarget_QueryType.structuredQuery,
    0: Target_QueryTarget_QueryType.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Target.QueryTarget',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: Target_QueryTarget.$_createMessage)
    ..oo(0, [2])
    ..aOS(1, _omitFieldNames ? '' : 'parent')
    ..aOM<$6.StructuredQuery>(2, _omitFieldNames ? '' : 'structuredQuery',
        subBuilder: $6.StructuredQuery.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Target_QueryTarget clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Target_QueryTarget copyWith(void Function(Target_QueryTarget) updates) =>
      super.copyWith((message) => updates(message as Target_QueryTarget))
          as Target_QueryTarget;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Target_QueryTarget() / Target_QueryTarget.new instead')
  static Target_QueryTarget create() => Target_QueryTarget._();
  static $pb.GeneratedMessage $_createMessage() => Target_QueryTarget._();
  @$core.override
  Target_QueryTarget createEmptyInstance() => Target_QueryTarget._();
  @$core.pragma('dart2js:noInline')
  static Target_QueryTarget getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Target_QueryTarget>(
          Target_QueryTarget.$_createMessage);
  static Target_QueryTarget? _defaultInstance;

  @$pb.TagNumber(2)
  Target_QueryTarget_QueryType whichQueryType() =>
      _Target_QueryTarget_QueryTypeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  void clearQueryType() => $_clearField($_whichOneof(0));

  /// The parent resource name. In the format:
  /// `projects/{project_id}/databases/{database_id}/documents` or
  /// `projects/{project_id}/databases/{database_id}/documents/{document_path}`.
  /// For example:
  /// `projects/my-project/databases/my-database/documents` or
  /// `projects/my-project/databases/my-database/documents/chatrooms/my-chatroom`
  @$pb.TagNumber(1)
  $core.String get parent => $_getSZ(0);
  @$pb.TagNumber(1)
  set parent($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasParent() => $_has(0);
  @$pb.TagNumber(1)
  void clearParent() => $_clearField(1);

  /// A structured query.
  @$pb.TagNumber(2)
  $6.StructuredQuery get structuredQuery => $_getN(1);
  @$pb.TagNumber(2)
  set structuredQuery($6.StructuredQuery value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasStructuredQuery() => $_has(1);
  @$pb.TagNumber(2)
  void clearStructuredQuery() => $_clearField(2);
  @$pb.TagNumber(2)
  $6.StructuredQuery ensureStructuredQuery() => $_ensure(1);
}

enum Target_TargetType { query, documents, notSet }

enum Target_ResumeType { resumeToken, readTime, notSet }

/// A specification of a set of documents to listen to.
class Target extends $pb.GeneratedMessage {
  factory Target({
    Target_QueryTarget? query,
    Target_DocumentsTarget? documents,
    $core.List<$core.int>? resumeToken,
    $core.int? targetId,
    $core.bool? once,
    $4.Timestamp? readTime,
    $11.Int32Value? expectedCount,
  }) {
    final result = Target._();
    if (query != null) result.query = query;
    if (documents != null) result.documents = documents;
    if (resumeToken != null) result.resumeToken = resumeToken;
    if (targetId != null) result.targetId = targetId;
    if (once != null) result.once = once;
    if (readTime != null) result.readTime = readTime;
    if (expectedCount != null) result.expectedCount = expectedCount;
    return result;
  }

  Target._();

  factory Target.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Target()..mergeFromBuffer(data, registry);
  factory Target.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Target()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, Target_TargetType> _Target_TargetTypeByTag =
      {
    2: Target_TargetType.query,
    3: Target_TargetType.documents,
    0: Target_TargetType.notSet
  };
  static const $core.Map<$core.int, Target_ResumeType> _Target_ResumeTypeByTag =
      {
    4: Target_ResumeType.resumeToken,
    11: Target_ResumeType.readTime,
    0: Target_ResumeType.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Target',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: Target.$_createMessage)
    ..oo(0, [2, 3])
    ..oo(1, [4, 11])
    ..aOM<Target_QueryTarget>(2, _omitFieldNames ? '' : 'query',
        subBuilder: Target_QueryTarget.$_createMessage)
    ..aOM<Target_DocumentsTarget>(3, _omitFieldNames ? '' : 'documents',
        subBuilder: Target_DocumentsTarget.$_createMessage)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'resumeToken', $pb.PbFieldType.OY)
    ..aI(5, _omitFieldNames ? '' : 'targetId')
    ..aOB(6, _omitFieldNames ? '' : 'once')
    ..aOM<$4.Timestamp>(11, _omitFieldNames ? '' : 'readTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..aOM<$11.Int32Value>(12, _omitFieldNames ? '' : 'expectedCount',
        subBuilder: $11.Int32Value.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Target clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Target copyWith(void Function(Target) updates) =>
      super.copyWith((message) => updates(message as Target)) as Target;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Target() / Target.new instead')
  static Target create() => Target._();
  static $pb.GeneratedMessage $_createMessage() => Target._();
  @$core.override
  Target createEmptyInstance() => Target._();
  @$core.pragma('dart2js:noInline')
  static Target getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Target>(Target.$_createMessage);
  static Target? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  Target_TargetType whichTargetType() =>
      _Target_TargetTypeByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearTargetType() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(4)
  @$pb.TagNumber(11)
  Target_ResumeType whichResumeType() =>
      _Target_ResumeTypeByTag[$_whichOneof(1)]!;
  @$pb.TagNumber(4)
  @$pb.TagNumber(11)
  void clearResumeType() => $_clearField($_whichOneof(1));

  /// A target specified by a query.
  @$pb.TagNumber(2)
  Target_QueryTarget get query => $_getN(0);
  @$pb.TagNumber(2)
  set query(Target_QueryTarget value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasQuery() => $_has(0);
  @$pb.TagNumber(2)
  void clearQuery() => $_clearField(2);
  @$pb.TagNumber(2)
  Target_QueryTarget ensureQuery() => $_ensure(0);

  /// A target specified by a set of document names.
  @$pb.TagNumber(3)
  Target_DocumentsTarget get documents => $_getN(1);
  @$pb.TagNumber(3)
  set documents(Target_DocumentsTarget value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDocuments() => $_has(1);
  @$pb.TagNumber(3)
  void clearDocuments() => $_clearField(3);
  @$pb.TagNumber(3)
  Target_DocumentsTarget ensureDocuments() => $_ensure(1);

  /// A resume token from a prior
  /// [TargetChange][google.firestore.v1.TargetChange] for an identical target.
  ///
  /// Using a resume token with a different target is unsupported and may fail.
  @$pb.TagNumber(4)
  $core.List<$core.int> get resumeToken => $_getN(2);
  @$pb.TagNumber(4)
  set resumeToken($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(4)
  $core.bool hasResumeToken() => $_has(2);
  @$pb.TagNumber(4)
  void clearResumeToken() => $_clearField(4);

  /// The target ID that identifies the target on the stream. Must be a positive
  /// number and non-zero.
  ///
  /// If `target_id` is 0 (or unspecified), the server will assign an ID for this
  /// target and return that in a `TargetChange::ADD` event. Once a target with
  /// `target_id=0` is added, all subsequent targets must also have
  /// `target_id=0`. If an `AddTarget` request with `target_id != 0` is
  /// sent to the server after a target with `target_id=0` is added, the server
  /// will immediately send a response with a `TargetChange::Remove` event.
  ///
  /// Note that if the client sends multiple `AddTarget` requests
  /// without an ID, the order of IDs returned in `TargetChange.target_ids` are
  /// undefined. Therefore, clients should provide a target ID instead of relying
  /// on the server to assign one.
  ///
  /// If `target_id` is non-zero, there must not be an existing active target on
  /// this stream with the same ID.
  @$pb.TagNumber(5)
  $core.int get targetId => $_getIZ(3);
  @$pb.TagNumber(5)
  set targetId($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(5)
  $core.bool hasTargetId() => $_has(3);
  @$pb.TagNumber(5)
  void clearTargetId() => $_clearField(5);

  /// If the target should be removed once it is current and consistent.
  @$pb.TagNumber(6)
  $core.bool get once => $_getBF(4);
  @$pb.TagNumber(6)
  set once($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(6)
  $core.bool hasOnce() => $_has(4);
  @$pb.TagNumber(6)
  void clearOnce() => $_clearField(6);

  /// Start listening after a specific `read_time`.
  ///
  /// The client must know the state of matching documents at this time.
  @$pb.TagNumber(11)
  $4.Timestamp get readTime => $_getN(5);
  @$pb.TagNumber(11)
  set readTime($4.Timestamp value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasReadTime() => $_has(5);
  @$pb.TagNumber(11)
  void clearReadTime() => $_clearField(11);
  @$pb.TagNumber(11)
  $4.Timestamp ensureReadTime() => $_ensure(5);

  /// The number of documents that last matched the query at the resume token or
  /// read time.
  ///
  /// This value is only relevant when a `resume_type` is provided. This value
  /// being present and greater than zero signals that the client wants
  /// `ExistenceFilter.unchanged_names` to be included in the response.
  @$pb.TagNumber(12)
  $11.Int32Value get expectedCount => $_getN(6);
  @$pb.TagNumber(12)
  set expectedCount($11.Int32Value value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasExpectedCount() => $_has(6);
  @$pb.TagNumber(12)
  void clearExpectedCount() => $_clearField(12);
  @$pb.TagNumber(12)
  $11.Int32Value ensureExpectedCount() => $_ensure(6);
}

/// Targets being watched have changed.
class TargetChange extends $pb.GeneratedMessage {
  factory TargetChange({
    TargetChange_TargetChangeType? targetChangeType,
    $core.Iterable<$core.int>? targetIds,
    $12.Status? cause,
    $core.List<$core.int>? resumeToken,
    $4.Timestamp? readTime,
  }) {
    final result = TargetChange._();
    if (targetChangeType != null) result.targetChangeType = targetChangeType;
    if (targetIds != null) result.targetIds.addAll(targetIds);
    if (cause != null) result.cause = cause;
    if (resumeToken != null) result.resumeToken = resumeToken;
    if (readTime != null) result.readTime = readTime;
    return result;
  }

  TargetChange._();

  factory TargetChange.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TargetChange()..mergeFromBuffer(data, registry);
  factory TargetChange.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TargetChange()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TargetChange',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: TargetChange.$_createMessage)
    ..aE<TargetChange_TargetChangeType>(
        1, _omitFieldNames ? '' : 'targetChangeType',
        enumValues: TargetChange_TargetChangeType.values)
    ..p<$core.int>(2, _omitFieldNames ? '' : 'targetIds', $pb.PbFieldType.K3)
    ..aOM<$12.Status>(3, _omitFieldNames ? '' : 'cause',
        subBuilder: $12.Status.$_createMessage)
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'resumeToken', $pb.PbFieldType.OY)
    ..aOM<$4.Timestamp>(6, _omitFieldNames ? '' : 'readTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TargetChange clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TargetChange copyWith(void Function(TargetChange) updates) =>
      super.copyWith((message) => updates(message as TargetChange))
          as TargetChange;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TargetChange() / TargetChange.new instead')
  static TargetChange create() => TargetChange._();
  static $pb.GeneratedMessage $_createMessage() => TargetChange._();
  @$core.override
  TargetChange createEmptyInstance() => TargetChange._();
  @$core.pragma('dart2js:noInline')
  static TargetChange getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TargetChange>(
          TargetChange.$_createMessage);
  static TargetChange? _defaultInstance;

  /// The type of change that occurred.
  @$pb.TagNumber(1)
  TargetChange_TargetChangeType get targetChangeType => $_getN(0);
  @$pb.TagNumber(1)
  set targetChangeType(TargetChange_TargetChangeType value) =>
      $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTargetChangeType() => $_has(0);
  @$pb.TagNumber(1)
  void clearTargetChangeType() => $_clearField(1);

  /// The target IDs of targets that have changed.
  ///
  /// If empty, the change applies to all targets.
  ///
  /// The order of the target IDs is not defined.
  @$pb.TagNumber(2)
  $pb.PbList<$core.int> get targetIds => $_getList(1);

  /// The error that resulted in this change, if applicable.
  @$pb.TagNumber(3)
  $12.Status get cause => $_getN(2);
  @$pb.TagNumber(3)
  set cause($12.Status value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCause() => $_has(2);
  @$pb.TagNumber(3)
  void clearCause() => $_clearField(3);
  @$pb.TagNumber(3)
  $12.Status ensureCause() => $_ensure(2);

  /// A token that can be used to resume the stream for the given `target_ids`,
  /// or all targets if `target_ids` is empty.
  ///
  /// Not set on every target change.
  @$pb.TagNumber(4)
  $core.List<$core.int> get resumeToken => $_getN(3);
  @$pb.TagNumber(4)
  set resumeToken($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasResumeToken() => $_has(3);
  @$pb.TagNumber(4)
  void clearResumeToken() => $_clearField(4);

  /// The consistent `read_time` for the given `target_ids` (omitted when the
  /// target_ids are not at a consistent snapshot).
  ///
  /// The stream is guaranteed to send a `read_time` with `target_ids` empty
  /// whenever the entire stream reaches a new consistent snapshot. ADD,
  /// CURRENT, and RESET messages are guaranteed to (eventually) result in a
  /// new consistent snapshot (while NO_CHANGE and REMOVE messages are not).
  ///
  /// For a given stream, `read_time` is guaranteed to be monotonically
  /// increasing.
  @$pb.TagNumber(6)
  $4.Timestamp get readTime => $_getN(4);
  @$pb.TagNumber(6)
  set readTime($4.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasReadTime() => $_has(4);
  @$pb.TagNumber(6)
  void clearReadTime() => $_clearField(6);
  @$pb.TagNumber(6)
  $4.Timestamp ensureReadTime() => $_ensure(4);
}

enum ListCollectionIdsRequest_ConsistencySelector { readTime, notSet }

/// The request for
/// [Firestore.ListCollectionIds][google.firestore.v1.Firestore.ListCollectionIds].
class ListCollectionIdsRequest extends $pb.GeneratedMessage {
  factory ListCollectionIdsRequest({
    $core.String? parent,
    $core.int? pageSize,
    $core.String? pageToken,
    $4.Timestamp? readTime,
    $3.RequestOptions? requestOptions,
  }) {
    final result = ListCollectionIdsRequest._();
    if (parent != null) result.parent = parent;
    if (pageSize != null) result.pageSize = pageSize;
    if (pageToken != null) result.pageToken = pageToken;
    if (readTime != null) result.readTime = readTime;
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  ListCollectionIdsRequest._();

  factory ListCollectionIdsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListCollectionIdsRequest()..mergeFromBuffer(data, registry);
  factory ListCollectionIdsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListCollectionIdsRequest()..mergeFromJson(json, registry);

  static const $core
      .Map<$core.int, ListCollectionIdsRequest_ConsistencySelector>
      _ListCollectionIdsRequest_ConsistencySelectorByTag = {
    4: ListCollectionIdsRequest_ConsistencySelector.readTime,
    0: ListCollectionIdsRequest_ConsistencySelector.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListCollectionIdsRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: ListCollectionIdsRequest.$_createMessage)
    ..oo(0, [4])
    ..aOS(1, _omitFieldNames ? '' : 'parent')
    ..aI(2, _omitFieldNames ? '' : 'pageSize')
    ..aOS(3, _omitFieldNames ? '' : 'pageToken')
    ..aOM<$4.Timestamp>(4, _omitFieldNames ? '' : 'readTime',
        subBuilder: $4.Timestamp.$_createMessage)
    ..aOM<$3.RequestOptions>(5, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCollectionIdsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCollectionIdsRequest copyWith(
          void Function(ListCollectionIdsRequest) updates) =>
      super.copyWith((message) => updates(message as ListCollectionIdsRequest))
          as ListCollectionIdsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListCollectionIdsRequest() / ListCollectionIdsRequest.new instead')
  static ListCollectionIdsRequest create() => ListCollectionIdsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListCollectionIdsRequest._();
  @$core.override
  ListCollectionIdsRequest createEmptyInstance() =>
      ListCollectionIdsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListCollectionIdsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListCollectionIdsRequest>(
          ListCollectionIdsRequest.$_createMessage);
  static ListCollectionIdsRequest? _defaultInstance;

  @$pb.TagNumber(4)
  ListCollectionIdsRequest_ConsistencySelector whichConsistencySelector() =>
      _ListCollectionIdsRequest_ConsistencySelectorByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(4)
  void clearConsistencySelector() => $_clearField($_whichOneof(0));

  /// Required. The parent document. In the format:
  /// `projects/{project_id}/databases/{database_id}/documents/{document_path}`.
  /// For example:
  /// `projects/my-project/databases/my-database/documents/chatrooms/my-chatroom`
  ///
  /// Use `projects/{project_id}/databases/{database_id}/documents` to list
  /// top-level collections.
  @$pb.TagNumber(1)
  $core.String get parent => $_getSZ(0);
  @$pb.TagNumber(1)
  set parent($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasParent() => $_has(0);
  @$pb.TagNumber(1)
  void clearParent() => $_clearField(1);

  /// The maximum number of results to return.
  @$pb.TagNumber(2)
  $core.int get pageSize => $_getIZ(1);
  @$pb.TagNumber(2)
  set pageSize($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPageSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearPageSize() => $_clearField(2);

  /// A page token. Must be a value from
  /// [ListCollectionIdsResponse][google.firestore.v1.ListCollectionIdsResponse].
  @$pb.TagNumber(3)
  $core.String get pageToken => $_getSZ(2);
  @$pb.TagNumber(3)
  set pageToken($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPageToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearPageToken() => $_clearField(3);

  /// Reads documents as they were at the given time.
  ///
  /// This must be a microsecond precision timestamp within the past one hour,
  /// or if Point-in-Time Recovery is enabled, can additionally be a whole
  /// minute timestamp within the past 7 days.
  @$pb.TagNumber(4)
  $4.Timestamp get readTime => $_getN(3);
  @$pb.TagNumber(4)
  set readTime($4.Timestamp value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasReadTime() => $_has(3);
  @$pb.TagNumber(4)
  void clearReadTime() => $_clearField(4);
  @$pb.TagNumber(4)
  $4.Timestamp ensureReadTime() => $_ensure(3);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(5)
  $3.RequestOptions get requestOptions => $_getN(4);
  @$pb.TagNumber(5)
  set requestOptions($3.RequestOptions value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasRequestOptions() => $_has(4);
  @$pb.TagNumber(5)
  void clearRequestOptions() => $_clearField(5);
  @$pb.TagNumber(5)
  $3.RequestOptions ensureRequestOptions() => $_ensure(4);
}

/// The response from
/// [Firestore.ListCollectionIds][google.firestore.v1.Firestore.ListCollectionIds].
class ListCollectionIdsResponse extends $pb.GeneratedMessage {
  factory ListCollectionIdsResponse({
    $core.Iterable<$core.String>? collectionIds,
    $core.String? nextPageToken,
  }) {
    final result = ListCollectionIdsResponse._();
    if (collectionIds != null) result.collectionIds.addAll(collectionIds);
    if (nextPageToken != null) result.nextPageToken = nextPageToken;
    return result;
  }

  ListCollectionIdsResponse._();

  factory ListCollectionIdsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListCollectionIdsResponse()..mergeFromBuffer(data, registry);
  factory ListCollectionIdsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListCollectionIdsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListCollectionIdsResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: ListCollectionIdsResponse.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'collectionIds')
    ..aOS(2, _omitFieldNames ? '' : 'nextPageToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCollectionIdsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCollectionIdsResponse copyWith(
          void Function(ListCollectionIdsResponse) updates) =>
      super.copyWith((message) => updates(message as ListCollectionIdsResponse))
          as ListCollectionIdsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListCollectionIdsResponse() / ListCollectionIdsResponse.new instead')
  static ListCollectionIdsResponse create() => ListCollectionIdsResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      ListCollectionIdsResponse._();
  @$core.override
  ListCollectionIdsResponse createEmptyInstance() =>
      ListCollectionIdsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListCollectionIdsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListCollectionIdsResponse>(
          ListCollectionIdsResponse.$_createMessage);
  static ListCollectionIdsResponse? _defaultInstance;

  /// The collection ids.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get collectionIds => $_getList(0);

  /// A page token that may be used to continue the list.
  @$pb.TagNumber(2)
  $core.String get nextPageToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set nextPageToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNextPageToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextPageToken() => $_clearField(2);
}

/// The request for
/// [Firestore.BatchWrite][google.firestore.v1.Firestore.BatchWrite].
class BatchWriteRequest extends $pb.GeneratedMessage {
  factory BatchWriteRequest({
    $core.String? database,
    $core.Iterable<$5.Write>? writes,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? labels,
    $3.RequestOptions? requestOptions,
  }) {
    final result = BatchWriteRequest._();
    if (database != null) result.database = database;
    if (writes != null) result.writes.addAll(writes);
    if (labels != null) result.labels.addEntries(labels);
    if (requestOptions != null) result.requestOptions = requestOptions;
    return result;
  }

  BatchWriteRequest._();

  factory BatchWriteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BatchWriteRequest()..mergeFromBuffer(data, registry);
  factory BatchWriteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BatchWriteRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BatchWriteRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: BatchWriteRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'database')
    ..pPM<$5.Write>(2, _omitFieldNames ? '' : 'writes',
        subBuilder: $5.Write.$_createMessage)
    ..m<$core.String, $core.String>(3, _omitFieldNames ? '' : 'labels',
        entryClassName: 'BatchWriteRequest.LabelsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('google.firestore.v1'))
    ..aOM<$3.RequestOptions>(4, _omitFieldNames ? '' : 'requestOptions',
        subBuilder: $3.RequestOptions.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchWriteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchWriteRequest copyWith(void Function(BatchWriteRequest) updates) =>
      super.copyWith((message) => updates(message as BatchWriteRequest))
          as BatchWriteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BatchWriteRequest() / BatchWriteRequest.new instead')
  static BatchWriteRequest create() => BatchWriteRequest._();
  static $pb.GeneratedMessage $_createMessage() => BatchWriteRequest._();
  @$core.override
  BatchWriteRequest createEmptyInstance() => BatchWriteRequest._();
  @$core.pragma('dart2js:noInline')
  static BatchWriteRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BatchWriteRequest>(
          BatchWriteRequest.$_createMessage);
  static BatchWriteRequest? _defaultInstance;

  /// Required. The database name. In the format:
  /// `projects/{project_id}/databases/{database_id}`.
  @$pb.TagNumber(1)
  $core.String get database => $_getSZ(0);
  @$pb.TagNumber(1)
  set database($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDatabase() => $_has(0);
  @$pb.TagNumber(1)
  void clearDatabase() => $_clearField(1);

  /// The writes to apply.
  ///
  /// Method does not apply writes atomically and does not guarantee ordering.
  /// Each write succeeds or fails independently. You cannot write to the same
  /// document more than once per request.
  @$pb.TagNumber(2)
  $pb.PbList<$5.Write> get writes => $_getList(1);

  /// Labels associated with this batch write.
  @$pb.TagNumber(3)
  $pb.PbMap<$core.String, $core.String> get labels => $_getMap(2);

  /// Optional. Any additional options for the request.
  @$pb.TagNumber(4)
  $3.RequestOptions get requestOptions => $_getN(3);
  @$pb.TagNumber(4)
  set requestOptions($3.RequestOptions value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRequestOptions() => $_has(3);
  @$pb.TagNumber(4)
  void clearRequestOptions() => $_clearField(4);
  @$pb.TagNumber(4)
  $3.RequestOptions ensureRequestOptions() => $_ensure(3);
}

/// The response from
/// [Firestore.BatchWrite][google.firestore.v1.Firestore.BatchWrite].
class BatchWriteResponse extends $pb.GeneratedMessage {
  factory BatchWriteResponse({
    $core.Iterable<$5.WriteResult>? writeResults,
    $core.Iterable<$12.Status>? status,
  }) {
    final result = BatchWriteResponse._();
    if (writeResults != null) result.writeResults.addAll(writeResults);
    if (status != null) result.status.addAll(status);
    return result;
  }

  BatchWriteResponse._();

  factory BatchWriteResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BatchWriteResponse()..mergeFromBuffer(data, registry);
  factory BatchWriteResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BatchWriteResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BatchWriteResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: BatchWriteResponse.$_createMessage)
    ..pPM<$5.WriteResult>(1, _omitFieldNames ? '' : 'writeResults',
        subBuilder: $5.WriteResult.$_createMessage)
    ..pPM<$12.Status>(2, _omitFieldNames ? '' : 'status',
        subBuilder: $12.Status.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchWriteResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BatchWriteResponse copyWith(void Function(BatchWriteResponse) updates) =>
      super.copyWith((message) => updates(message as BatchWriteResponse))
          as BatchWriteResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BatchWriteResponse() / BatchWriteResponse.new instead')
  static BatchWriteResponse create() => BatchWriteResponse._();
  static $pb.GeneratedMessage $_createMessage() => BatchWriteResponse._();
  @$core.override
  BatchWriteResponse createEmptyInstance() => BatchWriteResponse._();
  @$core.pragma('dart2js:noInline')
  static BatchWriteResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BatchWriteResponse>(
          BatchWriteResponse.$_createMessage);
  static BatchWriteResponse? _defaultInstance;

  /// The result of applying the writes.
  ///
  /// This i-th write result corresponds to the i-th write in the
  /// request.
  @$pb.TagNumber(1)
  $pb.PbList<$5.WriteResult> get writeResults => $_getList(0);

  /// The status of applying the writes.
  ///
  /// This i-th write status corresponds to the i-th write in the
  /// request.
  @$pb.TagNumber(2)
  $pb.PbList<$12.Status> get status => $_getList(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
