---
type: Decision
title: Topic management on the FCM v1 API, IID calls kept as Legacy
description: As in Node, `subscribeToTopic` and `unsubscribeFromTopic` use the FCM v1 topic-subscription API with per-token requests, while the old IID-based calls remain as `@Deprecated` `*Legacy` methods.
tags: [messaging, fcm, node-parity]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/messaging/**
sources:
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
    title: Per-token requests, the worker pool and `allow_missing` on unsubscribe
  - id: node-legacy
    resource: https://github.com/firebase/firebase-admin-node/blob/main/src/messaging/messaging.ts
    symbol: subscribeToTopicLegacy
    title: Node's FCM v1 topic management and its deprecated `*Legacy` methods
---

# Decision

`subscribeToTopic` and `unsubscribeFromTopic` use the FCM v1 topic-subscription REST API.[^subscribe-to-topic] They:

- send one request per registration token, through a worker pool of up to 100 concurrent requests;
- accept at most 1,000 tokens per call;
- treat `409` / `ALREADY_EXISTS` as success;
- send `allow_missing=true` on unsubscribe, so a token that isn't subscribed still succeeds;[^allow-missing]
- report a token that isn't registered as `registration-token-not-registered`, not as a success.

The old IID-based batch calls remain as `@Deprecated` `subscribeToTopicLegacy` and `unsubscribeFromTopicLegacy`.[^subscribe-to-topic-legacy]

Node has the same design: per-token v1 requests with a concurrency limit of 100, `allow_missing=true` on unsubscribe, and `@deprecated` `subscribeToTopicLegacy` and `unsubscribeFromTopicLegacy`.[^node-legacy]

# Why

The likely reason (not recorded in this repository): parity with Node. The Dart change matches Node's FCM v1 topic-management change point for point, but doesn't cite it.

Node's maintainers stated, for Node: concurrency is capped at 100 to avoid HTTP/2 stream exhaustion; `ALREADY_EXISTS` counts as success and `NOT_FOUND` maps to `registration-token-not-registered` to keep requests idempotent; and the `*Legacy` methods stay as deprecated escape hatches. Why Node left the IID endpoints isn't recorded.

On `allow_missing`, the maintainers' stated reason: it applies only to the leaf resource (AIP-135), so an unregistered token still reports `registrationTokenNotRegistered`. The code comment at the call says the same.[^allow-missing]

When the `*Legacy` methods can be removed isn't recorded. Ask a maintainer.

# Rules for agents

- **Must not:** remove the `*Legacy` methods without a deprecation cycle.
- **Must not:** report not-registered tokens as successes.

# Related

- [No FID message targets](/messaging/fid-targets.md)
- [ActionCodeSettings has linkDomain, not dynamicLinkDomain](/auth/dynamic-link-domain-removed.md)
- [Port of the Node.js Admin SDK](/architecture/node-port.md)

[^subscribe-to-topic]: `subscribeToTopic`
[^allow-missing]: `allow_missing` in the request handler
[^subscribe-to-topic-legacy]: The `*Legacy` methods
[^node-legacy]: Node's topic management
