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

/// Represents delivery scheduling options for a task.
///
/// Use [AbsoluteDelivery] to schedule a task at a specific time, or
/// [DelayDelivery] to schedule a task after a delay from the current time.
///
/// This is a sealed class, ensuring compile-time exhaustiveness checking
/// when pattern matching.
sealed class DeliverySchedule {
  const DeliverySchedule();
}

/// Schedules task delivery at an absolute time.
///
/// The task will be attempted or retried at the specified [scheduleTime].
class AbsoluteDelivery extends DeliverySchedule {
  /// Creates an absolute delivery schedule.
  ///
  /// The [scheduleTime] specifies when the task should be attempted.
  const AbsoluteDelivery(this.scheduleTime);

  /// The time when the task is scheduled to be attempted or retried.
  final DateTime scheduleTime;
}

/// Schedules task delivery after a delay from the current time.
///
/// The task will be attempted after [scheduleDelaySeconds] seconds from now.
class DelayDelivery extends DeliverySchedule {
  /// Creates a delayed delivery schedule.
  ///
  /// The [scheduleDelaySeconds] specifies how many seconds from now
  /// the task should be attempted. Must be non-negative.
  ///
  /// Throws [FirebaseFunctionsAdminException] if [scheduleDelaySeconds] is negative.
  DelayDelivery(this.scheduleDelaySeconds) {
    if (scheduleDelaySeconds < 0) {
      throw FirebaseFunctionsAdminException(
        FunctionsClientErrorCode.invalidArgument,
        'scheduleDelaySeconds must be a non-negative duration in seconds.',
      );
    }
  }

  /// The duration of delay (in seconds) before the task is scheduled
  /// to be attempted.
  ///
  /// This delay is added to the current time.
  final int scheduleDelaySeconds;
}

/// Experimental (beta) task options.
///
/// These options may change in future releases.
class TaskOptionsExperimental {
  /// Creates experimental task options.
  TaskOptionsExperimental({this.uri}) {
    if (uri != null && !isURL(uri)) {
      throw FirebaseFunctionsAdminException(
        FunctionsClientErrorCode.invalidArgument,
        'uri must be a valid URL string.',
      );
    }
  }

  /// The full URL path that the request will be sent to.
  ///
  /// Must be a valid URL.
  ///
  /// **Beta feature** - May change in future releases.
  final String? uri;
}

/// Options for enqueuing a task.
///
/// Specifies scheduling, delivery, and identification options for a task.
class TaskOptions {
  /// Creates task options with the specified configuration.
  TaskOptions({
    this.schedule,
    this.dispatchDeadlineSeconds,
    this.id,
    this.headers,
    this.experimental,
  }) {
    // Validate dispatchDeadlineSeconds range
    if (dispatchDeadlineSeconds != null &&
        (dispatchDeadlineSeconds! < 15 || dispatchDeadlineSeconds! > 1800)) {
      throw FirebaseFunctionsAdminException(
        FunctionsClientErrorCode.invalidArgument,
        'dispatchDeadlineSeconds must be between 15 and 1800 seconds.',
      );
    }

    // Validate task ID format
    if (id != null && !isValidTaskId(id)) {
      throw FirebaseFunctionsAdminException(
        FunctionsClientErrorCode.invalidArgument,
        'id can contain only letters ([A-Za-z]), numbers ([0-9]), '
        'hyphens (-), or underscores (_). The maximum length is 500 characters.',
      );
    }
  }

  /// Optional delivery schedule for the task.
  ///
  /// Use [AbsoluteDelivery] to schedule at a specific time, or
  /// [DelayDelivery] to schedule after a delay.
  ///
  /// If not specified, the task will be enqueued immediately.
  final DeliverySchedule? schedule;

  /// The deadline for requests sent to the worker.
  ///
  /// If the worker does not respond by this deadline then the request is
  /// cancelled and the attempt is marked as a DEADLINE_EXCEEDED failure.
  /// Cloud Tasks will retry the task according to the RetryConfig.
  ///
  /// The default is 10 minutes (600 seconds).
  /// The deadline must be in the range of 15 seconds to 30 minutes (1800 seconds).
  final int? dispatchDeadlineSeconds;

  /// The ID to use for the enqueued task.
  ///
  /// If not provided, one will be automatically generated.
  ///
  /// If provided, an explicitly specified task ID enables task de-duplication.
  /// If a task's ID is identical to that of an existing task or a task that
  /// was deleted or executed recently then the call will throw an error with
  /// code "task-already-exists". Another task with the same ID can't be
  /// created for ~1 hour after the original task was deleted or executed.
  ///
  /// Because there is an extra lookup cost to identify duplicate task IDs,
  /// setting ID significantly increases latency. Using hashed strings for
  /// the task ID or for the prefix of the task ID is recommended.
  ///
  /// Choosing task IDs that are sequential or have sequential prefixes,
  /// for example using a timestamp, causes an increase in latency and error
  /// rates in all task commands. The infrastructure relies on an approximately
  /// uniform distribution of task IDs to store and serve tasks efficiently.
  ///
  /// The ID can contain only letters (`[A-Za-z]`), numbers (`[0-9]`), hyphens
  /// (`-`), or underscores (`_`). The maximum length is 500 characters.
  final String? id;

  /// HTTP request headers to include in the request to the task queue function.
  ///
  /// These headers represent a subset of the headers that will accompany the
  /// task's HTTP request. Some HTTP request headers will be ignored or replaced,
  /// e.g. Authorization, Host, Content-Length, User-Agent etc. cannot be overridden.
  ///
  /// By default, Content-Type is set to 'application/json'.
  ///
  /// The size of the headers must be less than 80KB.
  final Map<String, String>? headers;

  /// Experimental (beta) task options.
  ///
  /// Contains experimental features that may change in future releases.
  final TaskOptionsExperimental? experimental;
}

/// Represents the scope of a function in a task queue.
sealed class FunctionScope {
  const FunctionScope._();

  /// Targets a function co-deployed in the same codebase/deployment context.
  const factory FunctionScope.current() = _CurrentFunctionScope;

  /// Targets a global function (e.g. without kit or extension namespacing).
  const factory FunctionScope.global() = _GlobalFunctionScope;

  /// Targets a function deployed within a specific Firebase Extension.
  const factory FunctionScope.extension(String extensionId) =
      _ExtensionFunctionScope;
}

class _GlobalFunctionScope extends FunctionScope {
  const _GlobalFunctionScope() : super._();

  @override
  String toString() => 'FunctionScope.global()';
}

class _ExtensionFunctionScope extends FunctionScope {
  const _ExtensionFunctionScope(this.extensionId) : super._();

  final String extensionId;

  @override
  String toString() => 'FunctionScope.extension($extensionId)';
}

class _KitFunctionScope extends FunctionScope {
  const _KitFunctionScope(this.kit) : super._();

  final String kit;

  @override
  String toString() => 'FunctionScope.kit($kit)';
}

class _CurrentFunctionScope extends FunctionScope {
  const _CurrentFunctionScope() : super._();

  @override
  String toString() => 'FunctionScope.current()';
}

class _ExtensionOrKitFunctionScope extends FunctionScope {
  const _ExtensionOrKitFunctionScope(this.instance) : super._();

  final String instance;

  @override
  String toString() => 'FunctionScope.extensionOrKit($instance)';
}
