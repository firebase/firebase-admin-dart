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

/// Verifies that a `Value` only has a single type set.
void _assertValidProtobufValue(firestore_v1.Value proto) {
  final values = [
    proto.booleanValue,
    proto.doubleValue,
    proto.integerValue,
    proto.stringValue,
    proto.timestampValue,
    proto.nullValue,
    proto.mapValue,
    proto.arrayValue,
    proto.referenceValue,
    proto.geoPointValue,
    proto.bytesValue,
    proto.fieldReferenceValue,
    proto.variableReferenceValue,
    proto.functionValue,
    proto.pipelineValue,
  ];
  if (values.nonNulls.length != 1) {
    throw ArgumentError.value(proto, 'proto', 'Unable to infer type value');
  }
}
