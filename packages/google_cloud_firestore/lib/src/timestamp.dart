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

/// Encode seconds+nanoseconds to a Google Firestore timestamp string.
String _toGoogleDateTime({required int seconds, required int nanoseconds}) {
  final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  var formattedDate = DateFormat('yyyy-MM-ddTHH:mm:ss').format(date);

  if (nanoseconds > 0) {
    final nanoString = nanoseconds.toString().padLeft(
      9,
      '0',
    ); // Ensure it has 9 digits
    formattedDate = '$formattedDate.$nanoString';
  }

  return '${formattedDate}Z';
}

/// A Timestamp represents a point in time independent of any time zone or calendar,
/// represented as seconds and fractions of seconds at nanosecond resolution in UTC
/// Epoch time. It is encoded using the Proleptic Gregorian Calendar which extends
/// the Gregorian calendar backwards to year one. It is encoded assuming all minutes
/// are 60 seconds long, i.e. leap seconds are "smeared" so that no leap second table
/// is needed for interpretation. Range is from 0001-01-01T00:00:00Z to
/// 9999-12-31T23:59:59.999999999Z. By restricting to that range, we ensure that we
/// can convert to and from RFC 3339 date strings.
///
/// For more information, see [the reference timestamp definition](https://github.com/google/protobuf/blob/master/src/google/protobuf/timestamp.proto)
@immutable
final class Timestamp implements _Serializable {
  Timestamp({required this.seconds, required this.nanoseconds}) {
    const minSeconds = -62135596800;
    const maxSeconds = 253402300799;

    if (seconds < minSeconds || seconds > maxSeconds) {
      throw ArgumentError.value(
        seconds,
        'seconds',
        'must be between $minSeconds and $maxSeconds.',
      );
    }

    const maxNanoSeconds = 999999999;
    if (nanoseconds < 0 || nanoseconds > maxNanoSeconds) {
      throw ArgumentError.value(
        nanoseconds,
        'nanoseconds',
        'must be between 0 and $maxNanoSeconds.',
      );
    }
  }

  /// Creates a new timestamp with the current date, with millisecond precision.
  ///
  /// ```dart
  /// final documentRef = firestore.doc('col/doc');
  ///
  /// documentRef.set({'updateTime': Timestamp.now()});
  /// ```
  /// Returns a new `Timestamp` representing the current date.
  factory Timestamp.now() => Timestamp.fromDate(DateTime.now());

  /// Creates a new timestamp from the given date.
  ///
  /// ```dart
  /// final documentRef = firestore.doc('col/doc');
  ///
  /// final date = Date.parse('01 Jan 2000 00:00:00 GMT');
  /// documentRef.set({ 'startTime': Timestamp.fromDate(date) });
  ///
  /// ```
  ///
  /// - [date]: The date to initialize the `Timestamp` from.
  ///
  /// Returns a new [Timestamp] representing the same point in time
  /// as the given date.
  factory Timestamp.fromDate(DateTime date) {
    return Timestamp.fromMicros(date.microsecondsSinceEpoch);
  }

  /// Creates a new timestamp from the given number of milliseconds.
  ///
  /// ```dart
  /// final documentRef = firestore.doc('col/doc');
  ///
  /// documentRef.set({ 'startTime': Timestamp.fromMillis(42) });
  /// ```
  ///
  /// - [milliseconds]: Number of milliseconds since Unix epoch
  /// 1970-01-01T00:00:00Z.
  ///
  /// Returns a new [Timestamp] representing the same point in time
  /// as the given number of milliseconds.
  factory Timestamp.fromMillis(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final nanos = (milliseconds - seconds * 1000) * _msToNanos;

    return Timestamp(seconds: seconds, nanoseconds: nanos);
  }

  /// Creates a new timestamp from the given number of microseconds.
  ///
  /// ```dart
  /// final documentRef = firestore.doc('col/doc');
  ///
  /// documentRef.set({ 'startTime': Timestamp.fromMicros(42) });
  /// ```
  ///
  /// - [microseconds]: Number of microseconds since Unix epoch
  /// 1970-01-01T00:00:00Z.
  ///
  /// Returns a new [Timestamp] representing the same point in time
  /// as the given number of microseconds.
  factory Timestamp.fromMicros(int microseconds) {
    final seconds = (microseconds / 1000 / 1000).floor();
    final nanos = (microseconds - seconds * 1000 * 1000) * _usToNanos;

    return Timestamp(seconds: seconds, nanoseconds: nanos);
  }

  factory Timestamp._fromProto(protobuf_v1.Timestamp proto) {
    return Timestamp(seconds: proto.seconds, nanoseconds: proto.nanos);
  }

  factory Timestamp._fromString(String timestampValue) {
    final date = DateTime.parse(timestampValue);
    var nanos = 0;

    if (timestampValue.length > 20) {
      final nanoString = timestampValue.substring(
        20,
        timestampValue.length - 1,
      );
      final trailingZeroes = 9 - nanoString.length;
      nanos = int.parse(nanoString) * (math.pow(10, trailingZeroes).toInt());
    }

    return Timestamp(seconds: (date.millisecondsSinceEpoch / 1000).floor(), nanoseconds: nanos);
  }

  static const _msToNanos = 1000000;
  static const _usToNanos = 1000;

  final int seconds;
  final int nanoseconds;

  /// Converts this Timestamp to a Dart DateTime object.
  ///
  /// Returns a DateTime representing the same point in time as this Timestamp,
  /// with millisecond precision. Nanoseconds are rounded to the nearest
  /// millisecond.
  ///
  /// Example:
  /// ```dart
  /// final timestamp = Timestamp(seconds: 1234567890, nanoseconds: 123456789);
  /// final date = timestamp.toDate();
  /// print(date); // 2009-02-13 23:31:30.123Z
  /// ```
  DateTime toDate() {
    final milliseconds = seconds * 1000 + (nanoseconds / _msToNanos).round();
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }

  /// Returns the number of milliseconds since Unix epoch 1970-01-01T00:00:00Z.
  ///
  /// The nanosecond component is floored to millisecond precision.
  ///
  /// Example:
  /// ```dart
  /// final timestamp = Timestamp(seconds: 1234567890, nanoseconds: 123456789);
  /// final millis = timestamp.toMillis();
  /// print(millis); // 1234567890123
  /// ```
  int toMillis() {
    return seconds * 1000 + (nanoseconds / _msToNanos).floor();
  }

  @override
  firestore_v1.Value _toProto() {
    return firestore_v1.Value(
      timestampValue: protobuf_v1.Timestamp(
        seconds: seconds,
        nanos: nanoseconds,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Timestamp &&
        seconds == other.seconds &&
        nanoseconds == other.nanoseconds;
  }

  @override
  int get hashCode => Object.hash(seconds, nanoseconds);

  @override
  String toString() {
    return 'Timestamp(seconds=$seconds, nanoseconds=$nanoseconds)';
  }
}
