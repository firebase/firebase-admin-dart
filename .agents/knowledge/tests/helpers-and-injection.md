---
type: Constraint
title: Inject test doubles and use the guarded emulator helpers
description: Unit tests inject doubles through the `@internal` factories, except that Storage's double is dropped under the Storage emulator and Firestore never sees `AppOptions.httpClient`; emulator tests build on helpers that refuse to run without the emulator and wipe shared state, so they run with `--concurrency=1`.
tags: [tests, mocks, emulators]
agents_md: always
governs:
  - packages/*/test/fixtures/**
  - packages/firebase_admin_sdk/test/unit/**
  - packages/firebase_admin_sdk/test/integration/**
  - packages/google_cloud_firestore/test/*.dart
sources:
  - id: create-auth-for-test
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/auth/helpers.dart
    symbol: Auth createAuthForTest(
    title: "`createAuthForTest()`: emulator guard, credential stripping and user cleanup"
  - id: create-firestore
    resource: ../../../packages/google_cloud_firestore/test/fixtures/helpers.dart
    symbol: Future<Firestore> createFirestore(
    title: "`createFirestore()`: emulator guard and document cleanup"
  - id: create-app
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/helpers.dart
    symbol: FirebaseApp createApp(
    title: "`createApp()`: a test app, closed on teardown"
  - id: mock-firestore-settings
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/helpers.dart
    symbol: const mockFirestoreSettings
    title: Firestore settings for admin unit tests, through `environmentOverride`
  - id: mocks
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/mock.dart
    symbol: class AuthRequestHandlerMock
    title: The shared mocktail doubles and `registerFallbacks()`
  - id: storage-empty-zone
    resource: ../../../packages/firebase_admin_sdk/test/unit/storage/storage_test.dart
    symbol: Future<T> _withoutEmulator<T>(
    title: The Storage unit tests' empty-environment zone
  - id: contributing-emulator
    resource: ../../../CONTRIBUTING.md
    symbol: "#### `firebase_admin_sdk` emulator tests"
    title: CONTRIBUTING's emulator commands, without `--concurrency=1`
---

# Where it lives

- Enforced by: the helpers' guards, `Auth createAuthForTest(` in `packages/firebase_admin_sdk/test/fixtures/auth/helpers.dart`[^create-auth-for-test] and `Future<Firestore> createFirestore(` in `packages/google_cloud_firestore/test/fixtures/helpers.dart`.[^create-firestore] The rest is review only.
- Test apps, and Firestore settings for admin unit tests: `FirebaseApp createApp(` and `const mockFirestoreSettings` in `packages/firebase_admin_sdk/test/fixtures/helpers.dart`.[^create-app][^mock-firestore-settings]
- The shared doubles: `class AuthRequestHandlerMock` and its neighbours in `test/fixtures/mock.dart`; other products declare theirs in their own test file.[^mocks]
- How a Storage unit test keeps its double: `Future<T> _withoutEmulator<T>(` in `test/unit/storage/storage_test.dart`.[^storage-empty-zone]
- CONTRIBUTING.md's out-of-date emulator commands: `` #### `firebase_admin_sdk` emulator tests `` and the Firestore section after it.[^contributing-emulator]

# Constraint

**Unit tests inject doubles through the `@internal` factories,** importing `package:firebase_admin_sdk/src/...` to reach them. Two products need care:

- **Storage.** `Storage.internal(app)` takes no handler and sends requests through `app.client`, so a double reaches it only as `AppOptions.httpClient` (`createApp(client: …)`). Under the Storage emulator, as in `scripts/coverage.sh`'s `-P ci` run, `FIREBASE_STORAGE_EMULATOR_HOST` is set and the `google_cloud_storage` delegate gets no client, so the double is dropped. The Storage unit tests run in a zone with an empty environment to avoid this.
- **Firestore** never uses `AppOptions.httpClient`. The admin wrapper only maps the app's options onto `google_cloud_firestore` `Settings`, and `FirestoreHttpClient` builds its own client. Admin Firestore unit tests pass a mock client only to stop the app from authenticating. They configure Firestore through `Settings.environmentOverride` (`mockFirestoreSettings`), because an admin zone override doesn't reach `google_cloud_firestore` (see [Zone-injected environment](/environment/zone-injected-environment.md)). Admin integration tests call `app.firestore()`, which reads `FIRESTORE_EMULATOR_HOST` from the process environment that `firebase emulators:exec` sets.

**Emulator tests run with `--concurrency=1`.** The helpers' teardowns delete the users on one `listUsers()` page and every document in the shared emulator. CONTRIBUTING.md's emulator commands are out of date: they lack `--concurrency=1`.

# Why

Why emulator runs use `--concurrency=1` isn't recorded. The likely reason (not recorded): the teardowns wipe state that other test files in the same emulator depend on.

The guards' reasons are in the helpers' comments.

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

- [Every change needs tests, in tiers selected by tags](/tests/tiers-and-tags.md)
- [Environment reads go through a zone override first](/environment/zone-injected-environment.md)
- [Services only through app methods, no public constructors](/app/service-access.md)
- [The publish dry run must pass for both packages](/release/publish-dry-run.md), for fake keys in fixtures (`false_secrets`)
- [Other generated, compiled or mirrored files, and API docs](/generated/other-generated-files.md), for the task-queue fixture

[^create-auth-for-test]: `createAuthForTest()`
[^create-firestore]: `createFirestore()`
[^create-app]: `createApp()`
[^mock-firestore-settings]: `mockFirestoreSettings`
[^mocks]: The shared mocktail doubles
[^storage-empty-zone]: The Storage unit tests' empty-environment zone
[^contributing-emulator]: CONTRIBUTING's emulator sections
