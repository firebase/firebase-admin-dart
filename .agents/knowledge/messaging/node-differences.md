---
type: Divergence
title: "Messaging: no FID targets, topic management on FCM v1"
description: "Dart has no FID message types and no `enableLegacyHttpTransport`, and topic subscription takes only a `List<String>`; as in Node, `subscribeToTopic` and `unsubscribeFromTopic` use the FCM v1 topic-subscription API with per-token requests, while the old IID-based calls remain as `@Deprecated` `*Legacy` methods."
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
  - id: subscribe-to-topic
    resource: ../../../packages/firebase_admin_sdk/lib/src/messaging/messaging.dart
    symbol: Future<MessagingTopicManagementResponse> subscribeToTopic(
    title: "`subscribeToTopic`, on the FCM v1 API"
  - id: subscribe-to-topic-legacy
    resource: ../../../packages/firebase_admin_sdk/lib/src/messaging/messaging.dart
    symbol: subscribeToTopicLegacy
    title: The `@Deprecated` IID-based `*Legacy` methods
  - id: allow-missing
    resource: ../../../packages/firebase_admin_sdk/lib/src/messaging/messaging_request_handler.dart
    symbol: allow_missing
    title: "`allow_missing` on unsubscribe, with its reason in a comment"
  - id: worker-pool
    resource: ../../../packages/firebase_admin_sdk/lib/src/messaging/messaging_request_handler.dart
    symbol: math.min(registrationTokens.length, 100)
    title: Per-token requests through a worker pool of up to 100
  - id: node-legacy
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/messaging/messaging.ts
    symbol: subscribeToTopicLegacy
    title: Node's FCM v1 topic management and its deprecated `*Legacy` methods
---

# Where it lives

- Enforced by: nothing; review only.
- The message targets Dart has: `sealed class Message` in `messaging_api.dart`.[^dart-message]
- The per-token requests, the worker pool, the token cap, `ALREADY_EXISTS` as success, `allow_missing` on unsubscribe (with its reason in a comment) and the not-registered mapping: the topic-management code in `messaging_request_handler.dart`.[^worker-pool][^allow-missing]
- The public methods, and the `@Deprecated` IID-based `*Legacy` methods: `messaging.dart`.[^subscribe-to-topic][^subscribe-to-topic-legacy]

# Node.js

## No FID targets

- `Message = FidMessage | TokenMessage | ...`, and `FidMulticastMessage`. The token form is deprecated in favour of FIDs.[^node-fid-message]
- `enableLegacyHttpTransport()`.[^node-legacy-transport]
- `subscribeToTopic(tokenOrTokens: string | string[], topic)`.

# Dart

## No FID targets

- `Message` has token, topic and condition targets. There are no FID message types.
- There is no `enableLegacyHttpTransport`.
- `subscribeToTopic` and `unsubscribeFromTopic` take a `List<String>` only.

Missing FID support is a gap. Taking a `List<String>` instead of Node's `string | string[]` union is a Dart idiom.

## Topic management on FCM v1

`subscribeToTopic` and `unsubscribeFromTopic` use the FCM v1 topic-subscription REST API, one request per token. The old IID-based batch calls remain as `@Deprecated` `*Legacy` methods.

Node has the same design: per-token v1 requests with a concurrency limit of 100, `allow_missing=true` on unsubscribe, and `@deprecated` `subscribeToTopicLegacy` and `unsubscribeFromTopicLegacy`.[^node-legacy]

# Why

## No FID targets

The reason isn't recorded. Ask a maintainer before changing it. Whether FID-based messaging is planned, and whether APIs Node has deprecated (such as `enableLegacyHttpTransport`) should be ported at all, are open questions for the maintainers.

## Topic management on FCM v1

The likely reason (not recorded in this repository): parity with Node. The Dart change matches Node's FCM v1 topic-management change point for point, but doesn't cite it.

The likely reasons for Node's design (not recorded in the Node files cited here): concurrency is capped at 100 to avoid HTTP/2 stream exhaustion; `ALREADY_EXISTS` counts as success and `NOT_FOUND` maps to `registration-token-not-registered` to keep requests idempotent; and the `*Legacy` methods stay as deprecated escape hatches. Why Node left the IID endpoints isn't recorded.

When the `*Legacy` methods can be removed isn't recorded. Ask a maintainer.

# Rules for agents

- **Ask first:** before adding FID message types or `enableLegacyHttpTransport`, or changing the topic-subscription parameter type.
- **Must not:** remove the `*Legacy` methods without a deprecation cycle.
- **Must not:** report not-registered tokens as successes.

# Related

- [Dart idioms win where Node's shape does not fit](/architecture/dart-idioms-over-node-shapes.md)
- [ActionCodeSettings has linkDomain, not dynamicLinkDomain](/auth/dynamic-link-domain-removed.md)
- [Port of the Node.js Admin SDK](/architecture/node-port.md)

[^node-fid-message]: Node's `FidMessage`
[^node-legacy-transport]: Node's `enableLegacyHttpTransport()`
[^dart-message]: Dart's sealed `Message`
[^subscribe-to-topic]: `subscribeToTopic`
[^worker-pool]: The worker pool in the request handler
[^allow-missing]: `allow_missing` in the request handler
[^subscribe-to-topic-legacy]: The `*Legacy` methods
[^node-legacy]: Node's topic management
