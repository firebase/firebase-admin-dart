---
type: Constraint
title: Inject test doubles and use the guarded emulator helpers
description: Unit tests build services through the `@internal` factories with injected request handlers or clients; emulator tests go through helpers that refuse to run without the emulator, strip production credentials and wipe emulator state on teardown.
tags: [tests, mocks, emulators]
agents_md: always
governs:
  - packages/*/test/fixtures/**
  - packages/firebase_admin_sdk/test/unit/**
  - packages/firebase_admin_sdk/test/integration/**
  - packages/google_cloud_firestore/test/*.dart
sources:
  - id: mocks
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/mock.dart
    symbol: class AuthRequestHandlerMock
    title: The mocktail doubles and `registerFallbacks()`
  - id: create-app
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/helpers.dart
    symbol: FirebaseApp createApp(
    title: "`createApp()`: a test app for `dart-firebase-admin`, closed on teardown"
  - id: mock-firestore-settings
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/helpers.dart
    symbol: const mockFirestoreSettings
    title: Firestore settings for admin unit tests, through `environmentOverride`
  - id: create-auth-for-test
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/auth/helpers.dart
    symbol: Auth createAuthForTest(
    title: "`createAuthForTest()`: emulator guard, credential stripping and user cleanup"
  - id: create-firestore
    resource: ../../../packages/google_cloud_firestore/test/fixtures/helpers.dart
    symbol: Future<Firestore> createFirestore(
    title: "`createFirestore()`: emulator guard and document cleanup"
  - id: firestore-env-symbol
    resource: ../../../packages/google_cloud_firestore/lib/google_cloud_firestore.dart
    symbol: "const envSymbol = #_envSymbol"
    title: The Firestore package's own zone key
---

# Constraint

**Unit tests inject doubles through the `@internal` factories.**

- Services are built through their `@internal` factories with an injected handler, such as `Auth.internal(app, requestHandler: ...)` and `AppCheck.internal(app, requestHandler: ...)`. `TenantManager` has an uncached `@internal` constructor instead, `TenantManager.internal(app, authRequestHandler: ...)`; its parameter is `authRequestHandler:`, not `requestHandler:`. Auth and `TenantManager` tests use the shared doubles in `test/fixtures/mock.dart` (`AuthRequestHandlerMock`, `AuthHttpClientMock`, `MockAuthClient`, `FirebaseAdminMock`, `MockFirebaseTokenVerifier`), and `registerFallbacks()` registers the fallback values.[^mocks] Other products declare theirs in their own test file, such as `MockAppCheckRequestHandler` in `test/unit/app_check/app_check_test.dart`. Tests import `package:firebase_admin_sdk/src/...` to reach these internals.
- `createApp()` creates an app for project `dart-firebase-admin` and closes it on teardown. `createApp(client: …)` passes a client double as `AppOptions.httpClient`.[^create-app]
- Storage: `Storage.internal(app)` takes no handler and sends requests through `app.client`, so a double reaches it through `createApp(client: …)`, but only outside Storage-emulator mode. When the tests run inside `firebase emulators:exec` with the Storage emulator, as `scripts/coverage.sh` runs `-P ci`, `FIREBASE_STORAGE_EMULATOR_HOST` is set and the `google_cloud_storage` delegate gets no client. The Storage unit tests avoid this by running in a zone with an empty environment.
- Firestore never uses `AppOptions.httpClient`. The admin wrapper only maps the app's options onto `google_cloud_firestore` `Settings`, and `FirestoreHttpClient` builds its own client. Admin Firestore unit tests pass a mock client only to stop the app from authenticating.

**The two packages have separate zone keys.** Each `envSymbol` is a public constant holding a library-private symbol, so the two are unequal and an admin zone override doesn't reach `google_cloud_firestore`.[^firestore-env-symbol] Admin unit tests configure Firestore through `Settings.environmentOverride` (`mockFirestoreSettings`).[^mock-firestore-settings] Admin integration tests call `app.firestore()`, which reads `FIRESTORE_EMULATOR_HOST` from the process environment that `firebase emulators:exec` sets.

**Emulator helpers guard against production.**

- `createAuthForTest()` throws a `StateError` unless `FIREBASE_AUTH_EMULATOR_HOST` is set (`requireEmulator: false` is the opt-out for prod-only tests). It removes `GOOGLE_APPLICATION_CREDENTIALS` through a zone override, and on teardown deletes the users on one `listUsers()` page, skipping cleanup without the emulator.[^create-auth-for-test]
- `createFirestore()` requires `FIRESTORE_EMULATOR_HOST`, then recursively deletes all documents and terminates the client on teardown.[^create-firestore]
- `prodEnv()` removes the emulator variables for prod-tagged tests.

Nearly every `createApp` call passes a `name:`, usually a fixed per-test string; the Auth and Functions helpers add a timestamp suffix. Fake keys in fixtures and test files are listed under `false_secrets`; the admin package also lists `test/unit/auth/jwt_test.dart` and `test/unit/app/credential_test.dart`.

# Why

The maintainers' stated reasons, in the helpers: "CRITICAL: Ensure emulator is running to prevent hitting production", and "Remove production credentials from zone environment to force emulator usage". `createAuthForTest` says: "Use unique app name for each test to avoid interference". CONTRIBUTING.md says to use the `helpers.dart` utilities and `mocktail`.

The likely reason for `--concurrency=1` (not recorded): the teardowns delete users and every document in the shared emulator.

# Enforced by

The helpers' `StateError` guards, and review.

# Rules for agents

- **Must:** unit-test new service methods by injecting a request handler or HTTP client double through the `@internal` factory. For Storage, inject it through `AppOptions.httpClient` (`createApp(client: …)`), and run the test in a zone with an empty environment, as the Storage unit tests do, so emulator mode doesn't drop the double.
- **Must not:** test Firestore requests through a mock `AppOptions.httpClient`; it never reaches `google_cloud_firestore`. Test Firestore requests in `google_cloud_firestore`'s own tests or against the emulator. Admin Firestore unit tests can still cover the wrapper itself: settings and credential mapping, caching per database, headers and lifecycle.
- **Must:** build emulator tests on `createApp`, `createAuthForTest` or `createFirestore`, or copy their guard into a new helper.
- **Must:** when an admin unit test needs Firestore without an emulator in the process environment, configure it through `Settings.environmentOverride` (`mockFirestoreSettings`).
- **Should:** give each test app a `name:` that no other app alive at the same time uses. Apps that share a name collide when their lifetimes overlap.
- **Must not:** remove or loosen the emulator guards beyond their explicit opt-outs, such as `requireEmulator: false`, or let a helper fall back to real credentials.
- **Must not:** expect an admin zone override to configure `google_cloud_firestore`.
- **Must not:** run emulator test files concurrently. Their teardowns wipe shared emulator state.

# Related

- [Test tiers and tags](/tests/tiers-and-tags.md)
- [What emulator tests need](/tests/emulator-requirements.md)
- [Zone-injected environment](/environment/zone-injected-environment.md)
- [Service access through app methods](/app/service-access.md)
- [The publish dry run](/release/publish-dry-run.md)

[^mocks]: The mocktail doubles and `registerFallbacks()`
[^create-app]: `createApp()`
[^firestore-env-symbol]: The Firestore package's own zone key
[^mock-firestore-settings]: `mockFirestoreSettings`
[^create-auth-for-test]: `createAuthForTest()`
[^create-firestore]: `createFirestore()`
