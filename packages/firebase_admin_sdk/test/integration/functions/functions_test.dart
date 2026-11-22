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

@Tags(['firebase-emulator'])
library;

import 'package:firebase_admin_sdk/functions.dart';
import 'package:test/test.dart';

import '../../fixtures/functions/helpers.dart';

void main() {
  group('Functions Integration Tests', () {
    setUpAll(ensureCloudTasksEmulatorConfigured);

    group('TaskQueue', () {
      late Functions functions;

      setUp(() {
        functions = createFunctionsForTest();
      });

      group('enqueue', () {
        test('enqueues a simple task', () async {
          final queue = functions.taskQueue('helloWorld');

          // Should not throw
          await queue.enqueue({'message': 'Hello from integration test'});
        });

        test('enqueues a task with delay', () async {
          final queue = functions.taskQueue('helloWorld');

          await queue.enqueue({
            'message': 'Delayed task',
          }, TaskOptions(schedule: DelayDelivery(30)));
        });

        test('enqueues a task with absolute schedule time', () async {
          final queue = functions.taskQueue('helloWorld');

          final scheduleTime = DateTime.now().add(const Duration(minutes: 5));
          await queue.enqueue({
            'message': 'Scheduled task',
          }, TaskOptions(schedule: AbsoluteDelivery(scheduleTime)));
        });

        test('enqueues a task with custom ID', () async {
          final queue = functions.taskQueue('helloWorld');
          final taskId = 'test-task-${DateTime.now().millisecondsSinceEpoch}';

          await queue.enqueue({
            'message': 'Task with custom ID',
          }, TaskOptions(id: taskId));

          // Clean up - delete the task
          await queue.delete(taskId);
        });

        test('enqueues a task with custom headers', () async {
          final queue = functions.taskQueue('helloWorld');

          await queue.enqueue({
            'message': 'Task with headers',
          }, TaskOptions(headers: {'X-Custom-Header': 'custom-value'}));
        });

        test('enqueues a task with dispatch deadline', () async {
          final queue = functions.taskQueue('helloWorld');

          await queue.enqueue({
            'message': 'Task with deadline',
          }, TaskOptions(dispatchDeadlineSeconds: 300));
        });

        test('enqueues a task with experimental URI', () async {
          final queue = functions.taskQueue('helloWorld');

          await queue.enqueue(
            {'message': 'Task with custom URI'},
            TaskOptions(
              experimental: TaskOptionsExperimental(
                uri: 'https://custom.example.com/handler',
              ),
            ),
          );
        });
      });

      group('delete', () {
        test('deletes an existing task', () async {
          final queue = functions.taskQueue('helloWorld');
          final taskId = 'delete-test-${DateTime.now().millisecondsSinceEpoch}';

          // First enqueue a task with a known ID
          await queue.enqueue({
            'message': 'Task to delete',
          }, TaskOptions(id: taskId));

          // Then delete it - should not throw
          await queue.delete(taskId);
        });

        test('succeeds silently when deleting non-existent task', () async {
          final queue = functions.taskQueue('helloWorld');

          // Should not throw even though task doesn't exist
          await queue.delete('non-existent-task-id');
        });
      });

      group('validation', () {
        test('throws on invalid task ID format', () async {
          final queue = functions.taskQueue('helloWorld');

          expect(
            () => queue.delete('invalid/task/id'),
            throwsA(isA<FirebaseFunctionsAdminException>()),
          );
        });

        test('throws on empty task ID', () async {
          final queue = functions.taskQueue('helloWorld');

          expect(() => queue.delete(''), throwsA(isA<ArgumentError>()));
        });

        test('throws on empty function name', () {
          expect(() => functions.taskQueue(''), throwsA(isA<ArgumentError>()));
        });

        test('throws on invalid dispatch deadline (too low)', () {
          final queue = functions.taskQueue('helloWorld');

          expect(
            () => queue.enqueue({
              'data': 'test',
            }, TaskOptions(dispatchDeadlineSeconds: 10)),
            throwsA(isA<FirebaseFunctionsAdminException>()),
          );
        });

        test('throws on invalid dispatch deadline (too high)', () {
          final queue = functions.taskQueue('helloWorld');

          expect(
            () => queue.enqueue({
              'data': 'test',
            }, TaskOptions(dispatchDeadlineSeconds: 2000)),
            throwsA(isA<FirebaseFunctionsAdminException>()),
          );
        });
      });
    });
  });
}
