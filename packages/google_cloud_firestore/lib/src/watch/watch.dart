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

/// The target ID used by watch. Each stream carries a single target.
const _watchTargetId = 0x1;

/// How long a watch stream may go without a response before it is reset.
///
/// Under normal load the backend sends a `TargetChange` roughly every 30
/// seconds, so a stream that is silent for this long is considered stalled.
@internal
const watchIdleTimeout = Duration(seconds: 120);

/// Creates a timer that runs `callback` once after `duration`.
@internal
typedef WatchTimerFactory =
    Timer Function(Duration duration, void Function() callback);

/// One snapshot of the results of a [Watch], delivered once the backend
/// reports the target as current.
@internal
@immutable
final class WatchSnapshot<T> {
  const WatchSnapshot._({
    required this.readTime,
    required this.docs,
    required this.changes,
  });

  /// The time at which this snapshot was read.
  final Timestamp readTime;

  /// The documents in the result set, in query order.
  final List<QueryDocumentSnapshot<T>> docs;

  /// The changes since the previous snapshot of this watch: removals, then
  /// additions, then modifications, each in query order, with indexes that
  /// apply when the changes are replayed in sequence on the previous [docs].
  ///
  /// Every document of the first snapshot is an addition.
  final List<DocumentChange<T>> changes;

  /// The number of documents in the result set.
  int get size => docs.length;

  /// The snapshot of the document [ref] refers to: its entry in [docs], or a
  /// missing document read at [readTime].
  DocumentSnapshot<T> documentFor(DocumentReference<T> ref) {
    for (final doc in docs) {
      if (doc.ref._path == ref._path) return doc;
    }
    return DocumentSnapshot<T>._(
      ref: ref,
      readTime: readTime,
      createTime: null,
      updateTime: null,
      fieldsProto: null,
    );
  }
}

/// Listens to a single document or query over a `Listen` stream and turns the
/// backend's change stream into consistent [WatchSnapshot]s.
///
/// Listening to [snapshots] opens the stream; cancelling the subscription
/// closes it. The stream is re-opened with the last resume token after a
/// retryable error or an unexpected end, backing off between attempts. A
/// permanent error, a target removed by the backend, or running out of
/// retries is delivered as the single error event of [snapshots], which then
/// closes.
///
/// The project ID must be resolved before [snapshots] is listened to: the
/// database name and the target are built synchronously each time a stream
/// opens, and if that fails the watch fails with a [StateError] without
/// retrying. The caller that exposes [snapshots] must resolve it first.
///
/// The watch does not own [ListenTransport]: it opens and closes its own
/// streams on it but never closes the transport. The caller that exposes
/// [snapshots] must track active watches, stop them and close the transport
/// on [Firestore.terminate].
@internal
final class Watch<T> {
  /// Watches the document [ref] refers to.
  Watch.document(
    DocumentReference<T> ref, {
    required ListenTransport transport,
    ExponentialBackoff? backoff,
    Duration idleTimeout = watchIdleTimeout,
    WatchTimerFactory createTimer = Timer.new,
  }) : this._(
         firestore: ref.firestore,
         converter: ref._converter,
         target: (resumeToken) => firestore_v1.Target(
           documents: firestore_v1.Target_DocumentsTarget(
             documents: [ref._formattedName],
           ),
           targetId: _watchTargetId,
           resumeToken: resumeToken,
         ),
         comparator: (left, right) => left.ref._path.compareTo(right.ref._path),
         transport: transport,
         backoff: backoff,
         idleTimeout: idleTimeout,
         createTimer: createTimer,
       );

  /// Watches the results of [query].
  Watch.query(
    Query<T> query, {
    required ListenTransport transport,
    ExponentialBackoff? backoff,
    Duration idleTimeout = watchIdleTimeout,
    WatchTimerFactory createTimer = Timer.new,
  }) : this._(
         firestore: query.firestore,
         converter: query._queryOptions.converter,
         target: (resumeToken) {
           final parent = query._buildProtoParentPath();
           final request = query._toProto(
             parent: parent,
             transactionId: null,
             readTime: null,
           );
           return firestore_v1.Target(
             query: firestore_v1.Target_QueryTarget(
               parent: parent,
               structuredQuery: request.structuredQuery,
             ),
             targetId: _watchTargetId,
             resumeToken: resumeToken,
           );
         },
         comparator: _queryComparator(query),
         transport: transport,
         backoff: backoff,
         idleTimeout: idleTimeout,
         createTimer: createTimer,
       );

  Watch._({
    required Firestore firestore,
    required _FirestoreDataConverter<T> converter,
    required firestore_v1.Target Function(Uint8List? resumeToken) target,
    required Comparator<QueryDocumentSnapshot<T>> comparator,
    required ListenTransport transport,
    required ExponentialBackoff? backoff,
    required Duration idleTimeout,
    required WatchTimerFactory createTimer,
  }) : _firestore = firestore,
       _converter = converter,
       _target = target,
       _comparator = comparator,
       _transport = transport,
       _backoff = backoff ?? ExponentialBackoff(),
       _idleTimeout = idleTimeout,
       _createTimer = createTimer;

  final Firestore _firestore;
  final _FirestoreDataConverter<T> _converter;
  final firestore_v1.Target Function(Uint8List? resumeToken) _target;
  final Comparator<QueryDocumentSnapshot<T>> _comparator;
  final ListenTransport _transport;
  final ExponentialBackoff _backoff;
  final Duration _idleTimeout;
  final WatchTimerFactory _createTimer;

  late final _controller = StreamController<WatchSnapshot<T>>(
    onListen: _start,
    onCancel: _shutdown,
  );

  /// The snapshots of the watched target.
  ///
  /// Single-subscription: listening starts the watch and cancelling stops it.
  /// A watch can be listened to once.
  ///
  /// While the subscription is paused the backend stream keeps being read and
  /// every snapshot is buffered, each holding its own copy of the document
  /// list, so a long pause on a busy target grows memory without bound. The
  /// public listener API must document this.
  Stream<WatchSnapshot<T>> get snapshots => _controller.stream;

  /// Whether the watch has started and has not stopped.
  var _isActive = false;

  /// The stream to the backend, while one is open.
  ListenStream? _currentStream;
  StreamSubscription<firestore_v1.ListenResponse>? _currentSubscription;

  /// The last resume token the backend sent with a snapshot.
  Uint8List? _resumeToken;

  /// The documents of the last snapshot, by relative path.
  final _docMap = <String, QueryDocumentSnapshot<T>>{};

  /// The documents of the last snapshot, sorted by [_comparator].
  final _docs = <QueryDocumentSnapshot<T>>[];

  /// The changes received since the last snapshot, by relative path. A
  /// `null` value removes the document.
  final _changeMap = <String, firestore_v1.Document?>{};

  /// Whether the backend has reported the target as current.
  var _current = false;

  /// Whether a snapshot was delivered. The first one is delivered even
  /// without changes.
  var _hasPushed = false;

  /// The most recent retryable error, reported if retries run out.
  (Object, StackTrace)? _lastRetryableError;

  Timer? _idleTimer;

  /// The wait before the next stream opens, while backing off.
  Timer? _backoffTimer;

  void _start() {
    _isActive = true;
    _initStream();
  }

  /// Opens a new stream to the backend after backing off.
  ///
  /// The wait runs on a timer from [_createTimer] rather than
  /// [ExponentialBackoff.backoffAndWait], so that stopping the watch cancels
  /// it instead of keeping the isolate alive for up to the maximum delay.
  void _initStream() {
    assert(_backoffTimer == null, 'Already backing off.');
    final Duration delay;
    try {
      delay = _backoff.nextDelay();
    } catch (error, stackTrace) {
      // Retries ran out: report what made them necessary.
      final (lastError, lastStackTrace) =
          _lastRetryableError ?? (error, stackTrace);
      _closeStream(lastError, lastStackTrace);
      return;
    }
    _backoffTimer = _createTimer(delay, () {
      _backoffTimer = null;
      _openStream();
    });
  }

  void _openStream() {
    if (!_isActive) return;

    // Build the request before opening the stream, so that a failure to
    // build it (such as an unresolved project ID) leaves no stream open.
    ListenStream? opened;
    try {
      final request = firestore_v1.ListenRequest(
        database: _firestore._formattedDatabaseName,
        addTarget: _target(_resumeToken),
      );
      opened = _transport.open();
      opened.send(request);
    } catch (error, stackTrace) {
      // Not yet [_currentStream], so [_closeStream] would not close it.
      if (opened != null) unawaited(opened.close());
      _closeStream(error, stackTrace);
      return;
    }

    final stream = opened;
    _currentStream = stream;
    _resetIdleTimeout();
    // The `identical` guards below are defensive: once a stream is replaced
    // its subscription is cancelled, and a conforming Stream delivers nothing
    // after that. They keep a [ListenStream] whose `responses` ignores
    // cancellation from feeding a replaced stream's events into this watch.
    _currentSubscription = stream.responses.listen(
      (response) {
        if (!identical(_currentStream, stream)) return;
        _resetIdleTimeout();
        try {
          _onData(response);
        } catch (error, stackTrace) {
          _closeStream(error, stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!identical(_currentStream, stream)) return;
        _abandonStream();
        _maybeReopenStream(error, stackTrace);
      },
      onDone: () {
        if (!identical(_currentStream, stream)) return;
        _abandonStream();
        _maybeReopenStream(
          FirestoreException(
            FirestoreClientErrorCode.unknown,
            'Stream ended unexpectedly',
          ),
          StackTrace.current,
        );
      },
    );
  }

  /// Stops listening to the current stream, if any, and closes it.
  ///
  /// Responses the stream still delivers are dropped.
  void _abandonStream() {
    _idleTimer?.cancel();
    _idleTimer = null;
    final stream = _currentStream;
    final subscription = _currentSubscription;
    _currentStream = null;
    _currentSubscription = null;
    unawaited(subscription?.cancel());
    if (stream != null) unawaited(stream.close());
  }

  /// Closes the current stream and opens a new one.
  void _resetStream() {
    _abandonStream();
    _initStream();
  }

  /// Re-opens the stream unless [error] is permanent, in which case the
  /// watch fails with it.
  void _maybeReopenStream(Object error, StackTrace stackTrace) {
    if (_isActive && !_isPermanentWatchError(error)) {
      _lastRetryableError = (error, stackTrace);
      if (_resumeToken == null) {
        // The pending changes are deliberately not cleared here. Without a
        // resume token the new stream re-sends the whole result set, so the
        // documents it no longer contains must still be removed: keep them
        // all marked removed, as RESET and an existence filter mismatch do,
        // instead of dropping those removals and leaving stale documents in
        // the next snapshot.
        _resetDocs();
      } else {
        _changeMap.clear();
      }
      if (_statusCodeOf(error) == StatusCode.resourceExhausted) {
        _backoff.resetToMax();
      }
      _initStream();
    } else {
      _closeStream(error, stackTrace);
    }
  }

  /// Delivers [error] if the watch is still active, then stops it.
  void _closeStream(Object error, StackTrace stackTrace) {
    if (_isActive) {
      _controller.addError(error, stackTrace);
      unawaited(_controller.close());
    }
    unawaited(_shutdown());
  }

  /// Stops the watch: no further snapshots, errors or reconnects.
  Future<void> _shutdown() async {
    _isActive = false;
    _idleTimer?.cancel();
    _idleTimer = null;
    _backoffTimer?.cancel();
    _backoffTimer = null;
    final stream = _currentStream;
    final subscription = _currentSubscription;
    _currentStream = null;
    _currentSubscription = null;
    await subscription?.cancel();
    await stream?.close();
  }

  void _resetIdleTimeout() {
    _idleTimer?.cancel();
    _idleTimer = _createTimer(_idleTimeout, () {
      _idleTimer = null;
      if (!_isActive) return;
      _abandonStream();
      _maybeReopenStream(
        FirestoreException(
          FirestoreClientErrorCode.unknown,
          'Watch stream idle timeout',
        ),
        StackTrace.current,
      );
    });
  }

  void _onData(firestore_v1.ListenResponse response) {
    if (response.targetChange case final change?) {
      switch (change.targetChangeType) {
        case firestore_v1.TargetChange_TargetChangeType.noChange:
          final readTime = change.readTime;
          if (change.targetIds.isEmpty && readTime != null && _current) {
            // Everything is up to date: deliver the accumulated changes.
            _pushSnapshot(
              Timestamp._fromProto(readTime),
              change.resumeToken.isEmpty ? null : change.resumeToken,
            );
          }
        case firestore_v1.TargetChange_TargetChangeType.add:
          if (change.targetIds.firstOrNull != _watchTargetId) {
            _closeStream(
              FirestoreException(
                FirestoreClientErrorCode.internal,
                'Unexpected target ID sent by server',
              ),
              StackTrace.current,
            );
          }
        case firestore_v1.TargetChange_TargetChangeType.remove:
          final cause = change.cause;
          _closeStream(
            cause == null
                ? FirestoreException(
                    FirestoreClientErrorCode.internal,
                    'internal error',
                  )
                : FirestoreException(
                    FirestoreClientErrorCode.fromStatusCode(cause.code),
                    cause.message.isEmpty ? null : cause.message,
                  ),
            StackTrace.current,
          );
        case firestore_v1.TargetChange_TargetChangeType.reset:
          // Whatever changed so far no longer matters.
          _resetDocs();
        case firestore_v1.TargetChange_TargetChangeType.current:
          _current = true;
        default:
          _closeStream(
            FirestoreException(
              FirestoreClientErrorCode.internal,
              'Unknown target change type: ${jsonEncode(change.toJson())}',
            ),
            StackTrace.current,
          );
      }

      // Every target change, including one that just failed the watch, falls
      // through to the resume token check. After a failure the watch is
      // already stopped, so resetting the backoff there is a no-op.
      if (change.resumeToken.isNotEmpty &&
          _affectsTarget(change.targetIds, _watchTargetId)) {
        _backoff.reset();
        _lastRetryableError = null;
      }
    } else if (response.documentChange case final change?) {
      final changed = change.targetIds.contains(_watchTargetId);
      final removed = change.removedTargetIds.contains(_watchTargetId);
      final document = change.document;
      if (document == null) return;
      final name = _relativeName(document.name);
      if (changed) {
        _changeMap[name] = document;
      } else if (removed) {
        _changeMap[name] = null;
      }
    } else if (response.documentDelete case final delete?) {
      _changeMap[_relativeName(delete.document)] = null;
    } else if (response.documentRemove case final remove?) {
      _changeMap[_relativeName(remove.document)] = null;
    } else if (response.filter case final filter?) {
      if (filter.count != _currentSize()) {
        // Remove all current results and re-issue the query.
        _resetDocs();
        _resetStream();
      }
    } else {
      _closeStream(
        FirestoreException(
          FirestoreClientErrorCode.internal,
          'Unknown listen response type: ${jsonEncode(response.toJson())}',
        ),
        StackTrace.current,
      );
    }
  }

  static String _relativeName(String name) =>
      _QualifiedResourcePath.fromSlashSeparatedString(name).relativeName;

  /// Whether [targetIds] includes [targetId]. An empty list affects every
  /// target.
  static bool _affectsTarget(List<int> targetIds, int targetId) =>
      targetIds.isEmpty || targetIds.contains(targetId);

  /// The number of documents once the pending changes are applied.
  int _currentSize() {
    var size = _docMap.length;
    for (final MapEntry(key: name, value: document) in _changeMap.entries) {
      if (document == null) {
        if (_docMap.containsKey(name)) size--;
      } else if (!_docMap.containsKey(name)) {
        size++;
      }
    }
    return size;
  }

  /// Marks every document as removed, to be re-added by the backend.
  void _resetDocs() {
    _changeMap
      ..clear()
      ..addAll({for (final name in _docMap.keys) name: null});
    _resumeToken = null;
    _current = false;
  }

  /// Applies the pending changes and delivers a snapshot when anything
  /// changed or none was delivered yet.
  void _pushSnapshot(Timestamp readTime, Uint8List? nextResumeToken) {
    final changes = _computeSnapshot(readTime);
    if (!_hasPushed || changes.isNotEmpty) {
      _controller.add(
        WatchSnapshot._(
          readTime: readTime,
          docs: List.unmodifiable(_docs),
          changes: List.unmodifiable(changes),
        ),
      );
      _hasPushed = true;
    }
    _changeMap.clear();
    _resumeToken = nextResumeToken;
  }

  QueryDocumentSnapshot<T> _snapshotOf(
    String name,
    firestore_v1.Document document,
    Timestamp readTime,
  ) {
    return QueryDocumentSnapshot<T>._(
      ref: DocumentReference<T>._(
        firestore: _firestore,
        path: _ResourcePath.empty._append(name),
        converter: _converter,
      ),
      fieldsProto: firestore_v1.MapValue(fields: document.fields),
      readTime: readTime,
      createTime: document.createTime.let(Timestamp._fromProto),
      updateTime: document.updateTime.let(Timestamp._fromProto),
    );
  }

  /// Applies the pending changes to [_docs] and [_docMap], returning them as
  /// [DocumentChange]s: removals, additions, then modifications, each sorted
  /// so that the indexes keep increasing.
  List<DocumentChange<T>> _computeSnapshot(Timestamp readTime) {
    final deletes = <String>[];
    final adds = <QueryDocumentSnapshot<T>>[];
    final updates = <QueryDocumentSnapshot<T>>[];
    for (final MapEntry(key: name, value: document) in _changeMap.entries) {
      if (document == null) {
        if (_docMap.containsKey(name)) deletes.add(name);
      } else if (_docMap.containsKey(name)) {
        updates.add(_snapshotOf(name, document, readTime));
      } else {
        adds.add(_snapshotOf(name, document, readTime));
      }
    }

    final changes = <DocumentChange<T>>[];

    deletes.sort((a, b) => _comparator(_docMap[a]!, _docMap[b]!));
    for (final name in deletes) {
      changes.add(_deleteDoc(name));
    }

    adds.sort(_comparator);
    for (final doc in adds) {
      changes.add(_addDoc(doc));
    }

    updates.sort(_comparator);
    for (final doc in updates) {
      if (_modifyDoc(doc) case final change?) changes.add(change);
    }

    assert(
      _docs.length == _docMap.length,
      'The sorted documents and the document map should have the same '
      'number of entries.',
    );
    return changes;
  }

  int _indexOf(QueryDocumentSnapshot<T> doc) {
    final index = lowerBound(_docs, doc, compare: _comparator);
    assert(
      index < _docs.length && identical(_docs[index], doc),
      'Document to find does not exist.',
    );
    return index;
  }

  DocumentChange<T> _deleteDoc(String name) {
    final oldDocument = _docMap.remove(name)!;
    final oldIndex = _indexOf(oldDocument);
    _docs.removeAt(oldIndex);
    return DocumentChange._(
      type: DocumentChangeType.removed,
      doc: oldDocument,
      oldIndex: oldIndex,
      newIndex: -1,
    );
  }

  DocumentChange<T> _addDoc(QueryDocumentSnapshot<T> newDocument) {
    final name = newDocument.ref.path;
    assert(!_docMap.containsKey(name), 'Document to add already exists.');
    final newIndex = lowerBound(_docs, newDocument, compare: _comparator);
    _docs.insert(newIndex, newDocument);
    _docMap[name] = newDocument;
    return DocumentChange._(
      type: DocumentChangeType.added,
      doc: newDocument,
      oldIndex: -1,
      newIndex: newIndex,
    );
  }

  /// Replaces a document whose update time changed. Returns `null` when it
  /// did not change.
  DocumentChange<T>? _modifyDoc(QueryDocumentSnapshot<T> newDocument) {
    final name = newDocument.ref.path;
    final oldDocument = _docMap[name]!;
    if (oldDocument.updateTime == newDocument.updateTime) return null;
    final removed = _deleteDoc(name);
    final added = _addDoc(newDocument);
    return DocumentChange._(
      type: DocumentChangeType.modified,
      doc: newDocument,
      oldIndex: removed.oldIndex,
      newIndex: added.newIndex,
    );
  }

  /// Whether the backend will never accept a re-opened stream after [error].
  /// Errors without a status code are transient.
  static bool _isPermanentWatchError(Object error) {
    final code = _statusCodeOf(error);
    if (code == null) return false;
    return switch (code) {
      StatusCode.aborted ||
      StatusCode.cancelled ||
      StatusCode.unknown ||
      StatusCode.deadlineExceeded ||
      StatusCode.resourceExhausted ||
      StatusCode.internal ||
      StatusCode.unavailable ||
      StatusCode.unauthenticated => false,
      _ => true,
    };
  }

  static StatusCode? _statusCodeOf(Object error) =>
      error is FirestoreException ? error.errorCode.statusCode : null;
}

/// Orders documents as [query] does: by its explicit orderings, then by
/// document name in the direction of the last of them.
Comparator<QueryDocumentSnapshot<T>> _queryComparator<T>(Query<T> query) {
  final fieldOrders = query._queryOptions.fieldOrders;
  final lastDirection = fieldOrders.isEmpty
      ? _Direction.ascending
      : fieldOrders.last.direction;
  final orderBys = [
    ...fieldOrders,
    _FieldOrder(fieldPath: FieldPath.documentId, direction: lastDirection),
  ];

  return (left, right) {
    for (final orderBy in orderBys) {
      final int comparison;
      if (orderBy.fieldPath == FieldPath.documentId) {
        comparison = left.ref._path.compareTo(right.ref._path);
      } else {
        final leftValue = left._protoField(orderBy.fieldPath);
        final rightValue = right._protoField(orderBy.fieldPath);
        if (leftValue == null || rightValue == null) {
          throw StateError(
            "Trying to compare documents on fields that don't exist. Please "
            'include the fields you are ordering on in your select() call.',
          );
        }
        comparison = compare(leftValue, rightValue);
      }
      if (comparison != 0) {
        return orderBy.direction == _Direction.ascending
            ? comparison
            : -comparison;
      }
    }
    return 0;
  };
}
