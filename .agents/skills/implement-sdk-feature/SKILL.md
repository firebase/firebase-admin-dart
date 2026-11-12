---
name: implement-sdk-feature
description: Adds or ports a public API (method, type, option or product) in firebase_admin_sdk or google_cloud_firestore from the Node.js reference, or fixes a bug in one. Use when asked to add, port, extend or fix an API.
---

# Implement an SDK feature

AGENTS.md has the rules. This is the order to apply them in.

For a bug fix, first write a failing test with the `write-and-sync-tests` skill. Then do the stop-and-ask check in "Scope" and continue from "Implement".

## 1. Scope

1. Run `./scripts/knowledge.sh for <the files you expect to edit>`. For a new file, pass its directory. Read the "Rules for agents" section of each concept listed; open the rest of a concept only when a rule needs it.
2. Follow steps 1 to 3 of the [compare-with-Node playbook](../../knowledge/playbooks/compare-with-node.md) to find the Node reference and read it at a release. Read Node's implementation, typings and unit tests for the feature.
3. Stop and ask the user if the change:
   - is for a product the README marks "Not supported";
   - ports something Node has deprecated;
   - needs a new runtime dependency, hand-written HTTP, a retry layer or a streaming RPC;
   - changes or removes an existing public name.

## 2. Design

Write the public Dart signatures before any implementation. Map Node's shapes with the table under "Decision" in [Dart idioms over Node's shapes](../../knowledge/architecture/dart-idioms-over-node-shapes.md), and match how the closest existing method in the same product takes options and returns. If no row of the table and no concept covers a shape, ask before adding a new divergence.

## 3. Implement

- Port every Node validation, in Node's order, so the same bad input gives the same error. In `firebase_admin_sdk` that is Node's error code: add a missing code to the product's enum and its server-to-client table. In `google_cloud_firestore`, misuse throws `ArgumentError` or `StateError`.
- A new file or a new product: follow "Rules for agents" in [libraries and barrels](../../knowledge/conventions/product-libraries-and-barrels.md). A new product needs every item under "A new admin product touches" in that concept.
- Read environment variables through `Zone.current[envSymbol]` first, as the surrounding code does, never `Platform.environment` alone.
- Use no language feature newer than the `environment.sdk` floor in the pubspec.
- A Pipeline API also needs a golden case, a live E2E case and the parity tables: "Rules for agents" in [Pipelines parity](../../knowledge/firestore/pipelines/node-parity.md).
- Write dartdoc from the behaviour you implemented, not by translating Node's JSDoc.

## 4. Test, record, verify

1. Tests: "Write" in the `write-and-sync-tests` skill, and its "Sync from Node" when you ported Node behaviour.
2. A CHANGELOG entry in each package you changed, written for users; a breaking one starts with `**Breaking:**`. If a package README lists or shows the API, update it there: the root `README.md` is a symlink.
3. If you added a deliberate difference from Node, record it with the `update-knowledge-base` skill.
4. Run analyze, format and the unit tests as in AGENTS.md › Verify your change. Run emulator tests only for the files of the product you touched, by appending their paths inside the quoted `dart test` command.

## 5. Report

The Node file and version you ported from, each difference from Node and the idiom or concept that covers it, and the checks you didn't run.
