---
type: Divergence
title: No FID message targets
description: Dart has no FID message types and no `enableLegacyHttpTransport`, and topic subscription takes only a `List<String>`.
tags: [messaging, fcm, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/messaging/**
sources:
  - id: dart-message
    resource: ../../../packages/firebase_admin_sdk/lib/src/messaging/messaging_api.dart
    symbol: sealed class Message
    title: "Dart's sealed `Message`: token, topic and condition targets"
  - id: node-fid-message
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/messaging/messaging-api.ts
    symbol: FidMessage
    title: Node's `FidMessage` in the `Message` union
  - id: node-legacy-transport
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/messaging/messaging.ts
    symbol: enableLegacyHttpTransport
    title: Node's `enableLegacyHttpTransport()`
---

# Where it lives

- Enforced by: nothing; review only.
- The message targets Dart has: `sealed class Message` in `messaging_api.dart`.[^dart-message]

# Node.js

- `Message = FidMessage | TokenMessage | ...`, and `FidMulticastMessage`. The token form is deprecated in favour of FIDs.[^node-fid-message]
- `enableLegacyHttpTransport()`.[^node-legacy-transport]
- `subscribeToTopic(tokenOrTokens: string | string[], topic)`.

# Dart

- `Message` has token, topic and condition targets. There are no FID message types.
- There is no `enableLegacyHttpTransport`.
- `subscribeToTopic` and `unsubscribeFromTopic` take a `List<String>` only.

Missing FID support is a gap. Taking a `List<String>` instead of Node's `string | string[]` union is a Dart idiom.

# Why

The reason isn't recorded. Ask a maintainer before changing it. Whether FID-based messaging is planned, and whether APIs Node has deprecated (such as `enableLegacyHttpTransport`) should be ported at all, are open questions for the maintainers.

# Rules for agents

- **Ask first:** before adding FID message types or `enableLegacyHttpTransport`, or changing the topic-subscription parameter type.

# Related

- [Topic management on the FCM v1 API](/messaging/topic-management-v1.md)
- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md)
- [ActionCodeSettings has linkDomain, not dynamicLinkDomain](/auth/dynamic-link-domain-removed.md)

[^node-fid-message]: Node's `FidMessage`
[^node-legacy-transport]: Node's `enableLegacyHttpTransport()`
[^dart-message]: Dart's sealed `Message`
