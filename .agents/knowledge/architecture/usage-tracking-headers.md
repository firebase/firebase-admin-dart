---
type: Decision
title: Usage-tracking headers on the default client and Firestore
description: Requests through the SDK-built default client and through admin Firestore carry `X-Firebase-Client` with `fire-admin-dart/<version>` and an `X-Goog-Api-Client` value containing `fire-admin/<version>`, appended to an existing value; a user-supplied client and the Auth, Functions and Storage emulator clients don't add them.
tags: [architecture, transport, telemetry]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/utils/utils.dart
  - packages/firebase_admin_sdk/lib/src/app/firebase_user_agent_client.dart
  - packages/firebase_admin_sdk/lib/src/firestore/**
sources:
  - id: firebase-client-tag
    resource: ../../../packages/firebase_admin_sdk/lib/src/utils/utils.dart
    symbol: "'fire-admin-dart/$packageVersion'"
    title: The header names and tag values
  - id: user-agent-client
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_user_agent_client.dart
    symbol: tokens.contains(fireAdminApiClientTag)
    title: "`FirebaseUserAgentClient.send`: append, never duplicate, overwrite `X-Firebase-Client`"
  - id: default-client
    resource: ../../../packages/firebase_admin_sdk/lib/src/app/firebase_app.dart
    symbol: Future<googleapis_auth.AuthClient> _createDefaultClient()
    title: "`FirebaseApp` wraps only the client it builds; `app.client` returns a user-supplied one as is"
  - id: auth-emulator-client
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_http_client.dart
    symbol: return EmulatorClient(http.Client());
    title: The Auth emulator client, which isn't wrapped
  - id: firestore-headers
    resource: ../../../packages/firebase_admin_sdk/lib/src/firestore/firestore.dart
    symbol: firestoreUsageTrackingHeaders
    title: "`app.firestore()` passes the headers through `Settings.headers`"
---

# Where it lives

- Enforced by: nothing; review only.
- The header names and values: `utils.dart`.[^firebase-client-tag]
- How an existing `X-Goog-Api-Client` value is appended to without duplicating the tag: `FirebaseUserAgentClient.send` in `firebase_user_agent_client.dart`.[^user-agent-client]
- The two paths that add them: `FirebaseApp._createDefaultClient` for the client the SDK builds, and `Settings.headers`, filled in by `app.firestore()`, for Firestore, emulator included.[^default-client][^firestore-headers]

# Decision

Two usage-tracking headers identify the SDK on the default client and on Firestore. Their `<version>` comes from the generated `version.g.dart`. Clients outside those two paths don't add them:

- a user-supplied `AppOptions.httpClient`, which `app.client` returns unwrapped;[^default-client]
- the Auth emulator client;[^auth-emulator-client]
- Functions' `CloudTasksEmulatorClient`;
- in Storage-emulator mode, the client `google_cloud_storage` builds for itself, because the delegate gets no `client`;
- the public-key fetches in `utils/jwt.dart`, which use `http.get` or an injected `http.Client`.

# Why

The maintainers' stated reason: the headers are for usage tracking. The Firebase team asked for `fire-admin` as the Admin SDK's tag in `X-Goog-Api-Client`, as Node uses; an earlier `fire-admin-dart` tag there was wrong. Firestore requests have to carry the headers too, so they get them through `Settings.headers`. Appending instead of overwriting keeps the value other libraries set, and matching whole whitespace-separated tokens avoids false duplicates.

Why a user-supplied client and the Auth, Functions and Storage emulator clients aren't wrapped isn't recorded. Ask a maintainer before changing it.

# Rules for agents

- **Must not:** change the tag strings.
- **Must not:** overwrite the `x-goog-api-client` value that `google_cloud_rpc` sets.
- **Should:** send a new service's production requests through `app.client`, so they carry the headers whenever the SDK built the client.
- **Ask first:** before wrapping a user-supplied `AppOptions.httpClient` or an emulator client in `FirebaseUserAgentClient`.

# Related

- [Releases, versioning, CHANGELOG and version.g.dart](/release/releases-and-versioning.md)
- [Firestore is a standalone package](/firestore/standalone-package.md)

[^firebase-client-tag]: The header values in `utils.dart`
[^user-agent-client]: `FirebaseUserAgentClient`
[^default-client]: `FirebaseApp._createDefaultClient()` and `app.client`
[^auth-emulator-client]: The Auth emulator client
[^firestore-headers]: Firestore usage-tracking headers
