---
name: write-and-sync-tests
description: Writes unit and emulator tests, and ports test cases from the Node.js SDKs, including the regression test of a Node issue or fix, to check whether Dart has the same bug. Use when asked to add or fix tests, port or sync Node tests, or reproduce an issue.
---

# Write tests, and sync them from Node

AGENTS.md › Tests has the rules. Read a concept only where a step below names it.

## 1. Write

- Use the lowest tier that can fail for the bug. Add an emulator test when the request's effect matters, not only its shape.
- Add to the existing file for the class under test, and copy the setup of the nearest test. Don't build a new harness.
- Admin exception classes don't share one naming pattern (`FirebaseAuthAdminException`, `FirebaseAppCheckException`). Check the product's `*_exception.dart` before asserting a type.
- For a Storage or Firestore unit test in `firebase_admin_sdk`, or a new emulator helper, read "Rules for agents" in [doubles and helpers](../../knowledge/tests/helpers-and-injection.md).
- For a new emulator or prod test, read "Rules for agents" in [tiers and tags](../../knowledge/tests/tiers-and-tags.md).

## 2. Sync from Node

1. **Find what Dart does on purpose.** Run `./scripts/knowledge.sh for <the lib files under test>`. The "Rules for agents" of the concepts it lists say where Dart differs from Node on purpose. Passing only the test path doesn't list them.
2. **Find the Node tests,** at the latest release tag (`gh release view --repo firebase/firebase-admin-node --json tagName`), or the pinned version for Pipelines:
   - admin: `firebase/firebase-admin-node`, `test/unit/<product>/*.spec.ts`;
   - Firestore: `googleapis/google-cloud-node`, `handwritten/firestore/dev/test/`.

   ```bash
   gh api -H 'Accept: application/vnd.github.raw' 'repos/<owner>/<repo>/contents/<path>?ref=<tag>'
   ```

   Never copy Node sources into this repo.
3. **For an issue or fix,** port the test the Node fix added or changed: `gh pr view <n> --repo <owner>/<repo> --json files`.
4. **List the cases.** For the method under test, list each Node `it(...)` with its input and expected result, and mark the ones Dart already covers. Port the rest.
5. **Translate.** Assert what Node asserts, in Dart's shapes: the same request fields, the same error code.
   - A loop over invalid values (`null`, `NaN`, `{}`): keep only the values Dart's types allow, and report the ones you skipped.
   - `undefined` versus `null` becomes omitted versus `null`. In Auth updates they differ: omitted leaves the field unchanged, `null` clears it.
   - A sinon stub or nock becomes the double the file's other tests use.
6. **Run the ported test before touching `lib/`.**
   - It passes: Dart doesn't have the bug. Keep the test.
   - It fails, and a concept from step 1 or a Pipeline parity table covers the difference: it is deliberate. Assert Dart's behaviour instead, and cite the concept in a comment.
   - It fails otherwise: Dart has the gap or bug. Fix it with the `implement-sdk-feature` skill if the user asked for a fix. Otherwise leave the test out and report it. Never commit a failing or skipped test.

## 3. Run

Run the files you changed, then the package's `dart test`. For one emulator file, append its path inside the quoted `dart test` command from AGENTS.md.

A request to raise coverage isn't a request to run the coverage scripts. Measure with `dart test --coverage=<dir>`.

## 4. Report

The tests added, by file and tier. For a sync: the Node file and version, how many cases Node has, how many you ported, and which you skipped and why. For an issue: whether Dart reproduces it. The tiers you didn't run.
