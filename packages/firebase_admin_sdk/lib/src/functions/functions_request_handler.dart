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

part of 'functions.dart';

/// Parsed resource name components.
class _ParsedResource {
  _ParsedResource({this.projectId, this.locationId, required this.resourceId});

  String? projectId;
  String? locationId;
  final String resourceId;
}

/// Request handler for Cloud Functions Task Queue operations.
///
/// Handles complex business logic, request/response transformations,
/// and validation. Delegates API calls to [FunctionsHttpClient].
class FunctionsRequestHandler {
  FunctionsRequestHandler(FirebaseApp app, {FunctionsHttpClient? httpClient})
    : _httpClient = httpClient ?? FunctionsHttpClient(app);

  final FunctionsHttpClient _httpClient;

  FunctionsHttpClient get httpClient => _httpClient;

  /// Enqueues a task to the specified function's queue.
  Future<void> enqueue(
    Map<String, dynamic> data,
    String functionName,
    FunctionScope scope,
    TaskOptions? options,
  ) async {
    validateNonEmptyString(functionName, 'functionName');

    // Parse the function name to extract project, location, and function ID
    final resources = _parseResourceName(functionName, 'functions');

    return _httpClient.cloudTasks((api, projectId) async {
      // Fill in missing resource components
      resources.projectId ??= projectId;
      resources.locationId ??= _defaultLocation;

      validateNonEmptyString(resources.resourceId, 'resourceId');

      final (queueId, extensionOrKitId) = _resolveResourceId(
        resources.resourceId,
        scope,
      );

      // Build the task
      final task = _buildTask(data, resources, queueId, options);

      // Update task with proper authentication (OIDC token or Authorization header)
      await _updateTaskAuth(task, await _httpClient.client, extensionOrKitId);

      final parent = _httpClient.buildTasksParent(
        projectId: resources.projectId!,
        locationId: resources.locationId!,
        queueId: queueId,
      );

      try {
        await api.projects.locations.queues.tasks.create(
          tasks2.CreateTaskRequest(task: task),
          parent,
        );
      } on tasks2.DetailedApiRequestError catch (error) {
        // Handle 409 Conflict (task already exists)
        if (error.status == 409) {
          throw FirebaseFunctionsAdminException(
            FunctionsClientErrorCode.taskAlreadyExists,
            'A task with ID ${options?.id} already exists',
          );
        }
        rethrow; // Will be caught by _functionsGuard
      }
    });
  }

  /// Deletes a task from the specified function's queue.
  Future<void> delete(
    String id,
    String functionName,
    FunctionScope scope,
  ) async {
    validateNonEmptyString(functionName, 'functionName');
    validateNonEmptyString(id, 'id');

    if (!isValidTaskId(id)) {
      throw FirebaseFunctionsAdminException(
        FunctionsClientErrorCode.invalidArgument,
        'id can contain only letters ([A-Za-z]), numbers ([0-9]), '
        'hyphens (-), or underscores (_). The maximum length is 500 characters.',
      );
    }

    // Parse the function name
    final resources = _parseResourceName(functionName, 'functions');

    return _httpClient.cloudTasks((api, projectId) async {
      // Fill in missing resource components
      resources.projectId ??= projectId;
      resources.locationId ??= _defaultLocation;

      validateNonEmptyString(resources.resourceId, 'resourceId');

      final (queueId, _) = _resolveResourceId(resources.resourceId, scope);

      // Build the full task name
      final taskName = _httpClient.buildTaskName(
        projectId: resources.projectId!,
        locationId: resources.locationId!,
        queueId: queueId,
        taskId: id,
      );

      try {
        await api.projects.locations.queues.tasks.delete(taskName);
      } on tasks2.DetailedApiRequestError catch (error) {
        // If the task doesn't exist (404), ignore the error
        if (error.status == 404) {
          return;
        }
        rethrow; // Will be caught by _functionsGuard
      }
    });
  }

  (String resourceId, String? extensionOrKitId) _resolveResourceId(
    String resourceId,
    FunctionScope scope,
  ) {
    switch (scope) {
      case _CurrentFunctionScope():
        final kitInstanceId = Environment.getKitInstanceId();
        if (kitInstanceId != null && kitInstanceId.isNotEmpty) {
          return ('kit-$kitInstanceId-$resourceId', kitInstanceId);
        }
        return (resourceId, null);
      case _GlobalFunctionScope():
        return (resourceId, null);
      case _ExtensionFunctionScope(:final extensionId):
        return ('ext-$extensionId-$resourceId', extensionId);
      case _KitFunctionScope(:final kit):
        return ('kit-$kit-$resourceId', kit);
      case _ExtensionOrKitFunctionScope(:final instance):
        return ('ext-$instance-$resourceId', instance);
    }
  }

  /// Parses a resource name into its components.
  ///
  /// Supports:
  /// - Full: `projects/{project}/locations/{location}/functions/{functionName}`
  /// - Partial: `locations/{location}/functions/{functionName}`
  /// - Simple: `{functionName}`
  _ParsedResource _parseResourceName(
    String resourceName,
    String resourceIdKey,
  ) {
    // Simple case: no slashes means it's just the resource ID
    if (!resourceName.contains('/')) {
      return _ParsedResource(resourceId: resourceName);
    }

    // Parse full or partial resource name
    final regex = RegExp(
      '^(projects/([^/]+)/)?locations/([^/]+)/$resourceIdKey/([^/]+)\$',
    );
    final match = regex.firstMatch(resourceName);

    if (match == null) {
      throw FirebaseFunctionsAdminException(
        FunctionsClientErrorCode.invalidArgument,
        'Invalid resource name format.',
      );
    }

    return _ParsedResource(
      projectId: match.group(2), // Optional project ID
      locationId: match.group(3), // Required location
      resourceId: match.group(4)!, // Required resource ID
    );
  }

  /// Builds a Cloud Tasks Task from the given data and options.
  tasks2.Task _buildTask(
    Map<String, dynamic> data,
    _ParsedResource resources,
    String queueId,
    TaskOptions? options,
  ) {
    // Base64 encode the data payload
    final bodyBytes = utf8.encode(jsonEncode({'data': data}));
    final bodyBase64 = base64Encode(bodyBytes);

    // Build HTTP request
    final httpRequest = tasks2.HttpRequest(
      body: bodyBase64,
      headers: {'Content-Type': 'application/json', ...?options?.headers},
    );

    // Build the task
    final task = tasks2.Task(httpRequest: httpRequest);

    // Set schedule time using pattern matching on DeliverySchedule
    switch (options?.schedule) {
      case AbsoluteDelivery(:final scheduleTime):
        task.scheduleTime = scheduleTime.toUtc().toIso8601String();
      case DelayDelivery(:final scheduleDelaySeconds):
        final scheduledTime = DateTime.now().toUtc().add(
          Duration(seconds: scheduleDelaySeconds),
        );
        task.scheduleTime = scheduledTime.toIso8601String();
      case null:
        // No scheduling specified - task will be enqueued immediately
        break;
    }

    // Set dispatch deadline
    if (options?.dispatchDeadlineSeconds != null) {
      task.dispatchDeadline = '${options!.dispatchDeadlineSeconds}s';
    }

    // Set task ID (for deduplication)
    if (options?.id != null) {
      task.name = _httpClient.buildTaskName(
        projectId: resources.projectId!,
        locationId: resources.locationId!,
        queueId: queueId,
        taskId: options!.id!,
      );
    }

    // Set custom URI if provided (experimental feature)
    if (options?.experimental?.uri != null) {
      httpRequest.url = options!.experimental!.uri;
    } else {
      // Use default function URL
      httpRequest.url = _httpClient.buildFunctionUrl(
        projectId: resources.projectId!,
        locationId: resources.locationId!,
        functionName: queueId,
      );
    }

    // Note: Authentication (OIDC token or Authorization header) is set
    // separately via _updateTaskAuth after the task is built.

    return task;
  }

  /// Updates the task with proper authentication.
  ///
  /// This method handles the authentication strategy based on the credential type:
  /// - When running with emulator: Uses a default emulated service account email
  /// - When running as an extension with ComputeEngine credentials: Uses ID token
  ///   with Authorization header (Cloud Tasks will not override this)
  /// - Otherwise: Uses OIDC token with the service account email
  Future<void> _updateTaskAuth(
    tasks2.Task task,
    googleapis_auth.AuthClient authClient,
    String? extensionOrKitId,
  ) async {
    final httpRequest = task.httpRequest!;

    // Check if running with emulator
    if (Environment.isCloudTasksEmulatorEnabled()) {
      httpRequest.oidcToken = tasks2.OidcToken(
        serviceAccountEmail: _emulatedServiceAccountDefault,
      );
      return;
    }

    // Service credentials via `FirebaseApp.options`.
    final isComputeEngine =
        _httpClient.app.options.credential?.serviceAccountCredentials == null;

    if (extensionOrKitId != null &&
        extensionOrKitId.isNotEmpty &&
        isComputeEngine) {
      // Running as extension with ComputeEngine - use ID token with Authorization header.
      final idToken = authClient.credentials.idToken;
      if (idToken != null && idToken.isNotEmpty) {
        httpRequest.headers = {
          ...?httpRequest.headers,
          'Authorization': 'Bearer $idToken',
        };
        // Don't set oidcToken when using Authorization header,
        // as Cloud Tasks would overwrite our Authorization header.
        httpRequest.oidcToken = null;
        return;
      }
    }

    // Default: Use OIDC token with service account email.
    // Try to get service account email from credential first, then from metadata service.
    final serviceAccountEmail = await _httpClient.app.serviceAccountEmail;

    if (serviceAccountEmail.isEmpty) {
      throw FirebaseFunctionsAdminException(
        FunctionsClientErrorCode.invalidCredential,
        'Failed to determine service account email. Initialize the SDK with '
        'service account credentials or ensure you are running on Google Cloud '
        'infrastructure with a default service account.',
      );
    }

    httpRequest.oidcToken = tasks2.OidcToken(
      serviceAccountEmail: serviceAccountEmail,
    );
  }
}
