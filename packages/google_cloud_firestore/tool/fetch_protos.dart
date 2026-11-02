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

// Adapted from google_cloud_pubsub's tool/fetch_protos.dart in
// https://github.com/googleapis/google-cloud-dart (Apache-2.0).

/// Downloads `google/firestore/v1/firestore.proto` and its transitive imports
/// into `protos/`, at pinned upstream commits so the vendored files (and the
/// code generated from them by `tool/compile_protos.dart`) are reproducible.
///
/// Run from `packages/google_cloud_firestore`:
///
/// ```bash
/// dart run tool/fetch_protos.dart
/// ```
library;

import 'dart:io';

import 'package:http/http.dart' as http;

/// googleapis/googleapis commit the Firestore and `google/api`, `google/rpc`
/// and `google/type` protos are fetched from.
const googleapisCommit = '954a825e3e4ceb076329a61ca6042f1fd6bc20b0';

/// protocolbuffers/protobuf commit (tag v36.2) the well-known types are
/// fetched from. They are only needed on protoc's import path: the generated
/// code uses the copies shipped with `package:protobuf`.
const protobufCommit = '2c74169b34066ceb8ddb6b882fcb3fb32d737a55';

const _googleapisBase =
    'https://raw.githubusercontent.com/googleapis/googleapis/$googleapisCommit';
const _protobufBase =
    'https://raw.githubusercontent.com/protocolbuffers/protobuf/$protobufCommit/src';

/// The transitive import closure of `google/firestore/v1/firestore.proto`.
const _googleapisProtos = [
  'google/api/annotations.proto',
  'google/api/client.proto',
  'google/api/field_behavior.proto',
  'google/api/http.proto',
  'google/api/launch_stage.proto',
  'google/api/routing.proto',
  'google/firestore/v1/aggregation_result.proto',
  'google/firestore/v1/bloom_filter.proto',
  'google/firestore/v1/common.proto',
  'google/firestore/v1/document.proto',
  'google/firestore/v1/explain_stats.proto',
  'google/firestore/v1/firestore.proto',
  'google/firestore/v1/pipeline.proto',
  'google/firestore/v1/query.proto',
  'google/firestore/v1/query_profile.proto',
  'google/firestore/v1/write.proto',
  'google/rpc/status.proto',
  'google/type/latlng.proto',
];

const _protobufProtos = [
  'google/protobuf/any.proto',
  'google/protobuf/descriptor.proto',
  'google/protobuf/duration.proto',
  'google/protobuf/empty.proto',
  'google/protobuf/struct.proto',
  'google/protobuf/timestamp.proto',
  'google/protobuf/wrappers.proto',
];

final _filesToFetch = {
  for (final path in _googleapisProtos) '$_googleapisBase/$path': path,
  for (final path in _protobufProtos) '$_protobufBase/$path': path,
};

Future<void> _fetchFile(
  http.Client client,
  String url,
  String relativePath,
) async {
  final file = File('protos/$relativePath');
  file.parent.createSync(recursive: true);

  print('Fetching $url ...');
  final response = await client.get(Uri.parse(url));
  if (response.statusCode == 200) {
    await file.writeAsBytes(response.bodyBytes);
    return;
  }
  throw Exception('Failed to fetch $url: ${response.statusCode}');
}

Future<void> main() async {
  final protosDir = Directory('protos');
  if (protosDir.existsSync()) {
    protosDir.deleteSync(recursive: true);
  }
  protosDir.createSync();

  final client = http.Client();
  try {
    await Future.wait([
      for (final MapEntry(key: url, value: path) in _filesToFetch.entries)
        _fetchFile(client, url, path),
    ]);
    print('Successfully fetched all protos!');
  } finally {
    client.close();
  }
}
