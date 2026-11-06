---
type: Constraint
title: What emulator tests need
description: Emulator tests need Java 21+, Node.js with `firebase-tools`, project ID `dart-firebase-admin` and `--concurrency=1`, and run through `firebase emulators:exec` or the coverage scripts.
tags: [tests, emulators, tooling]
agents_md: when-touching
governs:
  - packages/*/test/**
  - scripts/*coverage.sh
  - packages/*/firebase.json
sources:
  - id: admin-coverage-script
    resource: ../../../scripts/coverage.sh
    symbol: emulators:exec
    title: The admin emulator run, including the task-queue fixture build
  - id: firestore-coverage-script
    resource: ../../../scripts/firestore-coverage.sh
    symbol: emulators:exec
    title: The Firestore emulator run
  - id: admin-firebase-json
    resource: ../../../packages/firebase_admin_sdk/test/firebase.json
    title: The admin emulator configuration
  - id: firestore-firebase-json
    resource: ../../../packages/google_cloud_firestore/firebase.json
    title: The Firestore emulator configuration
  - id: firestore-helper-guard
    resource: ../../../packages/google_cloud_firestore/test/fixtures/helpers.dart
    symbol: FIRESTORE_EMULATOR_HOST
    title: The Firestore helpers refuse to run without the emulator
  - id: task-queue-fixture
    resource: ../../../packages/firebase_admin_sdk/test/fixtures/task_queue_functions/package.json
    title: The TypeScript functions fixture the Cloud Tasks emulator loads
---

# Constraint

Emulator tests need:

- Java 21+, for the Firestore emulator. CI installs Temurin with `setup-java`.
- Node.js with `firebase-tools`. CI installs `firebase-tools` unpinned, at the latest release.
- The project ID `dart-firebase-admin`.
- `--concurrency=1`.

How each package runs them:

- `firebase_admin_sdk`: `firebase emulators:exec --config test/firebase.json --project dart-firebase-admin --only auth,firestore,functions,tasks,storage`. The ports are in `test/firebase.json`.[^admin-firebase-json] The Cloud Tasks emulator needs the TypeScript fixture built first: `cd test/fixtures/task_queue_functions && npm install && npm run build`.[^task-queue-fixture]
- `google_cloud_firestore`: `firebase emulators:exec --project dart-firebase-admin --only firestore`, using the package's own `firebase.json`.[^firestore-firebase-json]

`scripts/coverage.sh` and `scripts/firestore-coverage.sh` do all of this, and they are what CI runs.[^admin-coverage-script][^firestore-coverage-script]

# Why

The maintainers' stated reasons, in CONTRIBUTING.md: Java 21+ is "required for the Firestore emulator", and the Cloud Tasks emulator "requires the functions fixture to be built first". The Firestore test helpers refuse to run without `FIRESTORE_EMULATOR_HOST`: "This prevents accidentally writing test data to production."[^firestore-helper-guard]

Why emulator runs use `--concurrency=1` isn't recorded. The likely reason (not recorded): the emulator helpers' teardowns delete users (one `listUsers()` page) and every document in the shared emulator.

# Enforced by

The `test` job of `.github/workflows/build.yml`, which runs both coverage scripts; the two `firebase.json` files; and the test helpers' guards.

# Rules for agents

- **Must:** run emulator tests through `firebase emulators:exec` or the scripts, never against a real project by removing guards.
- **Must not:** commit `task_queue_functions/node_modules`, or a rebuild-only change to its `lib/index.js` when `src/index.ts` didn't change.
- **Should:** leave out of your commits the `package-lock.json` churn in that fixture that `coverage.sh`'s `npm install` can cause.

# Related

- [Emulator detection](/environment/emulator-detection.md)
- [Other generated files](/generated/other-generated-files.md)
- [Test tiers and tags](/tests/tiers-and-tags.md)

[^admin-firebase-json]: The admin emulator configuration
[^task-queue-fixture]: The task-queue functions fixture
[^firestore-firebase-json]: The Firestore emulator configuration
[^admin-coverage-script]: `scripts/coverage.sh`
[^firestore-coverage-script]: `scripts/firestore-coverage.sh`
[^firestore-helper-guard]: The Firestore helpers' emulator guard
