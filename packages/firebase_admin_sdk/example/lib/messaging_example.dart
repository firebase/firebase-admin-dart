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
import 'package:firebase_admin_sdk/messaging.dart';

Future<void> messagingExample(FirebaseApp admin) async {
  print('\n### Messaging Example ###\n');

  final messaging = admin.messaging();

  // Example 1: Send a message to a topic
  try {
    print('> Sending message to topic: fcm_test_topic\n');
    final messageId = await messaging.send(
      TopicMessage(
        topic: 'fcm_test_topic',
        notification: Notification(
          title: 'Hello World',
          body: 'Dart Firebase Admin SDK works!',
        ),
        data: {'timestamp': DateTime.now().toIso8601String()},
      ),
    );
    print('Message sent successfully!');
    print('  - Message ID: $messageId');
    print('');
  } on FirebaseMessagingAdminException catch (e) {
    print('> Messaging error: ${e.code} - ${e.message}');
  } catch (e) {
    print('> Error sending message: $e');
  }

  // Example 2: Send multiple messages
  try {
    print('> Sending multiple messages...\n');
    final response = await messaging.sendEach([
      TopicMessage(
        topic: 'topic1',
        notification: Notification(title: 'Message 1'),
      ),
      TopicMessage(
        topic: 'topic2',
        notification: Notification(title: 'Message 2'),
      ),
    ]);

    print('Batch send completed!');
    print('  - Success: ${response.successCount}');
    print('  - Failures: ${response.failureCount}');
    for (var i = 0; i < response.responses.length; i++) {
      final resp = response.responses[i];
      if (resp.success) {
        print('  - Message $i: ${resp.messageId}');
      } else {
        print('  - Message $i failed: ${resp.error?.message}');
      }
    }
    print('');
  } on FirebaseMessagingAdminException catch (e) {
    print('> Messaging error: ${e.code} - ${e.message}');
  } catch (e) {
    print('> Error sending batch: $e');
  }

  // Example 3: Send multicast message to multiple Firebase Installation IDs
  try {
    print('> Sending multicast message...\n');
    // Note: Using fake FIDs for demonstration
    final response = await messaging.sendEachForMulticast(
      FidMulticastMessage(
        fids: ['fake-fid-1', 'fake-fid-2'],
        notification: Notification(
          title: 'Multicast Message',
          body: 'This goes to multiple devices',
        ),
      ),
      dryRun: true, // Use dry run to validate without actually sending
    );

    print('Multicast send completed!');
    print('  - Success: ${response.successCount}');
    print('  - Failures: ${response.failureCount}');
    print('');
  } on FirebaseMessagingAdminException catch (e) {
    print('> Messaging error: ${e.code} - ${e.message}');
  } catch (e) {
    print('> Error sending multicast: $e');
  }

  // Example 4: Send a message with a condition
  try {
    print('> Sending ConditionMessage...\n');
    final messageId = await messaging.send(
      ConditionMessage(
        condition: "'TopicA' in topics || 'TopicB' in topics",
        notification: Notification(
          title: 'Condition Message',
          body: 'Sent to subscribers of TopicA or TopicB',
        ),
      ),
      dryRun: true,
    );
    print('ConditionMessage sent!');
    print('  - Message ID: $messageId');
    print('');
  } on FirebaseMessagingAdminException catch (e) {
    print('> Messaging error: ${e.code} - ${e.message}');
  } catch (e) {
    print('> Error sending condition message: $e');
  }

  // Example 5: Subscribe tokens to a topic
  try {
    print('> Subscribing tokens to topic: test-topic\n');
    // Note: Using fake token for demonstration
    final response = await messaging.subscribeToTopic([
      'fake-registration-token',
    ], 'test-topic');

    print('Subscription completed!');
    print('  - Success: ${response.successCount}');
    print('  - Failures: ${response.failureCount}');
    if (response.errors.isNotEmpty) {
      for (final error in response.errors) {
        print('  - Token ${error.index} error: ${error.error.message}');
      }
    }
    print('');
  } on FirebaseMessagingAdminException catch (e) {
    if (e.errorCode == MessagingClientErrorCode.invalidArgument) {
      print('> Invalid topic format or empty tokens list');
    } else {
      print('> Messaging error: ${e.code} - ${e.message}');
    }
  } catch (e) {
    print('> Error subscribing to topic: $e');
  }

  // Example 6: Send with platform-specific options
  try {
    print('> Sending message with platform-specific options...\n');
    final messageId = await messaging.send(
      TokenMessage(
        token: 'fake-device-token',
        notification: Notification(
          title: 'Platform-specific message',
          body: 'With Android and iOS options',
        ),
        android: AndroidConfig(
          priority: AndroidConfigPriority.high,
          notification: AndroidNotification(color: '#FF0000', sound: 'default'),
        ),
        apns: ApnsConfig(
          payload: ApnsPayload(
            aps: Aps(
              contentAvailable: true,
              sound: const CriticalSound(critical: true, name: 'default'),
            ),
          ),
        ),
      ),
      dryRun: true, // Use dry run to validate
    );

    print('Platform-specific message validated!');
    print('  - Message ID: $messageId');
  } on FirebaseMessagingAdminException catch (e) {
    if (e.errorCode == MessagingClientErrorCode.invalidRegistrationToken) {
      print('> Invalid registration token format');
    } else {
      print('> Messaging error: ${e.code} - ${e.message}');
    }
  } catch (e) {
    print('> Error sending platform-specific message: $e');
  }
}
