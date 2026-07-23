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

import 'package:google_cloud_firestore/src/firestore_http_client.dart';
import 'package:test/test.dart';

ClientPool<int> _pool({
  required int maxConcurrentOperations,
  int maxIdleResources = 1,
}) {
  var nextId = 0;
  return ClientPool<int>(
    () async => nextId++,
    maxConcurrentOperations: maxConcurrentOperations,
    maxIdleResources: maxIdleResources,
    destroy: (_) async {},
  );
}

void main() {
  group('ClientPool', () {
    test('creates new resources as needed', () {
      final pool = _pool(maxConcurrentOperations: 2);
      final completers = List.generate(3, (_) => Completer<void>());

      expect(pool.size, 0);
      unawaited(pool.run((_) => completers[0].future));
      unawaited(pool.run((_) => completers[1].future));
      expect(pool.size, 1);
      unawaited(pool.run((_) => completers[2].future));
      expect(pool.size, 2);

      for (final c in completers) {
        c.complete();
      }
    });

    test('re-uses a resource with remaining capacity', () async {
      final pool = _pool(maxConcurrentOperations: 2);
      final completers = List.generate(3, (_) => Completer<void>());

      final first = pool.run((_) => completers[0].future);
      unawaited(pool.run((_) => completers[1].future));
      expect(pool.size, 1);

      completers[0].complete();
      await first;

      unawaited(pool.run((_) => completers[2].future));
      expect(pool.size, 1);

      completers[1].complete();
      completers[2].complete();
    });

    test('packs load onto the most-full resource', () async {
      final pool = _pool(maxConcurrentOperations: 2);
      final completers = List.generate(4, (_) => Completer<void>());
      final resourcesUsed = <int>[];

      void run(int i) =>
          unawaited(pool.run((r) {
            resourcesUsed.add(r);
            return completers[i].future;
          }));

      run(0);
      run(1);
      run(2); // Resource 0 is full - this should open resource 1.
      await Future<void>.value();
      expect(resourcesUsed, [0, 0, 1]);

      completers[0].complete();
      await Future<void>.value();

      run(3); // Resource 0 has a free slot again and is the most-full option.
      await Future<void>.value();
      expect(resourcesUsed, [0, 0, 1, 0]);

      completers[1].complete();
      completers[2].complete();
      completers[3].complete();
    });

    test('stops reusing a resource after it fails', () async {
      final pool = _pool(maxConcurrentOperations: 10);
      final resourcesUsed = <int>[];

      await pool
          .run((r) {
            resourcesUsed.add(r);
            return Future<void>.error('boom');
          })
          .catchError((_) {});

      await pool.run((r) {
        resourcesUsed.add(r);
        return Future<void>.value();
      });

      expect(resourcesUsed, [0, 1]);
    });

    test('garbage collects after success', () async {
      final pool = _pool(maxConcurrentOperations: 2, maxIdleResources: 0);
      final completers = List.generate(4, (_) => Completer<void>());

      final ops = [
        pool.run((_) => completers[0].future),
        pool.run((_) => completers[1].future),
        pool.run((_) => completers[2].future),
        pool.run((_) => completers[3].future),
      ];
      expect(pool.size, 2);

      for (final c in completers) {
        c.complete();
      }
      await Future.wait(ops);

      expect(pool.size, 0);
    });

    test('garbage collects after error', () async {
      final pool = _pool(maxConcurrentOperations: 2, maxIdleResources: 0);

      final ops = List.generate(
        4,
        (_) => pool.run((_) => Future<void>.error('boom')).catchError((_) {}),
      );
      await Future.wait(ops);

      expect(pool.size, 0);
    });

    test('keeps a pool of idle resources up to maxIdleResources', () async {
      final pool = _pool(maxConcurrentOperations: 1, maxIdleResources: 3);
      final completers = List.generate(4, (_) => Completer<void>());

      final ops = [
        pool.run((_) => completers[0].future),
        pool.run((_) => completers[1].future),
        pool.run((_) => completers[2].future),
        pool.run((_) => completers[3].future),
      ];
      expect(pool.size, 4);

      for (final c in completers) {
        c.complete();
      }
      await Future.wait(ops);

      expect(pool.size, 3);
    });

    test('rejects operations after terminate()', () async {
      final pool = _pool(maxConcurrentOperations: 1);

      await pool.terminate();

      expect(() => pool.run((_) async {}), throwsA(isA<StateError>()));
    });

    test('waits for in-flight operations before terminating', () async {
      final pool = _pool(maxConcurrentOperations: 1);
      final completer = Completer<void>();
      var terminated = false;

      unawaited(pool.run((_) => completer.future));
      final terminateOp = pool.terminate().then((_) => terminated = true);

      expect(terminated, isFalse);
      completer.complete();
      await terminateOp;
      expect(terminated, isTrue);
    });
  });
}
