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

/// An immutable object representing a geographic location in Firestore. The
/// location is represented as a latitude/longitude pair.
@immutable
final class GeoPoint implements _Serializable {
  GeoPoint({required this.latitude, required this.longitude}) {
    if (latitude.isNaN) {
      throw ArgumentError.value(
        latitude,
        'latitude',
        'Value for argument "latitude" is not a valid number',
      );
    }
    if (longitude.isNaN) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'Value for argument "longitude" is not a valid number',
      );
    }

    if (latitude < -90 || latitude > 90) {
      throw ArgumentError.value(
        latitude,
        'latitude',
        'Latitude must be in the range of [-90, 90]',
      );
    }
    if (longitude < -180 || longitude > 180) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'Longitude must be in the range of [-180, 180]',
      );
    }
  }

  /// Converts a google.type.LatLng proto to its GeoPoint representation.
  factory GeoPoint._fromProto(type_v1.LatLng latLng) {
    return GeoPoint(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
    );
  }

  /// The latitude as a number between -90 and 90.
  final double latitude;

  /// The longitude as a number between -180 and 180.
  final double longitude;

  @override
  firestore_v1.Value _toProto() {
    return firestore_v1.Value(
      geoPointValue: type_v1.LatLng(
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GeoPoint &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
