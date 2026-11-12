---
name: write-and-sync-tests
description: Writes unit and emulator tests for firebase_admin_sdk and google_cloud_firestore in the repository's layout, tiers and helpers, and ports test cases from the Node.js Admin SDK and @google-cloud/firestore, including the regression test of a Node issue or fix, to find out whether Dart has the same bug. Use when asked to add or fix tests, raise coverage, port or sync Node tests, or reproduce or validate an issue with a test.
---

# Write tests, and sync them from Node

Read these two concepts first. They hold the rules; this skill gives the procedure.

- [Test tiers and tags](../../knowledge/tests/tiers-and-tags.md)
- [Test doubles and emulator helpers](../../knowledge/tests/helpers-and-injection.md)

## 1. Pick the tier and the file

| Tier | Use it for | `firebase_admin_sdk` | `google_cloud_firestore` | Tag |
| --- | --- | --- | --- | --- |
| Unit | Validation, request building, response and error mapping | `test/unit/<product>/` | `test/*_test.dart` | none |
| Emulator | Behaviour that needs a real backend | `test/integration/<product>/` | `test/*_test.dart` | `firebase-emulator` |
| Prod | What no emulator supports | `test/integration/<product>/` | `test/e2e/` | `prod` |

- Prefer the lowest tier that can fail for the bug. Add an emulator test on top when the request's effect matters, not only its shape.
- Add to the existing file for the class under test. Create a file only for a new class or product, named `<node module in snake_case>_test.dart`, with the license header.
- A tag goes on the file (`@Tags([...])` above `library;`) or on a `group`. An untagged emulator test breaks the default run for everyone.
- Write prod tests only when the user asks. Never run them unless the user asks and supplies credentials.

## 2. Write the test

Copy the setup of the nearest test in the same directory. Don't build a new harness.

- **Admin unit tests:** inject a mocktail double of the product's request handler or HTTP client through the service's `@internal` factory. Shared doubles and `registerFallbacks()` are in `test/fixtures/mock.dart`; test apps come from `createApp` in `test/fixtures/helpers.dart`. Storage and Firestore need extra care: see the helpers concept.
- **Emulator tests:** build on `createAuthForTest` or `createFirestore`. They refuse to run without the emulator and clean up after each test.
- **Environment variables:** inject them through the zone override, never by changing the process environment. [How](../../knowledge/environment/zone-injected-environment.md)
- **Errors:** assert the exception type and its `code`, and the message when Node's test asserts it.
- **Fake keys:** reuse `test/fixtures/mock_service_account.dart`. A new fixture that looks like a key must be listed under `false_secrets` in the package's pubspec.
- **Names:** `group` per class or method, `test` names that state the behaviour, as the neighbouring tests do.

## 3. Sync test cases from Node

Use this to cover a ported feature, to fill a coverage gap, or to check whether a Node bug exists in Dart.

1. **Find the Node tests.** The [compare-with-Node playbook](../../knowledge/playbooks/compare-with-node.md) maps each Dart path to its Node source. The tests sit beside it:
   - firebase-admin-node: `test/unit/<product>/*.spec.ts`, and `test/integration/` for emulator and live cases;
   - `@google-cloud/firestore`: google-cloud-node `handwritten/firestore/dev/test/`, and `dev/system-test/`.

   Read them at the latest release tag, or at the pinned version for Pipelines. Fetch single files with `gh api repos/<owner>/<repo>/contents/<path>?ref=<tag>`, or make a shallow clone outside this repository. Never copy Node sources into the repo.
2. **For an issue or fix:** find the test the Node fix added or changed (`gh pr view <n> --repo <owner>/<repo> --json files`). That test is the regression case to port.
3. **List the cases.** For the method under test, write down each Node `it(...)`: its input, and the result or error it expects. Then mark which ones the Dart tests already cover. Port the rest.
4. **Translate each case.**

   | Node | Dart |
   | --- | --- |
   | `describe` / `it` | `group` / `test` |
   | sinon stub of the API request | mocktail `when(...)` on the request-handler or HTTP-client double |
   | `expect(...).to.be.rejected.and.have.property('code', 'auth/x')` | `expect(..., throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'auth/x')))` |
   | a loop over invalid values (`null`, `NaN`, `0`, `''`, `{}`) | only the values Dart's types allow. Skip a case the type system makes impossible, and say so in the report. |
   | `undefined` versus `null` | omitted versus `null`. In Auth updates these differ: see [unset versus null](../../knowledge/auth/unset-vs-null-sentinel.md). |
   | nock or a fake server | the same double as the other tests in the file |

   Assert what Node asserts, in Dart's shapes: the same request fields, the same error code. Don't assert Node-only details, such as a JS error class name.
5. **Run the ported test before touching `lib/`.** Then:
   - It passes: Dart doesn't have the bug, or already had the behaviour. Keep the test.
   - It fails, and a Divergence concept or a Pipeline parity table covers the difference: the difference is deliberate. Change the test to assert Dart's documented behaviour, and cite the concept in a comment.
   - It fails otherwise: Dart has the gap or the bug. Fix `lib/` with the `implement-sdk-feature` skill if the user asked for a fix; otherwise leave the failing test out of the change and report it. Never commit a failing or skipped test to make a record of a bug.
6. **Cite the source** in the PR description: the Node repository, file and version. Don't put issue or PR numbers in the knowledge base.

## 4. Run

From the package you changed:

```bash
dart analyze --fatal-infos
dart test <the files you changed>
dart test
```

For emulator tests, use the commands in AGENTS.md › Verify your change, with `--concurrency=1`. To run one file, append its path inside the quoted `dart test` command.

Don't run the coverage scripts unless the user asks.

## 5. Report

Tell the user:

- the tests added, by file and tier;
- for a sync: the Node file and version, how many cases Node has, how many you ported, and which you skipped and why;
- for an issue: whether Dart reproduces it, with the failing assertion;
- which tiers you ran, and which you didn't.
