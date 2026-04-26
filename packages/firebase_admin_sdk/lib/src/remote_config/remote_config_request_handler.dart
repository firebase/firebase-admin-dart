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

part of 'remote_config.dart';

/// Orchestrates Remote Config operations: validation, JSON ↔ data-class
/// conversion, and ETag handling. Delegates raw HTTP work to
/// [RemoteConfigHttpClient].
@internal
class RemoteConfigRequestHandler {
  RemoteConfigRequestHandler(
    FirebaseApp app, {
    RemoteConfigHttpClient? httpClient,
  }) : _httpClient = httpClient ?? RemoteConfigHttpClient(app);

  final RemoteConfigHttpClient _httpClient;

  Future<RemoteConfigTemplate> getTemplate([String? versionNumber]) async {
    if (versionNumber != null) {
      _validateVersionNumber(versionNumber);
    }
    final result = await _httpClient.getTemplate(versionNumber: versionNumber);
    return _parseTemplate(result);
  }

  Future<RemoteConfigTemplate> validateTemplate(
    RemoteConfigTemplate template,
  ) async {
    _validateTemplate(template);
    final result = await _httpClient.publishTemplate(
      body: _buildRequestBody(template),
      etag: template.etag,
      validateOnly: true,
    );
    // The validate-only response returns an etag with a `-0` suffix to indicate
    // success. Restore the original etag so callers can use the template for
    // follow-on operations.
    if (result.etag == null || result.etag!.isEmpty) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'ETag header missing from validateTemplate response.',
      );
    }
    final parsed = RemoteConfigTemplate.fromJson(<String, Object?>{
      ...result.body,
      'etag': template.etag,
    });
    return parsed;
  }

  Future<RemoteConfigTemplate> publishTemplate(
    RemoteConfigTemplate template, {
    bool force = false,
  }) async {
    _validateTemplate(template);
    final result = await _httpClient.publishTemplate(
      body: _buildRequestBody(template),
      etag: force ? '*' : template.etag,
    );
    return _parseTemplate(result);
  }

  Future<RemoteConfigTemplate> rollback(String versionNumber) async {
    _validateVersionNumber(versionNumber);
    final result = await _httpClient.rollback(versionNumber);
    return _parseTemplate(result);
  }

  Future<ListVersionsResult> listVersions([
    ListVersionsOptions? options,
  ]) async {
    if (options?.endVersionNumber != null) {
      _validateVersionNumber(options!.endVersionNumber!, 'endVersionNumber');
    }
    final body = await _httpClient.listVersions(
      pageSize: options?.pageSize,
      pageToken: options?.pageToken,
      endVersionNumber: options?.endVersionNumber,
      startTime: options?.startTime,
      endTime: options?.endTime,
    );
    return ListVersionsResult.fromJson(body);
  }

  Future<ServerTemplateData> getServerTemplate() async {
    final result = await _httpClient.getServerTemplate();
    if (result.etag == null || result.etag!.isEmpty) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'ETag header missing from getServerTemplate response.',
      );
    }
    return ServerTemplateData.fromJson(<String, Object?>{
      ...result.body,
      'etag': result.etag,
    });
  }

  RemoteConfigTemplate _parseTemplate(RemoteConfigHttpResult result) {
    if (result.etag == null || result.etag!.isEmpty) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'ETag header missing from response.',
      );
    }
    return RemoteConfigTemplate.fromJson(<String, Object?>{
      ...result.body,
      'etag': result.etag,
    });
  }

  Map<String, Object?> _buildRequestBody(RemoteConfigTemplate template) {
    // The PUT body carries everything except the etag (sent as `If-Match`),
    // and version metadata is stripped of output-only fields — only the
    // user-provided description is allowed on input.
    final body = template.toJson()..remove('etag');
    final description = template.version?.description;
    if (description != null) {
      body['version'] = <String, Object?>{'description': description};
    } else {
      body.remove('version');
    }
    return body;
  }

  void _validateTemplate(RemoteConfigTemplate template) {
    if (template.etag.isEmpty) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'ETag must be a non-empty string.',
      );
    }
  }

  void _validateVersionNumber(
    String versionNumber, [
    String propertyName = 'versionNumber',
  ]) {
    if (versionNumber.isEmpty) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        '$propertyName must be a non-empty string in int64 format.',
      );
    }
    if (BigInt.tryParse(versionNumber) == null) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        '$propertyName must be an integer in int64 format.',
      );
    }
  }
}
