---
okf_version: "0.2"
---

# App

* [Public authenticated app client and transport options](app/app-client-and-transport-options.md) - `FirebaseApp.client`, `AppOptions.httpClient`, `AppOptions.additionalScopes` and `Credential.createClient` let users call Google APIs the SDK does not wrap, which Node does not offer.
* [No public Credential.getAccessToken()](app/credential-access-token.md) - Node's public `Credential.getAccessToken()` has no Dart equivalent; the closest is `Credential.createClient(scopes)`.
* [Credential discovery when none is passed](app/credential-autodiscovery.md) - With no credential, the SDK reads `GOOGLE_APPLICATION_CREDENTIALS` as a service account if it is one and otherwise falls back to ADC.
* [Credential is a sealed class with factories](app/credential-sealed-hierarchy.md) - `Credential` is a sealed class with service-account, ADC and refresh-token subtypes built through factories, where Node has top-level `cert()`, `applicationDefault()` and `refreshToken()`.
* [Who closes which HTTP client, and lazy client creation](app/http-client-ownership.md) - `FirebaseApp` closes only the client it created, a service must close only clients it built (Auth and Functions also close a user-supplied client under their emulators), and authenticated clients are created on first use.
* [Node-style app lifecycle and registry](app/lifecycle.md) - Apps are created with `FirebaseApp.initializeApp({options, name})` into a named registry with Node's semantics and error codes, exposed as static members and closed with `app.close()`.
* [One fixed project-ID resolution order](app/project-id-resolution.md) - All services resolve the project ID in one fixed order through `FirebaseApp.resolveProjectIdSync()` and `getProjectId()`, with explicit configuration before ambient environment and async discovery last.
* [Re-initializing an app ignores a different credential](app/reinit-ignores-credential.md) - A second `initializeApp` with a different credential or `httpClient` silently returns the existing app, where Node throws `invalid-app-options`.
* [Services only through app methods, no public constructors](app/service-access.md) - Services are reached through instance methods such as `app.auth()` backed by `@internal` cached factories, with no public constructors and no Node-style top-level `getAuth()`.
* [Sign locally with the key, else through IAM signBlob](app/signing.md) - Custom tokens and App Check custom tokens are signed with the service-account key when present, otherwise through IAM `signBlob`, and left unsigned when the Auth emulator is enabled.

# Architecture

* [No general retry layer for admin REST calls](architecture/admin-http-retries.md) - Node's admin HTTP client retries 503s and connection resets, but `firebase_admin_sdk` has no general retry layer for its REST calls.
* [Dart idioms win where Node's shape does not fit](architecture/dart-idioms-over-node-shapes.md) - Where a Node API shape does not fit Dart, the Dart idiom is used and the difference is written down.
* [Admin services use generated REST clients from googleapis](architecture/generated-rest-clients.md) - Admin services call Google's REST/JSON APIs through generated `package:googleapis` discovery clients, and hand-written HTTP is the exception.
* [Each service splits HTTP client from request handler](architecture/http-client-request-handler-split.md) - Each service has a `*_http_client.dart` for transport and a `*_request_handler.dart` for validation and business logic.
* [Pooled HTTP/2 by default, HTTP/1.1 for plain-HTTP endpoints](architecture/http2-pooled-transport.md) - HTTPS traffic goes over pooled HTTP/2 connections by default, while emulators, `ssl: false` and the metadata server stay on HTTP/1.1.
* [Port of the Node.js Admin SDK](architecture/node-port.md) - The SDK is a close port of the Node.js Admin SDK and of Node Firestore, so Node's API names, file layout, validation rules and error codes are the reference.
* [Published as firebase_admin_sdk, owned by Google](architecture/package-name-and-ownership.md) - The package is published as `firebase_admin_sdk` from the `firebase/firebase-admin-dart` repository, no longer as `dart_firebase_admin`, and source headers name Google LLC.
* [Generic Google-auth features live upstream, not in this repo](architecture/upstream-generic-auth-features.md) - Generic Google-auth features such as signing, impersonation and project-ID discovery belong in Google's `googleapis_auth` and `google_cloud` packages, not in a local package.
* [Usage-tracking headers on the default client and Firestore](architecture/usage-tracking-headers.md) - Requests through the SDK-built default client and through admin Firestore carry `X-Firebase-Client` with `fire-admin-dart/<version>` and an `X-Goog-Api-Client` value containing `fire-admin/<version>`, appended to an existing value; a user-supplied client and the Auth, Functions and Storage emulator clients don't add them.

# Auth

* [Custom claims as a map, not an index signature](auth/claims-map.md) - Node's `DecodedIdToken` exposes custom claims through an index signature, while Dart has typed fields plus a `claims` map holding every claim that has no typed field.
* [ActionCodeSettings has linkDomain, not dynamicLinkDomain](auth/dynamic-link-domain-removed.md) - Dart's `ActionCodeSettings` has only `linkDomain`, with no `dynamicLinkDomain`, where Node keeps `dynamicLinkDomain` as deprecated.
* [Verifying ID tokens, session cookies and App Check tokens](auth/jwt-verification.md) - Tokens are verified with `dart_jsonwebtoken` against Google's public keys, without the JWT `typ` header check, mapping errors from exception types (the emulator verifier also matches message text) and accepting unsigned ID tokens and session cookies under the Auth emulator.
* [Unset versus null in Auth updates (sentinel and _Box)](auth/unset-vs-null-sentinel.md) - `_BaseUpdateRequest` encodes Node's three states for `displayName`, `photoURL` and `phoneNumber` with a `_sentinel` default and `_Box` (omitted leaves a field unchanged, a value sets it, `null` clears it), so every public constructor must make that default reachable.
* [Auth records encode JSON like Node's toJSON()](auth/user-record-tojson.md) - Auth records expose a public `toJson()` that encodes like Node's `toJSON()`.

# CI

* [Lints, analysis and formatting](ci/lint-and-format.md) - One root `analysis_options.yaml` builds on `dart_flutter_team_lints` with strict modes; CI analyzes and format-checks only `packages/firebase_admin_sdk/`, with `--fatal-infos` and the format check on the dev SDK only, so format only the files you change and check ignores against every analysis SDK.
* [What CI runs where, and what gates merging](ci/trigger-matrix.md) - Build runs on every non-docs PR, push to `main` and nightly, the knowledge-base check on every PR and push to `main`, the Firestore-only workflows on Firestore changes, admin prod tests never run in CI, and merging is gated by the `cla/google` status and an Alphabet-required zizmor scan, not by any workflow in this repo.
* [Workflow security rules (zizmor and the Actions allow-list)](ci/workflow-hardening.md) - Workflow edits must pass the mandatory Alphabet zizmor scan and the org Actions allow-list; every workflow sets read-only top-level permissions, and `persist-credentials: false` is repo practice, not enforced.

# Contributing

* [Squash merges with Conventional Commit titles](contributing/commit-and-pr-titles.md) - Only squash merges are allowed; the squash subject is the PR title (or a single-commit PR's commit subject) and the body keeps the commit messages, so PR titles and single commits follow Conventional Commits.
* [What a working checkout needs](contributing/dev-environment.md) - Working on the SDK needs Dart at or above the SDK floor, Java 21+ for the Firestore emulator, Node.js with `firebase-tools` for the emulators, a newer Node.js to regenerate the Pipeline fixtures, and `addlicense` for the CI header check.
* [Apache-2.0 licence and the Google CLA](contributing/license-and-cla.md) - The repo is Apache-2.0 with identical `LICENSE` copies at the root and in each package, and contributors must sign the Google CLA, whose `cla/google` status is the only check branch protection requires on `main`.
* [PR template and review](contributing/pr-template-and-review.md) - PRs fill `.github/PULL_REQUEST_TEMPLATE.md`, all PRs need review, new features need an issue with a proposal first, and Gemini Code Assist and a coverage bot comment automatically.

# Conventions

* [Mixed acronym casing (URL vs Url)](conventions/acronym-casing.md) - Most public members keep Node's `URL` casing, but `UserRecord.photoUrl` and `UserInfo.photoUrl` use Dart casing while their JSON keys stay Node's.
* [Dart core-library names replace Node member names](conventions/dart-member-names.md) - Where Dart has a core-library equivalent (`toJson`, `==`, `close`, `String` method names), it replaces Node's member name, and Pipeline renames are recorded in the parity table.
* [Promises become Futures, async iterables become Streams](conventions/futures-and-streams.md) - Node Promises become `Future`s and AsyncIterables become `Stream`s; Node's `Readable`-based APIs (`query.stream()`, `explainStream()`, `pipeline.stream()`) are not ported, and an incremental port needs a transport that streams (SSE or gRPC), because the server-streaming responses are buffered.
* [Apache-2.0 header on every source file](conventions/license-headers.md) - Every source file carries the Apache-2.0 header from `scripts/header_template.txt` (the text in that file), checked in CI with addlicense.
* [Named parameters for optional arguments and Pipeline options](conventions/named-parameters-for-options.md) - Node's trailing optional positionals become Dart named parameters; for Pipeline stages, Node options objects also become named parameters (enforced), while the admin services mostly keep Node's options objects as Dart classes.
* [Library code is written by hand](conventions/no-codegen.md) - Library code uses no code generation; `freezed` was removed and the only generated file is `version.g.dart`.
* [Overloads become separate methods; rest params become lists](conventions/no-overloads-or-rest-params.md) - Node overloads become separately named Dart methods and rest parameters become a trailing `List` or `Iterable`, not one `Object` parameter with runtime type checks.
* [Product libraries, parts and barrel exports](conventions/product-libraries-and-barrels.md) - Each admin product is one Dart library, mostly built from `part` files, exported through a barrel with a `hide` deny-list or a plain re-export, while `google_cloud_firestore` uses a `show` allow-list, so exporting a new public name must be a deliberate choice.
* [String unions become enums mapped to the wire string](conventions/string-unions-to-enums.md) - Node's string-literal unions become Dart enums that map to the wire string, with a few existing exceptions that take plain strings.
* [TypeScript object unions become sealed classes](conventions/unions-to-sealed-classes.md) - Node's object unions, intersections and runtime type tags become sealed class hierarchies used with pattern matching.

# Dependencies

* [Dependency constraint style](dependencies/constraint-style.md) - Caret constraints are the default, explicit `'>=a <b'` ranges are used where a range was widened across breaking releases (several `google_cloud_*` packages and `googleapis`), ranges are widened without raising minimums, and dependencies are sorted.
* [Dependabot updates GitHub Actions only](dependencies/dependabot.md) - Dependabot updates only GitHub Actions, monthly, grouped and with a cooldown, while Dart and npm dependencies are updated by hand.
* [Resolvable in Flutter workspaces and for firebase_functions](dependencies/flutter-and-functions-consumers.md) - `firebase_admin_sdk` must keep resolving in pub workspaces that contain a Flutter app and for `firebase_functions`, so Flutter-pinned packages such as `meta` keep low lower bounds and downstream-needed APIs stay public or injectable.
* [Minimum Dart SDK](dependencies/min-dart-sdk.md) - Every pubspec declares the same minimum Dart SDK (`sdk:`), and code must analyze on that floor and run on the stable and beta SDKs.
* [Keep the dependency set small](dependencies/minimal-dependencies.md) - Dependencies that are unmaintained, trivially inlined or thin wrappers have been removed, and adding a runtime dependency needs a reason and agreement.
* [No committed lockfiles or dependency overrides](dependencies/no-lockfiles-or-overrides.md) - `pubspec.lock` and `pubspec_overrides.yaml` are git-ignored and merged PRs carry no `dependency_overrides`, so CI always resolves the newest allowed versions; committed Node lockfiles are the exception.

# Environment

* [Emulators found only through standard environment variables](environment/emulator-detection.md) - Emulators are found only through the standard Admin SDK `*_EMULATOR_HOST` variables, as in Node, with no `useEmulator()` API and `Bearer owner` on Auth, Firestore and Cloud Tasks emulator requests.
* [Storage emulator host set in the native process environment](environment/storage-emulator-native-env.md) - The Storage emulator host reaches `google_cloud_storage` through `STORAGE_EMULATOR_HOST`, written with FFI `setenv` and removed with `unsetenv` in production mode.
* [Environment reads go through a zone override first](environment/zone-injected-environment.md) - Code that reads environment variables checks `Zone.current[envSymbol]` before `Platform.environment`, so tests can inject or remove variables.

# Errors

* [Typed per-service admin exceptions with Node's error codes](errors/admin-exceptions.md) - Admin errors are typed per service under `FirebaseAdminException`, with Node's `service/kebab-code` codes, Node's server-to-client code tables and `toJson()`.
* [FirestoreException is separate and maps HTTP to gRPC codes](errors/firestore-exception.md) - `google_cloud_firestore` throws its own `FirestoreException`, not a `FirebaseAdminException`, and maps REST and HTTP statuses onto gRPC-style codes.
* [Node's error extras are not ported](errors/node-error-extras.md) - Node's `FirebaseError` has `httpResponse`, `cause`, `hasCode()` and a richer `toJSON()`, while Dart's `FirebaseAdminException` has none of them and its `toJson()` returns only `code` and `message`.
* [Firestore misuse throws ArgumentError and StateError](errors/programmer-errors.md) - In `google_cloud_firestore`, most misuse throws Dart `ArgumentError` or `StateError` where Node throws a plain `Error`, while the admin package throws typed exceptions with `invalid-*` codes.

# Firestore

* [Positional aggregate fields with auto-aliases](firestore/aggregate-api.md) - Dart's `query.aggregate()` takes up to three positional fields with automatic aliases and adds `sum()` and `average()` shortcuts, where Node takes a map of user-chosen aliases.
* [Firestore uses generated google_cloud_firestore_v1](firestore/generated-client.md) - The Firestore package talks to Firestore through Google's generated `google_cloud_firestore_v1` client, not the `googleapis` `firestore/v1` client, and keeps the generated types out of its public API.
* [Settings.ignoreUndefinedProperties is never read](firestore/ignore-undefined-properties.md) - Dart declares Node's `Settings.ignoreUndefinedProperties`, but nothing reads it and `null` is always written as `nullValue`.
* [Firestore reference classes are mockable interfaces](firestore/mockable-references.md) - The Firestore reference classes `Query`, `CollectionReference`, `DocumentReference` and `CollectionGroup` are `interface class`es so users can mock them, while value types stay `final`.
* [One cached Firestore per database, settings fixed](firestore/multi-database.md) - The admin `app.firestore()` caches one `Firestore` per database ID; asking for it again with settings whose project, database, host, SSL flag or credential differ throws, and other setting changes are silently ignored.
* [No realtime listeners (onSnapshot)](firestore/no-realtime-listeners.md) - Node's Admin SDK supports Firestore realtime listeners through the bidirectional `Listen` RPC, which the generated REST client Dart uses doesn't have, so listeners are a transport limit and a gap, not out of scope.
* [Firestore follows Node, not FlutterFire](firestore/node-not-flutterfire.md) - The Firestore API follows Node rather than FlutterFire's `cloud_firestore`, and matching FlutterFire signatures to share code with Flutter clients was declined.
* [Firestore runs over REST, not gRPC](firestore/rest-transport.md) - Node's Firestore uses gRPC by default, while Dart's uses only REST through the generated `google_cloud_firestore_v1` client, which has no bidirectional `Listen` or `Write` RPC.
* [Firestore retries transient errors like Node](firestore/retries.md) - A standalone `WriteBatch.commit()` retries ABORTED, UNAVAILABLE and RESOURCE_EXHAUSTED as Node does, and queries, aggregations and pipelines retry `http.ClientException`s, such as connection-closed errors, only before any partial result and outside a transaction.
* [Firestore is a standalone package](firestore/standalone-package.md) - Firestore ships as `google_cloud_firestore`, which works without the Admin SDK and never imports it; `firebase_admin_sdk` wraps it through `app.firestore()`.
* [Timestamp shape and its Node JSON keys](firestore/timestamp.md) - Dart's `Timestamp` uses named parameters and `DateTime`, but `toJson()` keeps Node's `_seconds` and `_nanoseconds` keys on purpose.
* [One type parameter and a function-pair withConverter](firestore/typed-references.md) - Dart typed references have a single type parameter and `withConverter` takes a pair of functions, where Node has two model type parameters and a converter object.
* [No field-value-pairs form of update()](firestore/update-field-value-pairs.md) - Node's alternating `update(field, value, ...)` varargs form has no Dart equivalent; Dart has only the map form.
* [Firestore value types use Dart types and named parameters](firestore/value-types.md) - Firestore value types such as `GeoPoint`, dates, big integers, bytes and `FieldValue` use Dart types (`DateTime`, `BigInt`, `Uint8List`) and named or const constructors instead of Node's shapes.

# Firestore pipelines

* [Pipeline execution options Node lacks](firestore/pipelines/dart-only-options.md) - Dart's Pipeline execution adds options and behaviours that Node lacks, each recorded with its reason, and keeps query-level options on `execute()` rather than on the Pipeline.
* [Pipeline API mirrors Node with recorded exceptions](firestore/pipelines/dart-surface.md) - The Dart Pipeline API mirrors Node's `FirebaseFirestore.Pipelines` namespace, and every rename, type mapping, alias, Dart-only member and known difference is recorded in the parity tables.
* [Pipeline APIs Node has that Dart lacks](firestore/pipelines/missing-node-apis.md) - Some Node Pipeline APIs, including `pipeline.stream()`, have no Dart implementation; each one in the pinned Node release is a pending entry in the parity tables, which fail when an entry goes stale.
* [Pipeline wire format does not copy Node's bugs](firestore/pipelines/node-bugs-not-copied.md) - Where the pinned Node SDK sends Pipeline requests the backend rejects, Dart sends what the backend accepts, and each such difference is a checked entry in `_knownDivergences`.
* [Pipelines parity with Node is checked by machine](firestore/pipelines/node-parity.md) - For Firestore Pipelines, Node-generated golden requests, an API-signature snapshot, a single-implementation test and an E2E coverage guard check parity with Node in CI.

# Functions

* [Task Queue scopes: no extension self-targeting, private Kit](functions/task-queue-scopes.md) - The Task Queue scope port never reads `EXT_INSTANCE_ID`, so it drops Node's own-extension handling, keeps the Kit scope private and prints warnings with `print()`.

# Generated

* [API docs are pub.dev dartdoc](generated/api-docs.md) - The API reference is the pub.dev dartdoc, `melos run docs` writes local docs to git-ignored `doc/api/`, and new public APIs need `///` dartdoc.
* [Other generated, compiled or mirrored files](generated/other-generated-files.md) - The task-queue fixture's compiled JS and the Node tool lockfiles are committed, the root `README.md` is a symlink to the admin package README, and `doc/api/` is generated and git-ignored.
* [Pipeline API snapshot extracted from Node's typings](generated/pipeline-api-snapshot.md) - `node_pipeline_api.json` is extracted from the pinned Node SDK's TypeScript declarations, and `pipeline_api_parity_test.dart` compares the Dart Pipeline API against it.
* [Pipeline golden fixtures are generated by Node](generated/pipeline-golden-fixtures.md) - The Pipeline golden request fixtures are generated by the Node SDK pinned in `tool/pipeline_golden/package.json`, regenerated in CI, and never edited by hand.
* [version.g.dart is generated from the pubspec](generated/version-g-dart.md) - `packages/firebase_admin_sdk/lib/src/version.g.dart` is generated by `scripts/gen-version.sh` from the admin pubspec version, committed, and must match it exactly.

# Messaging

* [No FID message targets](messaging/fid-targets.md) - Dart has no FID message types and no `enableLegacyHttpTransport`, and topic subscription takes only a `List<String>`.
* [Topic management on the FCM v1 API, IID calls kept as Legacy](messaging/topic-management-v1.md) - As in Node, `subscribeToTopic` and `unsubscribeFromTopic` use the FCM v1 topic-subscription API with per-token requests, while the old IID-based calls remain as `@Deprecated` `*Legacy` methods.

# Playbooks

* [Compare with Node before changing a Dart API or behaviour](playbooks/compare-with-node.md) - How to check a Dart API or behaviour against the Node.js reference before changing it, covering which Node package, file and version to read, how the layouts map, where the automated parity checks live, and what to do when Node has something Dart lacks.

# Release

* [The publish dry run must pass for both packages](release/publish-dry-run.md) - CI's `publish` job runs `dart pub publish --dry-run` for both packages, which fails on fake keys not listed in `false_secrets`, modified checked-in files and other pub validator warnings.
* [Releases are manual and done by Google maintainers](release/release-process.md) - A release PR strips the unreleased markers, then `google_cloud_firestore` and `firebase_admin_sdk` are published by hand under the `firebase.google.com` publisher and tagged by hand; there is no publish workflow.
* [Pre-GA versioning and CHANGELOG headings between releases](release/versioning-and-changelog.md) - Packages stay on 0.x until GA with no fixed release cadence; between releases `firebase_admin_sdk` carries a `-wip` version and heading, while `google_cloud_firestore` keeps its released version under `## Unreleased`.

# Repo

* [One pub workspace, with melos on top](repo/workspace-and-melos.md) - The repo is a single pub workspace of four members, and CI runs `melos bootstrap`, whose post hook regenerates `version.g.dart`.

# Scope

* [Conveniences Dart adds on top of Node](scope/dart-only-conveniences.md) - Dart adds a few conveniences Node lacks, such as paged `listDocumentsPages`, `Settings.headers`, `FirebaseApp.instance` and `Timestamp.fromMicros`.
* [Server only: no web, no mobile](scope/server-only.md) - Both packages are native, server-side libraries that depend on `dart:io` (and `firebase_admin_sdk` also on `dart:ffi`); web is not supported and the SDK must not be used in mobile apps.
* [Firebase services Node has and Dart does not](scope/unsupported-services.md) - Eight Firebase products that Node's Admin SDK offers are marked 🔴 "Not supported" in the README, a ninth, Phone Number Verification, is missing without being listed, and none has a recorded permanent out-of-scope decision.

# Storage

* [Storage is a thin wrapper over google_cloud_storage](storage/google-cloud-storage-wrapper.md) - `app.storage()` is a thin wrapper over Google's `package:google_cloud_storage`, adding only Firebase helpers such as the default bucket and `getDownloadURL`, and returning that package's types.

# Tests

* [Coverage threshold in CI](tests/coverage-threshold.md) - CI merges both packages' coverage and fails the stable `test` job when total line coverage is below the threshold in `scripts/process_coverage.dart`.
* [What emulator tests need](tests/emulator-requirements.md) - Emulator tests need Java 21+, Node.js with `firebase-tools`, project ID `dart-firebase-admin` and `--concurrency=1`, and run through `firebase emulators:exec` or the coverage scripts.
* [The admin examples are workspace members tested in CI](tests/examples.md) - `packages/firebase_admin_sdk/example/` and `example_server_app/` are unpublished workspace members whose tests CI runs, while `google_cloud_firestore/example/` has no CI coverage.
* [Inject test doubles and use the guarded emulator helpers](tests/helpers-and-injection.md) - Unit tests build services through the `@internal` factories with injected request handlers or clients; emulator tests go through helpers that refuse to run without the emulator, strip production credentials and wipe emulator state on teardown.
* [Live Pipeline E2E suite](tests/pipeline-e2e-live.md) - The Firestore Pipeline E2E suite runs against a live Enterprise database in its own workflow, and every public Pipeline API member must have a live case there or a credential-free guard fails.
* [Prod and WIF test runs](tests/prod-and-wif.md) - `-P prod` needs a service account for the Google-owned `dart-firebase-admin` project and never runs in CI for `firebase_admin_sdk`, while `-P wif` runs one test file in the `test-wif` job.
* [Every change needs tests, in tiers selected by tags](tests/tiers-and-tags.md) - Every feature and fix needs tests, and tests are split into unit, emulator, prod and WIF tiers by `dart_test.yaml` tags, not by environment variables.
