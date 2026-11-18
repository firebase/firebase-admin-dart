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

import 'package:google_cloud_firestore/src/credential.dart';
import 'package:google_cloud_firestore/src/firestore.dart';
import 'package:google_cloud_firestore/src/firestore_exception.dart';
import 'package:google_cloud_firestore/src/firestore_http_client.dart';
import 'package:google_cloud_firestore/src/watch/listen_transport.dart';
import 'package:google_cloud_firestore_v1/firestore.dart' as firestore_v1;
import 'package:google_cloud_protobuf/protobuf.dart' as protobuf_v1;
import 'package:test/test.dart';

const _projectId = 'test-project';
const _database = 'projects/$_projectId/databases/(default)';
const _documents = '$_database/documents';
const _targetId = 0x1;

/// A [ListenStream] whose responses the test pushes.
final class _FakeListenStream implements ListenStream {
  final _responses = StreamController<firestore_v1.ListenResponse>();
  final requests = <firestore_v1.ListenRequest>[];
  bool closed = false;

  /// Thrown by [close], when set.
  Error? closeError;

  /// When set, [close] waits for it before finishing.
  Completer<void>? closeGate;

  @override
  Stream<firestore_v1.ListenResponse> get responses => _responses.stream;

  @override
  void send(firestore_v1.ListenRequest request) {
    if (closed) throw StateError('ListenStream has already ended.');
    requests.add(request);
  }

  @override
  Future<void> close() async {
    closed = true;
    await closeGate?.future;
    if (closeError case final error?) throw error;
  }

  void write(firestore_v1.ListenResponse response) {
    if (!_responses.isClosed) _responses.add(response);
  }

  /// Fails the call with [error].
  void fail(Object error) {
    if (_responses.isClosed) return;
    _responses.addError(error);
    unawaited(_responses.close());
  }
}

final class _FakeListenTransport implements ListenTransport {
  final streams = <_FakeListenStream>[];
  final _waiters = <Completer<_FakeListenStream>>[];
  var _taken = 0;
  bool closed = false;

  @override
  ListenStream open() {
    if (closed) throw StateError('Transport has already been closed.');
    final stream = _FakeListenStream();
    streams.add(stream);
    if (_waiters.isNotEmpty) {
      _taken++;
      _waiters.removeAt(0).complete(stream);
    }
    return stream;
  }

  /// The next stream a listener opens.
  Future<_FakeListenStream> nextStream() {
    if (_taken < streams.length) return Future.value(streams[_taken++]);
    final completer = Completer<_FakeListenStream>();
    _waiters.add(completer);
    return completer.future;
  }

  /// Thrown by [close] once the streams are closed, when set.
  Error? closeError;

  /// Closes the streams not closed yet, as closing the channel ends their
  /// calls, then rethrows the first error closing one, or [closeError].
  @override
  Future<void> close() async {
    closed = true;
    await Future.wait([
      for (final stream in streams)
        if (!stream.closed) stream.close(),
    ]);
    if (closeError case final error?) throw error;
  }
}

/// A client whose project ID is only known once [resolve] completes, as
/// when it comes from the metadata server.
final class _UndiscoveredProjectClient extends FirestoreHttpClient {
  _UndiscoveredProjectClient()
    : super(
        credential: Credential.fromApplicationDefaultCredentials(),
        settings: const Settings(environmentOverride: {}),
      );

  final resolve = Completer<String>();
  String? _resolved;
  int resolveCalls = 0;

  @override
  String? get cachedProjectId => _resolved;

  @override
  String? getProjectId() => _resolved;

  @override
  Future<String> resolveProjectId() async {
    resolveCalls++;
    return _resolved = await resolve.future;
  }
}

/// A client with a known project ID that records whether it was closed.
final class _RecordingClient extends FirestoreHttpClient {
  _RecordingClient()
    : super(
        credential: Credential.fromApplicationDefaultCredentials(),
        settings: const Settings(projectId: _projectId),
      );

  bool closed = false;

  @override
  Future<void> close() {
    closed = true;
    return super.close();
  }
}

/// Records the events of a stream, to be awaited in order.
final class _Events<T> {
  _Events(Stream<T> stream) {
    subscription = stream.listen(
      _add,
      onError: (Object error) => _add(_Error(error)),
      onDone: () => _add(const _Done()),
    );
  }

  late final StreamSubscription<T> subscription;
  final _pending = <Object?>[];
  final _waiters = <Completer<Object?>>[];

  void _add(Object? event) {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(event);
    } else {
      _pending.add(event);
    }
  }

  Future<Object?> next() {
    if (_pending.isNotEmpty) return Future.value(_pending.removeAt(0));
    final completer = Completer<Object?>();
    _waiters.add(completer);
    return completer.future;
  }

  bool get hasPending => _pending.isNotEmpty;

  Future<T> snapshot() async {
    final event = await next();
    if (event is T) return event;
    fail('Expected a snapshot, got $event');
  }

  Future<Object> error() async {
    final event = await next();
    if (event is _Error) {
      expect(await next(), isA<_Done>(), reason: 'closes after an error');
      return event.error;
    }
    fail('Expected an error, got $event');
  }

  Future<void> done() async {
    final event = await next();
    expect(event, isA<_Done>());
  }

  Future<void> cancel() => subscription.cancel();
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

/// Sends backend responses on one stream.
final class _Backend {
  _Backend(this.stream, this.firestore, {int version = 0}) : _version = version;

  final _FakeListenStream stream;
  final Firestore firestore;
  int _version;

  void sendAddTarget() => stream.write(
    firestore_v1.ListenResponse(
      targetChange: firestore_v1.TargetChange(
        targetChangeType: firestore_v1.TargetChange_TargetChangeType.add,
        targetIds: [_targetId],
      ),
    ),
  );

  void sendCurrent() => stream.write(
    firestore_v1.ListenResponse(
      targetChange: firestore_v1.TargetChange(
        targetChangeType: firestore_v1.TargetChange_TargetChangeType.current,
        targetIds: [_targetId],
      ),
    ),
  );

  /// Marks everything up to here consistent at the next version.
  void sendSnapshot() {
    _version++;
    stream.write(
      firestore_v1.ListenResponse(
        targetChange: firestore_v1.TargetChange(
          readTime: protobuf_v1.Timestamp(seconds: 0, nanos: _version),
        ),
      ),
    );
  }

  void sendDoc(DocumentReference<Object?> ref, DocumentData data) =>
      stream.write(
        firestore_v1.ListenResponse(
          documentChange: firestore_v1.DocumentChange(
            document: firestore_v1.Document(
              name: '$_documents/${ref.path}',
              fields: firestore.serializer.encodeFields(data).fields,
              createTime: protobuf_v1.Timestamp(seconds: 1),
              updateTime: protobuf_v1.Timestamp(seconds: 2, nanos: _version),
            ),
            targetIds: [_targetId],
          ),
        ),
      );

  void sendDocDelete(DocumentReference<Object?> ref) => stream.write(
    firestore_v1.ListenResponse(
      documentDelete: firestore_v1.DocumentDelete(
        document: '$_documents/${ref.path}',
        removedTargetIds: [_targetId],
      ),
    ),
  );

  /// Opens the target and delivers its first, empty snapshot.
  void sendInitial() {
    sendAddTarget();
    sendCurrent();
    sendSnapshot();
  }
}

Timestamp _version(int version) => Timestamp(seconds: 0, nanoseconds: version);

final class _City {
  const _City(this.name);
  final String name;
}

void main() {
  late _FakeListenTransport transport;
  late Firestore firestore;
  var transportsCreated = 0;

  setUp(() {
    transport = _FakeListenTransport();
    transportsCreated = 0;
    firestore = Firestore.internal(
      settings: const Settings(projectId: _projectId),
      listenTransport: () {
        transportsCreated++;
        return transport;
      },
    );
  });

  tearDown(() => firestore.terminate());

  Future<_Backend> nextBackend() async =>
      _Backend(await transport.nextStream(), firestore);

  group('DocumentReference.snapshots()', () {
    test('delivers a document as it is created, changed and deleted', () async {
      final ref = firestore.doc('col/doc');
      final events = _Events(ref.snapshots());
      final backend = await nextBackend();

      expect(backend.stream.requests.single.toJson(), {
        'database': _database,
        'addTarget': {
          'documents': {
            'documents': ['$_documents/col/doc'],
          },
          'targetId': _targetId,
        },
      });

      backend.sendInitial();
      var snapshot = await events.snapshot();
      expect(snapshot.exists, isFalse);
      expect(snapshot.ref, ref);
      expect(snapshot.readTime, _version(1));

      backend
        ..sendDoc(ref, {'foo': 'a'})
        ..sendSnapshot();
      snapshot = await events.snapshot();
      expect(snapshot.exists, isTrue);
      expect(snapshot.data(), {'foo': 'a'});
      expect(snapshot.readTime, _version(2));

      backend
        ..sendDoc(ref, {'foo': 'b'})
        ..sendSnapshot();
      snapshot = await events.snapshot();
      expect(snapshot.data(), {'foo': 'b'});

      backend
        ..sendDocDelete(ref)
        ..sendSnapshot();
      snapshot = await events.snapshot();
      expect(snapshot.exists, isFalse);
      expect(snapshot.readTime, _version(4));
    });

    test('converts documents with withConverter', () async {
      final ref = firestore
          .doc('col/doc')
          .withConverter<_City>(
            fromFirestore: (snapshot) =>
                _City(snapshot.data()['name']! as String),
            toFirestore: (city) => {'name': city.name},
          );
      final events = _Events(ref.snapshots());
      final backend = await nextBackend();

      backend
        ..sendAddTarget()
        ..sendCurrent()
        ..sendDoc(ref, {'name': 'SF'})
        ..sendSnapshot();
      final snapshot = await events.snapshot();
      expect(snapshot, isA<DocumentSnapshot<_City>>());
      expect(snapshot.ref, ref);
      expect(snapshot.data()?.name, 'SF');
    });

    test('opens nothing until listened to', () async {
      final stream = firestore.doc('col/doc').snapshots();
      await _settle();
      expect(transportsCreated, 0);
      expect(transport.streams, isEmpty);

      final events = _Events(stream);
      await nextBackend();
      expect(transport.streams, hasLength(1));
      await events.cancel();
    });

    test('opens a stream for every listen', () async {
      final stream = firestore.doc('col/doc').snapshots();
      expect(stream.isBroadcast, isFalse);

      final first = _Events(stream);
      final firstBackend = await nextBackend();
      final second = _Events(stream);
      final secondBackend = await nextBackend();
      expect(transportsCreated, 1, reason: 'the transport is shared');

      firstBackend.sendInitial();
      secondBackend.sendInitial();
      expect((await first.snapshot()).exists, isFalse);
      expect((await second.snapshot()).exists, isFalse);

      await first.cancel();
      expect(firstBackend.stream.closed, isTrue);
      expect(secondBackend.stream.closed, isFalse);
      await second.cancel();
    });

    test('closes the listen stream when cancelled', () async {
      final events = _Events(firestore.doc('col/doc').snapshots());
      final backend = await nextBackend();
      backend.sendInitial();
      await events.snapshot();

      await events.cancel();
      expect(backend.stream.closed, isTrue);
      expect(transport.closed, isFalse, reason: 'other listeners may use it');
    });

    test('fails the cancel when the listen stream fails to close', () async {
      final events = _Events(firestore.doc('col/doc').snapshots());
      final backend = await nextBackend();
      backend.sendInitial();
      await events.snapshot();
      backend.stream.closeError = StateError('close failed');

      await expectLater(
        events.cancel(),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'close failed'),
        ),
      );
      expect(backend.stream.closed, isTrue);
      expect(firestore.activeSnapshotListenerCount, 0);
    });

    test('closes the listen stream when cancelled before it opens', () async {
      final events = _Events(firestore.doc('col/doc').snapshots());
      await events.cancel();
      await _settle();
      expect(transport.streams.where((stream) => !stream.closed), isEmpty);
    });

    test('delivers a permanent error, then closes', () async {
      final events = _Events(firestore.doc('col/doc').snapshots());
      final backend = await nextBackend();
      backend.stream.fail(
        FirestoreException(
          FirestoreClientErrorCode.permissionDenied,
          'Missing permissions',
        ),
      );

      final error = await events.error();
      expect(
        error,
        isA<FirestoreException>().having(
          (e) => e.errorCode,
          'errorCode',
          FirestoreClientErrorCode.permissionDenied,
        ),
      );
      expect(backend.stream.closed, isTrue);
      expect(firestore.activeSnapshotListenerCount, 0);
    });

    test('unregisters a listener whose watch ends while paused', () async {
      final events = _Events(firestore.doc('col/doc').snapshots());
      final backend = await nextBackend();
      events.subscription.pause();
      backend.stream.fail(
        FirestoreException(
          FirestoreClientErrorCode.permissionDenied,
          'Missing permissions',
        ),
      );
      await _settle();

      // The consumer has not seen done yet, but the watch has ended.
      expect(events.hasPending, isFalse);
      expect(firestore.activeSnapshotListenerCount, 0);

      events.subscription.resume();
      expect(await events.error(), isA<FirestoreException>());
    });

    test('unregisters a listener once it is cancelled', () async {
      final events = _Events(firestore.doc('col/doc').snapshots());
      await nextBackend();
      expect(firestore.activeSnapshotListenerCount, 1);

      await events.cancel();
      expect(firestore.activeSnapshotListenerCount, 0);
    });
  });

  group('Query.snapshots()', () {
    test('carries the changes and read time of the watch', () async {
      final col = firestore.collection('col');
      final query = col.orderBy('n');
      final events = _Events(query.snapshots());
      final backend = await nextBackend();
      backend.sendInitial();

      var snapshot = await events.snapshot();
      expect(snapshot.query, query);
      expect(snapshot.readTime, _version(1));
      expect(snapshot.docs, isEmpty);
      expect(snapshot.docChanges, isEmpty);

      final a = col.doc('a');
      final b = col.doc('b');
      final c = col.doc('c');
      backend
        ..sendDoc(a, {'n': 1})
        ..sendDoc(b, {'n': 2})
        ..sendDoc(c, {'n': 3})
        ..sendSnapshot();
      snapshot = await events.snapshot();
      expect(snapshot.readTime, _version(2));
      expect([for (final doc in snapshot.docs) doc.id], ['a', 'b', 'c']);
      expect(
        [
          for (final change in snapshot.docChanges)
            (change.type, change.doc.id, change.oldIndex, change.newIndex),
        ],
        [
          (DocumentChangeType.added, 'a', -1, 0),
          (DocumentChangeType.added, 'b', -1, 1),
          (DocumentChangeType.added, 'c', -1, 2),
        ],
      );

      // Moves `a` to the end and removes `b`: not derivable from the docs.
      backend
        ..sendDocDelete(b)
        ..sendDoc(a, {'n': 4})
        ..sendSnapshot();
      snapshot = await events.snapshot();
      expect(snapshot.readTime, _version(3));
      expect([for (final doc in snapshot.docs) doc.id], ['c', 'a']);
      expect(
        [
          for (final change in snapshot.docChanges)
            (change.type, change.doc.id, change.oldIndex, change.newIndex),
        ],
        [
          (DocumentChangeType.removed, 'b', 1, -1),
          (DocumentChangeType.modified, 'a', 0, 1),
        ],
      );
      expect(snapshot.docChanges.last.doc.data(), {'n': 4});
    });

    test('converts documents with withConverter', () async {
      final col = firestore
          .collection('col')
          .withConverter<_City>(
            fromFirestore: (snapshot) =>
                _City(snapshot.data()['name']! as String),
            toFirestore: (city) => {'name': city.name},
          );
      final events = _Events(col.snapshots());
      final backend = await nextBackend();

      backend
        ..sendAddTarget()
        ..sendCurrent()
        ..sendDoc(col.doc('sf'), {'name': 'SF'})
        ..sendSnapshot();
      final snapshot = await events.snapshot();
      expect(snapshot, isA<QuerySnapshot<_City>>());
      expect(snapshot.query, col);
      expect(snapshot.docs.single.data().name, 'SF');
      expect(snapshot.docChanges.single.doc.data().name, 'SF');
    });

    test('listens to a collection group', () async {
      final group = firestore.collectionGroup('cities');
      final events = _Events(group.snapshots());
      final backend = await nextBackend();

      final target = backend.stream.requests.single.addTarget!.query!;
      expect(target.parent, _documents);
      expect(target.structuredQuery!.from.single.allDescendants, isTrue);

      backend.sendInitial();
      expect((await events.snapshot()).query, group);
    });

    test('keeps reading while paused and buffers snapshots', () async {
      final col = firestore.collection('col');
      final events = _Events(col.snapshots());
      final backend = await nextBackend();
      events.subscription.pause();

      backend
        ..sendInitial()
        ..sendDoc(col.doc('a'), {'n': 1})
        ..sendSnapshot();
      await _settle();
      expect(events.hasPending, isFalse);

      events.subscription.resume();
      expect((await events.snapshot()).size, 0);
      expect((await events.snapshot()).size, 1);
    });

    test('listens to a limitToLast query in ascending order', () async {
      final col = firestore.collection('col');
      final query = col.orderBy('n').limitToLast(2);
      final events = _Events(query.snapshots());
      final backend = await nextBackend();

      final structuredQuery =
          backend.stream.requests.single.addTarget!.query!.structuredQuery!;
      expect(
        [
          for (final order in structuredQuery.orderBy)
            (order.field!.fieldPath, order.direction),
        ],
        [('n', firestore_v1.StructuredQuery_Direction.descending)],
      );
      expect(structuredQuery.limit?.value, 2);

      backend
        ..sendAddTarget()
        ..sendCurrent()
        ..sendDoc(col.doc('c'), {'n': 3})
        ..sendDoc(col.doc('b'), {'n': 2})
        ..sendSnapshot();
      final snapshot = await events.snapshot();
      expect([for (final doc in snapshot.docs) doc.id], ['b', 'c']);
    });

    test('rejects a limitToLast query without orderBy', () async {
      final events = _Events(
        firestore.collection('col').limitToLast(2).snapshots(),
      );

      expect(
        await events.error(),
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('orderBy()'),
        ),
      );
      expect(transport.streams, isEmpty);
      expect(firestore.activeSnapshotListenerCount, 0);
    });
  });

  group('Firestore.terminate()', () {
    test('closes every listener and the transport', () async {
      final docEvents = _Events(firestore.doc('col/doc').snapshots());
      final docBackend = await nextBackend();
      final queryEvents = _Events(firestore.collection('col').snapshots());
      final queryBackend = await nextBackend();
      docBackend.sendInitial();
      queryBackend.sendInitial();
      await docEvents.snapshot();
      await queryEvents.snapshot();

      await firestore.terminate();

      await docEvents.done();
      await queryEvents.done();
      expect(docBackend.stream.closed, isTrue);
      expect(queryBackend.stream.closed, isTrue);
      expect(transport.closed, isTrue);
    });

    test('closes a listener that is still resolving the project ID', () async {
      final client = _UndiscoveredProjectClient();
      final undiscovered = Firestore.internal(
        client: client,
        listenTransport: () => transport,
      );

      final events = _Events(undiscovered.doc('col/doc').snapshots());
      await _settle();
      await undiscovered.terminate();
      await events.done();

      client.resolve.complete(_projectId);
      await _settle();
      expect(transport.streams, isEmpty);
    });

    test('drops a failure to resolve the project ID after closing', () async {
      final client = _UndiscoveredProjectClient();
      final undiscovered = Firestore.internal(
        client: client,
        listenTransport: () => transport,
      );

      final events = _Events(undiscovered.doc('col/doc').snapshots());
      await _settle();
      await undiscovered.terminate();
      await events.done();

      // The listener's stream is already closed: adding the failure to it
      // would be an uncaught error, failing this test.
      client.resolve.completeError(StateError('No project ID'));
      await _settle();
      expect(events.hasPending, isFalse);
      expect(transport.streams, isEmpty);
    });

    test('closes everything when a listen stream fails to close', () async {
      final client = _RecordingClient();
      final failing = Firestore.internal(
        client: client,
        listenTransport: () => transport,
      );

      final first = _Events(failing.doc('col/a').snapshots());
      final firstStream = await transport.nextStream();
      final second = _Events(failing.collection('col').snapshots());
      final secondStream = await transport.nextStream();
      firstStream.closeError = StateError('close failed');
      transport.closeError = StateError('transport close failed');

      await expectLater(
        failing.terminate(),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', 'close failed'),
        ),
      );

      const timeout = Duration(seconds: 5);
      await first.done().timeout(timeout);
      await second.done().timeout(timeout);
      expect(secondStream.closed, isTrue);
      expect(transport.closed, isTrue);
      expect(client.closed, isTrue);
      expect(failing.activeSnapshotListenerCount, 0);
    });

    test(
      'completes overlapping calls only once everything is closed',
      () async {
        final client = _RecordingClient();
        final terminating = Firestore.internal(
          client: client,
          listenTransport: () => transport,
        );

        final events = _Events(terminating.doc('col/doc').snapshots());
        final stream = await transport.nextStream();
        final gate = stream.closeGate = Completer<void>();

        final completed = <String>[];
        void expectAllClosed() {
          expect(stream.closed, isTrue);
          expect(transport.closed, isTrue);
          expect(client.closed, isTrue);
          expect(terminating.activeSnapshotListenerCount, 0);
        }

        final first = terminating.terminate().then((_) {
          expectAllClosed();
          completed.add('first');
        });
        final second = terminating.terminate().then((_) {
          expectAllClosed();
          completed.add('second');
        });
        await _settle();
        expect(
          completed,
          isEmpty,
          reason: 'the listen stream is still closing',
        );

        gate.complete();
        await Future.wait([first, second]);
        expect(completed, unorderedEquals(['first', 'second']));
        await events.done();
      },
    );

    test('delivers the snapshots a paused listener buffered', () async {
      final col = firestore.collection('col');
      final events = _Events(col.snapshots());
      final backend = await nextBackend();
      events.subscription.pause();
      backend.sendInitial();
      await _settle();

      await firestore.terminate();
      events.subscription.resume();
      expect((await events.snapshot()).size, 0);
      await events.done();
    });

    test('does not create a transport', () async {
      await firestore.terminate();
      expect(transportsCreated, 0);
    });

    test('makes later listens fail', () async {
      final stream = firestore.doc('col/doc').snapshots();
      await firestore.terminate();

      for (final stream in [
        stream,
        firestore.doc('col/doc').snapshots(),
        firestore.collection('col').snapshots(),
      ]) {
        expect(
          await _Events(stream).error(),
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('terminated'),
          ),
        );
      }
      expect(transportsCreated, 0);
    });
  });

  group('project ID', () {
    test('is resolved before the watch opens', () async {
      final client = _UndiscoveredProjectClient();
      final undiscovered = Firestore.internal(
        client: client,
        listenTransport: () {
          transportsCreated++;
          return transport;
        },
      );
      addTearDown(undiscovered.terminate);

      final events = _Events(undiscovered.doc('col/doc').snapshots());
      await _settle();
      expect(client.resolveCalls, 1);
      expect(transportsCreated, 0);
      expect(transport.streams, isEmpty);

      client.resolve.complete(_projectId);
      final backend = _Backend(await transport.nextStream(), undiscovered);
      expect(backend.stream.requests.single.database, _database);

      backend.sendInitial();
      expect((await events.snapshot()).exists, isFalse);
    });

    test('is abandoned by a listener cancelled while resolving', () async {
      final client = _UndiscoveredProjectClient();
      final undiscovered = Firestore.internal(
        client: client,
        listenTransport: () {
          transportsCreated++;
          return transport;
        },
      );
      addTearDown(undiscovered.terminate);

      final events = _Events(undiscovered.doc('col/doc').snapshots());
      await _settle();
      expect(undiscovered.activeSnapshotListenerCount, 1);

      await events.cancel();
      expect(undiscovered.activeSnapshotListenerCount, 0);

      client.resolve.complete(_projectId);
      await _settle();
      expect(transportsCreated, 0);
      expect(transport.streams, isEmpty);
      expect(undiscovered.activeSnapshotListenerCount, 0);
    });

    test('fails silently for a listener cancelled while resolving', () async {
      final client = _UndiscoveredProjectClient();
      final undiscovered = Firestore.internal(
        client: client,
        listenTransport: () => transport,
      );
      addTearDown(undiscovered.terminate);

      final errors = <Object>[];
      final subscription = undiscovered
          .doc('col/doc')
          .snapshots()
          .listen(null, onError: errors.add);
      await _settle();
      await subscription.cancel();

      client.resolve.completeError(StateError('No project ID'));
      await _settle();
      expect(errors, isEmpty);
      expect(transport.streams, isEmpty);
      expect(undiscovered.activeSnapshotListenerCount, 0);
    });

    test('is looked up once for concurrent listeners', () async {
      final client = _UndiscoveredProjectClient();
      final undiscovered = Firestore.internal(
        client: client,
        listenTransport: () => transport,
      );
      addTearDown(undiscovered.terminate);

      final first = _Events(undiscovered.doc('col/a').snapshots());
      final second = _Events(undiscovered.doc('col/b').snapshots());
      await _settle();
      expect(client.resolveCalls, 1);

      client.resolve.complete(_projectId);
      await transport.nextStream();
      await transport.nextStream();
      expect(client.resolveCalls, 1);
      await first.cancel();
      await second.cancel();
    });

    test('is not resolved again once known', () async {
      final client = _UndiscoveredProjectClient()..resolve.complete(_projectId);
      final undiscovered = Firestore.internal(
        client: client,
        listenTransport: () => transport,
      );
      addTearDown(undiscovered.terminate);

      final first = _Events(undiscovered.doc('col/a').snapshots());
      await transport.nextStream();
      final second = _Events(undiscovered.doc('col/b').snapshots());
      await transport.nextStream();
      expect(client.resolveCalls, 1);
      await first.cancel();
      await second.cancel();
    });

    test('delivers a failure to resolve it as an error', () async {
      final client = _UndiscoveredProjectClient();
      final undiscovered = Firestore.internal(
        client: client,
        listenTransport: () => transport,
      );
      addTearDown(undiscovered.terminate);

      final events = _Events(undiscovered.doc('col/doc').snapshots());
      client.resolve.completeError(StateError('No project ID'));
      expect(
        await events.error(),
        isA<StateError>().having((e) => e.message, 'message', 'No project ID'),
      );
      expect(transport.streams, isEmpty);
      expect(undiscovered.activeSnapshotListenerCount, 0);

      // The failed lookup is not reused: the next listener tries again.
      final retry = _Events(undiscovered.doc('col/doc').snapshots());
      await retry.error();
      expect(client.resolveCalls, 2);
    });
  });

  group('DocumentSnapshot equality', () {
    /// The last version sent, carried over between runs as the backend does.
    var version = 0;

    setUp(() => version = 0);

    /// Listens to [ref] and returns its snapshot once it holds [data].
    Future<DocumentSnapshot<DocumentData>> read(
      DocumentReference<DocumentData> ref,
      DocumentData data,
    ) async {
      final events = _Events(ref.snapshots());
      final backend = _Backend(
        await transport.nextStream(),
        firestore,
        version: version,
      );
      backend
        ..sendAddTarget()
        ..sendCurrent()
        ..sendDoc(ref, data)
        ..sendSnapshot();
      final snapshot = await events.snapshot();
      await events.cancel();
      version = backend._version;
      return snapshot;
    }

    test('for snapshots with equal data', () async {
      final ref = firestore.doc('col/doc');
      final data = {
        'foo': 'a',
        'nested': {
          'n': 1,
          'list': <Object?>[1, 'x'],
        },
      };
      final first = await read(ref, data);
      final second = await read(ref, data);

      expect(identical(first, second), isFalse);
      expect(second.updateTime, isNot(first.updateTime));
      expect(second, first);
      expect(second.hashCode, first.hashCode);
    });

    test('for snapshots with different data', () async {
      final ref = firestore.doc('col/doc');
      final first = await read(ref, {'foo': 'a'});
      final second = await read(ref, {'foo': 'b'});

      expect(second, isNot(first));
      expect(second.hashCode, isNot(first.hashCode));
    });

    test('for snapshots of different documents', () async {
      final first = await read(firestore.doc('col/a'), {'foo': 'a'});
      final second = await read(firestore.doc('col/b'), {'foo': 'a'});

      expect(second, isNot(first));
    });
  });

  group('QuerySnapshot equality', () {
    late CollectionReference<DocumentData> col;
    late DocumentReference<DocumentData> doc1;
    late DocumentReference<DocumentData> doc2;
    late DocumentReference<DocumentData> doc3;
    late DocumentReference<DocumentData> doc4;

    /// The last version sent, carried over between runs as the backend does.
    var version = 0;

    setUp(() {
      version = 0;
      col = firestore.collection('col');
      doc1 = col.doc('doc1');
      doc2 = col.doc('doc2');
      doc3 = col.doc('doc3');
      doc4 = col.doc('doc4');
    });

    /// Listens to [query] and returns its snapshots: the initial, empty one,
    /// then one after each of [steps] runs on the backend.
    Future<List<QuerySnapshot<DocumentData>>> run(
      List<void Function(_Backend backend)> steps, {
      Query<DocumentData>? query,
    }) async {
      final events = _Events((query ?? col).snapshots());
      final backend = _Backend(
        await transport.nextStream(),
        firestore,
        version: version,
      )..sendInitial();
      final snapshots = [await events.snapshot()];
      for (final step in steps) {
        step(backend);
        backend.sendSnapshot();
        snapshots.add(await events.snapshot());
      }
      await events.cancel();
      version = backend._version;
      return snapshots;
    }

    test('for equal snapshots', () async {
      final steps = <void Function(_Backend)>[
        (backend) => backend
          ..sendDoc(doc1, {'foo': 'a'})
          ..sendDoc(doc2, {'foo': 'b'})
          ..sendDoc(doc3, {'foo': 'c'}),
        (backend) => backend
          ..sendDocDelete(doc1)
          ..sendDoc(doc2, {'foo': 'bar'})
          ..sendDoc(doc4, {'foo': 'd'}),
      ];
      final first = await run(steps);
      final second = await run(steps);

      for (final (index, snapshot) in first.indexed) {
        expect(snapshot, snapshot);
        expect(second[index], snapshot, reason: 'snapshot $index');
        expect(second[index].hashCode, snapshot.hashCode);
      }
      expect(
        second[0].readTime,
        isNot(first[0].readTime),
        reason: 'the read time is ignored',
      );
    });

    test('for equal snapshots with materialized changes', () async {
      final steps = <void Function(_Backend)>[
        (backend) => backend
          ..sendDoc(doc1, {'foo': 'a'})
          ..sendDoc(doc2, {'foo': 'b'})
          ..sendDoc(doc3, {'foo': 'c'}),
      ];
      final first = await run(steps);
      final second = await run(steps);

      expect(second.last.docs, hasLength(3));
      expect(second.last, first.last);
    });

    test('for snapshots of different size', () async {
      final first = await run([
        (backend) => backend
          ..sendDoc(doc1, {'foo': 'a'})
          ..sendDoc(doc2, {'foo': 'b'}),
      ]);
      final second = await run([
        (backend) => backend.sendDoc(doc1, {'foo': 'a'}),
      ]);

      expect(second.last, isNot(first.last));
    });

    test('for snapshots with different kind of changes', () async {
      final first = await run([
        (backend) => backend.sendDoc(doc1, {'foo': 'a'}),
      ]);
      final second = await run([
        (backend) => backend.sendDoc(doc1, {'foo': 'b'}),
      ]);

      expect(first.last.docChanges[0], first.last.docChanges[0]);
      expect(second.last, isNot(first.last));
      expect(second.last.docChanges[0], isNot(first.last.docChanges[0]));
    });

    test('for snapshots with different number of changes', () async {
      final first = await run([
        (backend) => backend.sendDoc(doc1, {'foo': 'a'}),
        (backend) => backend.sendDoc(doc2, {'foo': 'b'}),
      ]);
      final second = await run([
        (backend) => backend.sendDoc(doc1, {'foo': 'a'}),
        (backend) => backend
          ..sendDocDelete(doc1)
          ..sendDoc(doc2, {'foo': 'b'})
          ..sendDoc(doc3, {'foo': 'c'}),
      ]);

      expect(second.last, isNot(first.last));
    });

    test('for snapshots with different data types', () async {
      final first = await run([
        (backend) => backend.sendDoc(doc1, {'foo': '1'}),
      ]);
      final second = await run([
        (backend) => backend.sendDoc(doc1, {'foo': 1}),
      ]);

      expect(second.last, isNot(first.last));
    });

    test('for snapshots with different queries', () async {
      final first = await run(const []);
      final second = await run(
        const [],
        query: col.where('foo', WhereFilter.equal, 'bar'),
      );

      expect(second.single, isNot(first.single));
    });

    test('for objects with different type', () async {
      final snapshot = (await run(const [])).single;

      expect(snapshot, isNot('foo'));
      expect(snapshot, isNot(<String, Object?>{}));
      expect(snapshot, isNot(GeoPoint(latitude: 0, longitude: 0)));
    });
  });
}
