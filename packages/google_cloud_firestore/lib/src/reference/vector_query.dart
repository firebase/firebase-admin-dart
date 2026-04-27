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

part of '../firestore.dart';

/// A query that finds the documents whose vector fields are closest to a certain query vector.
///
/// Create an instance of `VectorQuery` with [Query.findNearest].
@immutable
class VectorQuery<T> {
  /// @internal
  const VectorQuery._({
    required Query<T> query,
    required VectorQueryOptions options,
  }) : _query = query,
       _options = options;

  final Query<T> _query;
  final VectorQueryOptions _options;

  /// The query whose results participate in the vector search.
  ///
  /// Filtering performed by the query will apply before the vector search.
  Query<T> get query => _query;

  String get _rawVectorField {
    final field = _options.vectorField;
    return field is String ? field : (field as FieldPath)._formattedName;
  }

  String? get _rawDistanceResultField {
    final field = _options.distanceResultField;
    if (field == null) return null;
    return field is String ? field : (field as FieldPath)._formattedName;
  }

  List<double> get _rawQueryVector {
    final vector = _options.queryVector;
    return vector is List<double> ? vector : (vector as VectorValue).toArray();
  }

  /// Executes this vector search query.
  ///
  /// Returns a promise that will be resolved with the results of the query.
  Future<VectorQuerySnapshot<T>> get() async {
    final response = await _query.firestore._firestoreClient.v1((
      api,
      projectId,
    ) async {
      final request = _toProto(transactionId: null, readTime: null);
      final finalRequest = firestore_v1.RunQueryRequest(
        parent: _query._buildProtoParentPath(),
        structuredQuery: request.structuredQuery,
        transaction: request.transaction,
        readTime: request.readTime,
      );
      return api.runQuery(finalRequest);
    });

    Timestamp? readTime;
    final snapshots = <QueryDocumentSnapshot<T>>[];
    await for (final e in response) {
      final document = e.document;
      if (document == null) {
        readTime = e.readTime.let(Timestamp._fromProto);
        continue;
      }

      final snapshot = DocumentSnapshot._fromDocument(
        document,
        e.readTime,
        _query.firestore,
      );
      final finalDoc =
          _DocumentSnapshotBuilder(
              snapshot.ref.withConverter<T>(
                fromFirestore: _query._queryOptions.converter.fromFirestore,
                toFirestore: _query._queryOptions.converter.toFirestore,
              ),
            )
            ..fieldsProto = firestore_v1.MapValue(fields: document.fields)
            ..readTime = snapshot.readTime
            ..createTime = snapshot.createTime
            ..updateTime = snapshot.updateTime;

      snapshots.add(finalDoc.build() as QueryDocumentSnapshot<T>);
    }

    return VectorQuerySnapshot<T>._(
      query: this,
      readTime: readTime ?? Timestamp.now(),
      docs: snapshots,
    );
  }

  /// Plans and optionally executes this vector query, returning an [ExplainResults]
  /// object which contains information about the planning, and optionally
  /// the execution statistics and results.
  ///
  /// ```dart
  /// final vectorQuery = collection.findNearest(
  ///   vectorField: 'embedding',
  ///   queryVector: [1.0, 2.0, 3.0],
  ///   limit: 10,
  ///   distanceMeasure: DistanceMeasure.euclidean,
  /// );
  ///
  /// // Get query plan without executing
  /// final explainResults = await vectorQuery.explain(ExplainOptions(analyze: false));
  /// print('Indexes used: ${explainResults.metrics.planSummary.indexesUsed}');
  ///
  /// // Get query plan and execute
  /// final explainResultsWithData = await vectorQuery.explain(ExplainOptions(analyze: true));
  /// print('Results: ${explainResultsWithData.snapshot?.docs.length}');
  /// ```
  Future<ExplainResults<VectorQuerySnapshot<T>?>> explain(
    ExplainOptions options,
  ) async {
    final response = await _query.firestore._firestoreClient.v1((
      api,
      projectId,
    ) async {
      final request = _toProto(transactionId: null, readTime: null);
      final finalRequest = firestore_v1.RunQueryRequest(
        parent: _query._buildProtoParentPath(),
        structuredQuery: request.structuredQuery,
        transaction: request.transaction,
        readTime: request.readTime,
        explainOptions: options.toProto(),
      );

      return api.runQuery(finalRequest);
    });

    ExplainMetrics? metrics;
    VectorQuerySnapshot<T>? snapshot;
    Timestamp? readTime;

    final docs = <QueryDocumentSnapshot<T>>[];

    await for (final element in response) {
      // Extract explain metrics if present
      if (element.explainMetrics != null) {
        metrics = ExplainMetrics._fromProto(element.explainMetrics!);
      }

      // Extract document if present (when analyze: true)
      final document = element.document;
      if (document != null) {
        final docSnapshot = DocumentSnapshot._fromDocument(
          document,
          element.readTime,
          _query.firestore,
        );

        final finalDoc =
            _DocumentSnapshotBuilder(
                docSnapshot.ref.withConverter<T>(
                  fromFirestore: _query._queryOptions.converter.fromFirestore,
                  toFirestore: _query._queryOptions.converter.toFirestore,
                ),
              )
              ..fieldsProto = firestore_v1.MapValue(fields: document.fields)
              ..readTime = docSnapshot.readTime
              ..createTime = docSnapshot.createTime
              ..updateTime = docSnapshot.updateTime;

        docs.add(finalDoc.build() as QueryDocumentSnapshot<T>);
      }

      if (element.readTime != null) {
        readTime = Timestamp._fromProto(element.readTime!);
      }
    }

    // Create snapshot only if we have documents (analyze: true)
    if (docs.isNotEmpty || ((options.analyze ?? false) && readTime != null)) {
      snapshot = VectorQuerySnapshot<T>._(
        query: this,
        readTime: readTime ?? Timestamp.now(),
        docs: docs,
      );
    }

    if (metrics == null) {
      throw StateError('No explain metrics returned from query');
    }

    return ExplainResults._create(metrics: metrics, snapshot: snapshot);
  }

  /// Internal method for serializing a query to its proto representation.
  firestore_v1.RunQueryRequest _toProto({
    required String? transactionId,
    required Timestamp? readTime,
  }) {
    if (readTime != null && transactionId != null) {
      throw ArgumentError('readTime and transactionId cannot both be set.');
    }

    // Get the base structured query from the underlying query
    final structuredQueryBase = _query._toStructuredQuery();

    // Convert query vector to VectorValue if it's a List<double>
    final queryVector = _options.queryVector is VectorValue
        ? _options.queryVector as VectorValue
        : VectorValue(_options.queryVector as List<double>);

    // Reconstruct structuredQuery with findNearest
    final structuredQuery = firestore_v1.StructuredQuery(
      select: structuredQueryBase.select,
      from: structuredQueryBase.from,
      where: structuredQueryBase.where,
      orderBy: structuredQueryBase.orderBy,
      startAt: structuredQueryBase.startAt,
      endAt: structuredQueryBase.endAt,
      offset: structuredQueryBase.offset,
      limit: structuredQueryBase.limit,
      findNearest: firestore_v1.StructuredQuery_FindNearest(
        vectorField: firestore_v1.StructuredQuery_FieldReference(
          fieldPath: FieldPath.from(_options.vectorField)._formattedName,
        ),
        queryVector: queryVector._toProto(_query.firestore._serializer),
        distanceMeasure: _distanceMeasureToProto(_options.distanceMeasure),
        limit: protobuf_v1.Int32Value(value: _options.limit),
        distanceResultField:
            _options.distanceResultField != null
                ? FieldPath.from(_options.distanceResultField)._formattedName
                : '',
        distanceThreshold: _options.distanceThreshold?.let(
          (t) => protobuf_v1.DoubleValue(value: t),
        ),
      ),
    );

    return firestore_v1.RunQueryRequest(
      parent: '', // Will be set by caller
      structuredQuery: structuredQuery,
      transaction: transactionId.let(base64Decode),
      readTime: readTime?._toProto().timestampValue,
    );
  }

  firestore_v1.StructuredQuery_FindNearest_DistanceMeasure
  _distanceMeasureToProto(DistanceMeasure measure) {
    switch (measure) {
      case DistanceMeasure.euclidean:
        return firestore_v1.StructuredQuery_FindNearest_DistanceMeasure.euclidean;
      case DistanceMeasure.cosine:
        return firestore_v1.StructuredQuery_FindNearest_DistanceMeasure.cosine;
      case DistanceMeasure.dotProduct:
        return firestore_v1.StructuredQuery_FindNearest_DistanceMeasure.dotProduct;
    }
  }

  /// Compares this object with the given object for equality.
  ///
  /// This object is considered "equal" to the other object if and only if
  /// `other` performs the same vector distance search as this `VectorQuery` and
  /// the underlying Query of `other` compares equal to that of this object.
  bool isEqual(VectorQuery<T> other) {
    if (identical(this, other)) {
      return true;
    }

    if (_query != other._query) {
      return false;
    }

    // Compare vector query options
    return _rawVectorField == other._rawVectorField &&
        _listEquals(_rawQueryVector, other._rawQueryVector) &&
        _options.limit == other._options.limit &&
        _options.distanceMeasure == other._options.distanceMeasure &&
        _options.distanceThreshold == other._options.distanceThreshold &&
        _rawDistanceResultField == other._rawDistanceResultField;
  }

  bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) {
    return other is VectorQuery<T> && isEqual(other);
  }

  @override
  int get hashCode => Object.hash(
    _query,
    _rawVectorField,
    Object.hashAll(_rawQueryVector),
    _options.limit,
    _options.distanceMeasure,
    _options.distanceThreshold,
    _rawDistanceResultField,
  );
}
