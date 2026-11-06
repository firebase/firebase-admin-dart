---
type: Decision
title: Product libraries, parts and barrel exports
description: Each admin product is one Dart library, mostly built from `part` files, exported through a barrel with a `hide` deny-list or a plain re-export, while `google_cloud_firestore` uses a `show` allow-list, so exporting a new public name must be a deliberate choice.
tags: [conventions, public-api, libraries]
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
  - packages/google_cloud_firestore/lib/src/firestore.dart
sources:
  - id: auth-parts
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth.dart
    symbol: part 'auth/auth_http_client.dart'
    title: The Auth library, with its transport files as parts
  - id: auth-barrel
    resource: ../../../packages/firebase_admin_sdk/lib/auth.dart
    symbol: hide AuthHttpClient
    title: A barrel with a `hide` deny-list
  - id: app-check-barrel
    resource: ../../../packages/firebase_admin_sdk/lib/app_check.dart
    symbol: export 'src/app_check/app_check_api.dart'
    title: App Check's barrel re-exports its standalone API library whole
  - id: http2-library
    resource: ../../../packages/firebase_admin_sdk/lib/src/app.dart
    symbol: import 'app/http2_client.dart'
    title: The HTTP/2 client, a standalone internal library
  - id: firestore-barrel
    resource: ../../../packages/google_cloud_firestore/lib/google_cloud_firestore.dart
    symbol: show Credential
    title: "`google_cloud_firestore`'s `show` allow-list barrel"
  - id: contributing-public-api
    resource: ../../../CONTRIBUTING.md
    symbol: Only add exports there for types that users need directly
    title: CONTRIBUTING's Public API section
---

# Decision

**Admin libraries.** Each product is a library built from parts, rooted at `lib/src/app.dart`, `lib/src/auth.dart`, or `lib/src/<product>/<product>.dart` for App Check, Functions, Messaging, Security Rules and Storage. A product's `*_http_client.dart`, `*_request_handler.dart` and `*_exception.dart` are parts, so they share `_private` names, such as `_BaseAuth` across Auth.[^auth-parts] A part joins with `part '<dir>/<file>.dart';` in the root and `part of '<root>.dart';` in the file; parts can't declare imports, so add them to the root.

- App Check is the exception: `app_check_api.dart`, `token_generator.dart` and `token_verifier.dart` are standalone libraries that `app_check.dart` imports; only its exception, http-client and request-handler files are parts.
- Other standalone libraries under `lib/src/`: `app/http2_client.dart`, `utils/*.dart`, `object_utils.dart`, `version.g.dart`, and the admin Firestore wrapper `firestore/firestore.dart`.
- `Http2WithHttp1FallbackClient` lives in its own internal library, so no barrel can export it.[^http2-library] The other `http.Client` wrappers (`EmulatorClient`, `CloudTasksEmulatorClient`, `FirebaseUserAgentClient`) are parts of `app.dart`, hidden from the barrel.
- In Auth, methods shared by project-level and tenant-level auth live on `_BaseAuth`, which `Auth` and `TenantAwareAuth` extend, mirroring Node's `BaseAuth`.

**Admin barrels.** `lib/auth.dart`, `lib/functions.dart`, `lib/messaging.dart`, `lib/security_rules.dart` and `lib/firebase_admin_sdk.dart` export their library with a `hide` deny-list, so a new public name in a part is exported unless it is hidden.[^auth-barrel] `lib/app_check.dart` hides App Check's transport classes but re-exports `app_check_api.dart` whole.[^app-check-barrel] `lib/firestore.dart` and `lib/storage.dart` re-export with no `hide`. There, every new public name becomes API.

The `hide` barrels of Auth, App Check, Messaging and Security Rules hide their product's HTTP client and request handler, and `lib/firebase_admin_sdk.dart` hides the app's client wrappers. `lib/functions.dart` is the exception: it hides only `functionsServerToClientCode`, so it exports the public `FunctionsHttpClient` and `FunctionsRequestHandler`.

**`google_cloud_firestore`** is one library, `lib/src/firestore.dart`, built from parts, plus standalone libraries for its transport, credential, exception, status-code, backoff and environment code. Its barrel uses a `show` allow-list, so a new public type isn't exported until it is listed.[^firestore-barrel] The Pipeline parity test and the E2E-coverage guard fail on Pipeline declarations missing from the barrel.

**A new admin product** touches: a `FirebaseServiceType` value; a `FirebaseApp.x()` method plus an `@internal factory X.internal(app, {requestHandler})` through `getOrInitService`; `delete()` for `close()`; a product root with parts; a `lib/x.dart` barrel (choose `hide` or a plain re-export); its import in `lib/src/app.dart`; the README's "Supported Services" table; an example in `example/lib/`; unit and emulator tests; and a CHANGELOG entry.

# Why

- The maintainers' stated rule, in CONTRIBUTING: "Only add exports there for types that users need directly".[^contributing-public-api] In review, they suggested keeping a class public but hiding it from the barrel with `export … hide` and `@internal`, rather than exporting internals for tests.
- The HTTP/2 client was moved into a standalone internal library, rather than a part, to remove it from public exports entirely.
- The likely reason for one library per product (not recorded): it keeps Node's module-level privacy while the files mirror Node's file layout.
- Why barrels differ (`hide`, plain re-export, `show`) isn't recorded. Ask a maintainer before changing a barrel's style.

# Rules for agents

- **Should:** follow the layout of the product you're editing. Add a new file as a part where that product uses parts (a service's `*_http_client.dart` and `*_request_handler.dart` stay parts), and as a standalone library where it doesn't (App Check's API, token generator and verifier; `google_cloud_firestore`'s transport, credential, exception and environment code). For a brand-new product, follow the checklist above: a library built from parts.
- **Should:** put a new `http.Client` wrapper (a class extending `http.BaseClient`) in a standalone internal library that the product root imports and no barrel exports. This is inferred from how the HTTP/2 client was handled, not a recorded rule.
- **Must:** when you add a public name, check how its barrel exports it (`hide`, `show` or a plain re-export), so that exporting it is a deliberate choice. Make an internal name `_private`, add it to a `hide` list with `@internal`, or move it to a standalone library no barrel exports. Add every new public `google_cloud_firestore` type to the barrel's `show` list.
- **Must:** put Auth methods that tenants also need on `_BaseAuth`.
- **Must not:** export transport, request-handler, generated-client or server-to-client code-table types. `lib/functions.dart` already exports `FunctionsHttpClient` and `FunctionsRequestHandler`; don't add more such exports.
- **Ask first:** before hiding `FunctionsHttpClient` or `FunctionsRequestHandler`. Removing a public export is a breaking change.
- **Must not:** split a product's parts into separate libraries without a plan for the private names they share.

# Related

- [Each service splits HTTP client from request handler](/architecture/http-client-request-handler-split.md)
- [Services only through app methods](/app/service-access.md)
- [Typed per-service admin exceptions](/errors/admin-exceptions.md)
- [Firebase services Node has and Dart does not](/scope/unsupported-services.md)
- [Pipelines parity with Node is checked by machine](/firestore/pipelines/node-parity.md)

[^auth-parts]: `lib/src/auth.dart` and its parts
[^http2-library]: `import 'app/http2_client.dart'` in `lib/src/app.dart`
[^auth-barrel]: `lib/auth.dart`
[^app-check-barrel]: `lib/app_check.dart`
[^firestore-barrel]: `lib/google_cloud_firestore.dart`
[^contributing-public-api]: CONTRIBUTING's Public API section
