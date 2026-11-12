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

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:google_cloud_firestore/src/backoff.dart';
import 'package:google_cloud_firestore/src/firestore.dart';
import 'package:google_cloud_firestore/src/firestore_exception.dart';
import 'package:google_cloud_firestore/src/status_code.dart';
import 'package:google_cloud_firestore/src/watch/listen_transport.dart';
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:google_cloud_protobuf/protobuf.dart' as protobuf_v1;
import 'package:google_cloud_rpc/rpc.dart' as rpc;
import 'package:test/test.dart';

const _projectId = 'test-project';
const _database = 'projects/$_projectId/databases/(default)';
const _documents = '$_database/documents';
const _targetId = 0x1;

/// A [ListenStream] whose responses the test pushes.
///
/// As with a gRPC call, [close] only half-closes the request side: responses
/// the test pushes afterwards, data or an error, still reach any listener
/// until the call ends with [destroy] or [end].
final class _FakeListenStream implements ListenStream {
  _FakeListenStream({this.ignoreCancel = false, this.failSendsWith});

  /// When set, [send] throws this error.
  final Error? failSendsWith;

  /// Whether [responses] keeps delivering after its subscription is
  /// cancelled, as a non-conforming [ListenStream] might.
  final bool ignoreCancel;

  final _responses = StreamController<firestore_v1.ListenResponse>();
  final requests = <firestore_v1.ListenRequest>[];
  bool closed = false;

  @override
  Stream<firestore_v1.ListenResponse> get responses => ignoreCancel
      ? _CancelIgnoringStream(_responses.stream)
      : _responses.stream;

  /// Whether anyone still listens to [responses].
  bool get hasListener => _responses.hasListener;

  @override
  void send(firestore_v1.ListenRequest request) {
    if (closed) throw StateError('ListenStream has already ended.');
    if (failSendsWith case final error?) throw error;
    requests.add(request);
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  void write(firestore_v1.ListenResponse response) {
    if (!_responses.isClosed) _responses.add(response);
  }

  /// Fails the call with [error], as a transport error does.
  void destroy([Object? error]) {
    if (_responses.isClosed) return;
    _responses.addError(
      error ??
          FirestoreException(
            FirestoreClientErrorCode.unavailable,
            'Server disconnect',
          ),
    );
    unawaited(_responses.close());
  }

  /// Ends the call without an error, as a server half-close does.
  void end() {
    if (!_responses.isClosed) unawaited(_responses.close());
  }
}

/// A stream whose subscriptions ignore [StreamSubscription.cancel].
final class _CancelIgnoringStream<T> extends Stream<T> {
  _CancelIgnoringStream(this._inner);

  final Stream<T> _inner;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _CancelIgnoringSubscription(
    _inner.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    ),
  );
}

final class _CancelIgnoringSubscription<T> implements StreamSubscription<T> {
  _CancelIgnoringSubscription(this._inner);

  final StreamSubscription<T> _inner;

  @override
  Future<void> cancel() async {}

  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture(futureValue);
}

final class _FakeListenTransport implements ListenTransport {
  final streams = <_FakeListenStream>[];
  final _waiters = <Completer<_FakeListenStream>>[];
  var _taken = 0;

  /// When set, every stream opened fails with this error right away.
  Object? failNewStreamsWith;

  /// Whether streams opened from now on ignore cancellation.
  bool ignoreCancel = false;

  /// When set, sending on any stream opened from now on throws this error.
  Error? failSendsWith;

  @override
  ListenStream open() {
    final stream = _FakeListenStream(
      ignoreCancel: ignoreCancel,
      failSendsWith: failSendsWith,
    );
    streams.add(stream);
    if (failNewStreamsWith case final error?) {
      stream.destroy(error);
    }
    if (_waiters.isNotEmpty) {
      _taken++;
      _waiters.removeAt(0).complete(stream);
    }
    return stream;
  }

  /// The next stream the watch opens.
  Future<_FakeListenStream> nextStream() {
    if (_taken < streams.length) return Future.value(streams[_taken++]);
    final completer = Completer<_FakeListenStream>();
    _waiters.add(completer);
    return completer.future;
  }

  /// Waits for the next stream and returns the request it was opened with.
  Future<firestore_v1.ListenRequest> awaitOpen() async {
    final stream = await nextStream();
    return stream.requests.single;
  }

  _FakeListenStream get current => streams.last;

  @override
  Future<void> close() async {}
}

/// An [ExponentialBackoff] without delays that records its use.
final class _TestBackoff extends ExponentialBackoff {
  _TestBackoff()
    : super(
        options: const ExponentialBackoffSetting(
          initialDelayMs: 0,
          maxDelayMs: 0,
          jitterFactor: 0,
        ),
      );

  int attempts = 0;
  int resetCalls = 0;
  int resetToMaxCalls = 0;

  @override
  Duration nextDelay() {
    attempts++;
    return super.nextDelay();
  }

  @override
  void reset() {
    resetCalls++;
    super.reset();
  }

  @override
  void resetToMax() {
    resetToMaxCalls++;
    super.resetToMax();
  }
}

/// A [Timer] the test fires by hand.
final class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;
  var _active = true;

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  void fire() {
    if (!_active) return;
    _active = false;
    callback();
  }
}

/// Records the events of a watch, to be awaited in order.
final class _Events<T> {
  _Events(Stream<WatchSnapshot<T>> stream) {
    _subscription = stream.listen(
      _add,
      onError: (Object error) => _add(_Error(error)),
      onDone: () => _add(const _Done()),
    );
  }

  late final StreamSubscription<WatchSnapshot<T>> _subscription;
  final _pending = <Object?>[];
  final _waiters = <Completer<Object?>>[];

  void _add(Object? event) {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(event);
    } else {
      _pending.add(event);
    }
  }

  Future<Object?> _next() {
    if (_pending.isNotEmpty) return Future.value(_pending.removeAt(0));
    final completer = Completer<Object?>();
    _waiters.add(completer);
    return completer.future;
  }

  bool get hasPending => _pending.isNotEmpty;

  Future<WatchSnapshot<T>> snapshot() async {
    final event = await _next();
    if (event is WatchSnapshot<T>) return event;
    fail('Expected a snapshot, got $event');
  }

  Future<Object> error() async {
    final event = await _next();
    if (event is _Error) {
      expect(await _next(), isA<_Done>(), reason: 'closes after an error');
      return event.error;
    }
    fail('Expected an error, got $event');
  }

  Future<void> cancel() => _subscription.cancel();
}

final class _Error {
  const _Error(this.error);
  final Object error;
  @override
  String toString() => 'error($error)';
}

final class _Done {
  const _Done();
  @override
  String toString() => 'done';
}

/// Lets pending timers and microtasks run.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _ExpectedChange {
  const _ExpectedChange(this.type, this.ref, this.data);
  final DocumentChangeType type;
  final DocumentReference<DocumentData> ref;
  final DocumentData data;
}

typedef _Doc = (DocumentReference<DocumentData>, DocumentData);

_ExpectedChange _added(
  DocumentReference<DocumentData> ref,
  DocumentData data,
) => _ExpectedChange(DocumentChangeType.added, ref, data);
_ExpectedChange _modified(
  DocumentReference<DocumentData> ref,
  DocumentData data,
) => _ExpectedChange(DocumentChangeType.modified, ref, data);
_ExpectedChange _removed(
  DocumentReference<DocumentData> ref,
  DocumentData data,
) => _ExpectedChange(DocumentChangeType.removed, ref, data);

Timestamp _version(int version) => Timestamp(seconds: 0, nanoseconds: version);

/// Asserts that [actual] holds [docs] and [changes], and that replaying its
/// changes on [lastDocs] by `oldIndex`/`newIndex` yields its documents.
///
/// Returns the documents of [actual], to pass as [lastDocs] next.
List<QueryDocumentSnapshot<DocumentData>> _snapshotsEqual(
  List<QueryDocumentSnapshot<DocumentData>> lastDocs,
  int version,
  WatchSnapshot<DocumentData> actual, {
  List<_Doc> docs = const [],
  List<_ExpectedChange> changes = const [],
}) {
  final localDocs = [...lastDocs];

  expect(actual.changes, hasLength(changes.length), reason: 'changes');
  for (final (index, change) in actual.changes.indexed) {
    final expected = changes[index];
    expect(change.type, expected.type, reason: 'type of change $index');
    expect(change.doc.ref.path, expected.ref.path, reason: 'change $index');
    expect(change.doc.data(), expected.data, reason: 'data of change $index');
    final readVersion = change.type == DocumentChangeType.removed
        ? version - 1
        : version;
    expect(change.doc.readTime, _version(readVersion));

    if (change.oldIndex != -1) localDocs.removeAt(change.oldIndex);
    if (change.newIndex != -1) localDocs.insert(change.newIndex, change.doc);
  }

  void docsEqual(List<QueryDocumentSnapshot<DocumentData>> list) {
    expect(
      [
        for (final doc in list) [doc.ref.path, doc.data()],
      ],
      [
        for (final (ref, data) in docs) [ref.path, data],
      ],
    );
  }

  docsEqual(actual.docs);
  docsEqual(localDocs);
  expect(actual.readTime, _version(version));
  expect(actual.size, docs.length);
  return actual.docs;
}

/// Sends backend responses on the transport's current stream.
final class _Backend {
  _Backend(this.transport, this.firestore);

  final _FakeListenTransport transport;
  final Firestore firestore;
  int snapshotVersion = 0;

  void write(firestore_v1.ListenResponse response) =>
      transport.current.write(response);

  void sendAddTarget([int targetId = _targetId]) => write(
    firestore_v1.ListenResponse(
      targetChange: firestore_v1.TargetChange(
        targetChangeType: firestore_v1.TargetChange_TargetChangeType.add,
        targetIds: [targetId],
      ),
    ),
  );

  void sendRemoveTarget([int? cause]) => write(
    firestore_v1.ListenResponse(
      targetChange: firestore_v1.TargetChange(
        targetChangeType: firestore_v1.TargetChange_TargetChangeType.remove,
        targetIds: [_targetId],
        cause: cause == null
            ? null
            : rpc.Status(code: cause, message: 'test remove'),
      ),
    ),
  );

  void sendSnapshot(int version, [List<int>? resumeToken]) {
    snapshotVersion = version;
    write(
      firestore_v1.ListenResponse(
        targetChange: firestore_v1.TargetChange(
          readTime: protobuf_v1.Timestamp(seconds: 0, nanos: version),
          resumeToken: resumeToken == null
              ? null
              : Uint8List.fromList(resumeToken),
        ),
      ),
    );
  }

  void sendCurrent([List<int>? resumeToken]) => write(
    firestore_v1.ListenResponse(
      targetChange: firestore_v1.TargetChange(
        targetChangeType: firestore_v1.TargetChange_TargetChangeType.current,
        targetIds: [_targetId],
        resumeToken: resumeToken == null
            ? null
            : Uint8List.fromList(resumeToken),
      ),
    ),
  );

  void sendDoc(
    DocumentReference<DocumentData> ref,
    DocumentData data, {
    protobuf_v1.Timestamp? updateTime,
  }) => write(
    firestore_v1.ListenResponse(
      documentChange: firestore_v1.DocumentChange(
        document: firestore_v1.Document(
          name: '$_documents/${ref.path}',
          fields: firestore.serializer.encodeFields(data).fields,
          createTime: protobuf_v1.Timestamp(seconds: 1, nanos: 2),
          updateTime:
              updateTime ??
              protobuf_v1.Timestamp(seconds: 3, nanos: snapshotVersion),
        ),
        targetIds: [_targetId],
      ),
    ),
  );

  void sendDocRemove(DocumentReference<DocumentData> ref, DocumentData data) =>
      write(
        firestore_v1.ListenResponse(
          documentChange: firestore_v1.DocumentChange(
            document: firestore_v1.Document(
              name: '$_documents/${ref.path}',
              fields: firestore.serializer.encodeFields(data).fields,
            ),
            removedTargetIds: [_targetId],
          ),
        ),
      );

  void sendDocDelete(DocumentReference<DocumentData> ref) => write(
    firestore_v1.ListenResponse(
      documentDelete: firestore_v1.DocumentDelete(
        document: '$_documents/${ref.path}',
        removedTargetIds: [_targetId],
      ),
    ),
  );

  void sendReset() => write(
    firestore_v1.ListenResponse(
      targetChange: firestore_v1.TargetChange(
        targetChangeType: firestore_v1.TargetChange_TargetChangeType.reset,
      ),
    ),
  );

  void sendFilter(int count) => write(
    firestore_v1.ListenResponse(
      filter: firestore_v1.ExistenceFilter(targetId: _targetId, count: count),
    ),
  );
}

Map<String, Object?> _queryRequest({
  Map<String, Object?> structuredQuery = const {},
  List<int>? resumeToken,
}) => {
  'database': _database,
  'addTarget': {
    'query': {
      'parent': _documents,
      'structuredQuery': {
        'from': [
          {'collectionId': 'col'},
        ],
        ...structuredQuery,
      },
    },
    if (resumeToken != null)
      'resumeToken': base64Encode(Uint8List.fromList(resumeToken)),
    'targetId': _targetId,
  },
};

Map<String, Object?> _documentRequest(String path, {List<int>? resumeToken}) =>
    {
      'database': _database,
      'addTarget': {
        'documents': {
          'documents': ['$_documents/$path'],
        },
        if (resumeToken != null)
          'resumeToken': base64Encode(Uint8List.fromList(resumeToken)),
        'targetId': _targetId,
      },
    };

void _verifyRequest(
  firestore_v1.ListenRequest request,
  Map<String, Object?> expected,
) {
  expect(jsonDecode(jsonEncode(request.toJson())), expected);
}

Matcher _firestoreError(FirestoreClientErrorCode code, String message) =>
    isA<FirestoreException>()
        .having((e) => e.errorCode, 'errorCode', code)
        .having((e) => e.message, 'message', message);

void main() {
  late Firestore firestore;
  late _FakeListenTransport transport;
  late _TestBackoff backoff;
  late _Backend backend;
  late List<_FakeTimer> idleTimers;
  late List<Timer> backoffTimers;
  late bool holdBackoff;

  setUp(() {
    firestore = Firestore(settings: const Settings(projectId: _projectId));
    transport = _FakeListenTransport();
    backoff = _TestBackoff();
    backend = _Backend(transport, firestore);
    idleTimers = [];
    backoffTimers = [];
    holdBackoff = false;
  });

  tearDown(() => firestore.terminate());

  /// Idle timers are fired by hand. Backoff waits run on real timers, or
  /// on timers fired by hand while [holdBackoff] is set.
  Timer createTimer(Duration duration, void Function() callback) {
    if (duration == watchIdleTimeout) {
      final timer = _FakeTimer(duration, callback);
      idleTimers.add(timer);
      return timer;
    }
    final timer = holdBackoff
        ? _FakeTimer(duration, callback)
        : Timer(duration, callback);
    backoffTimers.add(timer);
    return timer;
  }

  Watch<DocumentData> queryWatch(Query<DocumentData> query) => Watch.query(
    query,
    transport: transport,
    backoff: backoff,
    createTimer: createTimer,
  );

  group('Query watch', () {
    late CollectionReference<DocumentData> colRef;
    late DocumentReference<DocumentData> doc1;
    late DocumentReference<DocumentData> doc2;
    late DocumentReference<DocumentData> doc3;
    late DocumentReference<DocumentData> doc4;
    late List<QueryDocumentSnapshot<DocumentData>> lastDocs;

    setUp(() {
      colRef = firestore.collection('col');
      doc1 = firestore.doc('col/doc1');
      doc2 = firestore.doc('col/doc2');
      doc3 = firestore.doc('col/doc3');
      doc4 = firestore.doc('col/doc4');
      lastDocs = [];
    });

    /// Starts watching [query] and verifies the first request.
    Future<_Events<DocumentData>> start({
      Query<DocumentData>? query,
      Map<String, Object?>? expectedRequest,
    }) async {
      final events = _Events(queryWatch(query ?? colRef).snapshots);
      _verifyRequest(
        await transport.awaitOpen(),
        expectedRequest ?? _queryRequest(),
      );
      return events;
    }

    /// Sends ADD, CURRENT and an empty snapshot at version 1, and checks it.
    Future<void> sendInitialSnapshot(
      _Events<DocumentData> events, [
      List<int>? resumeToken,
    ]) async {
      backend
        ..sendAddTarget()
        ..sendCurrent()
        ..sendSnapshot(1, resumeToken);
      lastDocs = _snapshotsEqual(lastDocs, 1, await events.snapshot());
    }

    Future<Object> expectFailure(void Function() send) async {
      final events = await start();
      send();
      final error = await events.error();
      await _settle();
      expect(transport.streams, hasLength(1), reason: 'no reconnect');
      expect(transport.current.closed, isTrue);
      return error;
    }

    test('handles invalid listen protos', () async {
      expect(
        await expectFailure(() => backend.write(firestore_v1.ListenResponse())),
        _firestoreError(
          FirestoreClientErrorCode.internal,
          'Unknown listen response type: {}',
        ),
      );
    });

    test('handles invalid target change protos', () async {
      expect(
        await expectFailure(
          () => backend.write(
            firestore_v1.ListenResponse(
              targetChange: firestore_v1.TargetChange(
                targetChangeType:
                    const firestore_v1.TargetChange_TargetChangeType('INVALID'),
                targetIds: [0xfeed],
              ),
            ),
          ),
        ),
        _firestoreError(
          FirestoreClientErrorCode.internal,
          'Unknown target change type: '
          '{"targetChangeType":"INVALID","targetIds":[65261]}',
        ),
      );
    });

    test('handles remove target change protos', () async {
      expect(
        await expectFailure(backend.sendRemoveTarget),
        _firestoreError(FirestoreClientErrorCode.internal, 'internal error'),
      );
    });

    test('handles remove target change with code', () async {
      expect(
        await expectFailure(() => backend.sendRemoveTarget(7)),
        _firestoreError(
          FirestoreClientErrorCode.permissionDenied,
          'test remove',
        ),
      );
    });

    test('rejects an unknown target', () async {
      expect(
        await expectFailure(() => backend.sendAddTarget(2)),
        _firestoreError(
          FirestoreClientErrorCode.internal,
          'Unexpected target ID sent by server',
        ),
      );
    });

    test('re-opens on unexpected stream end', () async {
      final events = await start();
      await sendInitialSnapshot(events, [0xab]);

      transport.current.end();
      _verifyRequest(
        await transport.awaitOpen(),
        _queryRequest(resumeToken: [0xab]),
      );

      transport.current.end();
      _verifyRequest(
        await transport.awaitOpen(),
        _queryRequest(resumeToken: [0xab]),
      );

      expect(transport.streams, hasLength(3));
      expect(events.hasPending, isFalse);
      await events.cancel();
    });

    test('stops attempts after maximum retry attempts', () async {
      final events = await start();
      final error = FirestoreException(
        FirestoreClientErrorCode.aborted,
        'GRPC Error',
      );
      for (var i = 0; i < ExponentialBackoff.maxRetryAttempts; i++) {
        transport.current.destroy(error);
        await transport.awaitOpen();
      }
      // The next retry fails, reporting the error that caused it.
      transport.current.destroy(error);
      expect(await events.error(), same(error));
      expect(
        transport.streams,
        hasLength(ExponentialBackoff.maxRetryAttempts + 1),
      );
    });

    test("doesn't re-open inactive stream", () async {
      final events = await start();
      await sendInitialSnapshot(events, [0xab]);

      holdBackoff = true;
      transport.current.end();
      await _settle();
      expect(backoff.attempts, 2, reason: 'waiting to re-open');
      final pending = backoffTimers.last as _FakeTimer;
      expect(pending.isActive, isTrue);

      await events.cancel();
      expect(pending.isActive, isFalse, reason: 'backoff wait cancelled');
      pending.fire();
      await _settle();
      expect(transport.streams, hasLength(1));
    });

    test('cancelling during a maximum backoff cancels the wait', () async {
      final events = _Events(
        Watch.query(
          colRef,
          transport: transport,
          backoff: ExponentialBackoff(),
          createTimer: createTimer,
        ).snapshots,
      );
      await transport.awaitOpen();
      await sendInitialSnapshot(events, [0xab]);

      holdBackoff = true;
      transport.current.destroy(
        FirestoreException(
          FirestoreClientErrorCode.resourceExhausted,
          'GRPC Error',
        ),
      );
      await _settle();
      final pending = backoffTimers.last as _FakeTimer;
      expect(
        pending.duration,
        greaterThanOrEqualTo(
          const Duration(
            milliseconds: ExponentialBackoff.defaultBackOffMaxDelayMs ~/ 2,
          ),
        ),
        reason: 'backed off to the maximum delay',
      );

      await events.cancel();
      expect(
        [...backoffTimers, ...idleTimers].where((t) => t.isActive),
        isEmpty,
        reason: 'no timer keeps the isolate alive',
      );
      expect(transport.streams, hasLength(1));
    });

    group('retries based on error code', () {
      const retried = {
        StatusCode.cancelled: true,
        StatusCode.unknown: true,
        StatusCode.invalidArgument: false,
        StatusCode.deadlineExceeded: true,
        StatusCode.notFound: false,
        StatusCode.alreadyExists: false,
        StatusCode.permissionDenied: false,
        StatusCode.resourceExhausted: true,
        StatusCode.failedPrecondition: false,
        StatusCode.aborted: true,
        StatusCode.outOfRange: false,
        StatusCode.unimplemented: false,
        StatusCode.internal: true,
        StatusCode.unavailable: true,
        StatusCode.dataLoss: false,
        StatusCode.unauthenticated: true,
      };

      for (final MapEntry(key: statusCode, value: expectRetry)
          in retried.entries) {
        test(
          '${statusCode.name}: ${expectRetry ? 'retried' : 'fails'}',
          () async {
            final events = await start();
            await sendInitialSnapshot(events, [0xab]);

            final error = FirestoreException(
              FirestoreClientErrorCode.fromStatusCode(statusCode.value),
              'GRPC Error',
            );
            transport.current.destroy(error);

            if (expectRetry) {
              _verifyRequest(
                await transport.awaitOpen(),
                _queryRequest(resumeToken: [0xab]),
              );
              expect(
                backoff.resetToMaxCalls,
                statusCode == StatusCode.resourceExhausted ? 1 : 0,
              );
              await events.cancel();
            } else {
              expect(await events.error(), same(error));
              await _settle();
              expect(transport.streams, hasLength(1));
              expect(transport.current.closed, isTrue);
            }
          },
        );
      }
    });

    test('retries with unknown code', () async {
      final events = await start();
      await sendInitialSnapshot(events, [0xab]);
      transport.current.destroy(StateError('Unknown'));
      await transport.awaitOpen();
      await events.cancel();
    });

    test('handles changing a doc', () async {
      final events = await start();
      await sendInitialSnapshot(events);

      // Add a result.
      backend
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendSnapshot(2);
      lastDocs = _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
        ],
      );

      // Add another result.
      backend
        ..sendDoc(doc2, {'foo': 'b'})
        ..sendSnapshot(3);
      lastDocs = _snapshotsEqual(
        lastDocs,
        3,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
          (doc2, {'foo': 'b'}),
        ],
        changes: [
          _added(doc2, {'foo': 'b'}),
        ],
      );

      // Change a result.
      backend
        ..sendDoc(doc2, {'bar': 'c'})
        ..sendSnapshot(4);
      _snapshotsEqual(
        lastDocs,
        4,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
          (doc2, {'bar': 'c'}),
        ],
        changes: [
          _modified(doc2, {'bar': 'c'}),
        ],
      );
      await events.cancel();
    });

    test('reconnects after error', () async {
      var resumeToken = [0xab];
      final events = await start();
      backend
        ..sendAddTarget()
        ..sendCurrent(resumeToken)
        ..sendSnapshot(1);
      lastDocs = _snapshotsEqual(lastDocs, 1, await events.snapshot());

      // Add a result.
      backend
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendSnapshot(2, resumeToken);
      lastDocs = _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
        ],
      );
      expect(transport.streams, hasLength(1));

      transport.current.destroy();
      _verifyRequest(
        await transport.awaitOpen(),
        _queryRequest(resumeToken: resumeToken),
      );
      resumeToken = [0xbc];
      backend
        ..sendAddTarget()
        ..sendDoc(doc2, {'foo': 'b'})
        ..sendSnapshot(3, resumeToken);
      lastDocs = _snapshotsEqual(
        lastDocs,
        3,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
          (doc2, {'foo': 'b'}),
        ],
        changes: [
          _added(doc2, {'foo': 'b'}),
        ],
      );

      transport.current.destroy();
      _verifyRequest(
        await transport.awaitOpen(),
        _queryRequest(resumeToken: resumeToken),
      );
      backend
        ..sendAddTarget()
        ..sendDoc(doc3, {'foo': 'c'})
        ..sendSnapshot(4, resumeToken);
      _snapshotsEqual(
        lastDocs,
        4,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
          (doc2, {'foo': 'b'}),
          (doc3, {'foo': 'c'}),
        ],
        changes: [
          _added(doc3, {'foo': 'c'}),
        ],
      );
      expect(transport.streams, hasLength(3));
      await events.cancel();
    });

    test('ignores changes sent after the last snapshot', () async {
      final events = await start();
      backend
        ..sendAddTarget()
        ..sendCurrent([0x0])
        ..sendSnapshot(1);
      lastDocs = _snapshotsEqual(lastDocs, 1, await events.snapshot());

      backend
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendDoc(doc2, {'foo': 'b'})
        ..sendSnapshot(2, [0x1]);
      lastDocs = _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
          (doc2, {'foo': 'b'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
          _added(doc2, {'foo': 'b'}),
        ],
      );
      expect(transport.streams, hasLength(1));

      // This document delete is dropped by the reconnect.
      backend.sendDocDelete(doc1);
      transport.current.destroy();
      await transport.awaitOpen();

      backend
        ..sendDocDelete(doc2)
        ..sendSnapshot(3, [0x2]);
      _snapshotsEqual(
        lastDocs,
        3,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _removed(doc2, {'foo': 'b'}),
        ],
      );
      await events.cancel();
    });

    test('ignores non-matching tokens', () async {
      final events = await start();
      backend
        ..sendAddTarget()
        ..sendCurrent()
        ..sendSnapshot(1, [0x1]);
      lastDocs = _snapshotsEqual(lastDocs, 1, await events.snapshot());

      backend.sendDoc(doc1, {'foo': 'a'});
      // A snapshot for another target: nothing is delivered.
      backend.write(
        firestore_v1.ListenResponse(
          targetChange: firestore_v1.TargetChange(
            targetIds: [0xfeed],
            readTime: protobuf_v1.Timestamp(seconds: 0, nanos: 0),
            resumeToken: Uint8List.fromList([0x2]),
          ),
        ),
      );
      // A snapshot for all targets: its token is used from now on.
      backend.write(
        firestore_v1.ListenResponse(
          targetChange: firestore_v1.TargetChange(
            readTime: protobuf_v1.Timestamp(seconds: 0, nanos: 0),
            resumeToken: Uint8List.fromList([0x3]),
          ),
        ),
      );
      lastDocs = _snapshotsEqual(
        lastDocs,
        0,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
        ],
      );

      transport.current.destroy();
      _verifyRequest(
        await transport.awaitOpen(),
        _queryRequest(resumeToken: [0x3]),
      );
      expect(transport.streams, hasLength(2));
      await events.cancel();
    });

    test('reconnects with multiple attempts', () async {
      final events = await start();
      await sendInitialSnapshot(events, [0xab]);

      final error = FirestoreException(
        FirestoreClientErrorCode.unavailable,
        'Stream Error',
      );
      transport.failNewStreamsWith = error;
      transport.current.destroy(error);

      expect(await events.error(), same(error));
      // Opened once, then retried until the backoff gives up.
      expect(
        transport.streams,
        hasLength(1 + ExponentialBackoff.maxRetryAttempts + 1),
      );
    });

    test('sorts docs', () async {
      final events = await start(
        query: colRef.orderBy('foo', descending: true),
        expectedRequest: _queryRequest(
          structuredQuery: {
            'orderBy': [
              {
                'field': {'fieldPath': 'foo'},
                'direction': 'DESCENDING',
              },
            ],
          },
        ),
      );
      await sendInitialSnapshot(events);

      backend
        ..sendDoc(doc1, {'foo': 'b'})
        ..sendDoc(doc2, {'foo': 'a'})
        ..sendSnapshot(2);
      lastDocs = _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'b'}),
          (doc2, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'b'}),
          _added(doc2, {'foo': 'a'}),
        ],
      );

      // Change the results so they sort in a different order.
      backend
        ..sendDoc(doc1, {'foo': 'c'})
        ..sendDoc(doc2, {'foo': 'd'})
        ..sendSnapshot(3);
      _snapshotsEqual(
        lastDocs,
        3,
        await events.snapshot(),
        docs: [
          (doc2, {'foo': 'd'}),
          (doc1, {'foo': 'c'}),
        ],
        changes: [
          _modified(doc2, {'foo': 'd'}),
          _modified(doc1, {'foo': 'c'}),
        ],
      );
      await events.cancel();
    });

    test('combines multiple change events for the same doc', () async {
      final events = await start();
      backend
        ..sendAddTarget()
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendDoc(doc1, {'foo': 'b'})
        ..sendCurrent()
        ..sendSnapshot(1);
      lastDocs = _snapshotsEqual(
        lastDocs,
        1,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'b'}),
        ],
        changes: [
          _added(doc1, {'foo': 'b'}),
        ],
      );

      backend
        ..sendDoc(doc1, {'foo': 'c'})
        ..sendDoc(doc1, {'foo': 'd'})
        ..sendSnapshot(2);
      lastDocs = _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'd'}),
        ],
        changes: [
          _modified(doc1, {'foo': 'd'}),
        ],
      );

      // Remove it, delete it, and then add it again.
      backend
        ..sendDocRemove(doc1, {'foo': 'e'})
        ..sendDocDelete(doc1)
        ..sendDoc(doc1, {'foo': 'f'})
        ..sendSnapshot(3);
      _snapshotsEqual(
        lastDocs,
        3,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'f'}),
        ],
        changes: [
          _modified(doc1, {'foo': 'f'}),
        ],
      );
      await events.cancel();
    });

    test('can sort by FieldPath.documentId()', () async {
      final events = await start(
        query: colRef
            .orderBy('foo', descending: true)
            .orderByFieldPath(FieldPath.documentId, descending: true),
        expectedRequest: _queryRequest(
          structuredQuery: {
            'orderBy': [
              {
                'field': {'fieldPath': 'foo'},
                'direction': 'DESCENDING',
              },
              {
                'field': {'fieldPath': '__name__'},
                'direction': 'DESCENDING',
              },
            ],
          },
        ),
      );
      await sendInitialSnapshot(events);

      backend
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendDoc(doc2, {'foo': 'a'})
        ..sendSnapshot(2);
      _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc2, {'foo': 'a'}),
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _added(doc2, {'foo': 'a'}),
          _added(doc1, {'foo': 'a'}),
        ],
      );
      await events.cancel();
    });

    test('sorts document changes in the right order', () async {
      final events = await start();
      backend
        ..sendAddTarget()
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendDoc(doc2, {'foo': 'a'})
        ..sendDoc(doc4, {'foo': 'a'})
        ..sendCurrent()
        ..sendSnapshot(1);
      lastDocs = _snapshotsEqual(
        lastDocs,
        1,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
          (doc2, {'foo': 'a'}),
          (doc4, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
          _added(doc2, {'foo': 'a'}),
          _added(doc4, {'foo': 'a'}),
        ],
      );

      backend
        ..sendDocDelete(doc1)
        ..sendDoc(doc2, {'foo': 'b'})
        ..sendDoc(doc3, {'foo': 'b'})
        ..sendDocDelete(doc4)
        ..sendSnapshot(2);
      _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc2, {'foo': 'b'}),
          (doc3, {'foo': 'b'}),
        ],
        changes: [
          _removed(doc1, {'foo': 'a'}),
          _removed(doc4, {'foo': 'a'}),
          _added(doc3, {'foo': 'b'}),
          _modified(doc2, {'foo': 'b'}),
        ],
      );
      await events.cancel();
    });

    test("handles changing a doc so it doesn't match", () async {
      final events = await start(
        query: colRef.where('included', WhereFilter.equal, 'yes'),
        expectedRequest: _queryRequest(
          structuredQuery: {
            'where': {
              'fieldFilter': {
                'field': {'fieldPath': 'included'},
                'op': 'EQUAL',
                'value': {'stringValue': 'yes'},
              },
            },
          },
        ),
      );
      await sendInitialSnapshot(events);

      backend
        ..sendDoc(doc1, {'included': 'yes'})
        ..sendSnapshot(2);
      lastDocs = _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'included': 'yes'}),
        ],
        changes: [
          _added(doc1, {'included': 'yes'}),
        ],
      );

      backend
        ..sendDoc(doc2, {'included': 'yes'})
        ..sendSnapshot(3);
      lastDocs = _snapshotsEqual(
        lastDocs,
        3,
        await events.snapshot(),
        docs: [
          (doc1, {'included': 'yes'}),
          (doc2, {'included': 'yes'}),
        ],
        changes: [
          _added(doc2, {'included': 'yes'}),
        ],
      );

      backend
        ..sendDocRemove(doc2, {'included': 'no'})
        ..sendSnapshot(4);
      _snapshotsEqual(
        lastDocs,
        4,
        await events.snapshot(),
        docs: [
          (doc1, {'included': 'yes'}),
        ],
        changes: [
          _removed(doc2, {'included': 'yes'}),
        ],
      );
      await events.cancel();
    });

    for (final (name, remove) in [
      (
        'handles deleting a doc',
        (_Backend backend, DocumentReference<DocumentData> ref) =>
            backend.sendDocDelete(ref),
      ),
      (
        'handles removing a doc',
        (_Backend backend, DocumentReference<DocumentData> ref) =>
            backend.sendDocRemove(ref, {'foo': 'c'}),
      ),
    ]) {
      test(name, () async {
        final events = await start();
        await sendInitialSnapshot(events);

        backend
          ..sendDoc(doc1, {'foo': 'a'})
          ..sendSnapshot(2);
        lastDocs = _snapshotsEqual(
          lastDocs,
          2,
          await events.snapshot(),
          docs: [
            (doc1, {'foo': 'a'}),
          ],
          changes: [
            _added(doc1, {'foo': 'a'}),
          ],
        );

        backend
          ..sendDoc(doc2, {'foo': 'b'})
          ..sendSnapshot(3);
        lastDocs = _snapshotsEqual(
          lastDocs,
          3,
          await events.snapshot(),
          docs: [
            (doc1, {'foo': 'a'}),
            (doc2, {'foo': 'b'}),
          ],
          changes: [
            _added(doc2, {'foo': 'b'}),
          ],
        );

        remove(backend, doc2);
        backend.sendSnapshot(4);
        _snapshotsEqual(
          lastDocs,
          4,
          await events.snapshot(),
          docs: [
            (doc1, {'foo': 'a'}),
          ],
          changes: [
            _removed(doc2, {'foo': 'b'}),
          ],
        );
        await events.cancel();
      });
    }

    test('handles deleting a non-existent doc', () async {
      // The delete is a no-op that delivers nothing.
      final events = await start();
      await sendInitialSnapshot(events);
      backend
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendSnapshot(2);
      lastDocs = _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
        ],
      );

      backend
        ..sendDocDelete(doc2)
        ..sendSnapshot(3)
        ..sendDoc(doc3, {'foo': 'c'})
        ..sendSnapshot(4);
      _snapshotsEqual(
        lastDocs,
        4,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
          (doc3, {'foo': 'c'}),
        ],
        changes: [
          _added(doc3, {'foo': 'c'}),
        ],
      );
      await events.cancel();
    });

    test('handles reset', () async {
      final events = await start();
      await sendInitialSnapshot(events);

      backend
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendDoc(doc2, {'foo': 'b'})
        ..sendDoc(doc3, {'foo': 'c'})
        // Same version, so the update times stay the same.
        ..sendSnapshot(1);
      lastDocs = _snapshotsEqual(
        lastDocs,
        1,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
          (doc2, {'foo': 'b'}),
          (doc3, {'foo': 'c'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
          _added(doc2, {'foo': 'b'}),
          _added(doc3, {'foo': 'c'}),
        ],
      );

      backend
        ..sendReset()
        // The same doc1, a modified doc2, no doc3, and a new doc4.
        ..sendDoc(doc1, {'foo': 'a'})
        ..snapshotVersion = 2
        ..sendDoc(doc2, {'foo': 'bb'})
        ..sendDoc(doc4, {'foo': 'd'})
        ..sendCurrent()
        ..sendSnapshot(2);
      _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
          (doc2, {'foo': 'bb'}),
          (doc4, {'foo': 'd'}),
        ],
        changes: [
          _removed(doc3, {'foo': 'c'}),
          _added(doc4, {'foo': 'd'}),
          _modified(doc2, {'foo': 'bb'}),
        ],
      );
      await events.cancel();
    });

    test('reset after idle timeout', () async {
      final events = await start();
      backend
        ..sendAddTarget()
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendCurrent()
        ..sendSnapshot(1, [0xab]);
      lastDocs = _snapshotsEqual(
        lastDocs,
        1,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
        ],
      );
      expect(idleTimers.last.duration, watchIdleTimeout);
      expect(idleTimers.where((t) => t.isActive), hasLength(1));

      final stalled = transport.current;
      idleTimers.last.fire();
      expect(stalled.closed, isTrue);
      expect(stalled.hasListener, isFalse, reason: 'responses unsubscribed');
      _verifyRequest(
        await transport.awaitOpen(),
        _queryRequest(resumeToken: [0xab]),
      );
      expect(idleTimers.where((t) => t.isActive), hasLength(1));

      // Late data and a late error on the stalled stream are ignored: the
      // invalid response would fail the watch, the error would re-open it.
      stalled
        ..write(firestore_v1.ListenResponse())
        ..destroy();
      await _settle();
      expect(events.hasPending, isFalse);
      expect(transport.streams, hasLength(2));

      backend
        ..sendAddTarget()
        ..snapshotVersion = 2
        ..sendDoc(doc2, {'foo': 'b'})
        ..sendCurrent()
        ..sendSnapshot(2);
      _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
          (doc2, {'foo': 'b'}),
        ],
        changes: [
          _added(doc2, {'foo': 'b'}),
        ],
      );
      expect(idleTimers.where((t) => t.isActive), hasLength(1));
      await events.cancel();
      expect(idleTimers.where((t) => t.isActive), isEmpty);
    });

    test('handles reset with phantom doc', () async {
      final events = await start();
      await sendInitialSnapshot(events);

      backend
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendSnapshot(2);
      lastDocs = _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
        ],
      );

      backend
        ..sendDoc(doc1, {'foo': 'b'})
        // A change that the reset discards.
        ..sendDoc(doc2, {'foo': 'c'})
        ..sendReset()
        ..sendDoc(doc1, {'foo': 'd'})
        ..sendCurrent()
        ..sendSnapshot(3);
      _snapshotsEqual(
        lastDocs,
        3,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'd'}),
        ],
        changes: [
          _modified(doc1, {'foo': 'd'}),
        ],
      );
      await events.cancel();
    });

    test('handles sending the snapshot version multiple times', () async {
      final events = await start();
      await sendInitialSnapshot(events);

      backend
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendSnapshot(2)
        ..sendSnapshot(3)
        ..sendSnapshot(4)
        ..sendSnapshot(5)
        ..sendSnapshot(6);
      _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
        ],
      );
      await _settle();
      expect(events.hasPending, isFalse);
      await events.cancel();
    });

    test('handles filter mismatch', () async {
      final events = await start();
      await sendInitialSnapshot(events);

      backend
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendSnapshot(2);
      lastDocs = _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
        ],
      );

      // A filter that doesn't match re-opens the stream, without the token.
      final oldStream = transport.current;
      backend.sendFilter(0);
      _verifyRequest(await transport.awaitOpen(), _queryRequest());
      expect(oldStream.closed, isTrue);
      expect(transport.streams, hasLength(2));

      backend
        ..sendAddTarget()
        ..sendCurrent()
        ..sendSnapshot(3);
      _snapshotsEqual(
        lastDocs,
        3,
        await events.snapshot(),
        changes: [
          _removed(doc1, {'foo': 'a'}),
        ],
      );
      await _settle();
      expect(transport.streams, hasLength(2), reason: 'own close not retried');
      await events.cancel();
    });

    group('a tokenless re-open after the stream fails', () {
      /// Delivers doc1 and doc2 at version 2 with a resume token.
      Future<_Events<DocumentData>> startWithDocs() async {
        final events = await start();
        await sendInitialSnapshot(events, [0xab]);
        backend
          ..sendDoc(doc1, {'foo': 'a'})
          ..sendDoc(doc2, {'foo': 'b'})
          ..sendSnapshot(2, [0xcd]);
        lastDocs = _snapshotsEqual(
          lastDocs,
          2,
          await events.snapshot(),
          docs: [
            (doc1, {'foo': 'a'}),
            (doc2, {'foo': 'b'}),
          ],
          changes: [
            _added(doc1, {'foo': 'a'}),
            _added(doc2, {'foo': 'b'}),
          ],
        );
        return events;
      }

      /// Fails the current stream, then answers the tokenless re-open with
      /// an empty result set, which must remove every document.
      Future<void> failAndExpectAllRemoved(_Events<DocumentData> events) async {
        transport.current.destroy();
        _verifyRequest(await transport.awaitOpen(), _queryRequest());

        backend
          ..sendAddTarget()
          ..sendCurrent()
          ..sendSnapshot(3);
        final snapshot = await events.snapshot();
        _snapshotsEqual(
          lastDocs,
          3,
          snapshot,
          changes: [
            _removed(doc1, {'foo': 'a'}),
            _removed(doc2, {'foo': 'b'}),
          ],
        );
        expect([for (final c in snapshot.changes) c.oldIndex], [0, 0]);
        expect(snapshot.size, 0);
        await events.cancel();
      }

      /// Fails the current stream and answers the tokenless re-open with
      /// the documents of [resent], unchanged since version 2.
      Future<void> failAndResend(List<_Doc> resent) async {
        transport.current.destroy();
        _verifyRequest(await transport.awaitOpen(), _queryRequest());

        backend.sendAddTarget();
        for (final (ref, data) in resent) {
          backend.sendDoc(
            ref,
            data,
            updateTime: protobuf_v1.Timestamp(seconds: 3, nanos: 1),
          );
        }
        backend
          ..sendCurrent()
          ..sendSnapshot(3, [0xef]);
      }

      final triggers = <String, Future<void> Function()>{
        'RESET': () async {
          backend.sendReset();
          await _settle();
        },
        'a filter mismatch': () async {
          backend.sendFilter(0);
          _verifyRequest(await transport.awaitOpen(), _queryRequest());
        },
      };

      for (final MapEntry(key: name, value: trigger) in triggers.entries) {
        test('keeps the removals queued by $name', () async {
          final events = await startWithDocs();
          await trigger();
          await failAndExpectAllRemoved(events);
        });

        test(
          'after $name, an unchanged full re-send changes nothing',
          () async {
            final events = await startWithDocs();
            await trigger();
            await failAndResend([
              (doc1, {'foo': 'a'}),
              (doc2, {'foo': 'b'}),
            ]);
            await _settle();
            expect(events.hasPending, isFalse, reason: 'no snapshot');

            // The next snapshot holds only the next change.
            backend
              ..sendDoc(doc3, {'foo': 'c'})
              ..sendSnapshot(4);
            _snapshotsEqual(
              lastDocs,
              4,
              await events.snapshot(),
              docs: [
                (doc1, {'foo': 'a'}),
                (doc2, {'foo': 'b'}),
                (doc3, {'foo': 'c'}),
              ],
              changes: [
                _added(doc3, {'foo': 'c'}),
              ],
            );
            await events.cancel();
          },
        );

        test('after $name, a partial re-send removes only the rest', () async {
          final events = await startWithDocs();
          await trigger();
          await failAndResend([
            (doc1, {'foo': 'a'}),
          ]);
          final snapshot = await events.snapshot();
          _snapshotsEqual(
            lastDocs,
            3,
            snapshot,
            docs: [
              (doc1, {'foo': 'a'}),
            ],
            changes: [
              _removed(doc2, {'foo': 'b'}),
            ],
          );
          expect(snapshot.changes.single.oldIndex, 1);
          await events.cancel();
        });
      }
    });

    test('handles filter match', () async {
      final events = await start();
      backend
        ..sendAddTarget()
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendCurrent()
        ..sendSnapshot(1);
      lastDocs = _snapshotsEqual(
        lastDocs,
        1,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
        ],
      );

      backend
        ..sendFilter(1)
        // Even a new snapshot version is a no-op.
        ..sendCurrent()
        ..sendSnapshot(2)
        ..sendDoc(doc2, {'foo': 'b'})
        ..sendCurrent()
        ..sendSnapshot(2);
      _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
          (doc2, {'foo': 'b'}),
        ],
        changes: [
          _added(doc2, {'foo': 'b'}),
        ],
      );
      expect(transport.streams, hasLength(1));
      await events.cancel();
    });

    test('handles resets with pending updates', () async {
      final events = await start();
      backend
        ..sendAddTarget()
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendCurrent()
        ..sendSnapshot(1);
      lastDocs = _snapshotsEqual(
        lastDocs,
        1,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
        ],
      );

      backend
        ..sendDoc(doc1, {'foo': 'b'})
        ..sendDoc(doc2, {'foo': 'c'})
        ..sendDoc(doc3, {'foo': 'd'})
        ..sendFilter(3)
        ..sendDoc(doc1, {'foo': 'd'})
        ..sendDoc(doc2, {'foo': 'e'})
        ..sendDocDelete(doc3)
        ..sendFilter(2)
        ..sendCurrent()
        ..sendSnapshot(2);
      _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'd'}),
          (doc2, {'foo': 'e'}),
        ],
        changes: [
          _added(doc2, {'foo': 'e'}),
          _modified(doc1, {'foo': 'd'}),
        ],
      );
      expect(transport.streams, hasLength(1));
      await events.cancel();
    });

    test('handles add and delete in same snapshot', () async {
      final events = await start();
      await sendInitialSnapshot(events);

      backend
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendDocDelete(doc1)
        ..sendDoc(doc2, {'foo': 'b'})
        ..sendSnapshot(2);
      _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc2, {'foo': 'b'}),
        ],
        changes: [
          _added(doc2, {'foo': 'b'}),
        ],
      );
      await events.cancel();
    });

    test('handles non-changing modify', () async {
      final events = await start();
      await sendInitialSnapshot(events);

      backend
        ..sendDoc(doc1, {'foo': 'a'})
        // Same version, so the update time stays the same.
        ..sendSnapshot(1);
      lastDocs = _snapshotsEqual(
        lastDocs,
        1,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
        ],
      );

      backend
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendDoc(doc1, {'foo': 'b'})
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendDoc(doc2, {'foo': 'c'})
        ..sendSnapshot(2);
      _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
          (doc2, {'foo': 'c'}),
        ],
        changes: [
          _added(doc2, {'foo': 'c'}),
        ],
      );
      await events.cancel();
    });

    test('handles update time change', () async {
      final events = await start();
      await sendInitialSnapshot(events);

      backend
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendSnapshot(2);
      lastDocs = _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
        ],
      );

      // The same document with a different update time.
      backend
        ..sendDoc(doc1, {
          'foo': 'a',
        }, updateTime: protobuf_v1.Timestamp(seconds: 3, nanos: 5))
        ..sendSnapshot(3);
      _snapshotsEqual(
        lastDocs,
        3,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _modified(doc1, {'foo': 'a'}),
        ],
      );
      await events.cancel();
    });

    test('handles delete and re-add in same snapshot', () async {
      final events = await start();
      await sendInitialSnapshot(events);

      backend
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendSnapshot(1);
      lastDocs = _snapshotsEqual(
        lastDocs,
        1,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
        ],
        changes: [
          _added(doc1, {'foo': 'a'}),
        ],
      );

      // Same version, so the re-added doc has the same update time.
      backend
        ..sendDocDelete(doc1)
        ..sendDoc(doc1, {'foo': 'a'})
        ..sendDoc(doc2, {'foo': 'b'})
        ..sendSnapshot(2);
      _snapshotsEqual(
        lastDocs,
        2,
        await events.snapshot(),
        docs: [
          (doc1, {'foo': 'a'}),
          (doc2, {'foo': 'b'}),
        ],
        changes: [
          _added(doc2, {'foo': 'b'}),
        ],
      );
      await events.cancel();
    });

    group('Listen stream contract', () {
      for (final (name, type) in [
        ('REMOVE', firestore_v1.TargetChange_TargetChangeType.remove),
        (
          'an unknown type',
          const firestore_v1.TargetChange_TargetChangeType('INVALID'),
        ),
      ]) {
        test('$name with a resume token fails the watch, then still '
            'resets the backoff', () async {
          final events = await start();
          await sendInitialSnapshot(events, [0xab]);
          final resetsBefore = backoff.resetCalls;
          backend.write(
            firestore_v1.ListenResponse(
              targetChange: firestore_v1.TargetChange(
                targetChangeType: type,
                targetIds: [_targetId],
                resumeToken: Uint8List.fromList([0xcd]),
              ),
            ),
          );
          expect(await events.error(), isA<FirestoreException>());
          expect(
            backoff.resetCalls,
            resetsBefore + 1,
            reason: 'the change falls through to the resume token check',
          );
          await _settle();
          expect(events.hasPending, isFalse, reason: 'no event follows');
          expect(transport.streams, hasLength(1), reason: 'no reconnect');
          expect(transport.current.closed, isTrue);
        });
      }

      test('a permission failure as target REMOVE fails the watch', () async {
        final events = await start();
        await sendInitialSnapshot(events, [0xab]);
        backend.sendRemoveTarget(StatusCode.permissionDenied.value);
        expect(
          await events.error(),
          _firestoreError(
            FirestoreClientErrorCode.permissionDenied,
            'test remove',
          ),
        );
        await _settle();
        expect(transport.current.closed, isTrue);
        expect(transport.streams, hasLength(1));
      });

      test('unauthenticated is retried until the backoff gives up', () async {
        final events = await start();
        final error = FirestoreException(
          FirestoreClientErrorCode.unauthenticated,
          'Could not obtain an access token',
        );
        transport.failNewStreamsWith = error;
        transport.current.destroy(error);
        expect(await events.error(), same(error));
        expect(
          transport.streams,
          hasLength(1 + ExponentialBackoff.maxRetryAttempts),
        );
      });

      test(
        'an unknown project ID fails the watch without leaking a stream',
        () async {
          final undiscovered = Firestore(
            settings: const Settings(environmentOverride: {}),
          );
          addTearDown(undiscovered.terminate);
          final events = _Events(
            queryWatch(undiscovered.collection('col')).snapshots,
          );
          expect(await events.error(), isStateError);
          await _settle();
          expect(
            transport.streams,
            isEmpty,
            reason: 'the request is built before any stream opens',
          );
          expect(idleTimers, isEmpty);
        },
      );

      test('a failed first request closes its stream', () async {
        final error = StateError('send failed');
        transport.failSendsWith = error;
        final events = _Events(queryWatch(colRef).snapshots);
        expect(await events.error(), same(error));
        await _settle();
        expect(transport.streams, hasLength(1), reason: 'no reconnect');
        expect(transport.current.closed, isTrue);
        expect(idleTimers, isEmpty);
      });

      test(
        'drops what a replaced stream delivers after cancellation',
        () async {
          // Exercises the guards against a stream that ignores cancellation.
          transport.ignoreCancel = true;
          final events = await start();
          await sendInitialSnapshot(events, [0xab]);

          final stalled = transport.current;
          idleTimers.last.fire();
          expect(stalled.closed, isTrue);
          expect(stalled.hasListener, isTrue, reason: 'cancellation ignored');
          _verifyRequest(
            await transport.awaitOpen(),
            _queryRequest(resumeToken: [0xab]),
          );

          // The invalid response would fail the watch, the error and the end
          // would each abandon the new stream and open another.
          stalled
            ..write(firestore_v1.ListenResponse())
            ..destroy();
          await _settle();
          expect(events.hasPending, isFalse);
          expect(transport.streams, hasLength(2));
          expect(transport.current.closed, isFalse);

          backend
            ..sendAddTarget()
            ..sendDoc(doc1, {'foo': 'a'})
            ..sendCurrent()
            ..sendSnapshot(2);
          _snapshotsEqual(
            lastDocs,
            2,
            await events.snapshot(),
            docs: [
              (doc1, {'foo': 'a'}),
            ],
            changes: [
              _added(doc1, {'foo': 'a'}),
            ],
          );
          await events.cancel();
        },
      );

      test('cancelling closes the stream without reconnecting', () async {
        final events = await start();
        await sendInitialSnapshot(events, [0xab]);
        final stream = transport.current;
        await events.cancel();
        expect(stream.closed, isTrue);
        expect(stream.hasListener, isFalse, reason: 'responses unsubscribed');
        expect(idleTimers.last.isActive, isFalse);

        // Late data and a late error after the watch stopped are ignored:
        // neither a snapshot nor a re-opened stream follows.
        backend
          ..sendDoc(doc1, {'foo': 'a'})
          ..sendSnapshot(2);
        stream.destroy();
        await _settle();
        expect(events.hasPending, isFalse);
        expect(transport.streams, hasLength(1));
      });

      test('snapshots wait for CURRENT', () async {
        final events = await start();
        backend
          ..sendAddTarget()
          ..sendDoc(doc1, {'foo': 'a'})
          ..sendSnapshot(1);
        await _settle();
        expect(events.hasPending, isFalse);

        backend
          ..sendCurrent()
          ..sendSnapshot(2);
        _snapshotsEqual(
          lastDocs,
          2,
          await events.snapshot(),
          docs: [
            (doc1, {'foo': 'a'}),
          ],
          changes: [
            _added(doc1, {'foo': 'a'}),
          ],
        );
        await events.cancel();
      });

      test('a paused listener does not stall the stream', () async {
        final watch = queryWatch(colRef);
        final received = <WatchSnapshot<DocumentData>>[];
        final subscription = watch.snapshots.listen(received.add);
        await transport.awaitOpen();
        subscription.pause();

        backend
          ..sendAddTarget()
          ..sendCurrent()
          ..sendSnapshot(1)
          ..sendDoc(doc1, {'foo': 'a'})
          ..sendSnapshot(2);
        await _settle();
        expect(received, isEmpty);

        subscription.resume();
        await _settle();
        expect([for (final s in received) s.size], [0, 1]);
        await subscription.cancel();
      });
    });
  });

  group('DocumentReference watch', () {
    late DocumentReference<DocumentData> doc;

    setUp(() => doc = firestore.doc('col/doc'));

    Future<_Events<DocumentData>> start() async {
      final events = _Events(
        Watch.document(
          doc,
          transport: transport,
          backoff: backoff,
          createTimer: createTimer,
        ).snapshots,
      );
      _verifyRequest(await transport.awaitOpen(), _documentRequest('col/doc'));
      return events;
    }

    Future<DocumentSnapshot<DocumentData>> next(
      _Events<DocumentData> events,
    ) async => (await events.snapshot()).documentFor(doc);

    Future<void> sendInitialSnapshot(_Events<DocumentData> events) async {
      backend
        ..sendAddTarget()
        ..sendCurrent()
        ..sendSnapshot(1);
      final snapshot = await next(events);
      expect(snapshot.exists, isFalse);
      expect(snapshot.readTime, _version(1));
    }

    test('handles invalid listen protos', () async {
      final events = await start();
      backend.write(firestore_v1.ListenResponse());
      expect(
        await events.error(),
        _firestoreError(
          FirestoreClientErrorCode.internal,
          'Unknown listen response type: {}',
        ),
      );
    });

    test('handles invalid target change protos', () async {
      final events = await start();
      backend.write(
        firestore_v1.ListenResponse(
          targetChange: firestore_v1.TargetChange(
            targetChangeType: const firestore_v1.TargetChange_TargetChangeType(
              'INVALID',
            ),
            targetIds: [0xfeed],
          ),
        ),
      );
      expect(
        await events.error(),
        _firestoreError(
          FirestoreClientErrorCode.internal,
          'Unknown target change type: '
          '{"targetChangeType":"INVALID","targetIds":[65261]}',
        ),
      );
    });

    test('handles remove target change protos', () async {
      final events = await start();
      backend.sendRemoveTarget();
      expect(
        await events.error(),
        _firestoreError(FirestoreClientErrorCode.internal, 'internal error'),
      );
    });

    test('handles remove target change with code', () async {
      final events = await start();
      backend.sendRemoveTarget(7);
      expect(
        await events.error(),
        _firestoreError(
          FirestoreClientErrorCode.permissionDenied,
          'test remove',
        ),
      );
    });

    test('handles changing a doc', () async {
      final events = await start();
      await sendInitialSnapshot(events);

      backend
        ..sendDoc(doc, {'foo': 'a'})
        ..sendSnapshot(2);
      var snapshot = await next(events);
      expect(snapshot.exists, isTrue);
      expect(snapshot.createTime, Timestamp(seconds: 1, nanoseconds: 2));
      expect(snapshot.updateTime, Timestamp(seconds: 3, nanoseconds: 1));
      expect(snapshot.readTime, _version(2));
      expect(snapshot.get('foo')?.value, 'a');

      backend
        ..sendDoc(doc, {'foo': 'b'})
        ..sendSnapshot(3);
      snapshot = await next(events);
      expect(snapshot.exists, isTrue);
      expect(snapshot.get('foo')?.value, 'b');
      await events.cancel();
    });

    test('ignores non-matching doc', () async {
      final events = await start();
      await sendInitialSnapshot(events);

      backend
        ..write(
          firestore_v1.ListenResponse(
            documentChange: firestore_v1.DocumentChange(
              document: firestore_v1.Document(
                name: '$_documents/col/wrong',
                createTime: protobuf_v1.Timestamp(seconds: 1, nanos: 2),
                updateTime: protobuf_v1.Timestamp(seconds: 3, nanos: 4),
              ),
              targetIds: [_targetId],
            ),
          ),
        )
        ..sendSnapshot(2);
      expect((await next(events)).exists, isFalse);
      await events.cancel();
    });

    test('reconnects after error', () async {
      const resumeToken = [0xab];
      final events = await start();
      await sendInitialSnapshot(events);

      backend
        ..sendDoc(doc, {'foo': 'a'})
        ..sendSnapshot(2, resumeToken);
      var snapshot = await next(events);
      expect(snapshot.exists, isTrue);
      expect(snapshot.get('foo')?.value, 'a');

      transport.current.destroy();
      _verifyRequest(
        await transport.awaitOpen(),
        _documentRequest('col/doc', resumeToken: resumeToken),
      );
      backend
        ..sendDoc(doc, {'foo': 'b'})
        ..sendSnapshot(3, resumeToken);
      snapshot = await next(events);
      expect(snapshot.exists, isTrue);
      expect(snapshot.get('foo')?.value, 'b');

      backend
        ..sendDocDelete(doc)
        ..sendSnapshot(4);
      snapshot = await next(events);
      expect(snapshot.exists, isFalse);
      expect(transport.streams, hasLength(2));
      await events.cancel();
    });

    test('combines multiple change events for the same doc', () async {
      final events = await start();
      backend
        ..sendAddTarget()
        ..sendDoc(doc, {'foo': 'a'})
        ..sendDoc(doc, {'foo': 'b'})
        ..sendCurrent()
        ..sendSnapshot(1);
      expect((await next(events)).get('foo')?.value, 'b');

      backend
        ..sendDoc(doc, {'foo': 'c'})
        ..sendDoc(doc, {'foo': 'd'})
        ..sendSnapshot(2);
      expect((await next(events)).get('foo')?.value, 'd');

      backend
        ..sendDocRemove(doc, {'foo': 'e'})
        ..sendDocDelete(doc)
        ..sendDoc(doc, {'foo': 'f'})
        ..sendSnapshot(3);
      expect((await next(events)).get('foo')?.value, 'f');
      await events.cancel();
    });

    for (final (name, remove) in [
      ('handles deleting a doc', (_Backend backend) => backend.sendDocDelete),
      (
        'handles removing a doc',
        (_Backend backend) =>
            (DocumentReference<DocumentData> ref) =>
                backend.sendDocRemove(ref, {'foo': 'c'}),
      ),
    ]) {
      test(name, () async {
        final events = await start();
        await sendInitialSnapshot(events);

        backend
          ..sendDoc(doc, {'foo': 'a'})
          ..sendSnapshot(2);
        expect((await next(events)).exists, isTrue);

        remove(backend)(doc);
        backend.sendSnapshot(3);
        expect((await next(events)).exists, isFalse);
        await events.cancel();
      });
    }

    test('handles reset', () async {
      final events = await start();
      await sendInitialSnapshot(events);

      backend
        ..sendDoc(doc, {'foo': 'a'})
        ..sendSnapshot(2);
      expect((await next(events)).get('foo')?.value, 'a');

      backend
        ..sendReset()
        ..sendDoc(doc, {'foo': 'b'})
        ..sendCurrent()
        ..sendSnapshot(3);
      expect((await next(events)).get('foo')?.value, 'b');
      await events.cancel();
    });
  });

  group('Query comparator', () {
    late CollectionReference<DocumentData> colRef;

    setUp(() => colRef = firestore.collection('col'));

    /// Watches [query], sends [input] in one snapshot and returns the
    /// delivered order.
    Future<WatchSnapshot<DocumentData>> sortThroughWatch(
      Query<DocumentData> query,
      List<_Doc> input,
    ) async {
      final events = _Events(queryWatch(query).snapshots);
      await transport.awaitOpen();
      backend.sendAddTarget();
      for (final (ref, data) in input) {
        backend.sendDoc(ref, data);
      }
      backend
        ..sendCurrent()
        ..sendSnapshot(1);
      final snapshot = await events.snapshot();
      await events.cancel();
      return snapshot;
    }

    void expectOrder(WatchSnapshot<DocumentData> snapshot, List<_Doc> docs) {
      _snapshotsEqual(
        [],
        1,
        snapshot,
        docs: docs,
        changes: [for (final (ref, data) in docs) _added(ref, data)],
      );
    }

    test('handles basic case', () async {
      final snapshot = await sortThroughWatch(colRef.orderBy('foo'), [
        (firestore.doc('col/doc3'), {'foo': 2}),
        (firestore.doc('col/doc4'), {'foo': 1}),
        (firestore.doc('col/doc2'), {'foo': 2}),
      ]);
      expectOrder(snapshot, [
        (firestore.doc('col/doc4'), {'foo': 1}),
        (firestore.doc('col/doc2'), {'foo': 2}),
        (firestore.doc('col/doc3'), {'foo': 2}),
      ]);
    });

    test('handles descending case', () async {
      final snapshot = await sortThroughWatch(
        colRef.orderBy('foo', descending: true),
        [
          (firestore.doc('col/doc3'), {'foo': 2}),
          (firestore.doc('col/doc4'), {'foo': 1}),
          (firestore.doc('col/doc2'), {'foo': 2}),
        ],
      );
      expectOrder(snapshot, [
        (firestore.doc('col/doc3'), {'foo': 2}),
        (firestore.doc('col/doc2'), {'foo': 2}),
        (firestore.doc('col/doc4'), {'foo': 1}),
      ]);
    });

    test('handles nested fields', () async {
      final snapshot = await sortThroughWatch(colRef.orderBy('foo.bar'), [
        (
          firestore.doc('col/doc3'),
          {
            'foo': {'bar': 2},
          },
        ),
        (
          firestore.doc('col/doc1'),
          {
            'foo': {'bar': 1},
          },
        ),
        (
          firestore.doc('col/doc2'),
          {
            'foo': {'bar': 2},
          },
        ),
      ]);
      expectOrder(snapshot, [
        (
          firestore.doc('col/doc1'),
          {
            'foo': {'bar': 1},
          },
        ),
        (
          firestore.doc('col/doc2'),
          {
            'foo': {'bar': 2},
          },
        ),
        (
          firestore.doc('col/doc3'),
          {
            'foo': {'bar': 2},
          },
        ),
      ]);
    });

    test('fails on missing fields', () async {
      final events = _Events(queryWatch(colRef.orderBy('bar')).snapshots);
      await transport.awaitOpen();
      backend
        ..sendAddTarget()
        ..sendDoc(firestore.doc('col/doc3'), {'foo': 2})
        ..sendDoc(firestore.doc('col/doc1'), {'foo': 1})
        ..sendCurrent()
        ..sendSnapshot(1);
      expect(
        await events.error(),
        isA<StateError>().having(
          (e) => e.message,
          'message',
          startsWith("Trying to compare documents on fields that don't exist"),
        ),
      );
    });
  });
}
