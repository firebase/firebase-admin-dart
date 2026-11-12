---
name: implement-sdk-feature
description: Adds or ports a public API (method, type, option or product) in firebase_admin_sdk or google_cloud_firestore, from the Node.js reference. Use when asked to add, port or extend an API.
---

# Implement an SDK feature

AGENTS.md has the rules. This is the order to apply them in.

For a bug fix rather than a new API, start with the `write-and-sync-tests` skill, section 2, to reproduce it, then come back to step 3.

## 1. Scope

1. Run `./scripts/knowledge.sh for <paths you expect to edit or add>` and read the concepts it lists.
2. Follow steps 1 to 3 of the [compare-with-Node playbook](../../knowledge/playbooks/compare-with-node.md). Read Node's implementation, typings and unit tests for the feature.
3. Stop and ask the user if the feature:
   - is a product the README marks "Not supported";
   - needs a new runtime dependency, hand-written HTTP, a retry layer or a streaming RPC;
   - changes or removes an existing public name.

## 2. Design

Write the public Dart signatures before any implementation. Map Node's shapes with the table in [Dart idioms over Node's shapes](../../knowledge/architecture/dart-idioms-over-node-shapes.md), and match how the closest existing method in the same product takes options and returns. If no row of the table and no concept covers a shape, ask before adding a new divergence.

## 3. Implement

- Follow the product's layout: [libraries and barrels](../../knowledge/conventions/product-libraries-and-barrels.md). A new product needs every item in that concept's new-product list.
- Port every Node validation, in Node's order, with Node's error code, so the same bad input gives the same error. Add a missing code to the product's enum and its server-to-client table.
- Read environment variables through the [zone override](../../knowledge/environment/zone-injected-environment.md).
- A Pipeline API also needs a golden case, a live E2E case and the parity tables: [Pipelines parity](../../knowledge/firestore/pipelines/node-parity.md).
- Write dartdoc from the behaviour you implemented, not by translating Node's JSDoc.

## 4. Test, record, verify

1. Tests: the `write-and-sync-tests` skill.
2. CHANGELOG entry, written for users; a breaking one starts with `**Breaking:**`. Update the package README if it lists or shows the API.
3. If you added a deliberate difference from Node, record it with the `update-knowledge-base` skill.
4. Run analyze, format and the unit tests as in AGENTS.md › Verify your change. Run emulator tests only for the files of the product you touched, by appending their paths inside the quoted `dart test` command.

## 5. Report

The Node file and version you ported from, each difference from Node and the idiom or concept that covers it, and the checks you didn't run.
