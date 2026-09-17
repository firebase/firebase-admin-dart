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

part of 'messaging.dart';

/// Request handler for Firebase Cloud Messaging API operations.
///
/// Handles complex business logic, request/response transformations,
/// and validation. Delegates simple API calls to [FirebaseMessagingHttpClient].
class FirebaseMessagingRequestHandler {
  FirebaseMessagingRequestHandler(
    FirebaseApp app, {
    FirebaseMessagingHttpClient? httpClient,
  }) : _httpClient = httpClient ?? FirebaseMessagingHttpClient(app);

  final FirebaseMessagingHttpClient _httpClient;

  /// Sends the given message via FCM.
  ///
  /// - [message] - The message payload.
  /// - [dryRun] - Whether to send the message in the dry-run
  ///   (validation only) mode.
  ///
  /// Returns a unique message ID string after the message has been successfully
  /// handed off to the FCM service for delivery.
  Future<String> send(Message message, {bool? dryRun}) {
    return _httpClient.v1((api, projectId) async {
      final parent = _httpClient.buildParent(projectId);
      final response = await api.projects.messages.send(
        fmc1.SendMessageRequest(
          message: message._toRequest(),
          validateOnly: dryRun,
        ),
        parent,
      );

      final name = response.name;
      if (name == null) {
        throw FirebaseMessagingAdminException(
          MessagingClientErrorCode.internalError,
          'No name in response',
        );
      }

      return name;
    });
  }

  /// Sends each message in the given array via Firebase Cloud Messaging.
  ///
  // TODO once we have Messaging.sendAll, add the following:
  // Unlike [Messaging.sendAll], this method makes a single RPC call for each message
  // in the given array.
  ///
  /// The responses list obtained from the return value corresponds to the order of `messages`.
  /// An error from this method or a `BatchResponse` with all failures indicates a total failure,
  /// meaning that none of the messages in the list could be sent. Partial failures or no
  /// failures are only indicated by a `BatchResponse` return value.
  ///
  /// - [messages]: A non-empty array containing up to 500 messages.
  /// - [dryRun]: Whether to send the messages in the dry-run
  ///   (validation only) mode.
  Future<BatchResponse> sendEach(List<Message> messages, {bool? dryRun}) {
    return _httpClient.v1((api, projectId) async {
      if (messages.isEmpty) {
        throw FirebaseMessagingAdminException(
          MessagingClientErrorCode.invalidArgument,
          'messages must be a non-empty array',
        );
      }
      if (messages.length > _fmcMaxBatchSize) {
        throw FirebaseMessagingAdminException(
          MessagingClientErrorCode.invalidArgument,
          'messages list must not contain more than $_fmcMaxBatchSize items',
        );
      }

      final parent = _httpClient.buildParent(projectId);
      final responses = await Future.wait<SendResponse>(
        messages.map((message) async {
          final response = api.projects.messages.send(
            fmc1.SendMessageRequest(
              message: message._toRequest(),
              validateOnly: dryRun,
            ),
            parent,
          );

          return response.then(
            (value) {
              return SendResponse._(success: true, messageId: value.name);
            },
            onError: (Object? error) {
              // Convert DetailedApiRequestError to FirebaseMessagingAdminException
              final messagingError = error is FirebaseMessagingAdminException
                  ? error
                  : error is fmc1.DetailedApiRequestError
                  ? _createFirebaseError(
                      statusCode: error.status,
                      body: switch (error.jsonResponse) {
                        null => '',
                        final json => jsonEncode(json),
                      },
                      isJson: error.jsonResponse != null,
                    )
                  : FirebaseMessagingAdminException(
                      MessagingClientErrorCode.internalError,
                      error.toString(),
                    );

              return SendResponse._(success: false, error: messagingError);
            },
          );
        }),
      );

      final successCount = responses.where((r) => r.success).length;

      return BatchResponse._(
        responses: responses,
        successCount: successCount,
        failureCount: responses.length - successCount,
      );
    });
  }

  /// Sends the given multicast message to all the FCM registration tokens
  /// specified in it.
  ///
  /// This method uses the [sendEach] API under the hood to send the given
  /// message to all the target recipients. The responses list obtained from the
  /// return value corresponds to the order of tokens in the `MulticastMessage`.
  /// An error from this method or a `BatchResponse` with all failures indicates a total
  /// failure, meaning that the messages in the list could be sent. Partial failures or
  /// failures are only indicated by a `BatchResponse` return value.
  ///
  /// - [message]: A multicast message containing up to 500 tokens.
  /// - [dryRun]: Whether to send the message in the dry-run
  ///   (validation only) mode.
  Future<BatchResponse> sendEachForMulticast(
    MulticastMessage message, {
    bool? dryRun,
  }) {
    return sendEach(
      message.tokens
          .map(
            (token) => TokenMessage(
              token: token,
              data: message.data,
              notification: message.notification,
              android: message.android,
              apns: message.apns,
              fcmOptions: message.fcmOptions,
              webpush: message.webpush,
            ),
          )
          .toList(),
      dryRun: dryRun,
    );
  }

  /// Subscribes a list of registration tokens to an FCM topic.
  Future<MessagingTopicManagementResponse> subscribeToTopic(
    List<String> registrationTokens,
    String topic,
  ) {
    return _sendTopicManagementRequestV1(
      registrationTokens: registrationTokens,
      topic: topic,
      methodName: 'subscribeToTopic',
      isSubscribe: true,
    );
  }

  /// Unsubscribes a list of registration tokens from an FCM topic.
  Future<MessagingTopicManagementResponse> unsubscribeFromTopic(
    List<String> registrationTokens,
    String topic,
  ) {
    return _sendTopicManagementRequestV1(
      registrationTokens: registrationTokens,
      topic: topic,
      methodName: 'unsubscribeFromTopic',
      isSubscribe: false,
    );
  }

  /// Subscribes a list of registration tokens to an FCM topic using the legacy IID API.
  Future<MessagingTopicManagementResponse> subscribeToTopicLegacy(
    List<String> registrationTokens,
    String topic,
  ) {
    return _sendTopicManagementRequestLegacy(
      registrationTokens,
      topic,
      'subscribeToTopicLegacy',
      '/iid/v1:batchAdd',
    );
  }

  /// Unsubscribes a list of registration tokens from an FCM topic using the legacy IID API.
  Future<MessagingTopicManagementResponse> unsubscribeFromTopicLegacy(
    List<String> registrationTokens,
    String topic,
  ) {
    return _sendTopicManagementRequestLegacy(
      registrationTokens,
      topic,
      'unsubscribeFromTopicLegacy',
      '/iid/v1:batchRemove',
    );
  }

  /// Sends a topic management request using FCM v1 REST API.
  Future<MessagingTopicManagementResponse> _sendTopicManagementRequestV1({
    required List<String> registrationTokens,
    required String topic,
    required String methodName,
    required bool isSubscribe,
  }) async {
    _validateRegistrationTokens(registrationTokens, methodName);
    _validateTopic(topic, methodName);

    final cleanTopic = topic.startsWith('/topics/')
        ? topic.substring('/topics/'.length)
        : topic;

    return _httpClient.withClient((client, projectId) async {
      final maxWorkers = math.min(registrationTokens.length, 100);
      final results = List<_TopicWorkerResult?>.filled(
        registrationTokens.length,
        null,
      );
      var nextIndex = 0;

      Future<void> runWorker() async {
        while (true) {
          if (nextIndex >= registrationTokens.length) {
            return;
          }
          final i = nextIndex++;
          final token = registrationTokens[i];
          results[i] = await _sendSingleTopicRequestV1(
            client: client,
            projectId: projectId,
            token: token,
            cleanTopic: cleanTopic,
            isSubscribe: isSubscribe,
            index: i,
          );
        }
      }

      await Future.wait(List.generate(maxWorkers, (_) => runWorker()));

      var successCount = 0;
      var failureCount = 0;
      final errors = <FirebaseArrayIndexError>[];

      for (var i = 0; i < results.length; i++) {
        final result = results[i]!;
        if (result.isSuccess) {
          successCount++;
        } else {
          failureCount++;
          errors.add(FirebaseArrayIndexError(index: i, error: result.error!));
        }
      }

      return MessagingTopicManagementResponse._(
        failureCount: failureCount,
        successCount: successCount,
        errors: errors,
      );
    });
  }

  Future<_TopicWorkerResult> _sendSingleTopicRequestV1({
    required googleapis_auth.AuthClient client,
    required String projectId,
    required String token,
    required String cleanTopic,
    required bool isSubscribe,
    required int index,
  }) async {
    try {
      final encodedToken = Uri.encodeComponent(token);
      final encodedTopic = Uri.encodeComponent(cleanTopic);

      final Response response;
      if (isSubscribe) {
        final uri = Uri.https(
          _httpClient.fcmHost,
          '/v1/projects/$projectId/registrations/$encodedToken/topicSubscriptions',
          {'topic_name': cleanTopic},
        );
        response = await client.post(
          uri,
          headers: {
            'content-type': 'application/json; charset=UTF-8',
            'x-goog-api-format-version': '2',
          },
          body: '{}',
        );
      } else {
        final uri = Uri.https(
          _httpClient.fcmHost,
          '/v1/projects/$projectId/registrations/$encodedToken/topicSubscriptions/$encodedTopic',
          {'allow_missing': 'true'},
        );
        response = await client.delete(
          uri,
          headers: {'x-goog-api-format-version': '2'},
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _TopicWorkerResult.success(index);
      }

      if (isSubscribe && _isAlreadyExists(response)) {
        return _TopicWorkerResult.success(index);
      }

      final error = _parseTopicError(response);
      return _TopicWorkerResult.failure(index, error);
    } catch (e) {
      final adminException = e is FirebaseMessagingAdminException
          ? e
          : FirebaseMessagingAdminException(
              MessagingClientErrorCode.unknownError,
              e.toString(),
            );
      return _TopicWorkerResult.failure(index, adminException);
    }
  }

  bool _isAlreadyExists(Response response) {
    if (response.statusCode == 409) return true;
    if (response.isJson) {
      try {
        final json = jsonDecode(response.body);
        final errorCode = _getErrorCode(json);
        if (errorCode == 'ALREADY_EXISTS' || errorCode == 'CONFLICT') {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  FirebaseMessagingAdminException _parseTopicError(Response response) {
    if (response.isJson) {
      try {
        final json = jsonDecode(response.body);
        final errorCode = _getErrorCode(json);
        final errorMessage = _getErrorMessage(json);
        if (errorCode != null) {
          return FirebaseMessagingAdminException.fromServerError(
            serverErrorCode: errorCode,
            message: errorMessage,
            rawServerResponse: json,
          );
        }
      } catch (_) {}
    }

    final error = switch (response.statusCode) {
      400 => MessagingClientErrorCode.invalidArgument,
      401 || 403 => MessagingClientErrorCode.authenticationError,
      404 => MessagingClientErrorCode.registrationTokenNotRegistered,
      429 => MessagingClientErrorCode.messageRateExceeded,
      500 => MessagingClientErrorCode.internalError,
      503 => MessagingClientErrorCode.serverUnavailable,
      _ => MessagingClientErrorCode.unknownError,
    };

    return FirebaseMessagingAdminException(
      error,
      '${error.message} Raw server response: "${response.body}". Status code: ${response.statusCode}.',
    );
  }

  /// Sends a topic management request to the legacy IID API.
  Future<MessagingTopicManagementResponse> _sendTopicManagementRequestLegacy(
    List<String> registrationTokens,
    String topic,
    String methodName,
    String path,
  ) async {
    // Validate inputs
    _validateRegistrationTokens(registrationTokens, methodName);
    _validateTopic(topic, methodName);

    // Normalize topic (prepend /topics/ if needed)
    final normalizedTopic = _normalizeTopic(topic);

    // Make the request
    final response = await _httpClient.invokeRequestHandler(
      host: _httpClient.iidApiHost,
      path: path,
      requestData: {
        'to': normalizedTopic,
        'registration_tokens': registrationTokens,
      },
    );

    // Map the response
    return _mapRawResponseToTopicManagementResponse(response);
  }

  /// Validates registration tokens list.
  void _validateRegistrationTokens(
    List<String> registrationTokens,
    String methodName,
  ) {
    if (registrationTokens.isEmpty) {
      throw FirebaseMessagingAdminException(
        MessagingClientErrorCode.invalidArgument,
        'Registration tokens provided to $methodName() must be a non-empty list.',
      );
    }

    if (registrationTokens.length > 1000) {
      throw FirebaseMessagingAdminException(
        MessagingClientErrorCode.invalidArgument,
        'Registration tokens provided to $methodName() must not contain more than 1000 tokens.',
      );
    }

    for (final token in registrationTokens) {
      if (token.isEmpty) {
        throw FirebaseMessagingAdminException(
          MessagingClientErrorCode.invalidArgument,
          'Registration tokens provided to $methodName() must all be non-empty strings.',
        );
      }
    }
  }

  /// Validates the topic format.
  void _validateTopic(String topic, String methodName) {
    if (topic.isEmpty) {
      throw FirebaseMessagingAdminException(
        MessagingClientErrorCode.invalidArgument,
        'Topic provided to $methodName() must be a non-empty string.',
      );
    }

    final topicRegex = RegExp(r'^(/topics/)?(private/)?[a-zA-Z0-9\-_.~%]+$');

    if (!topicRegex.hasMatch(topic)) {
      throw FirebaseMessagingAdminException(
        MessagingClientErrorCode.invalidArgument,
        'Topic provided to $methodName() must be a string which matches the format '
        '"/topics/[a-zA-Z0-9-_.~%]+".',
      );
    }
  }

  /// Normalizes a topic by prepending '/topics/' if necessary.
  String _normalizeTopic(String topic) {
    if (!topic.startsWith('/topics/')) {
      return '/topics/$topic';
    }
    return topic;
  }

  /// Maps the raw IID API response to MessagingTopicManagementResponse.
  MessagingTopicManagementResponse _mapRawResponseToTopicManagementResponse(
    Object? response,
  ) {
    var successCount = 0;
    var failureCount = 0;
    final errors = <FirebaseArrayIndexError>[];

    if (response is Map && response.containsKey('results')) {
      final results = response['results'] as List<dynamic>;

      for (var index = 0; index < results.length; index++) {
        final result = results[index] as Map;

        if (result.containsKey('error')) {
          failureCount++;
          final errorMessage = result['error'] as String;

          errors.add(
            FirebaseArrayIndexError(
              index: index,
              error: FirebaseMessagingAdminException(
                MessagingClientErrorCode.unknownError,
                errorMessage,
              ),
            ),
          );
        } else {
          successCount++;
        }
      }
    }

    return MessagingTopicManagementResponse._(
      failureCount: failureCount,
      successCount: successCount,
      errors: errors,
    );
  }
}

class _TopicWorkerResult {
  _TopicWorkerResult.success(this.index) : error = null;
  _TopicWorkerResult.failure(this.index, this.error);

  final int index;
  final FirebaseMessagingAdminException? error;
  bool get isSuccess => error == null;
}
