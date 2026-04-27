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

part of 'firestore.dart';

class ReadOptions {
  ReadOptions({this.fieldMask});

  /// Specifies the set of fields to return and reduces the amount of data
  /// transmitted by the backend.
  ///
  /// Adding a field mask does not filter results. Documents do not need to
  /// contain values for all the fields in the mask to be part of the result
  /// set.
  final List<FieldMask>? fieldMask;
}

List<FieldPath>? _parseFieldMask(ReadOptions? readOptions) {
  return readOptions?.fieldMask?.map(FieldPath.fromArgument).toList();
}

class _TransactionResult<T> {
  _TransactionResult({this.transaction, required this.result});

  final String? transaction;
  final T result;
}

/// A reference to a transaction.
///
/// The Transaction object passed to a transaction's updateFunction provides
/// the methods to read and write data within the transaction context. See
/// [Firestore.runTransaction].
class Transaction {
  Transaction(Firestore firestore, TransactionOptions? transactionOptions) {
    _firestore = firestore;

    _maxAttempts =
        transactionOptions?.maxAttempts ?? defaultMaxTransactionsAttempts;

    switch (transactionOptions) {
      case ReadOnlyTransactionOptions():
        _readOnlyReadTime = transactionOptions.readTime;
        _writeBatch = null;
      default:
        _writeBatch = WriteBatch._(_firestore);
        _backoff = ExponentialBackoff();
    }
  }

  static const int defaultMaxTransactionsAttempts = 5;

  //Error message for transactional reads that were executed after performing writes.
  static const String readAfterWriteErrorMsg =
      'Firestore transactions require all reads to be executed before all writes.';

  static const String readOnlyWriteErrorMsg =
      'Firestore read-only transactions cannot execute writes.';

  late final Firestore _firestore;

  late final int _maxAttempts;

  /// Optional, could be set only if transaction is read only
  Timestamp? _readOnlyReadTime;

  /// `null` if transaction is read only
  late final WriteBatch? _writeBatch;

  /// `null` if transaction is read only
  late final ExponentialBackoff _backoff;

  /// Future that resolves to the transaction ID of the current attempt.
  /// It is lazily initialised upon the first read. Upon retry, it is reset and
  /// [_prevTransactionId] is set
  Future<String>? _transactionIdPromise;
  String? _prevTransactionId;

  /// Retrieves a single document from the database. Holds a pessimistic lock on
  /// the returned document.
  ///
  /// - [docRef]: A reference to the document to retrieve.
  ///
  /// Returns a [DocumentSnapshot] containing the retrieved document.
  ///
  /// Throws a [FirestoreException] with [FirestoreClientErrorCode.notFound] status if no document exists at the
  /// provided [docRef].
  ///
  Future<DocumentSnapshot<T>> get<T>(DocumentReference<T> docRef) async {
    if (_writeBatch != null && _writeBatch._operations.isNotEmpty) {
      throw FirestoreException(
        FirestoreClientErrorCode.failedPrecondition,
        readAfterWriteErrorMsg,
      );
    }
    return _withLazyStartedTransaction<
      DocumentReference<T>,
      DocumentSnapshot<T>
    >(docRef, resultFn: _getSingleFn);
  }

  /// Executes a query and returns the results. Holds a pessimistic lock on
  /// all documents in the result set.
  ///
  /// - [query]: The query to execute.
  ///
  /// Returns a [QuerySnapshot] containing the query results.
  ///
  /// All documents matched by the query will be locked for the duration of
  /// the transaction. The query is executed at a consistent snapshot, ensuring
  /// that all reads see the same data.
  ///
  /// ```dart
  /// firestore.runTransaction((transaction) async {
  ///   final query = firestore.collection('users')
  ///       .where('active', WhereFilter.equal, true)
  ///       .limit(100);
  ///
  ///   final snapshot = await transaction.getQuery(query);
  ///
  ///   for (final doc in snapshot.docs) {
  ///     transaction.update(doc.ref, {'processed': true});
  ///   }
  /// });
  /// ```
  Future<QuerySnapshot<T>> getQuery<T>(Query<T> query) async {
    if (_writeBatch != null && _writeBatch._operations.isNotEmpty) {
      throw FirestoreException(
        FirestoreClientErrorCode.failedPrecondition,
        readAfterWriteErrorMsg,
      );
    }
    return _withLazyStartedTransaction<Query<T>, QuerySnapshot<T>>(
      query,
      resultFn: _getQueryFn,
    );
  }

  /// Executes an aggregation query and returns the results as part of this
  /// transaction. The aggregation is executed at the transaction's snapshot.
  ///
  /// ```dart
  /// firestore.runTransaction((transaction) async {
  ///   final query = firestore.collection('products')
  ///       .where('category', WhereFilter.equal, 'electronics');
  ///
  ///   final aggregation = query.aggregate(
  ///     const count(),
  ///     const sum('price'),
  ///     const average('price'),
  ///   );
  ///
  ///   final snapshot = await transaction.getAggregateQuery(aggregation);
  ///
  ///   print('Total products: ${snapshot.count}');
  ///   print('Total value: \$${snapshot.getSum('price')}');
  ///   print('Average price: \$${snapshot.getAverage('price')}');
  /// });
  /// ```
  Future<AggregateQuerySnapshot> getAggregateQuery(
    AggregateQuery aggregateQuery,
  ) async {
    if (_writeBatch != null && _writeBatch._operations.isNotEmpty) {
      throw FirestoreException(
        FirestoreClientErrorCode.failedPrecondition,
        readAfterWriteErrorMsg,
      );
    }
    return _withLazyStartedTransaction<AggregateQuery, AggregateQuerySnapshot>(
      aggregateQuery,
      resultFn: _getAggregateQueryFn,
    );
  }

  /// Retrieve multiple documents from the database by the provided
  /// [documentsRefs]. Holds a pessimistic lock on all returned documents.
  /// If any of the documents do not exist, the operation throws a
  /// [FirestoreException] with [FirestoreClientErrorCode.notFound].
  ///
  /// - [documentsRefs] A list of references to the documents to retrieve.
  /// - [fieldMasks] A list of field masks, one for each document.
  ///
  /// Returns a list of [DocumentSnapshot] containing the retrieved documents in
  /// the same order as the provided [documentsRefs].
  Future<List<DocumentSnapshot<T>>> getAll<T>(
    List<DocumentReference<T>> documentsRefs, {
    List<FieldPath>? fieldMasks,
  }) async {
    if (_writeBatch != null && _writeBatch._operations.isNotEmpty) {
      throw FirestoreException(
        FirestoreClientErrorCode.failedPrecondition,
        readAfterWriteErrorMsg,
      );
    }
    return _withLazyStartedTransaction<
      List<DocumentReference<T>>,
      List<DocumentSnapshot<T>>
    >(documentsRefs, fieldMask: fieldMasks, resultFn: _getBatchFn<T>);
  }

  /// Create the document referred to by the provided
  /// [DocumentReference]. The operation will
  /// fail the transaction if a document exists at the specified location.
  ///
  /// [documentData] data The object data to serialize as the document.
  ///
  void create<T>(DocumentReference<T> documentRef, T documentData) {
    if (_writeBatch == null) {
      throw FirestoreException(
        FirestoreClientErrorCode.failedPrecondition,
        readOnlyWriteErrorMsg,
      );
    }
    _writeBatch.create(documentRef, documentData);
  }

  /// Write to the document referred to by the provided
  /// [DocumentReference]. If the document does not exist yet, it will be
  /// created. If the document already exists, its contents will be
  /// overwritten with the newly provided data unless [SetOptions] is provided
  /// to merge the data.
  ///
  /// - [documentRef]: A reference to the document to be set.
  /// - [data] The object to serialize as the document.
  /// - [options] Optional [SetOptions] to control merge behavior.
  ///
  void set<T>(DocumentReference<T> documentRef, T data, {SetOptions? options}) {
    if (_writeBatch == null) {
      throw FirestoreException(
        FirestoreClientErrorCode.failedPrecondition,
        readOnlyWriteErrorMsg,
      );
    }
    _writeBatch.set<T>(documentRef, data, options: options);
  }

  /// Updates fields in the document referred to by the provided
  /// [DocumentReference]. If the document doesn't yet exist, the update fails
  /// and returns [FirestoreClientErrorCode.notFound].
  ///
  /// The update() method accepts either an object with field paths encoded as
  /// keys and field values encoded as values, or a variable number of arguments
  /// that alternate between field paths and field values.
  ///
  /// A [Precondition] restricting this update.
  ///
  void update(
    DocumentReference<dynamic> documentRef,
    Map<Object?, Object?> data, {
    Precondition? precondition,
  }) {
    if (_writeBatch == null) {
      throw FirestoreException(
        FirestoreClientErrorCode.failedPrecondition,
        readOnlyWriteErrorMsg,
      );
    }

    _writeBatch.update(documentRef, {
      for (final entry in data.entries) FieldPath.from(entry.key): entry.value,
    }, precondition: precondition);
  }

  /// Deletes the document referred to by this [DocumentReference].
  ///
  /// A delete for a non-existing document is treated as a success (unless
  /// [precondition] is specified, in which case it throws a [FirestoreException] with [FirestoreClientErrorCode.notFound]).
  void delete(
    DocumentReference<Map<String, dynamic>> documentRef, {
    Precondition? precondition,
  }) {
    if (_writeBatch == null) {
      throw FirestoreException(
        FirestoreClientErrorCode.failedPrecondition,
        readOnlyWriteErrorMsg,
      );
    }
    _writeBatch.delete(documentRef, precondition: precondition);
  }

  Future<void> _commit() async {
    if (_writeBatch == null) {
      throw FirestoreException(
        FirestoreClientErrorCode.failedPrecondition,
        readOnlyWriteErrorMsg,
      );
    }

    String? transactionId;
    // If we have not performed any reads in this particular attempt
    // then the writes will be atomically committed without a transaction ID
    if (_transactionIdPromise != null) {
      transactionId = await _transactionIdPromise;
    } else if (_writeBatch._operations.isEmpty) {
      // If we have not started a transaction (no reads) and we have no writes
      // then the commit is a no-op (success)
      return;
    }
    await _writeBatch._commit(transactionId: transactionId);

    _transactionIdPromise = null;
    _prevTransactionId = transactionId;
  }

  Future<void> _rollback() async {
    // No need to roll back if we have not lazily started the transaction
    // or if we are read only
    if (_transactionIdPromise == null || _writeBatch == null) {
      return;
    }

    String? transactionId;

    try {
      transactionId = await _transactionIdPromise;
    } catch (e) {
      // This means the initial read operation rejected
      // and we do not have a transaction ID to roll back
      _transactionIdPromise = null;
      return;
    }

    _transactionIdPromise = null;
    _prevTransactionId = transactionId;

    // We don't need to wait for rollback to completed before continuing.
    // If there are any locks held, then rollback will eventually release them.
    // Rollback can be done concurrently thereby reducing latency caused by
    // otherwise blocking.
    return _firestore._firestoreClient.v1((api, projectId) {
      final rollBackRequest = firestore_v1.RollbackRequest(
        database: _firestore._formattedDatabaseName,
        transaction: base64Decode(transactionId!),
      );
      return api.rollback(rollBackRequest);
    });
  }

  /// Given a function that performs a read operation, ensures that the first one
  /// is provided with new transaction options and all subsequent ones are queued
  /// upon the resulting transaction ID.
  Future<TResult> _withLazyStartedTransaction<T, TResult>(
    T docRef, {
    List<FieldPath>? fieldMask,
    required Future<_TransactionResult<TResult>> Function(
      T docRef, {
      String? transactionId,
      Timestamp? readTime,
      firestore_v1.TransactionOptions? transactionOptions,
      List<FieldPath>? fieldMask,
    })
    resultFn,
  }) {
    if (_transactionIdPromise != null) {
      // Simply queue this subsequent read operation after the first read
      // operation has resolved and we don't expect a transaction ID in the
      // response because we are not starting a new transaction
      return _transactionIdPromise!
          .then(
            (transactionId) => resultFn(
              docRef,
              transactionId: transactionId,
              fieldMask: fieldMask,
            ),
          )
          .then((r) => r.result);
    } else {
      if (_readOnlyReadTime != null) {
        // We do not start a transaction for read-only transactions
        // do not set _prevTransactionId
        return resultFn(
          docRef,
          readTime: _readOnlyReadTime,
          fieldMask: fieldMask,
        ).then((r) => r.result);
      } else {
        // This is the first read of the transaction so we create the appropriate
        // options for lazily starting the transaction inside this first read op
        final firestore_v1.TransactionOptions opts;
        if (_writeBatch != null) {
          opts = firestore_v1.TransactionOptions(
            readWrite:
                _prevTransactionId == null
                    ? firestore_v1.TransactionOptions_ReadWrite()
                    : firestore_v1.TransactionOptions_ReadWrite(
                      retryTransaction: base64Decode(_prevTransactionId!),
                    ),
          );
        } else {
          opts = firestore_v1.TransactionOptions(
            readOnly: firestore_v1.TransactionOptions_ReadOnly(),
          );
        }

        final resultPromise = resultFn(
          docRef,
          transactionOptions: opts,
          fieldMask: fieldMask,
        );

        // Ensure the _transactionIdPromise is set synchronously so that
        // subsequent operations will not race to start another transaction
        _transactionIdPromise = resultPromise.then((r) {
          if (r.transaction case final transaction?) {
            return transaction;
          } else {
            // Illegal state
            // The read operation was provided with new transaction options but did not return a transaction ID
            // Rejecting here will cause all queued reads to reject
            throw FirestoreException(
              FirestoreClientErrorCode.internal,
              'Transaction ID was missing from server response.',
            );
          }
        });

        return resultPromise.then((r) {
          return r.result;
        });
      }
    }
  }

  Future<_TransactionResult<DocumentSnapshot<T>>> _getSingleFn<T>(
    DocumentReference<T> docRef, {
    String? transactionId,
    Timestamp? readTime,
    firestore_v1.TransactionOptions? transactionOptions,
    List<FieldPath>? fieldMask,
  }) async {
    final reader = _DocumentReader(
      firestore: _firestore,
      documents: [docRef],
      fieldMask: fieldMask,
      transactionId: transactionId,
      readTime: readTime,
      transactionOptions: transactionOptions,
    );
    final result = await reader._get();
    return _TransactionResult(
      transaction: result.transaction,
      result: result.result.single,
    );
  }

  Future<_TransactionResult<List<DocumentSnapshot<T>>>> _getBatchFn<T>(
    List<DocumentReference<T>> docsdocumentRefs, {
    String? transactionId,
    Timestamp? readTime,
    firestore_v1.TransactionOptions? transactionOptions,
    List<FieldPath>? fieldMask,
  }) async {
    final reader = _DocumentReader(
      firestore: _firestore,
      documents: docsdocumentRefs,
      fieldMask: fieldMask,
      transactionId: transactionId,
      readTime: readTime,
      transactionOptions: transactionOptions,
    );

    final result = await reader._get();
    return _TransactionResult(
      transaction: result.transaction,
      result: result.result,
    );
  }

  Future<_TransactionResult<QuerySnapshot<T>>> _getQueryFn<T>(
    Query<T> query, {
    String? transactionId,
    Timestamp? readTime,
    firestore_v1.TransactionOptions? transactionOptions,
    List<FieldPath>? fieldMask,
  }) async {
    final reader = _QueryReader(
      query: query,
      transactionId: transactionId,
      readTime: readTime,
      transactionOptions: transactionOptions,
    );

    final result = await reader._get();
    return _TransactionResult(
      transaction: result.transaction,
      result: result.result,
    );
  }

  Future<_TransactionResult<AggregateQuerySnapshot>> _getAggregateQueryFn(
    AggregateQuery aggregateQuery, {
    String? transactionId,
    Timestamp? readTime,
    firestore_v1.TransactionOptions? transactionOptions,
    List<FieldPath>?
    fieldMask, // Unused for aggregations, but required by signature
  }) async {
    final reader = _AggregationReader(
      aggregateQuery: aggregateQuery,
      transactionId: transactionId,
      readTime: readTime,
      transactionOptions: transactionOptions,
    );

    final result = await reader._get();
    return _TransactionResult(
      transaction: result.transaction,
      result: result.result,
    );
  }

  Future<T> _runTransaction<T>(TransactionHandler<T> updateFunction) async {
    // No backoff is set for readonly transactions (i.e. attempts == 1)
    if (_writeBatch == null) {
      return _runTransactionOnce(updateFunction);
    }
    FirestoreException? lastError;

    for (var attempts = 0; attempts < _maxAttempts; attempts++) {
      try {
        _writeBatch.reset();
        await _maybeBackoff(_backoff, lastError);

        return await _runTransactionOnce(updateFunction);
      } on FirestoreException catch (e) {
        lastError = e;

        if (!_isRetryableTransactionError(e)) {
          rethrow;
        }
      }
    }

    throw FirestoreException(
      FirestoreClientErrorCode.aborted,
      'Transaction max attempts exceeded',
    );
  }

  Future<T> _runTransactionOnce<T>(TransactionHandler<T> updateFunction) async {
    try {
      final result = await updateFunction(this);
      //If we are on a readWrite transaction, commit
      if (_writeBatch != null) {
        await _commit();
      }
      return result;
    } catch (e) {
      await _rollback();
      rethrow;
    }
  }
}

/// The [TransactionHandler] may be executed multiple times; it should be able
/// to handle multiple executions.
typedef TransactionHandler<T> = Future<T> Function(Transaction transaction);

/// Delays further operations based on the provided error.
Future<void> _maybeBackoff(
  ExponentialBackoff backoff, [
  FirestoreException? error,
]) async {
  if (error?.errorCode.statusCode == StatusCode.resourceExhausted) {
    backoff.resetToMax();
  }
  await backoff.backoffAndWait();
}

bool _isRetryableTransactionError(FirestoreException error) {
  switch (error.errorCode.statusCode) {
    case StatusCode.aborted:
    case StatusCode.cancelled:
    case StatusCode.unknown:
    case StatusCode.deadlineExceeded:
    case StatusCode.internal:
    case StatusCode.unavailable:
    case StatusCode.unauthenticated:
    case StatusCode.resourceExhausted:
      return true;
    case StatusCode.invalidArgument:
      // The Firestore backend uses "INVALID_ARGUMENT" for transactions
      // IDs that have expired. While INVALID_ARGUMENT is generally not
      // retryable, we retry this specific case.
      return error.message.toLowerCase().contains('transaction has expired');
    default:
      return false;
  }
}
