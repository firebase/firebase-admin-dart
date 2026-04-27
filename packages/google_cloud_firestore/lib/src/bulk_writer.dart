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

/// The maximum number of writes that can be in a single batch.
const int _kMaxBatchSize = 20;

/// The maximum number of writes that can be in a batch being retried.
const int _kRetryMaxBatchSize = 10;

/// The starting maximum number of operations per second as allowed by the
/// 500/50/5 rule.
const int _defaultInitialOpsPerSecondLimit = 500;

/// The maximum number of operations per second as allowed by the 500/50/5 rule.
const int _defaultMaximumOpsPerSecondLimit = 10000;

/// The default jitter factor for exponential backoff.
const double _defaultJitterFactor = 0.3;

/// The rate by which to increase the capacity as specified by the 500/50/5 rule.
const double _rateLimiterMultiplier = 1.5;

/// How often the operations per second capacity should increase in milliseconds
/// as specified by the 500/50/5 rule.
const int _rateLimiterMultiplierMillis = 5 * 60 * 1000;

/// The default maximum number of pending operations that can be enqueued onto a
/// BulkWriter instance.
const int _defaultMaximumPendingOperationsCount = 500;

/// Options to configure BulkWriter behavior.
class BulkWriterOptions {
  const BulkWriterOptions({this.throttling = const EnabledThrottling()});

  /// Throttling configuration for rate limiting.
  ///
  /// Defaults to [EnabledThrottling] with 500 initial ops/sec and 10,000 max.
  /// Use [DisabledThrottling] to disable throttling entirely.
  final BulkWriterThrottling throttling;
}

/// Base class for throttling configuration.
sealed class BulkWriterThrottling {
  const BulkWriterThrottling();
}

/// Throttling is enabled with configurable rate limits.
class EnabledThrottling extends BulkWriterThrottling {
  const EnabledThrottling({
    this.initialOpsPerSecond = _defaultInitialOpsPerSecondLimit,
    this.maxOpsPerSecond = _defaultMaximumOpsPerSecondLimit,
  });

  /// Initial number of operations per second.
  final int initialOpsPerSecond;

  /// Maximum number of operations per second.
  final int maxOpsPerSecond;
}

/// Throttling is completely disabled (unlimited ops/sec).
class DisabledThrottling extends BulkWriterThrottling {
  const DisabledThrottling();
}

/// The error thrown when a BulkWriter operation fails.
@immutable
class BulkWriterError implements Exception {
  const BulkWriterError({
    required this.code,
    required this.message,
    required this.documentRef,
    required this.operationType,
    required this.failedAttempts,
  });

  /// The error code of the error.
  final FirestoreClientErrorCode code;

  /// The error message.
  final String message;

  /// The document reference the operation was performed on.
  final DocumentReference<Object?> documentRef;

  /// The type of operation performed.
  final String operationType;

  /// How many times this operation has been attempted unsuccessfully.
  final int failedAttempts;

  @override
  String toString() {
    return 'BulkWriterError: $message (code: $code, operation: $operationType, '
        'document: ${documentRef.path}, attempts: $failedAttempts)';
  }
}

/// Represents a single write operation for BulkWriter.
class _BulkWriterOperation {
  _BulkWriterOperation({
    required this.ref,
    required this.operationType,
    required this.completer,
    required this.sendFn,
    required this.errorCallback,
    required this.successCallback,
  });

  final DocumentReference<Object?> ref;
  final String operationType;
  final Completer<WriteResult> completer;
  final void Function(_BulkWriterOperation) sendFn;
  final bool Function(BulkWriterError) errorCallback;
  final void Function(DocumentReference<Object?>, WriteResult) successCallback;

  int failedAttempts = 0;
  FirestoreClientErrorCode? lastErrorCode;
  int backoffDuration = 0;

  /// Whether flush() was called when this was the last enqueued operation.
  bool flushed = false;

  void markFlushed() {
    flushed = true;
  }

  /// Called when the operation succeeds.
  void onSuccess(WriteResult result) {
    if (!completer.isCompleted) {
      try {
        successCallback(ref, result);
        completer.complete(result);
      } catch (error) {
        completer.completeError(error);
      }
    }
  }

  /// Called when the operation fails. Returns true if the operation should be
  /// retried.
  bool onError(Exception error, {FirestoreClientErrorCode? code}) {
    failedAttempts++;
    lastErrorCode = code;

    if (completer.isCompleted) {
      return false;
    }

    final bulkWriterError = BulkWriterError(
      code: code ?? FirestoreClientErrorCode.unknown,
      message: error.toString(),
      documentRef: ref,
      operationType: operationType,
      failedAttempts: failedAttempts,
    );

    try {
      final shouldRetry = errorCallback(bulkWriterError);
      if (shouldRetry) {
        _updateBackoffDuration();
      } else {
        completer.completeError(bulkWriterError);
      }
      return shouldRetry;
    } catch (callbackError) {
      // If the error callback throws, complete with that error
      completer.completeError(callbackError);
      return false;
    }
  }

  /// Updates the backoff duration based on the last error.
  void _updateBackoffDuration() {
    if (lastErrorCode == FirestoreClientErrorCode.resourceExhausted) {
      backoffDuration = ExponentialBackoff.defaultBackOffMaxDelayMs;
    } else if (backoffDuration == 0) {
      backoffDuration = ExponentialBackoff.defaultBackOffInitialDelayMs;
    } else {
      backoffDuration =
          (backoffDuration * ExponentialBackoff.defaultBackOffFactor).toInt();
    }
  }
}

/// A batch used by BulkWriter for committing operations.
class _BulkCommitBatch extends WriteBatch {
  _BulkCommitBatch(super.firestore, this._maxBatchSize) : super._();

  int _maxBatchSize;
  final Set<String> _docPaths = {};
  final List<_BulkWriterOperation> pendingOps = [];

  /// Gets the current maximum batch size.
  int get maxBatchSize => _maxBatchSize;

  /// Checks if this batch contains a write to the given document.
  bool has(DocumentReference<Object?> documentRef) {
    return _docPaths.contains(documentRef.path);
  }

  /// Returns true if the batch is full.
  bool get isFull => pendingOps.length >= _maxBatchSize;

  /// Adds an operation to this batch.
  void processOperation(_BulkWriterOperation op) {
    assert(
      !_docPaths.contains(op.ref.path),
      'Batch should not contain writes to the same document',
    );
    _docPaths.add(op.ref.path);
    pendingOps.add(op);
  }

  /// Dynamically sets the maximum batch size for this batch.
  /// Used to limit retry batches to a smaller size.
  void setMaxBatchSize(int size) {
    assert(
      pendingOps.length <= size,
      'New batch size cannot be less than the number of enqueued writes',
    );
    _maxBatchSize = size;
  }

  /// Commits this batch using batchWrite API and handles individual results.
  Future<void> bulkCommit() async {
    if (pendingOps.isEmpty) return;

    try {
      // Use batchWrite API instead of commit to get individual operation statuses
      final response = await firestore._firestoreClient.v1((
        api,
        projectId,
      ) async {
        final request = firestore_v1.BatchWriteRequest(
          database: firestore._formattedDatabaseName,
          writes: _operations.map((op) => op.op()).toList(),
        );

        return api.batchWrite(request);
      });

      // Process each operation individually based on its status
      for (var i = 0; i < pendingOps.length; i++) {
        final status = (i < response.status.length) ? response.status[i] : null;

        // Status code 0 means OK/success
        if (status == null || status.code == 0) {
          // Operation succeeded
          final updateTime =
              (i < response.writeResults.length &&
                      response.writeResults[i].updateTime != null)
                  ? Timestamp._fromProto(response.writeResults[i].updateTime!)
                  : Timestamp.now();

          pendingOps[i].onSuccess(WriteResult._(updateTime));
        } else {
          // Operation failed - create exception with status details
          final errorMessage = status.message;
          final errorCode = FirestoreClientErrorCode.fromStatusCode(
            status.code,
          );
          final exception = FirestoreException(errorCode, errorMessage);

          final shouldRetry = pendingOps[i].onError(exception, code: errorCode);

          if (shouldRetry) {
            pendingOps[i].sendFn(pendingOps[i]);
          }
        }
      }
    } catch (error) {
      // If the entire batch HTTP call fails, all operations fail with same error
      FirestoreClientErrorCode? errorCode;

      if (error is FirestoreException) {
        errorCode = error.errorCode;
      }

      // Process each operation in the failed batch
      for (final op in pendingOps) {
        final exception = error is Exception
            ? error
            : Exception(error.toString());
        final shouldRetry = op.onError(exception, code: errorCode);

        if (shouldRetry) {
          op.sendFn(op);
        }
      }
    }
  }
}

/// Used to represent a buffered BulkWriter operation.
class _BufferedOperation {
  _BufferedOperation(this.operation, this.sendFn);

  final _BulkWriterOperation operation;
  final void Function() sendFn;
}

/// A Firestore BulkWriter that can be used to perform a large number of writes
/// in parallel.
///
/// BulkWriter automatically batches writes (maximum 20 operations per batch),
/// sends them in parallel, and includes automatic retry logic for transient
/// failures. Each write operation returns its own Future that resolves when
/// that specific write completes.
///
/// Example:
/// ```dart
/// final bulkWriter = firestore.bulkWriter();
///
/// // Set up error handling
/// bulkWriter.onWriteError((error) {
///   if (error.code == FirestoreClientErrorCode.unavailable &&
///       error.failedAttempts < 5) {
///     return true; // Retry
///   }
///   print('Failed write: ${error.documentRef.path}');
///   return false; // Don't retry
/// });
///
/// // Each write returns its own Future
/// final future1 = bulkWriter.set(
///   firestore.collection('cities').doc('SF'),
///   {'name': 'San Francisco'},
/// );
/// final future2 = bulkWriter.set(
///   firestore.collection('cities').doc('LA'),
///   {'name': 'Los Angeles'},
/// );
///
/// // Wait for all writes to complete
/// await bulkWriter.close();
/// ```
class BulkWriter {
  BulkWriter._(this.firestore, BulkWriterOptions? options) {
    // Configure rate limiting based on throttling settings
    final throttling = options?.throttling ?? const EnabledThrottling();

    final int initialOpsPerSecond;
    final int maxOpsPerSecond;

    switch (throttling) {
      case DisabledThrottling():
        // Throttling disabled - unlimited ops/sec
        initialOpsPerSecond = double.maxFinite.toInt();
        maxOpsPerSecond = double.maxFinite.toInt();

      case EnabledThrottling():
        // Validate throttling parameters
        if (throttling.initialOpsPerSecond < 1) {
          throw ArgumentError(
            'Value for argument "initialOpsPerSecond" must be within [1, Infinity] inclusive, '
            'but was: ${throttling.initialOpsPerSecond}',
          );
        }

        if (throttling.maxOpsPerSecond < 1) {
          throw ArgumentError(
            'Value for argument "maxOpsPerSecond" must be within [1, Infinity] inclusive, '
            'but was: ${throttling.maxOpsPerSecond}',
          );
        }

        if (throttling.maxOpsPerSecond < throttling.initialOpsPerSecond) {
          throw ArgumentError(
            '"maxOpsPerSecond" cannot be less than "initialOpsPerSecond".',
          );
        }

        initialOpsPerSecond = throttling.initialOpsPerSecond;
        maxOpsPerSecond = throttling.maxOpsPerSecond;
    }

    // Ensure batch size doesn't exceed rate limit
    if (initialOpsPerSecond < _maxBatchSize) {
      _maxBatchSize = initialOpsPerSecond;
    }

    _rateLimiter = RateLimiter(
      initialOpsPerSecond,
      _rateLimiterMultiplier,
      _rateLimiterMultiplierMillis,
      maxOpsPerSecond,
    );
  }

  /// The Firestore instance this BulkWriter is associated with.
  final Firestore firestore;

  /// Rate limiter for throttling operations.
  late final RateLimiter _rateLimiter;

  /// The maximum number of writes that can be in a single batch.
  /// Visible for testing.
  int _maxBatchSize = _kMaxBatchSize;

  /// The batch currently being filled with operations.
  late _BulkCommitBatch _bulkCommitBatch = _BulkCommitBatch(
    firestore,
    _maxBatchSize,
  );

  /// Represents the tail of all active BulkWriter operations.
  Future<void> _lastOperation = Future.value();

  /// Future that is set when close() is called.
  Future<void>? _closeFuture;

  /// The number of pending operations enqueued on this BulkWriter instance.
  int _pendingOpsCount = 0;

  /// Buffer for operations when max pending ops is reached.
  final List<_BufferedOperation> _bufferedOperations = [];

  /// Maximum number of pending operations before buffering.
  int _maxPendingOpCount = _defaultMaximumPendingOperationsCount;

  /// User-provided success callback.
  void Function(DocumentReference<Object?>, WriteResult) _successCallback =
      (_, _) {};

  /// User-provided error callback. Returns true to retry, false otherwise.
  bool Function(BulkWriterError) _errorCallback = _defaultErrorCallback;

  /// Default error callback that retries UNAVAILABLE and ABORTED up to 10 times.
  /// Also retries INTERNAL errors for delete operations.
  static bool _defaultErrorCallback(BulkWriterError error) {
    // Delete operations with INTERNAL errors should be retried.
    final isRetryableDeleteError =
        error.operationType == 'delete' &&
        error.code == FirestoreClientErrorCode.internal;

    final retryableCodes = [
      FirestoreClientErrorCode.aborted,
      FirestoreClientErrorCode.unavailable,
    ];

    return (retryableCodes.contains(error.code) || isRetryableDeleteError) &&
        error.failedAttempts < ExponentialBackoff.maxRetryAttempts;
  }

  /// Attaches a listener that is run every time a BulkWriter operation
  /// successfully completes.
  ///
  /// Example:
  /// ```dart
  /// bulkWriter.onWriteResult((ref, result) {
  ///   print('Successfully wrote to ${ref.path}');
  /// });
  /// ```
  void onWriteResult(
    void Function(DocumentReference<Object?>, WriteResult) callback,
  ) {
    _successCallback = callback;
  }

  /// Attaches an error handler listener that is run every time a BulkWriter
  /// operation fails.
  ///
  /// BulkWriter has a default error handler that retries UNAVAILABLE and
  /// ABORTED errors up to a maximum of 10 failed attempts. When an error
  /// handler is specified, the default error handler will be overwritten.
  ///
  /// The callback should return `true` to retry the operation, or `false` to
  /// stop retrying.
  ///
  /// Example:
  /// ```dart
  /// bulkWriter.onWriteError((error) {
  ///   if (error.code == FirestoreClientErrorCode.unavailable &&
  ///       error.failedAttempts < 5) {
  ///     return true; // Retry
  ///   }
  ///   print('Failed write: ${error.documentRef.path}');
  ///   return false; // Don't retry
  /// });
  /// ```
  void onWriteError(bool Function(BulkWriterError) callback) {
    _errorCallback = callback;
  }

  /// Create a document with the provided data. This will fail if a document
  /// exists at its location.
  ///
  /// - [ref]: A reference to the document to be created.
  /// - [data]: The object to serialize as the document.
  ///
  /// Returns a Future that resolves with the result of the write. If the write
  /// fails, the Future is rejected with a [BulkWriterError].
  ///
  /// Example:
  /// ```dart
  /// final bulkWriter = firestore.bulkWriter();
  /// final documentRef = firestore.collection('col').doc();
  ///
  /// bulkWriter
  ///   .create(documentRef, {'foo': 'bar'})
  ///   .then((result) {
  ///     print('Successfully executed write at: $result');
  ///   })
  ///   .catchError((err) {
  ///     print('Write failed with: $err');
  ///   });
  /// ```
  Future<WriteResult> create<T>(DocumentReference<T> ref, T data) {
    _verifyNotClosed();
    return _enqueue(ref, 'create', (batch) => batch.create(ref, data));
  }

  /// Delete a document from the database.
  ///
  /// - [ref]: A reference to the document to be deleted.
  /// - [precondition]: A precondition to enforce for this delete.
  ///
  /// Returns a Future that resolves with the result of the delete. If the
  /// delete fails, the Future is rejected with a [BulkWriterError].
  ///
  /// Example:
  /// ```dart
  /// final bulkWriter = firestore.bulkWriter();
  /// final documentRef = firestore.doc('col/doc');
  ///
  /// bulkWriter
  ///   .delete(documentRef)
  ///   .then((result) {
  ///     print('Successfully deleted document');
  ///   })
  ///   .catchError((err) {
  ///     print('Delete failed with: $err');
  ///   });
  /// ```
  Future<WriteResult> delete(
    DocumentReference<Object?> ref, {
    Precondition? precondition,
  }) {
    _verifyNotClosed();
    return _enqueue(
      ref,
      'delete',
      (batch) => batch.delete(ref, precondition: precondition),
    );
  }

  /// Write to the document referred to by the provided [DocumentReference].
  /// If the document does not exist yet, it will be created.
  ///
  /// - [ref]: A reference to the document to be set.
  /// - [data]: The object to serialize as the document.
  ///
  /// Returns a Future that resolves with the result of the write. If the write
  /// fails, the Future is rejected with a [BulkWriterError].
  ///
  /// Example:
  /// ```dart
  /// final bulkWriter = firestore.bulkWriter();
  /// final documentRef = firestore.collection('col').doc();
  ///
  /// bulkWriter
  ///   .set(documentRef, {'foo': 'bar'})
  ///   .then((result) {
  ///     print('Successfully executed write at: $result');
  ///   })
  ///   .catchError((err) {
  ///     print('Write failed with: $err');
  ///   });
  /// ```
  Future<WriteResult> set<T>(
    DocumentReference<T> ref,
    T data, {
    SetOptions? options,
  }) {
    _verifyNotClosed();
    return _enqueue(
      ref,
      'set',
      (batch) => batch.set(ref, data, options: options),
    );
  }

  /// Update fields of the document referred to by the provided
  /// [DocumentReference]. If the document doesn't yet exist, the update fails
  /// and the entire batch will be rejected.
  ///
  /// - [ref]: A reference to the document to be updated.
  /// - [data]: An object containing the fields and values with which to update
  ///   the document.
  /// - [precondition]: A precondition to enforce on this update.
  ///
  /// Returns a Future that resolves with the result of the write. If the write
  /// fails, the Future is rejected with a [BulkWriterError].
  ///
  /// Example:
  /// ```dart
  /// final bulkWriter = firestore.bulkWriter();
  /// final documentRef = firestore.doc('col/doc');
  ///
  /// bulkWriter
  ///   .update(documentRef, {FieldPath(const ['foo']): 'bar'})
  ///   .then((result) {
  ///     print('Successfully executed write at: $result');
  ///   })
  ///   .catchError((err) {
  ///     print('Write failed with: $err');
  ///   });
  /// ```
  Future<WriteResult> update(
    DocumentReference<Object?> ref,
    UpdateMap data, {
    Precondition? precondition,
  }) {
    _verifyNotClosed();
    return _enqueue(
      ref,
      'update',
      (batch) => batch.update(ref, data, precondition: precondition),
    );
  }

  /// Commits all writes that have been enqueued up to this point in parallel.
  ///
  /// Returns a Future that resolves when all currently queued operations have
  /// been committed. The Future will never be rejected since the results for
  /// each individual operation are conveyed via their individual Futures.
  ///
  /// The Future resolves immediately if there are no pending writes. Otherwise,
  /// the Future waits for all previously issued writes, but it does not wait
  /// for writes that were added after the method is called. If you want to wait
  /// for additional writes, call `flush()` again.
  ///
  /// Example:
  /// ```dart
  /// final bulkWriter = firestore.bulkWriter();
  ///
  /// bulkWriter.create(documentRef, {'foo': 'bar'});
  /// bulkWriter.update(documentRef2, {FieldPath(const ['foo']): 'bar'});
  /// bulkWriter.delete(documentRef3);
  /// await bulkWriter.flush();
  /// print('Executed all writes');
  /// ```
  Future<void> flush() {
    _verifyNotClosed();
    _scheduleCurrentBatch(flush: true);

    // Mark the most recent operation as flushed to ensure that the batch
    // containing it will be sent once it's popped from the buffer.
    if (_bufferedOperations.isNotEmpty) {
      _bufferedOperations.last.operation.markFlushed();
    }

    return _lastOperation;
  }

  /// Commits all enqueued writes and marks the BulkWriter instance as closed.
  ///
  /// After calling `close()`, calling any method will throw an error.
  ///
  /// Returns a Future that resolves when there are no more pending writes. The
  /// Future will never be rejected. Calling this method will send all requests.
  /// The Future resolves immediately if there are no pending writes.
  ///
  /// Example:
  /// ```dart
  /// final bulkWriter = firestore.bulkWriter();
  ///
  /// bulkWriter.create(documentRef, {'foo': 'bar'});
  /// bulkWriter.update(documentRef2, {FieldPath(const ['foo']): 'bar'});
  /// bulkWriter.delete(documentRef3);
  /// await bulkWriter.close();
  /// print('Executed all writes');
  /// ```
  Future<void> close() {
    _closeFuture ??= flush();
    return _closeFuture!;
  }

  /// Enqueues a write operation and returns a Future for it.
  Future<WriteResult> _enqueue(
    DocumentReference<Object?> ref,
    String operationType,
    void Function(_BulkCommitBatch) writeFn,
  ) {
    final completer = Completer<WriteResult>();

    void sendOperation(_BulkWriterOperation op) {
      _sendOperation(op, writeFn);
    }

    final op = _BulkWriterOperation(
      ref: ref,
      operationType: operationType,
      completer: completer,
      sendFn: sendOperation,
      errorCallback: _errorCallback,
      successCallback: _successCallback,
    );

    final userFuture = completer.future;

    // Advance the `_lastOperation` pointer. This ensures that `_lastOperation`
    // only resolves when both the previous and the current write resolve.
    // We use a helper to silently handle the future without propagating errors.
    _lastOperation = _lastOperation.then((_) {
      // Silently handle the user future (don't propagate errors to _lastOperation)
      return userFuture.then<void>((_) => null, onError: (_) => null);
    });

    // Check if we should buffer this operation
    if (_pendingOpsCount >= _maxPendingOpCount) {
      _bufferedOperations.add(_BufferedOperation(op, () => sendOperation(op)));
    } else {
      sendOperation(op);
    }

    // Chain the BulkWriter operation future with the buffer processing logic
    // in order to ensure that it runs and that subsequent operations are
    // enqueued before the next batch is scheduled in `_scheduleCurrentBatch()`.
    return userFuture.then<WriteResult>(
      (result) {
        // Decrement pending ops count and process buffered operations on success
        _pendingOpsCount--;
        _processBufferedOperations();
        return result;
      },
      onError: (Object err, StackTrace stackTrace) {
        // Decrement pending ops count and process buffered operations on error
        _pendingOpsCount--;
        _processBufferedOperations();
        // Re-throw to propagate the error with stack trace
        if (err is Exception || err is Error) {
          Error.throwWithStackTrace(err, stackTrace);
        } else {
          throw Exception(err.toString());
        }
      },
    );
  }

  /// Actually sends an operation by adding it to a batch.
  void _sendOperation(
    _BulkWriterOperation op,
    void Function(_BulkCommitBatch) writeFn,
  ) {
    // A backoff duration greater than 0 implies that this batch is a retry.
    // Retried writes are sent with a batch size of 10 in order to guarantee
    // that the batch is under the 10MiB limit.
    if (op.backoffDuration > 0) {
      if (_bulkCommitBatch.pendingOps.length >= _kRetryMaxBatchSize) {
        _scheduleCurrentBatch();
      }
      _bulkCommitBatch.setMaxBatchSize(_kRetryMaxBatchSize);
    }

    // If the current batch already contains this document, send it first
    if (_bulkCommitBatch.has(op.ref)) {
      _scheduleCurrentBatch();
    }

    // Add the operation to the batch
    writeFn(_bulkCommitBatch);
    _bulkCommitBatch.processOperation(op);
    _pendingOpsCount++;

    // If batch is now full, send it
    if (_bulkCommitBatch.isFull) {
      _scheduleCurrentBatch();
    } else if (op.flushed) {
      // If flush() was called before this operation was enqueued into a batch,
      // we still need to schedule it.
      _scheduleCurrentBatch(flush: true);
    }

    // Process buffered operations if we have capacity
    _processBufferedOperations();
  }

  /// Processes buffered operations if there's capacity.
  void _processBufferedOperations() {
    while (_bufferedOperations.isNotEmpty &&
        _pendingOpsCount < _maxPendingOpCount) {
      final buffered = _bufferedOperations.removeAt(0);
      buffered.sendFn();
    }
  }

  /// Sends the current batch and creates a new one.
  void _scheduleCurrentBatch({bool flush = false}) {
    if (_bulkCommitBatch.pendingOps.isEmpty) {
      return;
    }

    final batchToSend = _bulkCommitBatch;

    // Create a new batch for future operations
    _bulkCommitBatch = _BulkCommitBatch(firestore, _maxBatchSize);

    // Use the write with the longest backoff duration when determining backoff
    final highestBackoffDuration = batchToSend.pendingOps.fold<int>(
      0,
      (prev, cur) => prev > cur.backoffDuration ? prev : cur.backoffDuration,
    );
    final backoffMsWithJitter = _applyJitter(highestBackoffDuration);

    // Apply backoff delay if needed, then send the batch
    if (backoffMsWithJitter > 0) {
      unawaited(
        Future<void>.delayed(
          Duration(milliseconds: backoffMsWithJitter),
        ).then((_) => _sendBatch(batchToSend, flush)),
      );
    } else {
      unawaited(_sendBatch(batchToSend, flush));
    }
  }

  /// Sends the provided batch once the rate limiter does not require any delay.
  Future<void> _sendBatch(_BulkCommitBatch batch, bool flush) async {
    // Check if we're under the rate limit
    final underRateLimit = _rateLimiter.tryMakeRequest(batch.pendingOps.length);

    if (underRateLimit) {
      // We have capacity - send the batch immediately
      await batch.bulkCommit();

      // If flush was requested, schedule any remaining batches
      if (flush) {
        _scheduleCurrentBatch(flush: true);
      }
    } else {
      // We need to wait - get the delay and schedule a retry
      final delayMs = _rateLimiter.getNextRequestDelayMs(
        batch.pendingOps.length,
      );

      if (delayMs > 0) {
        // Schedule another attempt after the delay
        unawaited(
          Future<void>.delayed(
            Duration(milliseconds: delayMs),
          ).then((_) => _sendBatch(batch, flush)),
        );
      }
      // Note: If delayMs is -1, the request can never be fulfilled with current
      // capacity. This shouldn't happen in practice since batch sizes are limited.
    }
  }

  /// Adds a 30% jitter to the provided backoff.
  ///
  /// Returns the backoff duration with jitter applied, capped at max delay.
  static int _applyJitter(int backoffMs) {
    if (backoffMs == 0) return 0;

    // Random value in [-0.3, 0.3]
    final random = math.Random();
    final jitter = _defaultJitterFactor * (random.nextDouble() * 2 - 1);
    final backoffWithJitter = backoffMs + (jitter * backoffMs).toInt();

    return math.min(
      ExponentialBackoff.defaultBackOffMaxDelayMs,
      backoffWithJitter,
    );
  }

  /// Throws an error if the BulkWriter instance has been closed.
  void _verifyNotClosed() {
    if (_closeFuture != null) {
      throw StateError('BulkWriter has already been closed.');
    }
  }

  /// For testing: Get buffered operations count.
  @visibleForTesting
  int get bufferedOperationsCount => _bufferedOperations.length;

  /// For testing: Get pending operations count.
  @visibleForTesting
  int get pendingOperationsCount => _pendingOpsCount;

  /// For testing: Access the rate limiter.
  @visibleForTesting
  RateLimiter get rateLimiter => _rateLimiter;

  /// For testing: Set max pending operations count.
  @visibleForTesting
  void setMaxPendingOpCount(int count) {
    _maxPendingOpCount = count;
  }

  /// For testing: Set max batch size.
  @visibleForTesting
  void setMaxBatchSize(int size) {
    assert(
      _bulkCommitBatch.pendingOps.isEmpty,
      'Cannot change batch size when there are pending operations',
    );
    _maxBatchSize = size;
    _bulkCommitBatch = _BulkCommitBatch(firestore, size);
  }
}
