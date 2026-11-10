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

import 'package:firebase_admin_sdk/messaging.dart';
import 'package:test/test.dart';

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

  test('rejects an empty FID', () {
    expect(() => FidMessage(fid: ''), throwsArgumentError);
  });
}
