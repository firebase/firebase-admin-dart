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

import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:firebase_admin_sdk/remote_config.dart';

Future<void> remoteConfigExample(FirebaseApp admin) async {
  print('\n### Remote Config Example ###\n');

  final remoteConfig = admin.remoteConfig();

  // Example 1: Read the active template.
  RemoteConfigTemplate? template;
  try {
    print('> Fetching active template...\n');
    template = await remoteConfig.getTemplate();
    print('Template fetched!');
    print('  - ETag: ${template.etag}');
    print('  - Conditions: ${template.conditions.length}');
    print('  - Parameters: ${template.parameters.length}');
    print('  - Parameter groups: ${template.parameterGroups.length}');
    if (template.version != null) {
      print('  - Version: ${template.version!.versionNumber}');
    }
    print('');
  } on FirebaseRemoteConfigException catch (e) {
    print('> Remote Config error: ${e.code} - ${e.message}');
    return;
  } catch (e) {
    print('> Error fetching template: $e');
    return;
  }

  // Example 2: Validate a modified template without publishing.
  try {
    print('> Validating a modified template (no publish)...\n');
    final modified = RemoteConfigTemplate(
      etag: template.etag,
      conditions: template.conditions,
      parameters: <String, RemoteConfigParameter>{
        ...template.parameters,
        'dart_admin_sdk_demo': RemoteConfigParameter(
          defaultValue: const ExplicitParameterValue(value: 'hello'),
          description: 'Demo parameter from the Dart Admin SDK example.',
          valueType: ParameterValueType.string,
        ),
      },
      parameterGroups: template.parameterGroups,
      version: template.version,
    );
    final validated = await remoteConfig.validateTemplate(modified);
    print('Template validated!');
    print('  - ETag (restored): ${validated.etag}');
    print('');
  } on FirebaseRemoteConfigException catch (e) {
    print('> Remote Config error: ${e.code} - ${e.message}');
  } catch (e) {
    print('> Error validating template: $e');
  }

  // Example 3: List published versions.
  try {
    print('> Listing published versions (page size 5)...\n');
    final result = await remoteConfig.listVersions(
      ListVersionsOptions(pageSize: 5),
    );
    print('Got ${result.versions.length} version(s):');
    for (final v in result.versions) {
      print('  - v${v.versionNumber}: ${v.description ?? '(no description)'}');
    }
    print('');
  } on FirebaseRemoteConfigException catch (e) {
    print('> Remote Config error: ${e.code} - ${e.message}');
  } catch (e) {
    print('> Error listing versions: $e');
  }

  // Example 4: Server-side template evaluation.
  try {
    print('> Fetching server template and evaluating...\n');
    final serverTemplate = await remoteConfig.getServerTemplate(
      defaultConfig: const <String, Object>{
        'enable_new_ui': false,
        'max_items': 50,
      },
    );
    final config = serverTemplate.evaluate(
      const EvaluationContext(
        randomizationId: 'demo-user-id',
        customSignals: <String, Object>{
          'app_version': '2.3.1',
          'country': 'US',
        },
      ),
    );
    print('Server config evaluated!');
    print('  - enable_new_ui: ${config.getBoolean('enable_new_ui')}');
    print('  - max_items: ${config.getInt('max_items')}');
    final all = config.getAll();
    print('  - total resolved keys: ${all.length}');
    print('');
  } on FirebaseRemoteConfigException catch (e) {
    print('> Remote Config error: ${e.code} - ${e.message}');
  } catch (e) {
    print('> Error evaluating server template: $e');
  }
}
