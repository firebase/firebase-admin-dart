---
type: Decision
title: Pooled HTTP/2 by default, HTTP/1.1 for plain-HTTP endpoints
description: "HTTPS traffic goes over pooled HTTP/2 connections by default, while emulators, `ssl: false` and the metadata server stay on HTTP/1.1."
tags: [architecture, transport, performance]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/app/http2_client.dart
  - packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
  - packages/google_cloud_firestore/lib/src/firestore_http_client.dart
  - packages/*/pubspec.yaml
sources:
  - id: admin-transport
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/http2_client.dart
    symbol: Credential negotiation can target plain
    title: The app client's `Http2WithHttp1FallbackClient`, its dartdoc and its `@experimental` comment
  - id: firestore-transport
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_http_client.dart
    symbol: Credential negotiation can target plain
    title: Firestore's copy of `Http2WithHttp1FallbackClient`
---

# Where it lives

- Enforced by: nothing; review only.
- Scheme routing (`https` over HTTP/2, anything else over HTTP/1.1), why plain-`http` credential endpoints need HTTP/1.1, and the `@experimental` pin: the dartdoc and file comment of `Http2WithHttp1FallbackClient` in `http2_client.dart`.[^admin-transport]
- Firestore's copy, `Http2WithHttp1FallbackClient` in `firestore_http_client.dart`.[^firestore-transport]

# Decision

By default, HTTPS traffic goes over pooled HTTP/2 connections, through `package:http2`'s `Http2Client`. Plain-HTTP endpoints, the emulators among them, stay on HTTP/1.1.

The wrapper is duplicated in both packages, because `google_cloud_firestore` can't import the admin package. The copies differ: only the admin copy rejects requests after `close()`. A change to one copy needs the same change in the other.

# Why

The maintainers' stated reason: `dart:io`'s `HttpClient` only speaks HTTP/1.1, so every concurrent request opened its own TCP and TLS connection. Under load that caused connection-storm failures and out-of-memory errors, and made Dart much slower than Node, whose Firestore client multiplexes concurrent operations over a small pool of HTTP/2 connections. The emulator stays on HTTP/1.1 to match Node's REST-mode behaviour.

Alternatives that were tried or rejected:

- Capping connections per host: it only limits how many requests run at once and queues the rest, which is much slower. A reviewer also questioned exposing a `dart:io`-specific setting.
- Retrying connection-closed errors: it fixed the crashes but not the speed.

# Rules for agents

- **Must:** change both copies of `Http2WithHttp1FallbackClient` together.
- **Must not:** return to one connection per request unless the problem it caused is solved: under concurrency it opened one TCP+TLS connection per request, causing connection storms, out-of-memory errors and much slower throughput than Node.
- **Ask first:** before adding an HTTP/1.1 opt-in or making the pool configurable.

# Related

- [Public authenticated app client and transport options](/app/app-client-and-transport-options.md)
- [Firestore is a standalone package](/firestore/standalone-package.md)
- [Firestore runs over REST, with buffered streaming](/firestore/rest-transport.md)
- [No realtime listeners](/firestore/no-realtime-listeners.md)

[^admin-transport]: The app client's transport
[^firestore-transport]: Firestore's transport
