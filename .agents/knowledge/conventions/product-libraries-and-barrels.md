---
type: Decision
title: Product libraries, parts and barrel exports
description: Each admin product is a Dart library, mostly built from `part` files (App Check also has standalone libraries), with a transport file and a request-handler file, exported through a barrel with a `hide` deny-list or a plain re-export, while `google_cloud_firestore` uses a `show` allow-list, so exporting a new public name must be a deliberate choice.
tags: [conventions, public-api, libraries, services]
agents_md: always
governs:
  - packages/*/lib/*.dart
  - packages/firebase_admin_sdk/lib/src/app.dart
  - packages/firebase_admin_sdk/lib/src/auth.dart
  - packages/firebase_admin_sdk/lib/src/app_check/app_check.dart
  - packages/firebase_admin_sdk/lib/src/functions/functions.dart
  - packages/firebase_admin_sdk/lib/src/messaging/messaging.dart
  - packages/firebase_admin_sdk/lib/src/security_rules/security_rules.dart
  - packages/firebase_admin_sdk/lib/src/storage/storage.dart
  - packages/firebase_admin_sdk/lib/src/*/*_http_client.dart
  - packages/firebase_admin_sdk/lib/src/*/*_request_handler.dart
  - packages/google_cloud_firestore/lib/src/firestore.dart
sources:
  - id: auth-parts
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth.dart
    symbol: part 'auth/auth_http_client.dart'
    title: The Auth library root, with its transport files as parts
  - id: auth-barrel
    resource: ../../../packages/firebase_admin_sdk/lib/auth.dart
    symbol: hide AuthHttpClient
    title: A barrel with a `hide` deny-list
  - id: functions-barrel
    resource: ../../../packages/firebase_admin_sdk/lib/functions.dart
    symbol: hide functionsServerToClientCode
    title: "`lib/functions.dart`, which hides only the code table"
  - id: http2-library
    resource: ../../../packages/firebase_admin_sdk/lib/src/app.dart
    symbol: import 'app/http2_client.dart'
    title: The HTTP/2 client, a standalone internal library
  - id: firestore-barrel
    resource: ../../../packages/google_cloud_firestore/lib/google_cloud_firestore.dart
    symbol: show Credential
    title: "`google_cloud_firestore`'s `show` allow-list barrel"
  - id: app-check-libraries
    resource: ../../../packages/firebase_admin_sdk/lib/src/app_check/app_check.dart
    symbol: import 'token_verifier.dart';
    title: App Check's root imports its standalone libraries
  - id: e2e-barrel-guard
    resource: ../../../packages/google_cloud_firestore/test/pipeline_e2e_coverage_test.dart
    symbol: public in lib/src/pipeline.dart but not exported from
    title: The E2E-coverage guard fails on Pipeline declarations missing from the barrel
  - id: app-check-run
    resource: ../../../packages/firebase_admin_sdk/lib/src/app_check/app_check_http_client.dart
    symbol: Future<R> _run<R>(
    title: The `_run` helper in a service's HTTP client
  - id: contributing-public-api
    resource: ../../../CONTRIBUTING.md
    symbol: "### Public API"
    title: CONTRIBUTING's Public API section
---

# Where it lives

- Enforced by: for `google_cloud_firestore`'s Pipeline declarations, the parity test and the E2E-coverage guard fail when one is missing from the barrel.[^e2e-barrel-guard] Everything else: nothing; review only.
- Each product's roots and parts: the `part` lines of its library root, such as `lib/src/auth.dart`.[^auth-parts]
- What each barrel exports: its `hide` list, `show` list or plain re-export in `lib/*.dart`, such as `lib/auth.dart`, `lib/functions.dart` and `lib/google_cloud_firestore.dart`.[^auth-barrel][^functions-barrel][^firestore-barrel]
- The transport/handler split: each service's `*_http_client.dart`, with its `_run` helper, and `*_request_handler.dart`.[^app-check-run]
- What may be exported: CONTRIBUTING's `### Public API`.[^contributing-public-api]

# Decision

**A barrel's style decides what a new public name does.** With `hide`, it is exported unless it is hidden. With a plain re-export, everything is exported. With `show`, nothing is exported until it is listed.

**Trap:** `lib/functions.dart` hides only `functionsServerToClientCode`, so it exports the public `FunctionsHttpClient` and `FunctionsRequestHandler`. The other `hide` barrels hide their product's HTTP client and request handler.

**Parts share private names.** A product's `*_http_client.dart`, `*_request_handler.dart` and `*_exception.dart` are parts of one library, so they share `_private` names. In Auth, methods shared by project-level and tenant-level auth live on `_BaseAuth`, mirroring Node's `BaseAuth`.

**App Check is the exception:** `app_check_api.dart`, `token_generator.dart` and `token_verifier.dart` are standalone libraries that `app_check.dart` imports, and `lib/app_check.dart` re-exports `app_check_api.dart` whole.[^app-check-libraries]

**Transport and logic are split.** A REST service's `*_http_client.dart` handles HTTP, emulator routing, the generated client and the project ID, through a `_run` helper. Its `*_request_handler.dart` handles validation, transformation and business logic. The split isn't uniform: some HTTP clients, such as `AuthHttpClient`, validate their own arguments.

**A new admin product touches:**

- a `FirebaseServiceType` value;
- a `FirebaseApp.x()` method, plus an `@internal factory X.internal(app, {requestHandler})` through `getOrInitService`;
- `delete()`, for `close()`;
- a product root with parts;
- a `lib/x.dart` barrel (choose `hide` or a plain re-export), imported in `lib/src/app.dart`;
- the README's "Supported Services" table;
- an example in `example/lib/`;
- unit and emulator tests;
- a CHANGELOG entry.

# Why

- In review, the maintainers suggested keeping a class public but hiding it from the barrel with `export … hide` and `@internal`, rather than exporting internals for tests.
- The HTTP/2 client was moved into a standalone internal library, rather than a part, to remove it from public exports entirely.[^http2-library]
- The maintainers' stated reason for the split: it separates low-level HTTP (emulator configuration, `googleapis`) from business logic, transformations and validation. `_run` removes the repeated `await app.client` calls from every operation. One API-internals file per service was the alternative.
- The likely reason for one library per product (not recorded): it keeps Node's module-level privacy while the files mirror Node's file layout.
- Why barrels differ (`hide`, plain re-export, `show`) isn't recorded. Ask a maintainer before changing a barrel's style.

# Rules for agents

- **Should:** add a new file the way the product you're editing adds its files: as a part where it uses parts, and as a standalone library where it doesn't. A brand-new product is a library built from parts.
- **Should:** put a new `http.Client` wrapper (a class extending `http.BaseClient`) in a standalone internal library that the product root imports and no barrel exports. This is inferred from how the HTTP/2 client was handled, not a recorded rule.
- **Must:** when you add a public name, check how its barrel exports it (`hide`, `show` or a plain re-export), so that exporting it is a deliberate choice. Make an internal name `_private`, add it to a `hide` list with `@internal`, or move it to a standalone library no barrel exports. Add every new public `google_cloud_firestore` type to the barrel's `show` list.
- **Must:** put Auth methods that tenants also need on `_BaseAuth`.
- **Must not:** export transport, request-handler, generated-client or server-to-client code-table types. Don't add more exports like `lib/functions.dart`'s.
- **Ask first:** before hiding `FunctionsHttpClient` or `FunctionsRequestHandler`. Removing a public export is a breaking change.
- **Must not:** split a product's parts into separate libraries without a plan for the private names they share.
- **Should:** put new validation in the request handler. Where an HTTP client already validates its arguments, as `AuthHttpClient` does, follow the surrounding code.
- **Should:** get the client and project ID through `_run`, or through the `v1`/`withClient`-style wrappers built on it, rather than awaiting `app.client` or `app.getProjectId()` in each operation.

# Related

- [Services only through app methods, no public constructors](/app/service-access.md)
- [Typed per-service admin exceptions](/errors/admin-exceptions.md)
- [Admin services use generated REST clients from googleapis](/architecture/generated-rest-clients.md)
- [Firebase services Node has and Dart does not](/scope/unsupported-services.md)
- [Pipelines parity with Node is checked by machine](/firestore/pipelines/node-parity.md)

[^e2e-barrel-guard]: The E2E-coverage guard's export check
[^auth-parts]: `lib/src/auth.dart` and its parts
[^app-check-libraries]: App Check's standalone libraries
[^auth-barrel]: `lib/auth.dart`
[^functions-barrel]: `lib/functions.dart`
[^firestore-barrel]: `lib/google_cloud_firestore.dart`
[^app-check-run]: App Check's `_run`
[^contributing-public-api]: CONTRIBUTING's Public API section
[^http2-library]: `import 'app/http2_client.dart'` in `lib/src/app.dart`
