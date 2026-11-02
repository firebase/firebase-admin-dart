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
// Generated from google/firestore/v1/bloom_filter.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// A sequence of bits, encoded in a byte array.
///
/// Each byte in the `bitmap` byte array stores 8 bits of the sequence. The only
/// exception is the last byte, which may store 8 _or fewer_ bits. The `padding`
/// defines the number of bits of the last byte to be ignored as "padding". The
/// values of these "padding" bits are unspecified and must be ignored.
///
/// To retrieve the first bit, bit 0, calculate: `(bitmap[0] & 0x01) != 0`.
/// To retrieve the second bit, bit 1, calculate: `(bitmap[0] & 0x02) != 0`.
/// To retrieve the third bit, bit 2, calculate: `(bitmap[0] & 0x04) != 0`.
/// To retrieve the fourth bit, bit 3, calculate: `(bitmap[0] & 0x08) != 0`.
/// To retrieve bit n, calculate: `(bitmap[n / 8] & (0x01 << (n % 8))) != 0`.
///
/// The "size" of a `BitSequence` (the number of bits it contains) is calculated
/// by this formula: `(bitmap.length * 8) - padding`.
class BitSequence extends $pb.GeneratedMessage {
  factory BitSequence({
    $core.List<$core.int>? bitmap,
    $core.int? padding,
  }) {
    final result = BitSequence._();
    if (bitmap != null) result.bitmap = bitmap;
    if (padding != null) result.padding = padding;
    return result;
  }

  BitSequence._();

  factory BitSequence.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BitSequence()..mergeFromBuffer(data, registry);
  factory BitSequence.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BitSequence()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BitSequence',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: BitSequence.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'bitmap', $pb.PbFieldType.OY)
    ..aI(2, _omitFieldNames ? '' : 'padding')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BitSequence clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BitSequence copyWith(void Function(BitSequence) updates) =>
      super.copyWith((message) => updates(message as BitSequence))
          as BitSequence;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BitSequence() / BitSequence.new instead')
  static BitSequence create() => BitSequence._();
  static $pb.GeneratedMessage $_createMessage() => BitSequence._();
  @$core.override
  BitSequence createEmptyInstance() => BitSequence._();
  @$core.pragma('dart2js:noInline')
  static BitSequence getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BitSequence>(
          BitSequence.$_createMessage);
  static BitSequence? _defaultInstance;

  /// The bytes that encode the bit sequence.
  /// May have a length of zero.
  @$pb.TagNumber(1)
  $core.List<$core.int> get bitmap => $_getN(0);
  @$pb.TagNumber(1)
  set bitmap($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBitmap() => $_has(0);
  @$pb.TagNumber(1)
  void clearBitmap() => $_clearField(1);

  /// The number of bits of the last byte in `bitmap` to ignore as "padding".
  /// If the length of `bitmap` is zero, then this value must be `0`.
  /// Otherwise, this value must be between 0 and 7, inclusive.
  @$pb.TagNumber(2)
  $core.int get padding => $_getIZ(1);
  @$pb.TagNumber(2)
  set padding($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPadding() => $_has(1);
  @$pb.TagNumber(2)
  void clearPadding() => $_clearField(2);
}

/// A bloom filter (https://en.wikipedia.org/wiki/Bloom_filter).
///
/// The bloom filter hashes the entries with MD5 and treats the resulting 128-bit
/// hash as 2 distinct 64-bit hash values, interpreted as unsigned integers
/// using 2's complement encoding.
///
/// These two hash values, named `h1` and `h2`, are then used to compute the
/// `hash_count` hash values using the formula, starting at `i=0`:
///
///     h(i) = h1 + (i * h2)
///
/// These resulting values are then taken modulo the number of bits in the bloom
/// filter to get the bits of the bloom filter to test for the given entry.
class BloomFilter extends $pb.GeneratedMessage {
  factory BloomFilter({
    BitSequence? bits,
    $core.int? hashCount,
  }) {
    final result = BloomFilter._();
    if (bits != null) result.bits = bits;
    if (hashCount != null) result.hashCount = hashCount;
    return result;
  }

  BloomFilter._();

  factory BloomFilter.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BloomFilter()..mergeFromBuffer(data, registry);
  factory BloomFilter.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      BloomFilter()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BloomFilter',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'google.firestore.v1'),
      createEmptyInstance: BloomFilter.$_createMessage)
    ..aOM<BitSequence>(1, _omitFieldNames ? '' : 'bits',
        subBuilder: BitSequence.$_createMessage)
    ..aI(2, _omitFieldNames ? '' : 'hashCount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BloomFilter clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BloomFilter copyWith(void Function(BloomFilter) updates) =>
      super.copyWith((message) => updates(message as BloomFilter))
          as BloomFilter;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use BloomFilter() / BloomFilter.new instead')
  static BloomFilter create() => BloomFilter._();
  static $pb.GeneratedMessage $_createMessage() => BloomFilter._();
  @$core.override
  BloomFilter createEmptyInstance() => BloomFilter._();
  @$core.pragma('dart2js:noInline')
  static BloomFilter getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BloomFilter>(
          BloomFilter.$_createMessage);
  static BloomFilter? _defaultInstance;

  /// The bloom filter data.
  @$pb.TagNumber(1)
  BitSequence get bits => $_getN(0);
  @$pb.TagNumber(1)
  set bits(BitSequence value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasBits() => $_has(0);
  @$pb.TagNumber(1)
  void clearBits() => $_clearField(1);
  @$pb.TagNumber(1)
  BitSequence ensureBits() => $_ensure(0);

  /// The number of hashes used by the algorithm.
  @$pb.TagNumber(2)
  $core.int get hashCount => $_getIZ(1);
  @$pb.TagNumber(2)
  set hashCount($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHashCount() => $_has(1);
  @$pb.TagNumber(2)
  void clearHashCount() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
