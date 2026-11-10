# AGENTS.md

Notes for AI coding agents working on the Dart Firebase Admin SDK. This file routes: the code and its docs are the source of truth, and `.agents/knowledge/` holds what they don't say (see [Knowledge base](#knowledge-base)). User docs: `README.md` and each package's README. Contribution rules: `CONTRIBUTING.md`.

## Setup

- Prerequisites: CONTRIBUTING.md › Prerequisites.
- A root `dart pub get` resolves the whole pub workspace. melos is a root dev dependency: `dart run melos bootstrap` works without a global install, and also regenerates `version.g.dart`.
- Install tools only when the user asks. Never set up, create or print credentials. [More](.agents/knowledge/repo/workspace-and-melos.md)

## Verify your change

Run from the package you changed unless noted.

| Check | Command |
| --- | --- |
| Analyze | `dart analyze --fatal-infos`, in every package you touched. CI analyzes only `firebase_admin_sdk`. |
| Format | `dart format <the files you changed>`. CI checks formatting on the dev SDK, and output differs between SDK versions, so don't run `dart format .` unless the user asks. |
| Unit tests | `dart test`. The default run excludes the emulator, prod and WIF tags. |
| Admin emulator tests | Build `test/fixtures/task_queue_functions` first (`npm install && npm run build`), then `firebase emulators:exec --config test/firebase.json --project dart-firebase-admin --only auth,firestore,functions,tasks,storage "dart test -P firebase-emulator --concurrency=1"`. |
| Firestore emulator tests | `firebase emulators:exec --project dart-firebase-admin --only firestore "dart test -P firebase-emulator --concurrency=1"`. |
| License headers | From the repo root: the `addlicense --check` command in `.github/workflows/build.yml` (job "Check License Headers"). |
| Knowledge base | From the repo root: `./scripts/knowledge.sh check`. |

- Run emulator tests with `--concurrency=1`. Test files share one emulator, and the test helpers delete emulator data on teardown.
- Don't run `scripts/coverage.sh` or `scripts/firestore-coverage.sh` unless the user asks. They install packages globally, `npm install` the fixture, and run the `-P prod` tests whenever `GOOGLE_APPLICATION_CREDENTIALS` is set.

## Rules

Each rule links to the concept that explains it.

- **Compare with Node first.** [Playbook](.agents/knowledge/playbooks/compare-with-node.md)
  - A feature Node has and Dart lacks is a gap unless a concept marks it deliberate, so ask before calling it out of scope.
  - Where Node's shape doesn't fit Dart, use the Dart idiom and record the difference. Don't add untyped `Map` option bags, and don't copy names from the JS Web SDK. [More](.agents/knowledge/architecture/dart-idioms-over-node-shapes.md)
- **Firestore stands alone.** `google_cloud_firestore` never imports `firebase_admin_sdk`. [More](.agents/knowledge/firestore/standalone-package.md)
- **Errors** are typed per service, under `FirebaseAdminException`, with Node's `service/code` strings. [More](.agents/knowledge/errors/admin-exceptions.md)
  - Map from the server's error code, and fall back to the HTTP status only when there is none.
  - Don't remove codes Node has. Don't throw a bare `Exception` in new code. Use `rethrow`, not `throw e`.
- **Barrels.** When you add a public name, check how its barrel exports it (`hide`, `show` or a plain re-export), so that exporting it is deliberate. Never export transport, request-handler or generated-client types. `lib/functions.dart` already exports `FunctionsHttpClient` and `FunctionsRequestHandler`; ask before hiding them, because removing an export is a breaking change. [More](.agents/knowledge/conventions/product-libraries-and-barrels.md)
- **Dependencies.** [More](.agents/knowledge/dependencies/flutter-and-functions-consumers.md)
  - The packages must keep resolving in Flutter workspaces and for `firebase_functions`.
  - Don't raise the lower bounds of Flutter-pinned packages (`meta`, `collection`, `intl`) above what stable Flutter pins.
  - Ask before adding a runtime dependency.
- **Tests.** Follow CONTRIBUTING.md › Testing Requirements, but gate tests with `dart_test.yaml` tags, not environment variables; its `RUN_PROD_TESTS` line is out of date. [Tiers](.agents/knowledge/tests/tiers-and-tags.md), [helpers](.agents/knowledge/tests/helpers-and-injection.md)
  - Tag tests that need an emulator or credentials, so they stay out of the default run.
  - Unit-test services by injecting doubles through their `@internal` factories. A mock `AppOptions.httpClient` never reaches Firestore, and Storage needs extra care; see the helpers concept.
  - Build emulator tests on the guarded helpers in `test/fixtures/`.
- **Credentials.** Never run `-P prod` or `-P wif` unless the user asks and supplies credentials. Never write credentials into the repo, logs or fixtures. [More](.agents/knowledge/tests/prod-and-wif.md)
- **CHANGELOG.** [More](.agents/knowledge/release/versioning-and-changelog.md)
  - Add an entry for every user-visible change, under the package's top heading: `## X.Y.Z-wip` for `firebase_admin_sdk`, `## Unreleased` for `google_cloud_firestore`. The PR template's example heading is wrong.
  - Never add a numbered release heading.
  - If the admin package has no `-wip` heading, bump to the next patch `-wip` and regenerate `version.g.dart` (below).
- **Releases.** Never publish, tag, or prepare a release unless the user asks. [More](.agents/knowledge/release/release-process.md)
- **License header.** Every new `.dart` file, Dockerfile and `.mjs` file starts with the text in `scripts/header_template.txt`. [More](.agents/knowledge/conventions/license-headers.md)
- **Lint and format.** Keep to the one root `analysis_options.yaml`. Don't add per-package options or disable rules. [More](.agents/knowledge/ci/lint-and-format.md)
- **Commits and PRs.** [Titles](.agents/knowledge/contributing/commit-and-pr-titles.md), [template](.agents/knowledge/contributing/pr-template-and-review.md)
  - PR titles, and the commit of a single-commit PR, are Conventional Commits (`type(scope): summary`).
  - Fill in the PR template, but never tick the CLA box for the user.

## Generated files: don't edit by hand

- `packages/firebase_admin_sdk/lib/src/version.g.dart`: run `scripts/gen-version.sh` after changing the admin version. [More](.agents/knowledge/generated/version-g-dart.md)
- The Pipeline golden fixtures and the Node API snapshot in `google_cloud_firestore`: regenerate them with their tools. [More](.agents/knowledge/firestore/pipelines/node-parity.md)

## Knowledge base

`.agents/knowledge/` is an [Open Knowledge Format](https://github.com/GoogleCloudPlatform/open-knowledge-format) bundle. It holds only what the code and docs don't say: why a decision was made, how Dart diverges from the Node.js SDK, and repository constraints. Each concept starts with "Where it lives", pointing at the code that holds the facts. `index.md` lists every concept.

- **Before you edit or add a file**, run `./scripts/knowledge.sh for <path>...`. It lists the concepts that govern those paths and the code each one points to. A path can be a file that doesn't exist yet, or a directory.
- **Keep it true.** If your change makes a concept wrong, update it in the same PR. The `update-knowledge-base` skill in `.agents/skills/` says how.
- CI runs `./scripts/knowledge.sh check`. It fails when a concept points at a file or symbol that no longer exists, so a change that breaks a concept shows up as a failing check.
