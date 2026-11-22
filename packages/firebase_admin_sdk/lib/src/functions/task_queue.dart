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

part of 'functions.dart';

/// A reference to a Cloud Functions task queue.
///
/// Use this to enqueue tasks for a specific Cloud Function or delete
/// pending tasks.
class TaskQueue {
  TaskQueue._({
    required String functionName,
    required FunctionsRequestHandler requestHandler,
    String? extensionId,
    FunctionScope? scope,
  }) : _functionName = functionName,
       _requestHandler = requestHandler {
    validateNonEmptyString(_functionName, 'functionName');

    if (extensionId != null && scope != null) {
      throw ArgumentError('Cannot set both extensionId and scope.');
    }

    if (extensionId != null) {
      validateString(extensionId, 'extensionId');
      _scope = extensionId.isEmpty
          ? const FunctionScope.current()
          : _ExtensionOrKitFunctionScope(extensionId);
    } else {
      _scope = scope ?? const FunctionScope.current();
    }

    if (_scope is _ExtensionOrKitFunctionScope) {
      final instance = (_scope as _ExtensionOrKitFunctionScope).instance;
      final kitInstanceId = Environment.getKitInstanceId();
      if (kitInstanceId != null &&
          kitInstanceId.isNotEmpty &&
          kitInstanceId == instance) {
        _scope = _KitFunctionScope(instance);
        print(
          'Targeting your own extension or kit no longer requires a second parameter, '
          'which can have performance implications. Please change the call '
          "taskQueue('$_functionName', extensionId: '$instance') to taskQueue('$_functionName') "
          "or taskQueue('$_functionName', scope: FunctionScope.current())",
        );
      }
    }
  }

  final String _functionName;
  final FunctionsRequestHandler _requestHandler;
  late FunctionScope _scope;

  /// Enqueues a task with the given [data] payload.
  ///
  /// The [data] will be JSON-encoded and sent to the function.
  ///
  /// Optional [options] can specify:
  /// - Schedule time (absolute or delay)
  /// - Dispatch deadline
  /// - Task ID (for deduplication)
  /// - Custom headers
  /// - Custom URI
  ///
  /// Example:
  /// ```dart
  /// await queue.enqueue(
  ///   {'userId': '123', 'action': 'sendEmail'},
  ///   TaskOptions(
  ///     scheduleDelaySeconds: 3600, // Send in 1 hour
  ///     id: 'unique-task-id',
  ///   ),
  /// );
  /// ```
  ///
  /// Throws [FirebaseFunctionsAdminException] if the request fails.
  Future<void> enqueue(
    Map<String, dynamic> data, [
    TaskOptions? options,
  ]) async {
    final currentScope = _scope;
    if (currentScope is! _ExtensionOrKitFunctionScope) {
      await _requestHandler.enqueue(data, _functionName, currentScope, options);
      return;
    }

    try {
      await _requestHandler.enqueue(data, _functionName, currentScope, options);
    } on FirebaseFunctionsAdminException catch (err) {
      if (err.errorCode != FunctionsClientErrorCode.notFound) {
        rethrow;
      }
      final tempKitScope = _KitFunctionScope(currentScope.instance);
      await _requestHandler.enqueue(data, _functionName, tempKitScope, options);
      // Only upgrade the stateful scope to kit if the retry request succeeds
      _scope = tempKitScope;
      _logFallbackWarning(_functionName, currentScope.instance);
    }
  }

  /// Deletes a task from the queue by its [id].
  ///
  /// A task can only be deleted if it hasn't been executed yet.
  /// If the task doesn't exist, this method completes successfully without error.
  ///
  /// Example:
  /// ```dart
  /// await queue.delete('unique-task-id');
  /// ```
  ///
  /// Throws [FirebaseFunctionsAdminException] if the request fails.
  Future<void> delete(String id) async {
    try {
      final currentScope = _scope;
      if (currentScope is! _ExtensionOrKitFunctionScope) {
        await _requestHandler.delete(id, _functionName, currentScope);
        return;
      }

      try {
        await _requestHandler.delete(id, _functionName, currentScope);
      } on FirebaseFunctionsAdminException catch (err) {
        if (err.errorCode != FunctionsClientErrorCode.notFound) {
          rethrow;
        }
        // Not found, try fallback to kit scope.
        final tempKitScope = _KitFunctionScope(currentScope.instance);
        await _requestHandler.delete(id, _functionName, tempKitScope);
        // Only upgrade the stateful scope to kit if the retry request succeeds
        _scope = tempKitScope;
        _logFallbackWarning(_functionName, currentScope.instance);
      }
    } on FirebaseFunctionsAdminException catch (err) {
      if (err.errorCode != FunctionsClientErrorCode.notFound) {
        rethrow;
      }
      // Swallow notFound errors as delete is idempotent.
    }
  }

  void _logFallbackWarning(String functionName, String instance) {
    print(
      'Targeting kit $instance with the legacy extensions API, '
      'which has performance implications. Please change the call '
      "taskQueue('$functionName', extensionId: '$instance') to taskQueue('$functionName')",
    );
  }
}
