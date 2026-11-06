---
type: Decision
title: Each service splits HTTP client from request handler
description: Each service has a `*_http_client.dart` for transport and a `*_request_handler.dart` for validation and business logic.
tags: [architecture, services]
agents_md: when-touching
governs:
  - packages/firebase_admin_sdk/lib/src/*/*_http_client.dart
  - packages/firebase_admin_sdk/lib/src/*/*_request_handler.dart
sources:
  - id: app-check-run
    resource: ../../../packages/firebase_admin_sdk/lib/src/app_check/app_check_http_client.dart
    symbol: Future<R> _run<R>(
    title: The `_run` helper in App Check's HTTP client
  - id: app-check-handler
    resource: ../../../packages/firebase_admin_sdk/lib/src/app_check/app_check_request_handler.dart
    symbol: class AppCheckRequestHandler
    title: App Check's request handler
  - id: auth-http-client
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_http_client.dart
    symbol: class AuthHttpClient
    title: Auth's HTTP client
  - id: auth-request-handler
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_request_handler.dart
    symbol: class AuthRequestHandler
    title: Auth's request handler
---

# Decision

Each REST service (App Check, Auth, Functions, Messaging and Security Rules) is split into two files:

- `*_http_client.dart` handles transport: HTTP, emulator routing, creating the generated client, and injecting the project ID through a `_run` helper.[^app-check-run][^auth-http-client]
- `*_request_handler.dart` handles validation, transformation and business logic.[^app-check-handler][^auth-request-handler]

Storage and the Firestore wrapper have neither file; they delegate to their packages.

The split isn't uniform:

- Messaging's FCM v1 topic management builds URIs and calls `client.post` inside `messaging_request_handler.dart`.
- `AuthHttpClient` validates many arguments inside its operations: emails, request types, page tokens and sizes, and tenant IDs.
- `FunctionsRequestHandler.enqueue` reads `_httpClient.client` directly to set up task authentication.
- `MessagingHttpClient.invokeRequestHandler` reads `app.client` outside `_run` for the legacy IID calls.

# Why

The maintainers' stated reason: the split separates low-level HTTP (emulator configuration, `googleapis`) from business logic, transformations and validation. `_run` removes the repeated `await app.client` calls from every operation.

The alternative was one API-internals file per service.

# Rules for agents

- **Should:** put new validation in the request handler. Where an HTTP client already validates its arguments, as `AuthHttpClient` does, follow the surrounding code.
- **Should:** get the client and project ID through `_run`, or through the `v1`/`withClient`-style wrappers built on it, rather than awaiting `app.client` or `app.getProjectId()` in each operation.

# Related

- [How product libraries are laid out and exported through barrels](/conventions/product-libraries-and-barrels.md)

[^app-check-run]: App Check's `_run`
[^auth-http-client]: `AuthHttpClient`
[^app-check-handler]: `AppCheckRequestHandler`
[^auth-request-handler]: `AuthRequestHandler`
