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

// Adapted from google_cloud_pubsub's tool/compile_protos.dart in
// https://github.com/googleapis/google-cloud-dart (Apache-2.0).

/// Generates the protobuf message classes in `lib/src/generated/` from the
/// protos vendored by `tool/fetch_protos.dart`.
///
/// Requires `protoc` on the `PATH`. The Dart plugin is the `protoc_plugin`
/// dev dependency, pinned in `pubspec.yaml`. Run from
/// `packages/google_cloud_firestore`:
///
/// ```bash
/// dart run tool/compile_protos.dart
/// ```
library;

import 'dart:io';

const _outDir = 'lib/src/generated';

/// The `protoc` the checked-in code was generated with. The Dart output
/// comes from the pinned `protoc_plugin`, but a different `protoc` could still
/// parse the protos differently, so other versions are refused.
const _protocVersion = 'libprotoc 36.2';

/// Only the Firestore protos and the non-well-known message types they use
/// are generated. `google/api` only contributes options, and the well-known
/// types are imported from `package:protobuf`.
const _protosToCompile = [
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

/// Prepended to every generated file: the license header CI checks for, and
/// the marker that keeps generated code out of coverage.
const _header = '''
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

''';

void main() {
  if (!Directory('protos').existsSync()) {
    print('Protos directory not found! Please run fetch_protos.dart first.');
    exit(1);
  }

  String? version;
  try {
    final protoc = Process.runSync('protoc', ['--version']);
    if (protoc.exitCode == 0) version = (protoc.stdout as String).trim();
  } on ProcessException {
    // protoc is not on the PATH.
  }
  if (version != _protocVersion) {
    print(
      'Expected `protoc --version` to print "$_protocVersion", got '
      '"${version ?? 'no protoc on the PATH'}". Install that protoc release, or update _protocVersion '
      'after checking the regenerated code.',
    );
    exit(1);
  }

  final outDir = Directory(_outDir);
  if (outDir.existsSync()) outDir.deleteSync(recursive: true);
  outDir.createSync(recursive: true);

  print('Compiling protos...');
  final pluginScript = Platform.isWindows
      ? r'tool\protoc-gen-dart.bat'
      : 'tool/protoc-gen-dart.sh';
  final result = Process.runSync('protoc', [
    '--plugin=protoc-gen-dart=$pluginScript',
    // `grpc:` also emits the `package:grpc` client in `.pbgrpc.dart`.
    '--dart_out=grpc:$_outDir',
    '-I',
    'protos',
    ..._protosToCompile.map((path) => 'protos/$path'),
  ]);

  stdout.write(result.stdout);
  stderr.write(result.stderr);

  if (result.exitCode != 0) {
    print('Failed to compile protos!');
    exit(1);
  }

  for (final file in outDir.listSync(recursive: true).whereType<File>()) {
    // Descriptor JSON is unused.
    if (file.path.endsWith('.pbjson.dart') ||
        file.path.endsWith('.pbserver.dart')) {
      file.deleteSync();
      continue;
    }
    file.writeAsStringSync('$_header${file.readAsStringSync()}');
  }

  print('Successfully compiled protos!');
}
