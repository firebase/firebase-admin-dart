---
name: write-and-sync-tests
description: Writes unit and emulator tests and ports Node.js test cases, including a Node fix's regression test, to check whether Dart has the same bug. Use when asked to add or fix tests, sync Node tests, raise coverage, or reproduce an issue.
---

# Write tests, and sync them from Node

AGENTS.md › Tests has the rules. Read a concept only where a step below names it.

## 1. Write

- Use the lowest tier that can fail for the bug. Add an emulator test when the request's effect matters, not only its shape.
- Add to the existing file for the class under test, and copy the setup of the nearest test.
- Admin exception classes don't share one naming pattern (`FirebaseAuthAdminException`, `FirebaseAppCheckException`). Check the product's `*_exception.dart` before asserting a type.
- For a Storage or Firestore unit test in `firebase_admin_sdk`, or a new emulator helper, read "Rules for agents" in [doubles and helpers](../../knowledge/tests/helpers-and-injection.md).
- For a new emulator or prod test, read "Rules for agents" in [tiers and tags](../../knowledge/tests/tiers-and-tags.md).

## 2. Sync from Node

1. **Find what Dart does on purpose.** Run `./scripts/knowledge.sh for <the lib files under test>`. The "Rules for agents" of the concepts it lists say where Dart differs from Node on purpose. Passing only the test path doesn't list them.
2. **Find the Node tests** with steps 3 and 4 of the [compare-with-Node playbook](../../knowledge/playbooks/compare-with-node.md): the version, the fetch command and the test directories.
3. **For an issue or fix,** port the test the Node fix added or changed: `gh pr view <n> --repo <owner>/<repo> --json files`.
4. **List the cases.** For the method under test, list each Node `it(...)` with its input and expected result, and mark the ones Dart already covers. If more than about 20 are left, or the user named no method, show the list and ask which to port.
5. **Translate.** Assert what Node asserts, in Dart's shapes: the same request fields, the same error code.
   - A loop over invalid values (`null`, `NaN`, `{}`): keep only the values Dart's types allow, and report the ones you skipped.
   - `undefined` versus `null` becomes omitted versus `null`. In Auth updates they differ: omitted leaves the field unchanged, `null` clears it.
   - A sinon stub or nock becomes the double the file's other tests use.
6. **Run the ported test before touching `lib/`.**
   - It passes: Dart doesn't have the bug. Keep the test.
   - It fails, and a concept from step 1 or a Pipeline parity table covers the difference: it is deliberate. Assert Dart's behaviour instead, and cite the concept in a comment.
   - It fails, and you have checked that the translation and the double are right: Dart has the gap or bug. If the user asked for a fix, continue from "Implement" in the `implement-sdk-feature` skill. Otherwise leave the test out and report it.
   - You can't tell which: report it as suspected, with the failing assertion, and ask.

   Never commit a failing or skipped test.

## 3. Run

Run the files you changed, then the package's `dart test`. For one emulator file, append its path inside the quoted `dart test` command from AGENTS.md. Report a prod-tagged test you wrote as not run.

For coverage, ask which files or product, and measure with `dart test --coverage=<dir>`, with `<dir>` outside the repo. Don't run the coverage scripts.

## 4. Report

The tests added, by file and tier. For a sync: the Node file and version, how many cases Node has, how many you ported, and which you skipped and why. For an issue: whether Dart reproduces it. The tiers you didn't run.
