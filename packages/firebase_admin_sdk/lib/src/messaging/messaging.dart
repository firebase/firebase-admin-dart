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
import 'dart:math' as math;

import 'package:googleapis/fcm/v1.dart' as fmc1;
import 'package:googleapis_auth/auth_io.dart' as googleapis_auth;
import 'package:http/http.dart';
import 'package:meta/meta.dart';

import '../app.dart';

part 'fmc_exception.dart';
part 'messaging_api.dart';
part 'messaging_http_client.dart';
part 'messaging_request_handler.dart';

const _fmcMaxBatchSize = 500;

/// An interface for interacting with the Firebase Cloud Messaging service.
class Messaging implements FirebaseService {
  /// Creates or returns the cached Messaging instance for the given app.
  @internal
  factory Messaging.internal(
    FirebaseApp app, {
    FirebaseMessagingRequestHandler? requestHandler,
  }) {
    return app.getOrInitService(
      FirebaseServiceType.messaging.name,
      (app) => Messaging._(app, requestHandler: requestHandler),
    );
  }

  /// An interface for interacting with the Firebase Cloud Messaging service.
  Messaging._(this.app, {FirebaseMessagingRequestHandler? requestHandler})
    : _requestHandler = requestHandler ?? FirebaseMessagingRequestHandler(app);

  /// The app associated with this Messaging instance.
  @override
  final FirebaseApp app;

  final FirebaseMessagingRequestHandler _requestHandler;

  /// Sends the given message via FCM.
  ///
  /// - [message] - The message payload.
  /// - [dryRun] - Whether to send the message in the dry-run
  ///   (validation only) mode.
  ///
  /// Returns a unique message ID string after the message has been successfully
  /// handed off to the FCM service for delivery.
  Future<String> send(Message message, {bool? dryRun}) {
    return _requestHandler.send(message, dryRun: dryRun);
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
    return _requestHandler.sendEach(messages, dryRun: dryRun);
  }

  /// Sends the given multicast message to all the FCM registration tokens
  /// specified in it.
  ///
  /// This method uses the [Messaging.sendEach] API under the hood to send the given
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
    return _requestHandler.sendEachForMulticast(message, dryRun: dryRun);
  }

  /// Subscribes a list of registration tokens to an FCM topic.
  ///
  /// See [Subscribe to a topic](https://firebase.google.com/docs/cloud-messaging/admin/manage-topic-subscriptions#subscribe_to_a_topic)
  /// for code samples and detailed documentation.
  ///
  /// - [registrationTokens]: A list of registration tokens to subscribe to the topic.
  /// - [topic]: The topic to which to subscribe.
  ///
  /// Returns a Future fulfilled with the server's response after the registration
  /// tokens have been subscribed to the topic.
  Future<MessagingTopicManagementResponse> subscribeToTopic(
    List<String> registrationTokens,
    String topic,
  ) {
    return _requestHandler.subscribeToTopic(registrationTokens, topic);
  }

  /// Unsubscribes a list of registration tokens from an FCM topic.
  ///
  /// See [Unsubscribe from a topic](https://firebase.google.com/docs/cloud-messaging/admin/manage-topic-subscriptions#unsubscribe_from_a_topic)
  /// for code samples and detailed documentation.
  ///
  /// - [registrationTokens]: A list of registration tokens to unsubscribe from the topic.
  /// - [topic]: The topic from which to unsubscribe.
  ///
  /// Returns a Future fulfilled with the server's response after the registration
  /// tokens have been unsubscribed from the topic.
  Future<MessagingTopicManagementResponse> unsubscribeFromTopic(
    List<String> registrationTokens,
    String topic,
  ) {
    return _requestHandler.unsubscribeFromTopic(registrationTokens, topic);
  }

  /// Subscribes a list of registration tokens to an FCM topic using the legacy IID API.
  ///
  /// See [Subscribe to a topic](https://firebase.google.com/docs/cloud-messaging/admin/manage-topic-subscriptions#subscribe_to_a_topic)
  /// for code samples and detailed documentation.
  ///
  /// - [registrationTokens]: A list of registration tokens to subscribe to the topic.
  /// - [topic]: The topic to which to subscribe.
  ///
  /// Returns a Future fulfilled with the server's response after the registration
  /// tokens have been subscribed to the topic.
  @Deprecated('Use subscribeToTopic instead.')
  Future<MessagingTopicManagementResponse> subscribeToTopicLegacy(
    List<String> registrationTokens,
    String topic,
  ) {
    return _requestHandler.subscribeToTopicLegacy(registrationTokens, topic);
  }

  /// Unsubscribes a list of registration tokens from an FCM topic using the legacy IID API.
  ///
  /// See [Unsubscribe from a topic](https://firebase.google.com/docs/cloud-messaging/admin/manage-topic-subscriptions#unsubscribe_from_a_topic)
  /// for code samples and detailed documentation.
  ///
  /// - [registrationTokens]: A list of registration tokens to unsubscribe from the topic.
  /// - [topic]: The topic from which to unsubscribe.
  ///
  /// Returns a Future fulfilled with the server's response after the registration
  /// tokens have been unsubscribed from the topic.
  @Deprecated('Use unsubscribeFromTopic instead.')
  Future<MessagingTopicManagementResponse> unsubscribeFromTopicLegacy(
    List<String> registrationTokens,
    String topic,
  ) {
    return _requestHandler.unsubscribeFromTopicLegacy(
      registrationTokens,
      topic,
    );
  }

  @override
  Future<void> delete() async {
    // Messaging service cleanup if needed
  }
}
