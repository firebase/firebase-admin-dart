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
    symbol: class Http2WithHttp1FallbackClient
    title: The app client's HTTP/2 transport with an HTTP/1.1 fallback
  - id: firestore-transport
    resource: ../../../packages/google_cloud_firestore/lib/src/firestore_http_client.dart
    symbol: class Http2WithHttp1FallbackClient
    title: Firestore's HTTP/2 transport with an HTTP/1.1 fallback
  - id: admin-pubspec
    resource: ../../../packages/firebase_admin_sdk/pubspec.yaml
    symbol: "http2:"
    title: The admin package's `http2` constraint
  - id: firestore-pubspec
    resource: ../../../packages/google_cloud_firestore/pubspec.yaml
    symbol: "http2:"
    title: The Firestore package's `http2` constraint
---

# Decision

By default, HTTPS traffic goes over pooled HTTP/2 connections, through `package:http2`'s `Http2Client`. Both the app's default client (`FirebaseApp.client`) and Firestore's `FirestoreHttpClient` use a wrapper, `Http2WithHttp1FallbackClient`.[^admin-transport][^firestore-transport]

The wrapper routes by URL scheme: `https` goes over HTTP/2, anything else over plain HTTP/1.1. That keeps these endpoints on HTTP/1.1:

- the emulators;
- Firestore with `Settings.ssl: false`;
- the GCE metadata server, which Application Default Credentials use on GCE and Cloud Run, and the link-local addresses that WIF/OIDC credentials often point at.

`Http2Client` is `@experimental` upstream. The `http2` constraint in each pubspec bounds that risk, as the transport files say in a comment.[^admin-pubspec][^firestore-pubspec]

# Why

The maintainers' stated reason: `dart:io`'s `HttpClient` only speaks HTTP/1.1, so every concurrent request opened its own TCP and TLS connection. Under load that caused connection-storm failures and out-of-memory errors, and made Dart much slower than Node, whose Firestore client multiplexes concurrent operations over a small pool of HTTP/2 connections. The emulator stays on HTTP/1.1 to match Node's REST-mode behaviour.

Alternatives that were tried or rejected:

- Capping connections per host: it only limits how many requests run at once and queues the rest, which is much slower. A reviewer also questioned exposing a `dart:io`-specific setting.
- Retrying connection-closed errors: it fixed the crashes but not the speed.

# Rules for agents

- **Must not:** send plain-`http` URLs through `Http2Client`. It rejects them, which breaks WIF/OIDC and metadata-server credentials.
- **Must not:** return to one connection per request unless the problem it caused is solved: under concurrency it opened one TCP+TLS connection per request, causing connection storms, out-of-memory errors and much slower throughput than Node.
- **Ask first:** before adding an HTTP/1.1 opt-in or making the pool configurable.

# Related

- [Public authenticated app client and transport options](/app/app-client-and-transport-options.md)
- [Firestore runs over REST, not gRPC](/firestore/rest-transport.md)
- [No realtime listeners](/firestore/no-realtime-listeners.md)

[^admin-transport]: The app client's transport
[^firestore-transport]: Firestore's transport
[^admin-pubspec]: Admin `http2` constraint
[^firestore-pubspec]: Firestore `http2` constraint
