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

// coverage:ignore-file

// This is a generated file - do not edit.
//
// Generated from google/firestore/v1/firestore.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// The type of change.
class TargetChange_TargetChangeType extends $pb.ProtobufEnum {
  /// No change has occurred. Used only to send an updated `resume_token`.
  static const TargetChange_TargetChangeType NO_CHANGE =
      TargetChange_TargetChangeType._(0, _omitEnumNames ? '' : 'NO_CHANGE');

  /// The targets have been added.
  static const TargetChange_TargetChangeType ADD =
      TargetChange_TargetChangeType._(1, _omitEnumNames ? '' : 'ADD');

  /// The targets have been removed.
  static const TargetChange_TargetChangeType REMOVE =
      TargetChange_TargetChangeType._(2, _omitEnumNames ? '' : 'REMOVE');

  /// The targets reflect all changes committed before the targets were added
  /// to the stream.
  ///
  /// This will be sent after or with a `read_time` that is greater than or
  /// equal to the time at which the targets were added.
  ///
  /// Listeners can wait for this change if read-after-write semantics
  /// are desired.
  static const TargetChange_TargetChangeType CURRENT =
      TargetChange_TargetChangeType._(3, _omitEnumNames ? '' : 'CURRENT');

  /// The targets have been reset, and a new initial state for the targets
  /// will be returned in subsequent changes.
  ///
  /// After the initial state is complete, `CURRENT` will be returned even
  /// if the target was previously indicated to be `CURRENT`.
  static const TargetChange_TargetChangeType RESET =
      TargetChange_TargetChangeType._(4, _omitEnumNames ? '' : 'RESET');

  static const $core.List<TargetChange_TargetChangeType> values =
      <TargetChange_TargetChangeType>[
    NO_CHANGE,
    ADD,
    REMOVE,
    CURRENT,
    RESET,
  ];

  static final $core.List<TargetChange_TargetChangeType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static TargetChange_TargetChangeType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TargetChange_TargetChangeType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
