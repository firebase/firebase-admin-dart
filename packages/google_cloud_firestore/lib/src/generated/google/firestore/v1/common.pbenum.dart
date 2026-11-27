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
// Generated from google/firestore/v1/common.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// The type of concurrency control mode for transactions.
class TransactionOptions_ConcurrencyMode extends $pb.ProtobufEnum {
  /// Start the transaction with the database-level default concurrency mode.
  static const TransactionOptions_ConcurrencyMode CONCURRENCY_MODE_UNSPECIFIED =
      TransactionOptions_ConcurrencyMode._(
          0, _omitEnumNames ? '' : 'CONCURRENCY_MODE_UNSPECIFIED');

  /// Use optimistic concurrency control for the new transaction.
  static const TransactionOptions_ConcurrencyMode OPTIMISTIC =
      TransactionOptions_ConcurrencyMode._(
          1, _omitEnumNames ? '' : 'OPTIMISTIC');

  /// Use pessimistic concurrency control for the new transaction.
  static const TransactionOptions_ConcurrencyMode PESSIMISTIC =
      TransactionOptions_ConcurrencyMode._(
          2, _omitEnumNames ? '' : 'PESSIMISTIC');

  static const $core.List<TransactionOptions_ConcurrencyMode> values =
      <TransactionOptions_ConcurrencyMode>[
    CONCURRENCY_MODE_UNSPECIFIED,
    OPTIMISTIC,
    PESSIMISTIC,
  ];

  static final $core.List<TransactionOptions_ConcurrencyMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static TransactionOptions_ConcurrencyMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TransactionOptions_ConcurrencyMode._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
