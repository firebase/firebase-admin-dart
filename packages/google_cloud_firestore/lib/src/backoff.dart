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

import 'dart:math' as math;
import 'package:meta/meta.dart';

@internal
class ExponentialBackoffSetting {
  const ExponentialBackoffSetting({
    this.initialDelayMs,
    this.backoffFactor,
    this.maxDelayMs,
    this.jitterFactor,
  });

  final int? initialDelayMs;
  final double? backoffFactor;
  final int? maxDelayMs;
  final double? jitterFactor;
}

/// A helper for running delayed tasks following an exponential backoff curve
/// between attempts.
///
/// Each delay is made up of a "base" delay which follows the exponential
/// backoff curve, and a "jitter" (+/- 50% by default) that is calculated and
/// added to the base delay. This prevents clients from accidentally
/// synchronizing their delays causing spikes of load to the backend.
///
@internal
class ExponentialBackoff {
  ExponentialBackoff({
    ExponentialBackoffSetting options = const ExponentialBackoffSetting(),
  }) : initialDelayMs = options.initialDelayMs ?? defaultBackOffInitialDelayMs,
       backoffFactor = options.backoffFactor ?? defaultBackOffFactor,
       maxDelayMs = options.maxDelayMs ?? defaultBackOffMaxDelayMs,
       jitterFactor = options.jitterFactor ?? defaultJitterFactor;

  static const defaultBackOffInitialDelayMs = 1000;
  static const defaultBackOffFactor = 1.5;
  static const defaultBackOffMaxDelayMs = 60 * 1000;
  static const defaultJitterFactor = 1.0;

  static const maxRetryAttempts = 10;

  final int initialDelayMs;
  final double backoffFactor;
  final int maxDelayMs;
  final double jitterFactor;

  int _retryCount = 0;
  int _currentBaseMs = 0;
  bool _awaitingBackoffCompletion = false;

  /// Returns a future that resolves after currentDelayMs, and increases the
  /// delay for any subsequent attempts.
  ///
  /// @return A [Future] that resolves when the current delay elapsed.
  Future<void> backoffAndWait() async {
    if (_awaitingBackoffCompletion) {
      throw Exception('A backoff operation is already in progress.');
    }

    final delay = nextDelay();

    _awaitingBackoffCompletion = true;
    await Future<void>.delayed(delay);
    _awaitingBackoffCompletion = false;
  }

  /// Returns the delay to wait before the next attempt, and increases the
  /// delay for any subsequent attempts, as [backoffAndWait] does without
  /// waiting.
  ///
  /// For callers that wait on a timer of their own, so that the wait can be
  /// cancelled. Throws once the retries are exhausted.
  Duration nextDelay() {
    if (_retryCount > maxRetryAttempts) {
      throw Exception('Exceeded maximum number of retries allowed.');
    }

    final delayWithJitterMs = _currentBaseMs + _jitterDelayMs();

    _currentBaseMs = (_currentBaseMs * backoffFactor).toInt();
    _currentBaseMs = _currentBaseMs.clamp(initialDelayMs, maxDelayMs);
    _retryCount += 1;

    return Duration(milliseconds: delayWithJitterMs);
  }

  /// Resets the backoff delay and retry count.
  ///
  /// The very next [backoffAndWait] or [nextDelay] will have no delay. If
  /// either is called again (i.e. due to an error), [initialDelayMs] (plus
  /// jitter) will be used, and subsequent ones will increase according to the
  /// [backoffFactor].
  void reset() {
    _retryCount = 0;
    _currentBaseMs = 0;
  }

  /// Resets the backoff delay to the maximum delay (e.g. for use after a
  /// RESOURCE_EXHAUSTED error), so the next [backoffAndWait] or [nextDelay]
  /// waits [maxDelayMs] (plus jitter).
  void resetToMax() {
    _currentBaseMs = maxDelayMs;
  }

  int _jitterDelayMs() {
    return ((math.Random().nextDouble() - 0.5) * jitterFactor * _currentBaseMs)
        .toInt();
  }
}
