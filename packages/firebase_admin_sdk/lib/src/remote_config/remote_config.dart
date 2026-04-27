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

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:googleapis_auth/auth_io.dart' as googleapis_auth;
import 'package:http/http.dart';
import 'package:meta/meta.dart';

import '../app.dart';

part 'condition_evaluator.dart';
part 'remote_config_api.dart';
part 'remote_config_exception.dart';
part 'remote_config_http_client.dart';
part 'remote_config_request_handler.dart';

/// Manages Firebase Remote Config templates and evaluates server-side
/// configuration.
///
/// Access via [FirebaseApp.remoteConfig].
class RemoteConfig implements FirebaseService {
  /// Creates or returns the cached Remote Config instance for the given app.
  @internal
  factory RemoteConfig.internal(
    FirebaseApp app, {
    RemoteConfigRequestHandler? requestHandler,
  }) {
    return app.getOrInitService(
      FirebaseServiceType.remoteConfig.name,
      (app) => RemoteConfig._(app, requestHandler: requestHandler),
    );
  }

  RemoteConfig._(this.app, {RemoteConfigRequestHandler? requestHandler})
    : _requestHandler = requestHandler ?? RemoteConfigRequestHandler(app);

  @override
  final FirebaseApp app;

  final RemoteConfigRequestHandler _requestHandler;

  /// Returns a Remote Config template.
  ///
  /// With no argument, returns the current active version. Passing
  /// [versionNumber] (an integer in int64 format) returns that specific
  /// historical version.
  Future<RemoteConfigTemplate> getTemplate([String? versionNumber]) {
    return _requestHandler.getTemplate(versionNumber);
  }

  /// Validates a Remote Config template against the server. Returns the
  /// validated template (with the original etag).
  Future<RemoteConfigTemplate> validateTemplate(
    RemoteConfigTemplate template,
  ) => _requestHandler.validateTemplate(template);

  /// Publishes a Remote Config template.
  ///
  /// If [force] is true, the request bypasses the etag check (sends `If-Match: *`).
  /// Bypassing the etag risks losing concurrent updates and is not recommended.
  Future<RemoteConfigTemplate> publishTemplate(
    RemoteConfigTemplate template, {
    bool force = false,
  }) => _requestHandler.publishTemplate(template, force: force);

  /// Rolls back the published template to the specified [versionNumber].
  ///
  /// [versionNumber] must be lower than the current version and not deleted
  /// due to staleness. Equivalent to publishing a previously published template
  /// with `force: true`.
  Future<RemoteConfigTemplate> rollback(String versionNumber) {
    return _requestHandler.rollback(versionNumber);
  }

  /// Lists published template versions in reverse chronological order.
  Future<ListVersionsResult> listVersions([ListVersionsOptions? options]) {
    return _requestHandler.listVersions(options);
  }

  /// Builds a [RemoteConfigTemplate] from a JSON string. Throws
  /// [FirebaseRemoteConfigException] with code `invalid-argument` on parse
  /// failure or missing required fields.
  RemoteConfigTemplate createTemplateFromJson(String json) {
    if (json.isEmpty) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'JSON string must be a non-empty string.',
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } catch (e) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'Failed to parse the JSON string: $json. $e',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.invalidArgument,
        'JSON must decode to an object, got ${decoded.runtimeType}.',
      );
    }
    return RemoteConfigTemplate.fromJson(decoded);
  }

  /// Fetches and caches the current active server template, returning a
  /// [ServerTemplate] ready for [ServerTemplate.evaluate].
  Future<ServerTemplate> getServerTemplate({
    Map<String, Object>? defaultConfig,
  }) async {
    final template = initServerTemplate(defaultConfig: defaultConfig);
    await template.load();
    return template;
  }

  /// Synchronously builds a [ServerTemplate] without fetching. The caller can
  /// pre-load the template via [ServerTemplate.set] or trigger a fetch via
  /// [ServerTemplate.load].
  ///
  /// [template] may be a [ServerTemplateData] or a JSON string in
  /// [ServerTemplateData] shape.
  ServerTemplate initServerTemplate({
    Map<String, Object>? defaultConfig,
    Object? template,
  }) {
    final result = ServerTemplate._(
      _requestHandler,
      ConditionEvaluator(),
      defaultConfig ?? const <String, Object>{},
    );
    if (template != null) {
      result.set(template);
    }
    return result;
  }

  @override
  Future<void> delete() async {
    // No cleanup needed.
  }
}

/// Stateful wrapper around a server-side Remote Config template, with built-in
/// caching and in-process evaluation against an [EvaluationContext].
///
/// Obtain instances via [RemoteConfig.getServerTemplate] (asynchronous fetch)
/// or [RemoteConfig.initServerTemplate] (synchronous, no fetch).
class ServerTemplate {
  ServerTemplate._(
    this._requestHandler,
    this._evaluator,
    Map<String, Object> defaultConfig,
  ) : defaultConfig = Map<String, Object>.unmodifiable(defaultConfig),
      _stringifiedDefaultConfig = <String, String>{
        for (final entry in defaultConfig.entries) entry.key: '${entry.value}',
      };

  final RemoteConfigRequestHandler _requestHandler;
  final ConditionEvaluator _evaluator;

  /// In-app default values used by [evaluate] for keys missing from the
  /// remote template. Values must be `String`, `num`, or `bool`.
  final Map<String, Object> defaultConfig;

  final Map<String, String> _stringifiedDefaultConfig;
  ServerTemplateData? _cache;

  /// Fetches the current active server template and caches it locally.
  Future<void> load() async {
    _cache = await _requestHandler.getServerTemplate();
  }

  /// Replaces the cached template. [data] may be a [ServerTemplateData] or a
  /// JSON string in [ServerTemplateData] shape.
  void set(Object data) {
    if (data is ServerTemplateData) {
      _cache = data;
      return;
    }
    if (data is String) {
      Object? parsed;
      try {
        parsed = jsonDecode(data);
      } catch (e) {
        throw FirebaseRemoteConfigException(
          RemoteConfigErrorCode.invalidArgument,
          'Failed to parse the JSON string: $data. $e',
        );
      }
      if (parsed is! Map<String, Object?>) {
        throw FirebaseRemoteConfigException(
          RemoteConfigErrorCode.invalidArgument,
          'JSON must decode to an object, got ${parsed.runtimeType}.',
        );
      }
      _cache = ServerTemplateData.fromJson(parsed);
      return;
    }
    throw FirebaseRemoteConfigException(
      RemoteConfigErrorCode.invalidArgument,
      'Expected ServerTemplateData or String, got ${data.runtimeType}.',
    );
  }

  /// Evaluates the cached template against [context] and returns a
  /// [ServerConfig].
  ///
  /// Throws [FirebaseRemoteConfigException] with code `failed-precondition`
  /// if no template is cached. Call [load] or [set] first.
  ServerConfig evaluate([EvaluationContext? context]) {
    final template = _cache;
    if (template == null) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.failedPrecondition,
        'No Remote Config Server template in cache. '
        'Call load() before calling evaluate().',
      );
    }

    final ctx = context ?? const EvaluationContext();
    final conditionResults = _evaluator.evaluateConditions(
      template.conditions,
      ctx,
    );

    // 1. Seed config values with stringified default config.
    final configValues = <String, Value>{
      for (final entry in _stringifiedDefaultConfig.entries)
        entry.key: Value._(ValueSource.valueDefault, entry.value),
    };

    // 2. Overlay parameter values from the evaluated template.
    for (final entry in template.parameters.entries) {
      final key = entry.key;
      final parameter = entry.value;
      final conditionalValues =
          parameter.conditionalValues ??
          const <String, RemoteConfigParameterValue>{};

      RemoteConfigParameterValue? selected;
      // Iterate evaluated conditions in template order; first match wins.
      for (final result in conditionResults.entries) {
        final conditionalValue = conditionalValues[result.key];
        if (conditionalValue != null && result.value) {
          selected = conditionalValue;
          break;
        }
      }

      if (selected is InAppDefaultValue) {
        // Use whatever was already in defaultConfig; do not override.
        continue;
      }
      if (selected is ExplicitParameterValue) {
        configValues[key] = Value._(ValueSource.valueRemote, selected.value);
        continue;
      }

      // No matching conditional value — fall back to the parameter default.
      final defaultValue = parameter.defaultValue;
      if (defaultValue is InAppDefaultValue) continue;
      if (defaultValue is ExplicitParameterValue) {
        configValues[key] = Value._(
          ValueSource.valueRemote,
          defaultValue.value,
        );
      }
    }

    return ServerConfig.internal(configValues);
  }

  /// Returns the cached [ServerTemplateData], or throws if no template has
  /// been loaded.
  ServerTemplateData toJson() {
    final cache = _cache;
    if (cache == null) {
      throw FirebaseRemoteConfigException(
        RemoteConfigErrorCode.failedPrecondition,
        'No Remote Config Server template in cache. '
        'Call load() or set() before calling toJson().',
      );
    }
    return cache;
  }
}
