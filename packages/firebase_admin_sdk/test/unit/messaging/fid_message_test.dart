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

import 'dart:convert';

import 'package:firebase_admin_sdk/messaging.dart';
import 'package:test/test.dart';

class _CustomPayload {
  Map<String, Object?> toJson() => {
    'items': [1, true, null],
  };
}

void main() {
  test('serializes an FID and all supported payload fields', () {
    final message = FidMessage(
      fid: 'installation-id',
      data: {'key': 'value'},
      notification: Notification(title: 'Hello'),
      android: AndroidConfig(collapseKey: 'group'),
      webpush: WebpushConfig(headers: {'TTL': '60'}),
      apns: ApnsConfig(headers: {'apns-priority': '10'}),
      fcmOptions: FcmOptions(analyticsLabel: 'campaign'),
    );

    expect(message.toJson(), {
      'fid': 'installation-id',
      'data': {'key': 'value'},
      'notification': {'title': 'Hello'},
      'android': {'collapseKey': 'group'},
      'webpush': {
        'headers': {'TTL': '60'},
      },
      'apns': {
        'headers': {'apns-priority': '10'},
      },
      'fcmOptions': {'analyticsLabel': 'campaign'},
    });
  });

  test('recursively serializes nested configuration and custom data', () {
    final message = FidMessage(
      fid: 'installation-id',
      android: AndroidConfig(
        fcmOptions: AndroidFcmOptions(analyticsLabel: 'android'),
        notification: AndroidNotification(
          title: 'Title',
          lightSettings: LightSettings(
            color: (red: 0.5, green: 0.25, blue: 1.0, alpha: null),
            lightOnDurationMillis: '1s',
            lightOffDurationMillis: '2s',
          ),
        ),
      ),
      apns: ApnsConfig(
        fcmOptions: ApnsFcmOptions(analyticsLabel: 'ios'),
        payload: ApnsPayload(aps: Aps(badge: 1)),
      ),
      webpush: WebpushConfig(
        fcmOptions: WebpushFcmOptions(link: 'https://example.com'),
        notification: WebpushNotification(data: _CustomPayload()),
      ),
    );

    final json = message.toJson();
    expect(jsonDecode(jsonEncode(json)), json);
    expect(json['android'], {
      'fcmOptions': {'analyticsLabel': 'android'},
      'notification': {
        'title': 'Title',
        'lightSettings': {
          'color': {'red': 0.5, 'green': 0.25, 'blue': 1.0},
          'lightOnDuration': '1s',
          'lightOffDuration': '2s',
        },
      },
    });
    expect((json['apns'] as Map<String, dynamic>)['fcmOptions'], {
      'analyticsLabel': 'ios',
    });
    expect((json['webpush'] as Map<String, dynamic>)['fcmOptions'], {
      'link': 'https://example.com',
    });
    final webpush = json['webpush'] as Map<String, dynamic>;
    final notification = webpush['notification'] as Map<String, dynamic>;
    expect(notification['data'], {
      'items': [1, true, null],
    });
  });

  test('rejects an empty FID', () {
    expect(() => FidMessage(fid: ''), throwsArgumentError);
  });
}
