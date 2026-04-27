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

@immutable
interface class Query<T> {
  const Query._({
    required this.firestore,
    required _QueryOptions<T> queryOptions,
  }) : _queryOptions = queryOptions;

  static List<Object?> _extractFieldValues(
    DocumentSnapshot<Object?> documentSnapshot,
    List<_FieldOrder> fieldOrders,
  ) {
    return fieldOrders.map((fieldOrder) {
      if (fieldOrder.fieldPath == FieldPath.documentId) {
        return documentSnapshot.ref;
      }

      final fieldValue = documentSnapshot.get(fieldOrder.fieldPath);
      if (fieldValue == null) {
        throw StateError(
          'Field "${fieldOrder.fieldPath}" is missing in the provided DocumentSnapshot. '
          'Please provide a document that contains values for all specified orderBy() '
          'and where() constraints.',
        );
      }
      return fieldValue.value;
    }).toList();
  }

  final Firestore firestore;
  final _QueryOptions<T> _queryOptions;

  /// Applies a custom data converter to this Query, allowing you to use your
  /// own custom model objects with Firestore. When you call [get] on the
  /// returned [Query], the provided converter will convert between Firestore
  /// data and your custom type U.
  ///
  /// Using the converter allows you to specify generic type arguments when
  /// storing and retrieving objects from Firestore.
  ///
  /// Passing `null` for both parameters removes the current converter and
  /// returns an untyped `Query<DocumentData>`.
  @mustBeOverridden
  Query<U> withConverter<U>({
    FromFirestore<U>? fromFirestore,
    ToFirestore<U>? toFirestore,
  }) {
    // If null, use the default JSON converter
    final converter = (fromFirestore == null || toFirestore == null)
        ? _jsonConverter as _FirestoreDataConverter<U>
        : (fromFirestore: fromFirestore, toFirestore: toFirestore);

    return Query<U>._(
      firestore: firestore,
      queryOptions: _queryOptions.withConverter(converter),
    );
  }

  _QueryCursor _createCursor(
    List<_FieldOrder> fieldOrders, {
    List<Object?>? fieldValues,
    DocumentSnapshot<Object?>? snapshot,
    required bool before,
  }) {
    if (fieldValues != null && snapshot != null) {
      throw ArgumentError(
        'You cannot specify both "fieldValues" and "snapshot".',
      );
    }

    final effectiveFieldValues = snapshot != null
        ? Query._extractFieldValues(snapshot, fieldOrders)
        : fieldValues;

    if (effectiveFieldValues == null) {
      throw ArgumentError('You must specify "fieldValues" or "snapshot".');
    }

    if (effectiveFieldValues.length > fieldOrders.length) {
      throw ArgumentError(
        'Too many cursor values specified. The specified '
        'values must match the orderBy() constraints of the query.',
      );
    }

    final cursorValues = <firestore_v1.Value>[];
    final cursor = _QueryCursor(before: before, values: cursorValues);

    for (var i = 0; i < effectiveFieldValues.length; ++i) {
      final fieldValue = effectiveFieldValues[i];

      if (fieldOrders[i].fieldPath == FieldPath.documentId &&
          fieldValue is! DocumentReference) {
        throw ArgumentError(
          'When ordering with FieldPath.documentId(), '
          'the cursor must be a DocumentReference.',
        );
      }

      _validateQueryValue('$i', fieldValue);
      cursor.values.add(firestore._serializer.encodeValue(fieldValue)!);
    }

    return cursor;
  }

  (_QueryCursor, List<_FieldOrder>) _cursorFromValues({
    List<Object?>? fieldValues,
    DocumentSnapshot<Object?>? snapshot,
    required bool before,
  }) {
    if (fieldValues != null && fieldValues.isEmpty) {
      throw ArgumentError.value(
        fieldValues,
        'fieldValues',
        'Value must not be an empty List.',
      );
    }

    final fieldOrders = _createImplicitOrderBy(snapshot);
    final cursor = _createCursor(
      fieldOrders,
      fieldValues: fieldValues,
      snapshot: snapshot,
      before: before,
    );
    return (cursor, fieldOrders);
  }

  /// Computes the backend ordering semantics for DocumentSnapshot cursors.
  List<_FieldOrder> _createImplicitOrderBy(
    DocumentSnapshot<Object?>? snapshot,
  ) {
    // Add an implicit orderBy if the only cursor value is a DocumentSnapshot
    // or a DocumentReference.
    if (snapshot == null) return _queryOptions.fieldOrders;

    final fieldOrders = _queryOptions.fieldOrders.toList();

    // If no explicit ordering is specified, use the first inequality to
    // define an implicit order.
    if (fieldOrders.isEmpty) {
      for (final filter in _queryOptions.filters) {
        final fieldReference = filter.firstInequalityField;
        if (fieldReference != null) {
          fieldOrders.add(_FieldOrder(fieldPath: fieldReference));
          break;
        }
      }
    }

    final hasDocumentId = fieldOrders.any(
      (fieldOrder) => fieldOrder.fieldPath == FieldPath.documentId,
    );
    if (!hasDocumentId) {
      // Add implicit sorting by name, using the last specified direction.
      final lastDirection = fieldOrders.isEmpty
          ? _Direction.ascending
          : fieldOrders.last.direction;

      fieldOrders.add(
        _FieldOrder(fieldPath: FieldPath.documentId, direction: lastDirection),
      );
    }

    return fieldOrders;
  }

  /// Creates and returns a new [Query] that starts at the provided
  /// set of field values relative to the order of the query. The order of the
  /// provided values must match the order of the order by clauses of the query.
  ///
  /// - [fieldValues] The field values to start this query at,
  ///   in order of the query's order by.
  ///
  /// ```dart
  /// final query = firestore.collection('col');
  ///
  /// query.orderBy('foo').startAt(42).get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Found document at ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  Query<T> startAt(List<Object?> fieldValues) {
    final (startAt, fieldOrders) = _cursorFromValues(
      fieldValues: fieldValues,
      before: true,
    );

    final options = _queryOptions.copyWith(
      fieldOrders: fieldOrders,
      startAt: startAt,
    );
    return Query<T>._(firestore: firestore, queryOptions: options);
  }

  /// Creates and returns a new [Query] that starts at the provided
  /// set of field values relative to the order of the query. The order of the
  /// provided values must match the order of the order by clauses of the query.
  ///
  /// - [documentSnapshot] The snapshot of the document the query results
  ///   should start at, in order of the query's order by.
  Query<T> startAtDocument(DocumentSnapshot<Object?> documentSnapshot) {
    final (startAt, fieldOrders) = _cursorFromValues(
      snapshot: documentSnapshot,
      before: true,
    );

    final options = _queryOptions.copyWith(
      fieldOrders: fieldOrders,
      startAt: startAt,
    );
    return Query<T>._(firestore: firestore, queryOptions: options);
  }

  /// Creates and returns a new [Query] that starts after the
  /// provided set of field values relative to the order of the query. The order
  /// of the provided values must match the order of the order by clauses of the
  /// query.
  ///
  /// - [fieldValues]: The field values to
  ///   start this query after, in order of the query's order by.
  ///
  /// ```dart
  /// final query = firestore.collection('col');
  ///
  /// query.orderBy('foo').startAfter(42).get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Found document at ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  Query<T> startAfter(List<Object?> fieldValues) {
    final (startAt, fieldOrders) = _cursorFromValues(
      fieldValues: fieldValues,
      before: false,
    );

    final options = _queryOptions.copyWith(
      fieldOrders: fieldOrders,
      startAt: startAt,
    );
    return Query<T>._(firestore: firestore, queryOptions: options);
  }

  /// Creates and returns a new [Query] that starts after the
  /// provided set of field values relative to the order of the query. The order
  /// of the provided values must match the order of the order by clauses of the
  /// query.
  ///
  /// - [snapshot]: The snapshot of the document the query results
  ///   should start at, in order of the query's order by.
  Query<T> startAfterDocument(DocumentSnapshot<Object?> snapshot) {
    final (startAt, fieldOrders) = _cursorFromValues(
      snapshot: snapshot,
      before: false,
    );

    final options = _queryOptions.copyWith(
      fieldOrders: fieldOrders,
      startAt: startAt,
    );
    return Query<T>._(firestore: firestore, queryOptions: options);
  }

  /// Creates and returns a new [Query] that ends before the set of
  /// field values relative to the order of the query. The order of the provided
  /// values must match the order of the order by clauses of the query.
  ///
  /// - [fieldValues]: The field values to
  ///   end this query before, in order of the query's order by.
  ///
  /// ```dart
  /// final query = firestore.collection('col');
  ///
  /// query.orderBy('foo').endBefore(42).get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Found document at ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  Query<T> endBefore(List<Object?> fieldValues) {
    final (endAt, fieldOrders) = _cursorFromValues(
      fieldValues: fieldValues,
      before: true,
    );

    final options = _queryOptions.copyWith(
      fieldOrders: fieldOrders,
      endAt: endAt,
    );
    return Query<T>._(firestore: firestore, queryOptions: options);
  }

  /// Creates and returns a new [Query] that ends before the set of
  /// field values relative to the order of the query. The order of the provided
  /// values must match the order of the order by clauses of the query.
  ///
  /// - [snapshot]: The snapshot
  ///   of the document the query results should end before.
  Query<T> endBeforeDocument(DocumentSnapshot<Object?> snapshot) {
    final (endAt, fieldOrders) = _cursorFromValues(
      snapshot: snapshot,
      before: true,
    );

    final options = _queryOptions.copyWith(
      fieldOrders: fieldOrders,
      endAt: endAt,
    );
    return Query<T>._(firestore: firestore, queryOptions: options);
  }

  /// Creates and returns a new [Query] that ends at the provided
  /// set of field values relative to the order of the query. The order of the
  /// provided values must match the order of the order by clauses of the query.
  ///
  /// - [fieldValues]: The field values to end
  ///   this query at, in order of the query's order by.
  ///
  /// ```dart
  /// final query = firestore.collection('col');
  ///
  /// query.orderBy('foo').endAt(42).get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Found document at ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  Query<T> endAt(List<Object?> fieldValues) {
    final (endAt, fieldOrders) = _cursorFromValues(
      fieldValues: fieldValues,
      before: false,
    );

    final options = _queryOptions.copyWith(
      fieldOrders: fieldOrders,
      endAt: endAt,
    );
    return Query<T>._(firestore: firestore, queryOptions: options);
  }

  /// Creates and returns a new [Query] that ends at the provided
  /// set of field values relative to the order of the query. The order of the
  /// provided values must match the order of the order by clauses of the query.
  ///
  /// - [snapshot]: The snapshot
  ///   of the document the query results should end at, in order of the query's order by.
  /// ```
  Query<T> endAtDocument(DocumentSnapshot<Object?> snapshot) {
    final (endAt, fieldOrders) = _cursorFromValues(
      snapshot: snapshot,
      before: false,
    );

    final options = _queryOptions.copyWith(
      fieldOrders: fieldOrders,
      endAt: endAt,
    );
    return Query<T>._(firestore: firestore, queryOptions: options);
  }

  /// Executes the query and returns the results as a [QuerySnapshot].
  ///
  /// ```dart
  /// final query = firestore.collection('col').where('foo', WhereFilter.equal, 'bar');
  ///
  /// query.get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Found document at ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  Future<QuerySnapshot<T>> get() => _get(transactionId: null);

  /// Plans and optionally executes this query, returning an [ExplainResults]
  /// object which contains information about the planning, and optionally
  /// the execution statistics and results.
  ///
  /// ```dart
  /// final query = firestore.collection('col').where('foo', WhereFilter.equal, 'bar');
  ///
  /// // Get query plan without executing
  /// final explainResults = await query.explain();
  /// print('Indexes used: ${explainResults.metrics.planSummary.indexesUsed}');
  ///
  /// // Get query plan and execute
  /// final explainResultsWithData = await query.explain(ExplainOptions(analyze: true));
  /// print('Results: ${explainResultsWithData.snapshot?.docs.length}');
  /// print('Read operations: ${explainResultsWithData.metrics.executionStats?.readOperations}');
  /// ```
  Future<ExplainResults<QuerySnapshot<T>?>> explain([
    ExplainOptions? options,
  ]) async {
    final response = await firestore._firestoreClient.v1((
      api,
      projectId,
    ) async {
      final request = _toProto(
        parent: _buildProtoParentPath(),
        transactionId: null,
        readTime: null,
        explainOptions: options?.toProto(),
      );

      return api.runQuery(request);
    });

    ExplainMetrics? metrics;
    QuerySnapshot<T>? snapshot;
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
          firestore,
        );

        final finalDoc =
            _DocumentSnapshotBuilder(
                docSnapshot.ref.withConverter<T>(
                  fromFirestore: _queryOptions.converter.fromFirestore,
                  toFirestore: _queryOptions.converter.toFirestore,
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
    if (docs.isNotEmpty || ((options?.analyze ?? false) && readTime != null)) {
      snapshot = QuerySnapshot<T>._(
        query: this,
        readTime: readTime,
        docs: docs,
      );
    }

    if (metrics == null) {
      throw StateError('No explain metrics returned from query');
    }

    return ExplainResults._create(metrics: metrics, snapshot: snapshot);
  }

  Future<QuerySnapshot<T>> _get({required String? transactionId}) async {
    final response = await firestore._firestoreClient.v1((
      api,
      projectId,
    ) async {
      final request = _toProto(
        parent: _buildProtoParentPath(),
        transactionId: transactionId,
        readTime: null,
      );
      return api.runQuery(request);
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
        firestore,
      );
      final finalDoc =
          _DocumentSnapshotBuilder(
              snapshot.ref.withConverter<T>(
                fromFirestore: _queryOptions.converter.fromFirestore,
                toFirestore: _queryOptions.converter.toFirestore,
              ),
            )
            // Recreate the QueryDocumentSnapshot with the DocumentReference
            // containing the original converter.
            ..fieldsProto = firestore_v1.MapValue(fields: document.fields)
            ..readTime = snapshot.readTime
            ..createTime = snapshot.createTime
            ..updateTime = snapshot.updateTime;

      snapshots.add(finalDoc.build() as QueryDocumentSnapshot<T>);
    }

    return QuerySnapshot<T>._(query: this, readTime: readTime, docs: snapshots);
  }

  String _buildProtoParentPath() {
    return _queryOptions.parentPath
        ._toQualifiedResourcePath(firestore.projectId, firestore.databaseId)
        ._formattedName;
  }

  firestore_v1.RunQueryRequest _toProto({
    required String parent,
    required String? transactionId,
    required Timestamp? readTime,
    firestore_v1.TransactionOptions? transactionOptions,
    firestore_v1.ExplainOptions? explainOptions,
  }) {
    // Validate mutual exclusivity of transaction parameters
    final providedParams = [
      transactionId,
      readTime,
      transactionOptions,
    ].nonNulls.length;

    if (providedParams > 1) {
      throw ArgumentError(
        'Only one of transactionId, readTime, or transactionOptions can be specified. '
        'Got: transactionId=$transactionId, readTime=$readTime, transactionOptions=$transactionOptions',
      );
    }

    final structuredQuery = _toStructuredQuery();

    // For limitToLast queries, the structured query has to be translated to a version with
    // reversed ordered, and flipped startAt/endAt to work properly.
    if (_queryOptions.limitType == LimitType.last) {
      if (!_queryOptions.hasFieldOrders) {
        throw ArgumentError(
          'limitToLast() queries require specifying at least one orderBy() clause.',
        );
      }

      final reversedOrderBy = _queryOptions.fieldOrders.map((order) {
        // Flip the orderBy directions since we want the last results
        final dir = order.direction == _Direction.descending
            ? _Direction.ascending
            : _Direction.descending;
        return _FieldOrder(
          fieldPath: order.fieldPath,
          direction: dir,
        )._toProto();
      }).toList();

      // Swap the cursors to match the now-flipped query ordering.
      final reversedStartAt = _queryOptions.endAt != null
          ? _toCursor(
              _QueryCursor(
                values: _queryOptions.endAt!.values,
                before: !_queryOptions.endAt!.before,
              ),
            )
          : null;
      final reversedEndAt = _queryOptions.startAt != null
          ? _toCursor(
              _QueryCursor(
                values: _queryOptions.startAt!.values,
                before: !_queryOptions.startAt!.before,
              ),
            )
          : null;

      final reversedStructuredQuery = firestore_v1.StructuredQuery(
        select: structuredQuery.select,
        from: structuredQuery.from,
        where: structuredQuery.where,
        orderBy: reversedOrderBy,
        startAt: reversedStartAt,
        endAt: reversedEndAt,
        offset: structuredQuery.offset,
        limit: structuredQuery.limit,
      );

      return firestore_v1.RunQueryRequest(
        parent: parent,
        structuredQuery: reversedStructuredQuery,
        transaction: transactionId.let(base64Decode),
        readTime: readTime?._toProto().timestampValue,
        newTransaction: transactionOptions,
        explainOptions: explainOptions,
      );
    }

    return firestore_v1.RunQueryRequest(
      parent: parent,
      structuredQuery: structuredQuery,
      transaction: transactionId.let(base64Decode),
      readTime: readTime?._toProto().timestampValue,
      newTransaction: transactionOptions,
      explainOptions: explainOptions,
    );
  }

  firestore_v1.StructuredQuery _toStructuredQuery() {
    final selectors = [
      firestore_v1.StructuredQuery_CollectionSelector(
        collectionId: _queryOptions.kindless ? '' : _queryOptions.collectionId,
        allDescendants: _queryOptions.allDescendants,
      ),
    ];

    final where =
        _queryOptions.filters.isNotEmpty
            ? _CompositeFilterInternal(
              filters: _queryOptions.filters,
              op: _CompositeOperator.and,
            ).toProto()
            : null;

    final orderBy =
        _queryOptions.hasFieldOrders
            ? _queryOptions.fieldOrders.map((o) => o._toProto()).toList()
            : const <firestore_v1.StructuredQuery_Order>[];

    return firestore_v1.StructuredQuery(
      select: _queryOptions.projection,
      from: selectors,
      where: where,
      orderBy: orderBy,
      startAt: _toCursor(_queryOptions.startAt),
      endAt: _toCursor(_queryOptions.endAt),
      offset: _queryOptions.offset ?? 0,
      limit: _queryOptions.limit?.let((l) => protobuf_v1.Int32Value(value: l)),
    );
  }

  /// Converts a QueryCursor to its proto representation.
  firestore_v1.Cursor? _toCursor(_QueryCursor? cursor) {
    if (cursor == null) return null;

    return cursor.before
        ? firestore_v1.Cursor(before: true, values: cursor.values)
        : firestore_v1.Cursor(values: cursor.values);
  }

  // TODO onSnapshot
  // TODO stream

  /// {@macro collection_reference.where}
  Query<T> where(Object path, WhereFilter op, Object? value) {
    final fieldPath = FieldPath.from(path);
    return whereFieldPath(fieldPath, op, value);
  }

  /// {@template collection_reference.where}
  /// Creates and returns a new [Query] with the additional filter
  /// that documents must contain the specified field and that its value should
  /// satisfy the relation constraint provided.
  ///
  /// This function returns a new (immutable) instance of the Query (rather than
  /// modify the existing instance) to impose the filter.
  ///
  /// - [fieldPath]: The name of a property value to compare.
  /// - [op]: A comparison operation in the form of a string.
  ///   Acceptable operator strings are "<", "<=", "==", "!=", ">=", ">", "array-contains",
  ///   "in", "not-in", and "array-contains-any".
  /// - [value]: The value to which to compare the field for inclusion in
  ///   a query.
  ///
  /// ```dart
  /// final collectionRef = firestore.collection('col');
  ///
  /// collectionRef.where('foo', WhereFilter.equal, 'bar').get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Found document at ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  /// {@endtemplate}
  Query<T> whereFieldPath(FieldPath fieldPath, WhereFilter op, Object? value) {
    return whereFilter(Filter.where(fieldPath, op, value));
  }

  /// Creates and returns a new [Query] with the additional filter
  /// that documents should satisfy the relation constraint(s) provided.
  ///
  /// This function returns a new (immutable) instance of the Query (rather than
  /// modify the existing instance) to impose the filter.
  ///
  /// - [filter] A unary or composite filter to apply to the Query.
  ///
  /// ```dart
  /// final collectionRef = firestore.collection('col');
  ///
  /// collectionRef.where(Filter.and(Filter.where('foo', WhereFilter.equal, 'bar'), Filter.where('foo', WhereFilter.notEqual, 'baz'))).get()
  ///   .then((querySnapshot) {
  ///     querySnapshot.forEach((documentSnapshot) {
  ///       print('Found document at ${documentSnapshot.ref.path}');
  ///     });
  /// });
  /// ```
  Query<T> whereFilter(Filter filter) {
    if (_queryOptions.startAt != null || _queryOptions.endAt != null) {
      throw ArgumentError(
        'Cannot specify a where() filter after calling '
        'startAt(), startAfter(), endBefore() or endAt().',
      );
    }

    final parsedFilter = _parseFilter(filter);
    if (parsedFilter.filters.isEmpty) {
      // Return the existing query if not adding any more filters (e.g. an empty composite filter).
      return this;
    }

    final options = _queryOptions.copyWith(
      filters: [..._queryOptions.filters, parsedFilter],
    );
    return Query<T>._(firestore: firestore, queryOptions: options);
  }

  _FilterInternal _parseFilter(Filter filter) {
    switch (filter) {
      case _UnaryFilter():
        return _parseFieldFilter(filter);
      case _CompositeFilter():
        return _parseCompositeFilter(filter);
    }
  }

  _FieldFilterInternal _parseFieldFilter(_UnaryFilter fieldFilterData) {
    final value = fieldFilterData.value;
    final operator = fieldFilterData.op;
    final fieldPath = fieldFilterData.fieldPath;

    _validateQueryValue('value', value);

    if (fieldPath == FieldPath.documentId) {
      switch (operator) {
        case WhereFilter.arrayContains:
        case WhereFilter.arrayContainsAny:
          throw ArgumentError.value(
            operator,
            'op',
            "Invalid query. You can't perform '$operator' queries on FieldPath.documentId().",
          );
        case WhereFilter.isIn:
        case WhereFilter.notIn:
          if (value is! List || value.isEmpty) {
            throw ArgumentError.value(
              value,
              'value',
              "Invalid query. A non-empty array is required for '$operator' filters.",
            );
          }
          for (final item in value) {
            if (item is! DocumentReference) {
              throw ArgumentError.value(
                value,
                'value',
                "Invalid query. When querying with '$operator', "
                    'you must provide a List of non-empty DocumentReference instances as the argument.',
              );
            }
          }
        default:
          if (value is! DocumentReference) {
            throw ArgumentError.value(
              value,
              'value',
              'Invalid query. When querying by document ID you must provide a '
                  'DocumentReference instance.',
            );
          }
      }
    }

    return _FieldFilterInternal(
      serializer: firestore._serializer,
      field: fieldPath,
      op: operator,
      value: value,
    );
  }

  _FilterInternal _parseCompositeFilter(_CompositeFilter compositeFilterData) {
    final parsedFilters = compositeFilterData.filters
        .map(_parseFilter)
        .where((filter) => filter.filters.isNotEmpty)
        .toList();

    // For composite filters containing 1 filter, return the only filter.
    // For example: AND(FieldFilter1) == FieldFilter1
    if (parsedFilters.length == 1) {
      return parsedFilters.single;
    }
    return _CompositeFilterInternal(
      filters: parsedFilters,
      op: compositeFilterData.operator == _CompositeOperator.and
          ? _CompositeOperator.and
          : _CompositeOperator.or,
    );
  }

  /// Creates and returns a new [Query] instance that applies a
  /// field mask to the result and returns only the specified subset of fields.
  /// You can specify a list of field paths to return, or use an empty list to
  /// only return the references of matching documents.
  ///
  /// Queries that contain field masks cannot be listened to via `onSnapshot()`
  /// listeners.
  ///
  /// This function returns a new (immutable) instance of the Query (rather than
  /// modify the existing instance) to impose the field mask.
  ///
  /// - [fieldPaths] The field paths to return.
  ///
  /// ```dart
  /// final collectionRef = firestore.collection('col');
  /// final documentRef = collectionRef.doc('doc');
  ///
  /// return documentRef.set({x:10, y:5}).then(() {
  ///   return collectionRef.where('x', '>', 5).select('y').get();
  /// }).then((res) {
  ///   print('y is ${res.docs[0].get('y')}.');
  /// });
  /// ```
  Query<DocumentData> select([List<FieldPath> fieldPaths = const []]) {
    final fields = <firestore_v1.StructuredQuery_FieldReference>[
      if (fieldPaths.isEmpty)
        firestore_v1.StructuredQuery_FieldReference(
          fieldPath: FieldPath.documentId._formattedName,
        )
      else
        for (final fieldPath in fieldPaths)
          firestore_v1.StructuredQuery_FieldReference(fieldPath: fieldPath._formattedName),
    ];

    return Query<DocumentData>._(
      firestore: firestore,
      queryOptions: _queryOptions
          .copyWith(projection: firestore_v1.StructuredQuery_Projection(fields: fields))
          .withConverter(
            // By specifying a field mask, the query result no longer conforms to type
            // `T`. We there return `Query<DocumentData>`.
            _jsonConverter,
          ),
    );
  }

  /// Creates and returns a new [Query] that's additionally sorted
  /// by the specified field, optionally in descending order instead of
  /// ascending.
  ///
  /// This function returns a new (immutable) instance of the Query (rather than
  /// modify the existing instance) to impose the field mask.
  ///
  /// - [fieldPath]: The field to sort by.
  /// - [descending] (false by default) Whether to obtain documents in descending order.
  ///
  /// ```dart
  /// final query = firestore.collection('col').where('foo', WhereFilter.equal, 42);
  ///
  /// query.orderBy('foo', descending: true).get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Found document at ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  Query<T> orderByFieldPath(FieldPath fieldPath, {bool descending = false}) {
    if (_queryOptions.startAt != null || _queryOptions.endAt != null) {
      throw ArgumentError(
        'Cannot specify an orderBy() constraint after calling '
        'startAt(), startAfter(), endBefore() or endAt().',
      );
    }

    final newOrder = _FieldOrder(
      fieldPath: fieldPath,
      direction: descending ? _Direction.descending : _Direction.ascending,
    );

    final options = _queryOptions.copyWith(
      fieldOrders: [..._queryOptions.fieldOrders, newOrder],
    );
    return Query<T>._(firestore: firestore, queryOptions: options);
  }

  /// Creates and returns a new [Query] that's additionally sorted
  /// by the specified field, optionally in descending order instead of
  /// ascending.
  ///
  /// This function returns a new (immutable) instance of the Query (rather than
  /// modify the existing instance) to impose the field mask.
  ///
  /// - [path]: The field to sort by.
  /// - [descending] (false by default) Whether to obtain documents in descending order.
  ///
  /// ```dart
  /// final query = firestore.collection('col').where('foo', WhereFilter.equal, 42);
  ///
  /// query.orderBy('foo', descending: true).get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Found document at ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  Query<T> orderBy(Object path, {bool descending = false}) {
    return orderByFieldPath(FieldPath.from(path), descending: descending);
  }

  /// Creates and returns a new [Query] that only returns the first matching documents.
  ///
  /// This function returns a new (immutable) instance of the Query (rather than
  /// modify the existing instance) to impose the limit.
  ///
  /// - [limit] The maximum number of items to return.
  ///
  /// ```dart
  /// final query = firestore.collection('col').where('foo', WhereFilter.equal, 42);
  ///
  /// query.limit(1).get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Found document at ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  Query<T> limit(int limit) {
    final options = _queryOptions.copyWith(
      limit: limit,
      limitType: LimitType.first,
    );
    return Query<T>._(firestore: firestore, queryOptions: options);
  }

  /// Creates and returns a new [Query] that only returns the last matching
  /// documents.
  ///
  /// You must specify at least one [orderBy] clause for limitToLast queries,
  /// otherwise an exception will be thrown during execution.
  ///
  /// Results for limitToLast queries cannot be streamed.
  ///
  /// ```dart
  /// final query = firestore.collection('col').where('foo', '>', 42);
  ///
  /// query.limitToLast(1).get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Last matching document is ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  Query<T> limitToLast(int limit) {
    final options = _queryOptions.copyWith(
      limit: limit,
      limitType: LimitType.last,
    );
    return Query<T>._(firestore: firestore, queryOptions: options);
  }

  /// Specifies the offset of the returned results.
  ///
  /// This function returns a new (immutable) instance of the [Query]
  /// (rather than modify the existing instance) to impose the offset.
  ///
  /// - [offset] The offset to apply to the Query results
  ///
  /// ```dart
  /// final query = firestore.collection('col').where('foo', WhereFilter.equal, 42);
  ///
  /// query.limit(10).offset(20).get().then((querySnapshot) {
  ///   querySnapshot.forEach((documentSnapshot) {
  ///     print('Found document at ${documentSnapshot.ref.path}');
  ///   });
  /// });
  /// ```
  Query<T> offset(int offset) {
    final options = _queryOptions.copyWith(offset: offset);
    return Query<T>._(firestore: firestore, queryOptions: options);
  }

  @mustBeOverridden
  @override
  bool operator ==(Object other) {
    return other is Query<T> &&
        runtimeType == other.runtimeType &&
        _queryOptions == other._queryOptions;
  }

  @override
  int get hashCode => Object.hash(runtimeType, _queryOptions);

  /// Returns an [AggregateQuery] that can be used to execute one or more
  /// aggregation queries over the result set of this query.
  ///
  /// ## Limitations
  /// - Aggregation queries are only supported through direct server response
  /// - Cannot be used with real-time listeners or offline queries
  /// - Must complete within 60 seconds or returns DEADLINE_EXCEEDED error
  /// - For sum() and average(), non-numeric values are ignored
  /// - When combining aggregations on different fields, only documents
  ///   containing all those fields are included
  ///
  /// ```dart
  /// firestore.collection('cities').aggregate(
  ///   count(),
  ///   sum('population'),
  ///   average('population'),
  /// ).get().then(
  ///   (res) {
  ///     print(res.count);
  ///     print(res.getSum('population'));
  ///     print(res.getAverage('population'));
  ///   },
  ///   onError: (e) => print('Error completing: $e'),
  /// );
  /// ```
  AggregateQuery aggregate(
    AggregateField aggregateField1, [
    AggregateField? aggregateField2,
    AggregateField? aggregateField3,
  ]) {
    final fields = [aggregateField1, ?aggregateField2, ?aggregateField3];

    return AggregateQuery._(
      query: this,
      aggregations: fields.map((field) => field._toInternal()).toList(),
    );
  }

  /// Returns an [AggregateQuery] that can be used to execute a count
  /// aggregation.
  ///
  /// The returned query, when executed, counts the documents in the result
  /// set of this query without actually downloading the documents.
  ///
  /// ```dart
  /// firestore.collection('cities').count().get().then(
  ///   (res) => print(res.count),
  ///   onError: (e) => print('Error completing: $e'),
  /// );
  /// ```
  AggregateQuery count() {
    return aggregate(AggregateField.count());
  }

  /// Returns an [AggregateQuery] that can be used to execute a sum
  /// aggregation on the specified field.
  ///
  /// The returned query, when executed, calculates the sum of all values
  /// for the specified field across all documents in the result set.
  ///
  /// - [field]: The field to sum across all matching documents. Can be a
  ///   String or a [FieldPath] for nested fields.
  ///
  /// ```dart
  /// firestore.collection('products').sum('price').get().then(
  ///   (res) => print(res.getSum('price')),
  ///   onError: (e) => print('Error completing: $e'),
  /// );
  /// ```
  AggregateQuery sum(Object field) {
    assert(
      field is String || field is FieldPath,
      'field must be a String or FieldPath, got ${field.runtimeType}',
    );
    return aggregate(AggregateField.sum(field));
  }

  /// Returns an [AggregateQuery] that can be used to execute an average
  /// aggregation on the specified field.
  ///
  /// The returned query, when executed, calculates the average of all values
  /// for the specified field across all documents in the result set.
  ///
  /// - [field]: The field to average across all matching documents. Can be a
  ///   String or a [FieldPath] for nested fields.
  ///
  /// ```dart
  /// firestore.collection('products').average('price').get().then(
  ///   (res) => print(res.getAverage('price')),
  ///   onError: (e) => print('Error completing: $e'),
  /// );
  /// ```
  AggregateQuery average(Object field) {
    assert(
      field is String || field is FieldPath,
      'field must be a String or FieldPath, got ${field.runtimeType}',
    );
    return aggregate(AggregateField.average(field));
  }

  /// Returns a query that can perform vector distance (similarity) search.
  ///
  /// The returned query, when executed, performs a distance (similarity) search
  /// on the specified [vectorField] against the given [queryVector] and returns
  /// the top documents that are closest to the [queryVector].
  ///
  /// Only documents whose [vectorField] field is a [VectorValue] of the same
  /// dimension as [queryVector] participate in the query, all other documents
  /// are ignored.
  ///
  /// ```dart
  /// // Returns the closest 10 documents whose Euclidean distance from their
  /// // 'embedding' fields are closest to [41, 42].
  /// final vectorQuery = firestore.collection('documents').findNearest(
  ///   vectorField: 'embedding',
  ///   queryVector: [41.0, 42.0],
  ///   limit: 10,
  ///   distanceMeasure: DistanceMeasure.euclidean,
  ///   distanceResultField: 'distance',  // Optional
  ///   distanceThreshold: 0.5,           // Optional
  /// );
  ///
  /// final querySnapshot = await vectorQuery.get();
  /// querySnapshot.forEach((doc) {
  ///   print('Found ${doc.id} with distance ${doc.get('distance')}');
  /// });
  /// ```
  VectorQuery<T> findNearest({
    required Object vectorField,
    required Object queryVector,
    required int limit,
    required DistanceMeasure distanceMeasure,
    Object? distanceResultField,
    double? distanceThreshold,
  }) {
    // Validate vectorField
    if (vectorField is! String && vectorField is! FieldPath) {
      throw ArgumentError.value(
        vectorField,
        'vectorField',
        'must be a String or FieldPath',
      );
    }

    // Validate queryVector
    if (queryVector is! VectorValue && queryVector is! List<double>) {
      throw ArgumentError.value(
        queryVector,
        'queryVector',
        'must be a VectorValue or List<double>',
      );
    }

    // Validate limit
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be a positive number');
    }

    if (limit > 1000) {
      throw ArgumentError.value(limit, 'limit', 'must be at most 1000');
    }

    // Validate queryVector is not empty
    final vectorValues = queryVector is VectorValue
        ? queryVector.toArray()
        : queryVector as List<double>;
    if (vectorValues.isEmpty) {
      throw ArgumentError.value(
        queryVector,
        'queryVector',
        'vector size must be larger than 0',
      );
    }

    // Validate distanceResultField
    if (distanceResultField != null &&
        distanceResultField is! String &&
        distanceResultField is! FieldPath) {
      throw ArgumentError.value(
        distanceResultField,
        'distanceResultField',
        'must be a String or FieldPath',
      );
    }

    final options = VectorQueryOptions(
      vectorField: vectorField,
      queryVector: queryVector,
      limit: limit,
      distanceMeasure: distanceMeasure,
      distanceResultField: distanceResultField,
      distanceThreshold: distanceThreshold,
    );

    return VectorQuery<T>._(query: this, options: options);
  }
}
