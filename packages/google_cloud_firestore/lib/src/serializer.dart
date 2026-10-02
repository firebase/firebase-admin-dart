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

@internal
typedef ApiMapValue = Map<String, firestore_v1.Value>;

abstract class _Serializable {
  firestore_v1.Value _toProto();
}

class Serializer {
  Serializer._(this.firestore);

  @internal
  factory Serializer.internal(Firestore firestore) => Serializer._(firestore);

  final Firestore firestore;

  Object _createInteger(int n) {
    if (firestore._settings.useBigInt) {
      return BigInt.from(n);
    } else {
      return n;
    }
  }

  /// Encodes a Dart object into the Firestore 'Fields' representation.
  firestore_v1.MapValue encodeFields(DocumentData obj) {
    return firestore_v1.MapValue(
      fields: obj.map((key, value) {
        return MapEntry(key, encodeValue(value));
      }).whereValueNotNull(),
    );
  }

  /// Encodes a vector (list of doubles) into the Firestore 'Value' representation.
  ///
  /// Vectors are stored as a map with a special `__type__` field set to `__vector__`
  /// and a `value` field containing the array of numbers.
  firestore_v1.Value encodeVector(List<double> values) {
    return firestore_v1.Value(
      mapValue: firestore_v1.MapValue(
        fields: {
          '__type__': firestore_v1.Value(stringValue: '__vector__'),
          'value': firestore_v1.Value(
            arrayValue: firestore_v1.ArrayValue(
              values: values
                  .map((v) => firestore_v1.Value(doubleValue: v))
                  .toList(),
            ),
          ),
        },
      ),
    );
  }

  /// Encodes a Dart value into the Firestore 'Value' representation.
  firestore_v1.Value? encodeValue(Object? value) {
    switch (value) {
      case _FieldTransform():
        return null;

      case String():
        return firestore_v1.Value(stringValue: value);

      case bool():
        return firestore_v1.Value(booleanValue: value);

      case int():
        return firestore_v1.Value(integerValue: value);
      case BigInt():
        return firestore_v1.Value(integerValue: value.toInt());

      case double():
        return firestore_v1.Value(doubleValue: value);

      case DateTime():
        final timestamp = Timestamp.fromDate(value);
        return timestamp._toProto();

      case null:
        return firestore_v1.Value(nullValue: protobuf_v1.NullValue.nullValue);

      case VectorValue():
        return value._toProto(this);

      case _Serializable():
        return value._toProto();

      case Uint8List():
        return firestore_v1.Value(bytesValue: value);

      case List():
        return firestore_v1.Value(
          arrayValue: firestore_v1.ArrayValue(
            values: value.map(encodeValue).nonNulls.toList(),
          ),
        );

      case Map():
        if (value.isEmpty) {
          return firestore_v1.Value(
            mapValue: firestore_v1.MapValue(fields: {}),
          );
        }

        final fields = encodeFields(Map.from(value));
        if (fields.fields.isEmpty) return null;

        return firestore_v1.Value(mapValue: fields);
      default:
        throw ArgumentError.value(
          value,
          'value',
          'Unsupported field value: ${value.runtimeType}',
        );
    }
  }

  /// Decodes a single Firestore 'Value' Protobuf.
  ///
  /// A reference value must name a document and decodes to a
  /// [DocumentReference]; any other reference throws an [ArgumentError].
  Object? decodeValue(Object? proto) => _decodeValue(proto, _decodeReference);

  /// Decodes a document reference value, as [decodeValue] does.
  DocumentReference<DocumentData> _decodeReference(String referenceValue) {
    final resourcePath = _QualifiedResourcePath.fromSlashSeparatedString(
      referenceValue,
    );
    return firestore.doc(resourcePath.relativeName);
  }

  /// Decodes [proto] like [decodeValue], but hands every reference value, at
  /// any depth, to [decodeReference].
  Object? _decodeValue(
    Object? proto,
    Object? Function(String referenceValue) decodeReference,
  ) {
    if (proto is! firestore_v1.Value) {
      throw ArgumentError.value(
        proto,
        'proto',
        'Cannot decode type from Firestore Value: ${proto.runtimeType}',
      );
    }
    _assertValidProtobufValue(proto);

    switch (proto) {
      case firestore_v1.Value(:final stringValue?):
        return stringValue;
      case firestore_v1.Value(:final booleanValue?):
        return booleanValue;
      case firestore_v1.Value(:final integerValue?):
        return _createInteger(integerValue);
      case firestore_v1.Value(:final doubleValue?):
        return doubleValue;
      case firestore_v1.Value(:final timestampValue?):
        return Timestamp._fromProto(timestampValue);
      case firestore_v1.Value(:final referenceValue?):
        return decodeReference(referenceValue);
      case firestore_v1.Value(:final arrayValue?):
        final values = arrayValue.values;
        return <Object?>[
          for (final value in values) _decodeValue(value, decodeReference),
        ];
      case firestore_v1.Value(nullValue: != null):
        return null;
      case firestore_v1.Value(:final mapValue?):
        final fields = mapValue.fields;
        // Check if this is a vector value (special map with __type__: __vector__)
        if (fields.isNotEmpty &&
            fields['__type__']?.stringValue == '__vector__' &&
            fields['value']?.arrayValue != null) {
          final vectorValues = fields['value']!.arrayValue!.values;
          final doubles = vectorValues
              .map((v) => v.doubleValue ?? 0.0)
              .toList();
          return VectorValue(doubles);
        }
        return <String, Object?>{
          for (final entry in fields.entries)
            entry.key: _decodeValue(entry.value, decodeReference),
        };
      case firestore_v1.Value(:final geoPointValue?):
        return GeoPoint._fromProto(geoPointValue);
      case firestore_v1.Value(:final bytesValue?):
        return bytesValue;

      default:
        // An empty Value or any other unknown type is treated as null.
        return null;
    }
  }
}
