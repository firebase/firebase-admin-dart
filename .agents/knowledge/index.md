---
okf_version: "0.2"
---

# App

* [Public authenticated app client and transport options](app/app-client-and-transport-options.md) - `FirebaseApp.client`, `AppOptions.httpClient`, `AppOptions.additionalScopes` and `Credential.createClient` let users call Google APIs the SDK does not wrap, which Node does not offer.
* [Credential discovery when none is passed](app/credential-autodiscovery.md) - With no credential, the SDK reads `GOOGLE_APPLICATION_CREDENTIALS` as a service account if it is one and otherwise falls back to ADC.
* [Credential is a sealed class with factories](app/credential-sealed-hierarchy.md) - `Credential` is a sealed class with service-account, ADC and refresh-token subtypes built through factories, where Node has top-level `cert()`, `applicationDefault()` and `refreshToken()` and a public `getAccessToken()`.
* [Who closes which HTTP client, and lazy client creation](app/http-client-ownership.md) - `FirebaseApp` closes only the client it created, a service must close only clients it built (Auth and Functions also close a user-supplied client under their emulators), and authenticated clients are created on first use.
* [Node-style app lifecycle and registry](app/lifecycle.md) - Apps are created with `FirebaseApp.initializeApp({options, name})` into a named registry with Node's semantics and error codes, exposed as static members and closed with `app.close()`.
* [One fixed project-ID resolution order](app/project-id-resolution.md) - All services resolve the project ID in one fixed order through `FirebaseApp.resolveProjectIdSync()` and `getProjectId()`, with explicit configuration before ambient environment and async discovery last.
* [Re-initializing an app ignores a different credential](app/reinit-ignores-credential.md) - A second `initializeApp` with a different credential or `httpClient` silently returns the existing app, where Node throws `invalid-app-options`.
* [Services only through app methods, no public constructors](app/service-access.md) - Services are reached through instance methods such as `app.auth()` backed by `@internal` cached factories, with no public constructors and no Node-style top-level `getAuth()`.
* [Sign locally with the key, else through IAM signBlob](app/signing.md) - Custom tokens and App Check custom tokens are signed with the service-account key when present, otherwise through IAM `signBlob`, and left unsigned when the Auth emulator is enabled.

# Architecture

* [Dart idioms win where Node's shape does not fit](architecture/dart-idioms-over-node-shapes.md) - Where a Node API shape does not fit Dart, the Dart idiom is used and the difference is written down; this concept holds the one table of those mappings.
* [Admin services use generated REST clients from googleapis](architecture/generated-rest-clients.md) - Admin services call Google's REST/JSON APIs through generated `package:googleapis` discovery clients, hand-written HTTP is the exception, and there is no general retry layer as Node has.
* [Pooled HTTP/2 by default, HTTP/1.1 for plain-HTTP endpoints](architecture/http2-pooled-transport.md) - HTTPS traffic goes over pooled HTTP/2 connections by default, while emulators, `ssl: false` and the metadata server stay on HTTP/1.1.
* [Port of the Node.js Admin SDK](architecture/node-port.md) - The SDK is a close port of the Node.js Admin SDK and of Node Firestore, so Node's API names, file layout, validation rules and error codes are the reference.
* [Published as firebase_admin_sdk, owned by Google](architecture/package-name-and-ownership.md) - The package is published as `firebase_admin_sdk` from the `firebase/firebase-admin-dart` repository, no longer as `dart_firebase_admin`, and source headers name Google LLC.
* [Generic Google-auth features live upstream, not in this repo](architecture/upstream-generic-auth-features.md) - Generic Google-auth features such as signing, impersonation and project-ID discovery belong in Google's `googleapis_auth` and `google_cloud` packages, not in a local package.
* [Usage-tracking headers on the default client and Firestore](architecture/usage-tracking-headers.md) - Requests through the SDK-built default client and through admin Firestore carry `X-Firebase-Client` with `fire-admin-dart/<version>` and an `X-Goog-Api-Client` value containing `fire-admin/<version>`, appended to an existing value; a user-supplied client and the Auth, Functions and Storage emulator clients don't add them.

# Auth

* [ActionCodeSettings has linkDomain, not dynamicLinkDomain](auth/dynamic-link-domain-removed.md) - Dart's `ActionCodeSettings` has only `linkDomain`, with no `dynamicLinkDomain`, where Node keeps `dynamicLinkDomain` as deprecated.
* [Verifying ID tokens, session cookies and App Check tokens](auth/jwt-verification.md) - Tokens are verified with `dart_jsonwebtoken` against Google's public keys, without the JWT `typ` header check, mapping errors from exception types (the emulator verifier also matches message text), accepting unsigned ID tokens and session cookies under the Auth emulator, and exposing custom claims as a map where Node has an index signature.
* [Unset versus null in Auth updates (sentinel and _Box)](auth/unset-vs-null-sentinel.md) - `_BaseUpdateRequest` encodes Node's three states for `displayName`, `photoURL` and `phoneNumber` with a `_sentinel` default and `_Box` (omitted leaves a field unchanged, a value sets it, `null` clears it), so every public constructor must keep that default reachable.

# CI

* [Lints, analysis and formatting](ci/lint-and-format.md) - One root `analysis_options.yaml` applies to every package, but CI analyzes and format-checks only `packages/firebase_admin_sdk/`, with `--fatal-infos` and the format check on the dev SDK only, so format only the files you change and check ignores against every analysis SDK.
* [What CI runs, the coverage gate, and what gates merging](ci/trigger-matrix.md) - The workflow files say what runs where, and a green PR doesn't mean every suite ran; beyond them, the coverage threshold is copied as text in two places, and merging is gated only by the `cla/google` status and an Alphabet zizmor scan.
* [Workflow security rules and Dependabot](ci/workflow-hardening.md) - Workflow edits must pass the mandatory Alphabet zizmor scan and the org Actions allow-list, both configured outside the repo; Dependabot updates only GitHub Actions, and Dart and npm dependencies are updated by hand.

# Contributing

* [Squash merges with Conventional Commit titles](contributing/commit-and-pr-titles.md) - Only squash merges are allowed; the squash subject is the PR title (or a single-commit PR's commit subject) and the body keeps the commit messages, so PR titles and single commits follow Conventional Commits.
* [PR template, review, licence and CLA](contributing/pr-template-and-review.md) - PRs fill `.github/PULL_REQUEST_TEMPLATE.md` but take the CHANGELOG heading from the versioning rules, bots review and report coverage automatically, the issue templates are copied from another project, and the three identical `LICENSE` files stay untouched.

# Conventions

* [URL casing; JSON keys stay Node's](conventions/acronym-casing.md) - Most public members keep Node's `URL` casing but `photoUrl` uses Dart casing, and Auth records' and config classes' `toJson()` encodes like Node's `toJSON()`, with Node's keys and dates as strings.
* [Apache-2.0 header on every source file](conventions/license-headers.md) - Every source file carries the Apache-2.0 header from `scripts/header_template.txt` (the text in that file), checked in CI with addlicense.
* [Product libraries, parts and barrel exports](conventions/product-libraries-and-barrels.md) - Each admin product is a Dart library, mostly built from `part` files (App Check also has standalone libraries), with a transport file and a request-handler file, exported through a barrel with a `hide` deny-list or a plain re-export, while `google_cloud_firestore` uses a `show` allow-list, so exporting a new public name must be a deliberate choice.

# Dependencies

* [Dependency constraint style](dependencies/constraint-style.md) - Upper bounds are widened without raising minimums, a range may span two breaking lines, and lower bounds are untested, so they are raised only when the code needs it.
* [Resolvable in Flutter workspaces and for firebase_functions](dependencies/flutter-and-functions-consumers.md) - `firebase_admin_sdk` must keep resolving for `firebase_functions` and, with `google_cloud_firestore`, in pub workspaces that contain a stable Flutter app, so Flutter-pinned packages such as `meta` keep low lower bounds.
* [Minimum Dart SDK](dependencies/min-dart-sdk.md) - The `environment.sdk` constraint is the SDK floor; code must analyze on it, although no tests run on it, and the floor is repeated as text in three places that must be kept in sync.
* [Keep the dependency set small, with no code generation](dependencies/minimal-dependencies.md) - Dependencies that are unmaintained, trivially inlined or thin wrappers have been removed, library code is written by hand without code generators, and adding a runtime dependency or a generator needs agreement.
* [No committed lockfiles or dependency overrides](dependencies/no-lockfiles-or-overrides.md) - No `pubspec.lock`, `pubspec_overrides.yaml` or merged `dependency_overrides`, so CI always resolves the newest allowed versions; the committed Node lockfiles are the exception, installed with `npm ci` in the tools and `npm install` in the test fixture.

# Environment

* [Emulators found only through standard environment variables](environment/emulator-detection.md) - Emulators are found only through the standard Admin SDK `*_EMULATOR_HOST` variables, as in Node, with no `useEmulator()` API and `Bearer owner` on Auth, Firestore and Cloud Tasks emulator requests.
* [Storage emulator host set in the native process environment](environment/storage-emulator-native-env.md) - The Storage emulator host reaches `google_cloud_storage` through `STORAGE_EMULATOR_HOST`, written with FFI `setenv` and removed with `unsetenv` in production mode.
* [Environment reads go through a zone override first](environment/zone-injected-environment.md) - Code that reads environment variables checks `Zone.current[envSymbol]` before `Platform.environment`, so tests can inject or remove variables.

# Errors

* [Typed per-service admin exceptions with Node's error codes](errors/admin-exceptions.md) - Admin errors are typed per service under `FirebaseAdminException`, with Node's `service/kebab-code` codes, Node's server-to-client code tables and `toJson()`, but without Node's error extras.
* [Firestore errors: FirestoreException, and Errors for misuse](errors/firestore-exception.md) - `google_cloud_firestore` throws its own `FirestoreException`, not a `FirebaseAdminException`, mapping HTTP statuses onto gRPC-style codes, and throws `ArgumentError` or `StateError` for most misuse where Node throws a plain `Error`.

# Firestore

* [Settings.ignoreUndefinedProperties is never read](firestore/ignore-undefined-properties.md) - Dart declares Node's `Settings.ignoreUndefinedProperties`, but nothing reads it and `null` is always written as `nullValue`.
* [Firestore reference classes are mockable interfaces](firestore/mockable-references.md) - The Firestore reference classes `Query`, `CollectionReference`, `DocumentReference` and `CollectionGroup` are `interface class`es so users can mock them, while the value types `Timestamp` and `GeoPoint` stay `final`.
* [One cached Firestore per database, settings fixed](firestore/multi-database.md) - The admin `app.firestore()` caches one `Firestore` per database ID; asking for it again with settings that differ in a field `_areSettingsEqual` compares throws, and other setting changes are silently ignored.
* [No realtime listeners (onSnapshot)](firestore/no-realtime-listeners.md) - Node's Admin SDK supports Firestore realtime listeners through the bidirectional `Listen` RPC, which the generated REST client Dart uses doesn't have, so listeners are a transport limit and a gap, not out of scope.
* [Firestore follows Node, with a few FlutterFire look-alikes](firestore/node-not-flutterfire.md) - The Firestore API follows Node rather than FlutterFire's `cloud_firestore`, and matching FlutterFire to share code with Flutter clients was declined, yet the aggregate API, `withConverter` and some Pipeline aliases look like FlutterFire's.
* [Firestore runs over REST, with buffered streaming](firestore/rest-transport.md) - Node's Firestore uses gRPC by default, while Dart's uses only REST through the generated `google_cloud_firestore_v1` client, which has no bidirectional RPC and buffers every server-streaming response, so Node's `Readable` APIs aren't ported.
* [Firestore retries transient errors like Node](firestore/retries.md) - A standalone `WriteBatch.commit()` retries Node's commit codes, transactions retry as a whole, and queries, aggregations and pipelines retry an `http.ClientException`, such as a dropped connection, only before any partial result and outside a transaction, all with `package:retry`.
* [Firestore is a standalone package](firestore/standalone-package.md) - Firestore ships as `google_cloud_firestore`, which works without the Admin SDK and never imports it; `firebase_admin_sdk` wraps it through `app.firestore()`.
* [Timestamp shape and its Node JSON keys](firestore/timestamp.md) - Dart's `Timestamp` uses named parameters and `DateTime` and adds `fromMicros`, but `toJson()` keeps Node's `_seconds` and `_nanoseconds` keys on purpose.
* [No field-value-pairs form of update()](firestore/update-field-value-pairs.md) - Node's alternating `update(field, value, ...)` varargs form has no Dart equivalent; Dart has only the map form.

# Firestore pipelines

* [Pipelines parity with Node is checked by machine](firestore/pipelines/node-parity.md) - Firestore Pipelines are checked against the pinned Node SDK in CI, by golden requests, an API-signature snapshot, a single-implementation test and a live E2E coverage guard, and every difference from Node is a table entry.

# Functions

* [Task Queue scopes: no extension self-targeting, private Kit](functions/task-queue-scopes.md) - The Task Queue scope port never reads `EXT_INSTANCE_ID`, so it drops Node's own-extension handling, keeps the Kit scope private and prints warnings with `print()`.

# Generated

* [Other generated, compiled or mirrored files, and API docs](generated/other-generated-files.md) - The root `README.md` is a symlink to the admin package README, the task-queue fixture's compiled JS is committed and rebuilt from its TypeScript, and the API reference is pub.dev dartdoc, with no docs workflow and nothing that checks dartdoc is present.
* [version.g.dart is generated from the pubspec](generated/version-g-dart.md) - `packages/firebase_admin_sdk/lib/src/version.g.dart` is written by `scripts/gen-version.sh` from the admin pubspec version and committed; nothing compares the two, but a stale file fails the publish dry run.

# Messaging

* [No FID message targets](messaging/fid-targets.md) - Dart has no FID message types and no `enableLegacyHttpTransport`, and topic subscription takes only a `List<String>`.
* [Topic management on the FCM v1 API, IID calls kept as Legacy](messaging/topic-management-v1.md) - As in Node, `subscribeToTopic` and `unsubscribeFromTopic` use the FCM v1 topic-subscription API with per-token requests, while the old IID-based calls remain as `@Deprecated` `*Legacy` methods.

# Playbooks

* [Compare with Node before changing a Dart API or behaviour](playbooks/compare-with-node.md) - How to check a Dart API or behaviour against the Node.js reference before changing it, covering which Node package, file and version to read, how the layouts map, and what to do when Node has something Dart lacks.

# Release

* [The publish dry run must pass for both packages](release/publish-dry-run.md) - CI runs `dart pub publish --dry-run` for both packages, which fails on fake keys not listed in `false_secrets`, modified checked-in files and other pub validator warnings, but not on a bad description length or dependency overrides.
* [Releases are manual and done by Google maintainers](release/release-process.md) - A release PR strips the unreleased markers, then `google_cloud_firestore` and `firebase_admin_sdk` are published by hand under the `firebase.google.com` publisher and tagged by hand; there is no publish workflow.
* [Pre-GA versioning and CHANGELOG headings between releases](release/versioning-and-changelog.md) - Packages stay on 0.x until GA with no fixed release cadence; between releases `firebase_admin_sdk` carries a `-wip` version and heading, while `google_cloud_firestore` keeps its released version under `## Unreleased`, and the PR template's example matches neither.

# Repo

* [The pub workspace, melos and local setup](repo/workspace-and-melos.md) - A root `dart pub get` resolves the whole pub workspace and melos runs from the root dev dependency without a global install; local resolution hides a too-low lower bound on `google_cloud_firestore`, and tools and credentials are set up only when the user asks.

# Scope

* [Server only: no web, no mobile](scope/server-only.md) - Both packages are native, server-side libraries that depend on `dart:io` (and `firebase_admin_sdk` also on `dart:ffi`); web is not supported and the SDK must not be used in mobile apps.
* [Firebase services Node has and Dart does not](scope/unsupported-services.md) - Eight Firebase products that Node's Admin SDK offers are marked 🔴 "Not supported" in the README, a ninth, Phone Number Verification, is missing without being listed, and none has a recorded permanent out-of-scope decision.

# Storage

* [Storage is a thin wrapper over google_cloud_storage](storage/google-cloud-storage-wrapper.md) - `app.storage()` is a thin wrapper over Google's `package:google_cloud_storage`, adding only Firebase helpers such as the default bucket and `getDownloadURL`, and returning that package's types.

# Tests

* [The admin examples are tested in CI, Firestore's is not](tests/examples.md) - CI runs the tests of `firebase_admin_sdk`'s `example/` and `example_server_app/`, while `google_cloud_firestore/example/` is not a workspace member and nothing in CI analyzes or runs it.
* [Inject test doubles and use the guarded emulator helpers](tests/helpers-and-injection.md) - Unit tests inject doubles through the `@internal` factories, except that Storage's double is dropped under the Storage emulator and Firestore never sees `AppOptions.httpClient`; emulator tests build on helpers that refuse to run without the emulator and wipe shared state, so they run with `--concurrency=1`.
* [Prod and WIF test runs](tests/prod-and-wif.md) - `-P prod` and `-P wif` need real credentials and run only on request; the coverage scripts add `-P prod` whenever `GOOGLE_APPLICATION_CREDENTIALS` is set, and CI never runs admin prod tests, so the Pipeline E2E suite is the only prod suite CI runs.
* [Every change needs tests, in tiers selected by tags](tests/tiers-and-tags.md) - Every feature and fix needs tests, and tests are split into unit, emulator, prod and WIF tiers by `dart_test.yaml` tags, never by environment variables; CONTRIBUTING.md's lines that say otherwise are out of date.
