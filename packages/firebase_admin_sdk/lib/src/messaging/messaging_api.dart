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

abstract class _BaseMessage {
  _BaseMessage._({
    this.data,
    this.notification,
    this.android,
    this.webpush,
    this.apns,
    this.fcmOptions,
  });

  final Map<String, String>? data;
  final Notification? notification;
  final AndroidConfig? android;
  final WebpushConfig? webpush;
  final ApnsConfig? apns;
  final FcmOptions? fcmOptions;
}

/// Payload for the [Messaging.send] operation. The payload contains all the fields
/// in the BaseMessage type, and exactly one of fid, token, topic or condition.
///
/// See also:
/// - [Messaging.send], to send a message.
/// - [TopicMessage], to send a message to a topic.
/// - [ConditionMessage], to send a message to a condition.
/// - [TokenMessage], to send a message to a device.
/// - [FidMessage], to send a message to a Firebase installation.
sealed class Message extends _BaseMessage {
  Message._({
    super.data,
    super.notification,
    super.android,
    super.webpush,
    super.apns,
    super.fcmOptions,
  }) : super._();

  fmc1.Message _toRequest();
}

/// A message targeting a Firebase Installation ID (FID).
///
/// Use this target when migrating from FCM registration tokens to FIDs.
/// See [FCM registration token management](https://firebase.google.com/docs/cloud-messaging/manage-tokens).
class FidMessage extends Message {
  /// Creates a message for the non-empty Firebase Installation ID [fid].
  FidMessage({
    required this.fid,
    super.data,
    super.notification,
    super.android,
    super.webpush,
    super.apns,
    super.fcmOptions,
  }) : super._() {
    if (fid.isEmpty) {
      throw ArgumentError.value(fid, 'fid', 'must be non-empty');
    }
  }

  /// The Firebase Installation ID of the target device.
  final String fid;

  /// Returns the FCM HTTP v1 message payload.
  Map<String, dynamic> toJson() =>
      jsonDecode(jsonEncode(_toRequest())) as Map<String, dynamic>;

  @override
  fmc1.Message _toRequest() => _FidRequestMessage(
    targetFid: fid,
    data: data,
    notification: notification?._toRequest(),
    android: android?._toRequest(),
    webpush: webpush?._toRequest(),
    apns: apns?._toRequest(),
    fcmOptions: fcmOptions?._toRequest(),
  );
}

// googleapis 16 does not yet expose the FID field.
class _FidRequestMessage extends fmc1.Message {
  _FidRequestMessage({
    required this.targetFid,
    super.data,
    super.notification,
    super.android,
    super.webpush,
    super.apns,
    super.fcmOptions,
  });

  final String targetFid;

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'fid': targetFid};
}

/// A message targeting a specific registration token.
///
/// See [Send to individual devices](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk#send-messages-to-specific-devices)
class TokenMessage extends Message {
  TokenMessage({
    required this.token,
    super.data,
    super.notification,
    super.android,
    super.webpush,
    super.apns,
    super.fcmOptions,
  }) : super._();

  final String token;

  @override
  fmc1.Message _toRequest() {
    return fmc1.Message(
      data: data,
      notification: notification?._toRequest(),
      android: android?._toRequest(),
      webpush: webpush?._toRequest(),
      apns: apns?._toRequest(),
      fcmOptions: fcmOptions?._toRequest(),
      token: token,
    );
  }
}

/// A message targeting a topic.
///
/// See [Send to a topic](https://firebase.google.com/docs/cloud-messaging/send-topic-messages)
class TopicMessage extends Message {
  TopicMessage({
    required this.topic,
    super.data,
    super.notification,
    super.android,
    super.webpush,
    super.apns,
    super.fcmOptions,
  }) : super._();

  final String topic;

  @override
  fmc1.Message _toRequest() {
    return fmc1.Message(
      data: data,
      notification: notification?._toRequest(),
      android: android?._toRequest(),
      webpush: webpush?._toRequest(),
      apns: apns?._toRequest(),
      fcmOptions: fcmOptions?._toRequest(),
      topic: topic,
    );
  }
}

/// A message targeting a condition.
///
/// See [Send to topic conditions](https://firebase.google.com/docs/cloud-messaging/send-topic-messages#sending-to-topic-conditions).
class ConditionMessage extends Message {
  ConditionMessage({
    required this.condition,
    super.data,
    super.notification,
    super.android,
    super.webpush,
    super.apns,
    super.fcmOptions,
  }) : super._();

  final String condition;

  @override
  fmc1.Message _toRequest() {
    return fmc1.Message(
      data: data,
      notification: notification?._toRequest(),
      android: android?._toRequest(),
      webpush: webpush?._toRequest(),
      apns: apns?._toRequest(),
      fcmOptions: fcmOptions?._toRequest(),
      condition: condition,
    );
  }
}

/// Payload for the [Messaging.sendEachForMulticast] method. The payload contains all the fields
/// in the BaseMessage type, and a list of tokens.
///
/// See [Send to multiple devices](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk#send-messages-to-multiple-devices)
class MulticastMessage extends _BaseMessage {
  MulticastMessage({
    super.data,
    super.notification,
    super.android,
    super.webpush,
    super.apns,
    super.fcmOptions,
    required this.tokens,
  }) : super._();

  final List<String> tokens;
}

/// A notification that can be included in [Message].
class Notification {
  /// A notification that can be included in [Message].
  Notification({this.title, this.body, this.imageUrl});

  /// The title of the notification.
  final String? title;

  /// The notification body
  final String? body;

  /// URL of an image to be displayed in the notification.
  final String? imageUrl;

  fmc1.Notification _toRequest() {
    return fmc1.Notification(title: title, body: body, image: imageUrl);
  }
}

/// Represents platform-independent options for features provided by the FCM SDKs.
class FcmOptions {
  /// Represents platform-independent options for features provided by the FCM SDKs.
  FcmOptions({this.analyticsLabel});

  /// The label associated with the message's analytics data.
  final String? analyticsLabel;

  fmc1.FcmOptions _toRequest() {
    return fmc1.FcmOptions(analyticsLabel: analyticsLabel);
  }
}

/// Represents the WebPush protocol options that can be included in a [Message].
class WebpushConfig {
  /// Represents the WebPush protocol options that can be included in a [Message].
  WebpushConfig({this.headers, this.data, this.notification, this.fcmOptions});

  /// A collection of WebPush headers. Header values must be strings.
  ///
  /// See [WebPush specification](https://tools.ietf.org/html/rfc8030#section-5)
  /// for supported headers.
  final Map<String, String>? headers;

  /// A collection of data fields.
  final Map<String, String>? data;

  /// A WebPush notification payload to be included in the message.
  final WebpushNotification? notification;

  /// Options for features provided by the FCM SDK for Web.
  final WebpushFcmOptions? fcmOptions;

  fmc1.WebpushConfig _toRequest() {
    return fmc1.WebpushConfig(
      headers: headers,
      data: data,
      notification: notification?._toRequest(),
      fcmOptions: fcmOptions?._toRequest(),
    );
  }
}

/// Represents options for features provided by the FCM SDK for Web
/// (which are not part of the Webpush standard).
class WebpushFcmOptions {
  /// Represents options for features provided by the FCM SDK for Web
  /// (which are not part of the Webpush standard).
  WebpushFcmOptions({this.link});

  /// The link to open when the user clicks on the notification.
  /// For all URL values, HTTPS is required.
  final String? link;

  fmc1.WebpushFcmOptions _toRequest() {
    return fmc1.WebpushFcmOptions(link: link);
  }
}

class WebpushNotificationAction {
  WebpushNotificationAction({
    required this.action,
    this.icon,
    required this.title,
  });

  /// An action available to the user when the notification is presented
  final String action;

  /// Optional icon for a notification action.
  final String? icon;

  /// Title of the notification action.
  final String title;

  Map<String, Object?> _toRequest() {
    return {'action': action, 'icon': icon, 'title': title}.toCleanRequest();
  }
}

extension on Map<String, Object?> {
  Map<String, Object?> toCleanRequest() {
    for (final entry in entries) {
      switch (entry.value) {
        case true:
          this[entry.key] = 1;
        case false:
          this[entry.key] = 0;
      }
    }

    return this;
  }
}

enum WebpushNotificationDirection { auto, ltr, rtl }

/// Represents the WebPush-specific notification options that can be included in
/// [WebpushConfig]. This supports most of the standard
/// options as defined in the Web Notification
/// [specification](https://developer.mozilla.org/en-US/docs/Web/API/notification/Notification).
class WebpushNotification {
  WebpushNotification({
    this.title,
    this.customData,
    this.actions,
    this.badge,
    this.body,
    this.data,
    this.dir,
    this.icon,
    this.image,
    this.lang,
    this.renotify,
    this.requireInteraction,
    this.silent,
    this.tag,
    this.timestamp,
    this.vibrate,
  });

  /// Title text of the notification.
  final String? title;

  /// A list of notification actions representing the actions
  /// available to the user when the notification is presented.
  final List<WebpushNotificationAction>? actions;

  /// URL of the image used to represent the notification when there is
  /// not enough space to display the notification itself.
  final String? badge;

  /// Body text of the notification.
  final String? body;

  /// Arbitrary data that you want associated with the notification.
  /// This can be of any data type.
  final Object? data;

  /// The direction in which to display the notification. Must be one
  /// of `auto`, `ltr` or `rtl`.
  final WebpushNotificationDirection? dir;

  /// URL to the notification icon.
  final String? icon;

  /// URL of an image to be displayed in the notification.
  final String? image;

  /// The notification's language as a BCP 47 language tag.
  final String? lang;

  /// A boolean specifying whether the user should be notified after a
  /// new notification replaces an old one. Defaults to false.
  final bool? renotify;

  /// Indicates that a notification should remain active until the user
  /// clicks or dismisses it, rather than closing automatically.
  /// Defaults to false.
  final bool? requireInteraction;

  /// A boolean specifying whether the notification should be silent.
  /// Defaults to false.
  final bool? silent;

  /// An identifying tag for the notification.
  final String? tag;

  /// Timestamp of the notification. Refer to
  /// https://developer.mozilla.org/en-US/docs/Web/API/notification/timestamp
  /// for details.
  final int? timestamp;

  /// A vibration pattern for the device's vibration hardware to emit
  /// when the notification fires.
  final List<num>? vibrate;

  /// Arbitrary key/value payload.
  final Map<String, Object?>? customData;

  Map<String, Object?> _toRequest() {
    return {
      'title': title,
      'actions': actions?.map((a) => a._toRequest()).toList(),
      'badge': badge,
      'body': body,
      'data': data,
      'dir': dir?.toString().split('.').last,
      'icon': icon,
      'image': image,
      'lang': lang,
      'renotify': renotify,
      'requireInteraction': requireInteraction,
      'silent': silent,
      'tag': tag,
      'timestamp': timestamp,
      'vibrate': vibrate,
      ...?customData,
    }.toCleanRequest();
  }
}

/// Represents the APNs-specific options that can be included in an
/// [Message]. Refer to
/// [Apple documentation](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html)
/// for various headers and payload fields supported by APNs.
class ApnsConfig {
  /// Represents the APNs-specific options that can be included in an
  /// [Message]. Refer to
  /// [Apple documentation](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/CommunicatingwithAPNs.html)
  /// for various headers and payload fields supported by APNs.
  ApnsConfig({
    this.headers,
    this.payload,
    this.fcmOptions,
    this.liveActivityToken,
  });

  /// A collection of APNs headers. Header values must be strings.
  final Map<String, String>? headers;

  /// An APNs payload to be included in the message.
  final ApnsPayload? payload;

  /// Options for features provided by the FCM SDK for iOS.
  final ApnsFcmOptions? fcmOptions;

  /// APN `pushToStartToken` or `pushToken` to start or update live activities.
  final String? liveActivityToken;

  fmc1.ApnsConfig _toRequest() {
    return fmc1.ApnsConfig(
      headers: headers,
      payload: payload?._toRequest(),
      fcmOptions: fcmOptions?._toRequest(),
      liveActivityToken: liveActivityToken,
    );
  }
}

/// Represents the payload of an APNs message. Mainly consists of the `aps`
/// dictionary.
class ApnsPayload {
  /// Represents the payload of an APNs message. Mainly consists of the `aps`
  /// dictionary.
  ApnsPayload({required this.aps, this.customData});

  /// The `aps` dictionary to be included in the message.
  final Aps aps;

  /// Arbitrary custom data.
  final Map<String, String>? customData;

  Map<String, Object?> _toRequest() {
    return {'aps': aps._toRequest(), ...?customData}.toCleanRequest();
  }
}

/// Represents the [aps dictionary](https://developer.apple.com/library/content/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/PayloadKeyReference.html)
/// that is part of APNs messages.
class Aps {
  Aps({
    this.alert,
    this.badge,
    this.sound,
    this.contentAvailable,
    this.mutableContent,
    this.category,
    this.threadId,
    this.interruptionLevel,
  });

  /// Alert to be included in the message. This may be a string or an object of
  /// type `admin.messaging.ApsAlert`.
  final ApsAlert? alert;

  /// Badge to be displayed with the message. Set to 0 to remove the badge. When
  /// not specified, the badge will remain unchanged.
  final num? badge;

  /// Sound to be played with the message. May be a simple sound name via
  /// [ApsSoundName] or a critical alert configuration via [CriticalSound].
  final ApsSound? sound;

  /// Specifies whether to configure a background update notification.
  final bool? contentAvailable;

  /// Specifies whether to set the `mutable-content` property on the message
  /// so the clients can modify the notification via app extensions.
  final bool? mutableContent;

  /// Type of the notification.
  final String? category;

  /// An app-specific identifier for grouping notifications.
  final String? threadId;

  /// The interruption level of the notification.
  final ApsInterruptionLevel? interruptionLevel;

  Map<String, Object?> _toRequest() {
    return {
      'alert': ?alert?._toRequest(),
      'badge': ?badge,
      'sound': ?sound?._toRequest(),
      'content-available': ?contentAvailable,
      'mutable-content': ?mutableContent,
      'category': ?category,
      'thread-id': ?threadId,
      'interruption-level': ?interruptionLevel?._value,
    }.toCleanRequest();
  }
}

class ApsAlert {
  ApsAlert({
    this.title,
    this.subtitle,
    this.body,
    this.locKey,
    this.locArgs,
    this.titleLocKey,
    this.titleLocArgs,
    this.subtitleLocKey,
    this.subtitleLocArgs,
    this.actionLocKey,
    this.launchImage,
  });

  final String? title;
  final String? subtitle;
  final String? body;
  final String? locKey;
  final List<String>? locArgs;
  final String? titleLocKey;
  final List<String>? titleLocArgs;
  final String? subtitleLocKey;
  final List<String>? subtitleLocArgs;
  final String? actionLocKey;
  final String? launchImage;

  Map<String, Object?> _toRequest() {
    return {
      'title': title,
      'subtitle': subtitle,
      'body': body,
      'loc-key': locKey,
      'loc-args': locArgs,
      'title-loc-key': titleLocKey,
      'title-loc-args': titleLocArgs,
      'subtitle-loc-key': subtitleLocKey,
      'subtitle-loc-args': subtitleLocArgs,
      'action-loc-key': actionLocKey,
      'launch-image': launchImage,
    }.toCleanRequest();
  }
}

/// The interruption level of an APNs notification, as defined by Apple.
///
/// See https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel
enum ApsInterruptionLevel {
  /// The system presents the notification immediately, lights up the screen,
  /// and can play a sound.
  active,

  /// The system presents the notification immediately, lights up the screen,
  /// and bypasses the mute switch to play a sound. Requires the Critical Alerts
  /// entitlement.
  critical,

  /// The system adds the notification to the notification list without lighting
  /// up the screen or playing a sound.
  passive,

  /// The notification appears immediately and can play a sound, but will not
  /// break through Focus or Do Not Disturb.
  timeSensitive;

  String get _value => switch (this) {
    ApsInterruptionLevel.active => 'active',
    ApsInterruptionLevel.critical => 'critical',
    ApsInterruptionLevel.passive => 'passive',
    ApsInterruptionLevel.timeSensitive => 'time-sensitive',
  };
}

/// Base class for the APNs `sound` field.
///
/// Use [ApsSoundName] for a simple sound file name, or [CriticalSound] for a
/// critical alert sound configuration.
sealed class ApsSound {
  const ApsSound();
  Object _toRequest();
}

/// A simple sound name for an APNs notification.
///
/// Use `"default"` to play the system sound, or provide the filename of a
/// sound resource bundled in the app.
final class ApsSoundName extends ApsSound {
  const ApsSoundName(this.name);

  /// The name of the sound file to play.
  final String name;

  @override
  String _toRequest() => name;
}

/// Represents a critical sound configuration that can be included in the
/// `aps` dictionary of an APNs payload.
///
/// Requires the Critical Alerts entitlement. For a simple sound name, use
/// [ApsSoundName] instead.
final class CriticalSound extends ApsSound {
  const CriticalSound({this.critical, required this.name, this.volume});

  /// The critical alert flag. Set to `true` to enable the critical alert.
  final bool? critical;

  /// The name of a sound file in the app's main bundle or in the `Library/Sounds`
  /// folder of the app's container directory. Specify the string "default" to play
  /// the system sound.
  final String name;

  /// The volume for the critical alert's sound. Must be a value between 0.0
  /// (silent) and 1.0 (full volume).
  final double? volume;

  @override
  Map<String, Object?> _toRequest() {
    return {
      'critical': critical,
      'name': name,
      'volume': volume,
    }.toCleanRequest();
  }
}

/// Represents options for features provided by the FCM SDK for iOS.
class ApnsFcmOptions {
  /// Represents options for features provided by the FCM SDK for iOS.
  ApnsFcmOptions({this.analyticsLabel, this.imageUrl});

  /// The label associated with the message's analytics data.
  final String? analyticsLabel;

  /// URL of an image to be displayed in the notification.
  final String? imageUrl;

  fmc1.ApnsFcmOptions _toRequest() {
    return fmc1.ApnsFcmOptions(analyticsLabel: analyticsLabel, image: imageUrl);
  }
}

enum AndroidConfigPriority { high, normal }

/// Represents the Android-specific options that can be included in an [Message].
class AndroidConfig {
  /// Represents the Android-specific options that can be included in an [Message].
  AndroidConfig({
    this.collapseKey,
    this.priority,
    this.ttl,
    this.restrictedPackageName,
    this.data,
    this.notification,
    this.fcmOptions,
    this.directBootOk,
  });

  /// Collapse key for the message. Collapse key serves as an identifier for a
  /// group of messages that can be collapsed, so that only the last message gets
  /// sent when delivery can be resumed. A maximum of four different collapse keys
  /// may be active at any given time.
  final String? collapseKey;

  /// Priority of the message. Must be either `normal` or `high`.
  final AndroidConfigPriority? priority;

  /// How long (in seconds) the message should be kept in FCM storage if the
  /// device is offline.
  ///
  /// The maximum time to live supported is 4 weeks, and the default value is 4
  /// weeks if not set. Set it to 0 if want to send the message immediately. In
  /// JSON format, the Duration type is encoded as a string rather than an
  /// object, where the string ends in the suffix "s" (indicating seconds) and
  /// is preceded by the number of seconds, with nanoseconds expressed as
  /// fractional seconds. For example, 3 seconds with 0 nanoseconds should be
  /// encoded in JSON format as "3s", while 3 seconds and 1 nanosecond should be
  /// expressed in JSON format as "3.000000001s". The ttl will be rounded down
  /// to the nearest second.
  final String? ttl;

  /// Package name of the application where the registration tokens must match
  /// in order to receive the message.
  final String? restrictedPackageName;

  /// A collection of data fields to be included in the message. All values must
  /// be strings. When provided, overrides any data fields set on the top-level
  /// [Message].
  final Map<String, String>? data;

  /// Android notification to be included in the message.
  final AndroidNotification? notification;

  /// Options for features provided by the FCM SDK for Android.
  final AndroidFcmOptions? fcmOptions;

  /// A boolean indicating whether messages will be allowed to be delivered to
  /// the app while the device is in direct boot mode.
  final bool? directBootOk;

  fmc1.AndroidConfig _toRequest() {
    return fmc1.AndroidConfig(
      collapseKey: collapseKey,
      priority: priority?.toString().split('.').last,
      ttl: ttl,
      restrictedPackageName: restrictedPackageName,
      data: data,
      notification: notification?._toRequest(),
      fcmOptions: fcmOptions?._toRequest(),
      directBootOk: directBootOk,
    );
  }
}

enum AndroidNotificationPriority {
  min('PRIORITY_MIN'),
  low('PRIORITY_LOW'),
  $default('PRIORITY_DEFAULT'),
  high('PRIORITY_HIGH'),
  max('PRIORITY_MAX');

  const AndroidNotificationPriority(this._code);

  final String _code;
}

enum AndroidNotificationVisibility { private, public, secret }

/// Enum representing proxy behaviors for Android notifications.
enum AndroidNotificationProxy {
  /// Allow notifications to be proxied to other devices.
  allow,

  /// Deny notifications from being proxied to other devices.
  deny,

  /// Proxy notifications only if priority is lowered.
  ifPriorityLowered;

  String get _code {
    switch (this) {
      case AndroidNotificationProxy.allow:
        return 'allow';
      case AndroidNotificationProxy.deny:
        return 'deny';
      case AndroidNotificationProxy.ifPriorityLowered:
        return 'if_priority_lowered';
    }
  }
}

/// Represents the Android-specific notification options that can be included in
/// [AndroidConfig].
class AndroidNotification {
  /// Represents the Android-specific notification options that can be included in
  /// [AndroidConfig].
  AndroidNotification({
    this.title,
    this.body,
    this.icon,
    this.color,
    this.sound,
    this.tag,
    this.imageUrl,
    this.clickAction,
    this.bodyLocKey,
    this.bodyLocArgs,
    this.titleLocKey,
    this.titleLocArgs,
    this.channelId,
    this.ticker,
    this.sticky,
    this.eventTimestamp,
    this.localOnly,
    this.priority,
    this.vibrateTimingsMillis,
    this.defaultVibrateTimings,
    this.defaultSound,
    this.lightSettings,
    this.defaultLightSettings,
    this.visibility,
    this.notificationCount,
    this.proxy,
  });

  /// Title of the Android notification. When provided, overrides the title set via
  /// `admin.messaging.Notification`.
  final String? title;

  /// Body of the Android notification. When provided, overrides the body set via
  /// `admin.messaging.Notification`.
  final String? body;

  /// Icon resource for the Android notification.
  final String? icon;

  /// Notification icon color in `#rrggbb` format.
  final String? color;

  /// File name of the sound to be played when the device receives the
  /// notification.
  final String? sound;

  /// Notification tag. This is an identifier used to replace existing
  /// notifications in the notification drawer. If not specified, each request
  /// creates a new notification.
  final String? tag;

  /// URL of an image to be displayed in the notification.
  final String? imageUrl;

  /// Action associated with a user click on the notification. If specified, an
  /// activity with a matching Intent Filter is launched when a user clicks on the
  /// notification.
  final String? clickAction;

  /// Key of the body string in the app's string resource to use to localize the
  /// body text.
  ///
  final String? bodyLocKey;

  /// An array of resource keys that will be used in place of the format
  /// specifiers in `bodyLocKey`.
  final List<String>? bodyLocArgs;

  /// Key of the title string in the app's string resource to use to localize the
  /// title text.
  final String? titleLocKey;

  /// An array of resource keys that will be used in place of the format
  /// specifiers in `titleLocKey`.
  final List<String>? titleLocArgs;

  /// The Android notification channel ID (new in Android O). The app must create
  /// a channel with this channel ID before any notification with this channel ID
  /// can be received. If you don't send this channel ID in the request, or if the
  /// channel ID provided has not yet been created by the app, FCM uses the channel
  /// ID specified in the app manifest.
  final String? channelId;

  /// Sets the "ticker" text, which is sent to accessibility services. Prior to
  /// API level 21 (Lollipop), sets the text that is displayed in the status bar
  /// when the notification first arrives.
  final String? ticker;

  /// When set to `false` or unset, the notification is automatically dismissed when
  /// the user clicks it in the panel. When set to `true`, the notification persists
  /// even when the user clicks it.
  final bool? sticky;

  /// For notifications that inform users about events with an absolute time reference, sets
  /// the time that the event in the notification occurred. Notifications
  /// in the panel are sorted by this time.
  final DateTime? eventTimestamp;

  /// Sets whether or not this notification is relevant only to the current device.
  /// Some notifications can be bridged to other devices for remote display, such as
  /// a Wear OS watch. This hint can be set to recommend this notification not be bridged.
  /// See [Wear OS guides](https://developer.android.com/training/wearables/notifications/bridger#existing-method-of-preventing-bridging).
  final bool? localOnly;

  /// Sets the relative priority for this notification. Low-priority notifications
  /// may be hidden from the user in certain situations. Note this priority differs
  /// from `AndroidMessagePriority`. This priority is processed by the client after
  /// the message has been delivered. Whereas `AndroidMessagePriority` is an FCM concept
  /// that controls when the message is delivered.
  final AndroidNotificationPriority? priority;

  /// Sets the vibration pattern to use. Pass in an array of milliseconds to
  /// turn the vibrator on or off. The first value indicates the duration to wait before
  /// turning the vibrator on. The next value indicates the duration to keep the
  /// vibrator on. Subsequent values alternate between duration to turn the vibrator
  /// off and to turn the vibrator on. If `vibrate_timings` is set and `default_vibrate_timings`
  /// is set to `true`, the default value is used instead of the user-specified `vibrate_timings`.
  final List<String>? vibrateTimingsMillis;

  /// If set to `true`, use the Android framework's default vibrate pattern for the
  /// notification. Default values are specified in [`config.xml`](https://android.googlesource.com/platform/frameworks/base/+/master/core/res/res/values/config.xml).
  /// If `default_vibrate_timings` is set to `true` and `vibrate_timings` is also set,
  /// the default value is used instead of the user-specified `vibrate_timings`.
  final bool? defaultVibrateTimings;

  /// If set to `true`, use the Android framework's default sound for the notification.
  /// Default values are specified in [`config.xml`](https://android.googlesource.com/platform/frameworks/base/+/master/core/res/res/values/config.xml).
  final bool? defaultSound;

  /// Settings to control the notification's LED blinking rate and color if LED is
  /// available on the device. The total blinking time is controlled by the OS.
  final LightSettings? lightSettings;

  /// If set to `true`, use the Android framework's default LED light settings
  /// for the notification. Default values are specified in [`config.xml`](https://android.googlesource.com/platform/frameworks/base/+/master/core/res/res/values/config.xml).
  /// If `default_light_settings` is set to `true` and `light_settings` is also set,
  /// the user-specified `light_settings` is used instead of the default value.
  final bool? defaultLightSettings;

  /// Sets the visibility of the notification. Must be either `private`, `public`,
  /// or `secret`. If unspecified, defaults to `private`.
  final AndroidNotificationVisibility? visibility;

  /// Sets the number of items this notification represents. May be displayed as a
  /// badge count for Launchers that support badging. See [NotificationBadge](https://developer.android.com/training/notify-user/badges).
  /// For example, this might be useful if you're using just one notification to
  /// represent multiple new messages but you want the count here to represent
  /// the number of total new messages. If zero or unspecified, systems
  /// that support badging use the default, which is to increment a number
  /// displayed on the long-press menu each time a new notification arrives.
  final int? notificationCount;

  /// Sets proxy option for the notification. Proxy can be `allow`, `deny`, or
  /// `ifPriorityLowered`. This controls whether the notification can be proxied
  /// to other devices.
  final AndroidNotificationProxy? proxy;

  fmc1.AndroidNotification _toRequest() {
    return fmc1.AndroidNotification(
      title: title,
      body: body,
      icon: icon,
      color: color,
      sound: sound,
      tag: tag,
      image: imageUrl,
      clickAction: clickAction,
      bodyLocKey: bodyLocKey,
      bodyLocArgs: bodyLocArgs,
      titleLocKey: titleLocKey,
      titleLocArgs: titleLocArgs,
      channelId: channelId,
      ticker: ticker,
      sticky: sticky,
      eventTime: eventTimestamp?.toUtc().toIso8601String(),
      localOnly: localOnly,
      notificationPriority: priority?._code,
      vibrateTimings: vibrateTimingsMillis,
      defaultVibrateTimings: defaultVibrateTimings,
      defaultSound: defaultSound,
      lightSettings: lightSettings?._toRequest(),
      defaultLightSettings: defaultLightSettings,
      visibility: visibility?.toString().split('.').last,
      notificationCount: notificationCount,
      proxy: proxy?._code,
    );
  }
}

/// Represents settings to control notification LED that can be included in [AndroidNotification].
class LightSettings {
  /// Represents settings to control notification LED that can be included in [AndroidNotification].
  LightSettings({
    required this.color,
    required this.lightOnDurationMillis,
    required this.lightOffDurationMillis,
  });

  /// Required. Sets color of the LED in `#rrggbb` or `#rrggbbaa` format.
  final ({double? red, double? blue, double? green, double? alpha}) color;

  /// Required. Along with `light_off_duration`, defines the blink rate of LED flashes.
  final String lightOnDurationMillis;

  /// Required. Along with `light_on_duration`, defines the blink rate of LED flashes.
  final String lightOffDurationMillis;

  fmc1.LightSettings _toRequest() {
    return fmc1.LightSettings(
      color: fmc1.Color(
        red: color.red,
        green: color.green,
        blue: color.blue,
        alpha: color.alpha,
      ),
      lightOnDuration: lightOnDurationMillis,
      lightOffDuration: lightOffDurationMillis,
    );
  }
}

/// Represents options for features provided by the FCM SDK for Android.
class AndroidFcmOptions {
  /// Represents options for features provided by the FCM SDK for Android.
  AndroidFcmOptions({this.analyticsLabel});

  /// The label associated with the message's analytics data.
  final String? analyticsLabel;

  fmc1.AndroidFcmOptions _toRequest() {
    return fmc1.AndroidFcmOptions(analyticsLabel: analyticsLabel);
  }
}

/// Interface representing the server response from the legacy {@link Messaging.sendToTopic} method.
///
/// See
/// [Send to a topic](https://firebase.google.com/docs/cloud-messaging/admin/send-messages#send_to_a_topic)
/// for code samples and detailed documentation.
class MessagingTopicResponse {
  /// Interface representing the server response from the legacy {@link Messaging.sendToTopic} method.
  ///
  /// See
  /// [Send to a topic](https://firebase.google.com/docs/cloud-messaging/admin/send-messages#send_to_a_topic)
  /// for code samples and detailed documentation.
  MessagingTopicResponse({required this.messageId});

  /// The message ID for a successfully received request which FCM will attempt to
  /// deliver to all subscribed devices.
  final num messageId;
}

/// Interface representing the server response from the
/// [Messaging.sendEach] and [Messaging.sendEachForMulticast] methods.
class BatchResponse {
  /// Interface representing the server response from the
  /// [Messaging.sendEach] and [Messaging.sendEachForMulticast] methods.
  BatchResponse._({
    required this.responses,
    required this.successCount,
    required this.failureCount,
  });

  /// An array of responses, each corresponding to a message.
  final List<SendResponse> responses;

  /// The number of messages that were successfully handed off for sending.
  final int successCount;

  /// The number of messages that resulted in errors when sending.
  final int failureCount;
}

/// Interface representing the status of an individual message that was sent as
/// part of a batch request.
class SendResponse {
  /// Interface representing the status of an individual message that was sent as
  /// part of a batch request.
  SendResponse._({required this.success, this.messageId, this.error});

  /// A boolean indicating if the message was successfully handed off to FCM or
  /// not. When true, the `messageId` attribute is guaranteed to be set. When
  /// false, the `error` attribute is guaranteed to be set.
  final bool success;

  /// A unique message ID string, if the message was handed off to FCM for
  /// delivery.
  final String? messageId;

  /// An error, if the message was not handed off to FCM successfully.
  final FirebaseAdminException? error;
}

/// Interface representing the server response from the
/// [Messaging.subscribeToTopic] and [Messaging.unsubscribeFromTopic] methods.
class MessagingTopicManagementResponse {
  /// Interface representing the server response from the
  /// [Messaging.subscribeToTopic] and [Messaging.unsubscribeFromTopic] methods.
  MessagingTopicManagementResponse._({
    required this.failureCount,
    required this.successCount,
    required this.errors,
  });

  /// The number of registration tokens that could not be subscribed to the topic
  /// and resulted in an error.
  final int failureCount;

  /// The number of registration tokens that were successfully subscribed to the
  /// topic.
  final int successCount;

  /// An array of errors corresponding to the provided registration token(s). The
  /// length of this array will be equal to [failureCount].
  final List<FirebaseArrayIndexError> errors;
}
