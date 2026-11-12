---
name: implement-sdk-feature
description: Implements a new method, type, option or product in firebase_admin_sdk or google_cloud_firestore, from the Node.js reference to a change ready for review. Covers finding the Node source, mapping its shape to Dart idioms, wiring the transport and request handler, typed errors, barrel exports, dartdoc, the CHANGELOG and the checks CI runs. Use when asked to add, port or extend a public API, or to fix behaviour that should match Node.
---

# Implement an SDK feature

The SDK is a port of the Node.js Admin SDK and of `@google-cloud/firestore`. A feature is ported, not designed: read Node first, then write the Dart idiom for it.

The rules live in `.agents/knowledge/`. This skill gives the order to apply them in. Where a step links a concept, read it before writing code for that step.

## 1. Scope it

1. Run `./scripts/knowledge.sh for <each path you expect to edit or add>`, and read every concept it lists.
2. Find the Node reference and version with the [compare-with-Node playbook](../../knowledge/playbooks/compare-with-node.md), steps 1 to 3. Read the Node implementation, its public typings and its unit tests.
3. Stop and ask the user before going further if the feature:
   - is a product the README marks "Not supported" ([why](../../knowledge/scope/unsupported-services.md));
   - needs a new runtime dependency, hand-written HTTP or a retry layer ([why](../../knowledge/architecture/generated-rest-clients.md));
   - needs a realtime listener or another streaming RPC ([why](../../knowledge/firestore/rest-transport.md));
   - changes or removes an existing public name. That is a breaking change.

## 2. Design the Dart surface

Write down the public signatures before the implementation.

- **Names and behaviour** follow Node: method names, validation rules, error codes and messages. [Port policy](../../knowledge/architecture/node-port.md)
- **Shapes** follow Dart: sealed classes for unions, enums for string unions, named methods for overloads, named parameters for trailing optionals, `Future` and `Stream`. Use the table in [Dart idioms over Node's shapes](../../knowledge/architecture/dart-idioms-over-node-shapes.md); don't invent a mapping it already has.
- **Casing and JSON** keep Node's `URL` casing and `toJson()` keys. [Details](../../knowledge/conventions/acronym-casing.md)
- **Follow the neighbours.** Open the closest existing method in the same product and match how it takes options, validates and returns.

If Node's shape fits no idiom in the table and no concept covers it, ask before adding a new divergence.

## 3. Implement

### In `firebase_admin_sdk`

[Layout and barrels](../../knowledge/conventions/product-libraries-and-barrels.md)

1. **Transport:** add the call in the product's `*_http_client.dart`, through its `_run` helper and the generated `package:googleapis` client.
2. **Logic:** add validation and request and response mapping in `*_request_handler.dart`. Port every Node validation, in Node's order, so the same bad input gives the same error.
3. **Public method:** add it to the service class. In Auth, a method tenants also need goes on `_BaseAuth`.
4. **Types:** add new public types as parts of the product library, in a file named after Node's module in snake_case.
5. **Errors:** throw the product's exception with Node's code. Add a missing code to the product's enum and its server-to-client table. Never throw a bare `Exception`; use `rethrow`, not `throw e`. [Rules](../../knowledge/errors/admin-exceptions.md)
6. **Exports:** check the product's barrel in `lib/`. With `hide`, a new public name is exported unless you hide it, so hide internals. Never export transport or request-handler types.
7. **Environment:** read environment variables through the zone override, not `Platform.environment` directly. [How](../../knowledge/environment/zone-injected-environment.md)

A new product needs every item in the "A new admin product touches" list of the layout concept.

### In `google_cloud_firestore`

- The package never imports `firebase_admin_sdk`. [Why](../../knowledge/firestore/standalone-package.md)
- Add each new public type to the `show` list in `lib/google_cloud_firestore.dart`.
- Errors are `FirestoreException`, or `ArgumentError` and `StateError` for misuse. [Rules](../../knowledge/errors/firestore-exception.md)
- A Pipeline API also needs a golden case, a live E2E case and the parity tables updated. [Rules](../../knowledge/firestore/pipelines/node-parity.md)
- If `firebase_admin_sdk` uses the new API, raise its lower bound on `google_cloud_firestore`, and say in the PR that Firestore must be released first.

### In both

- Start every new `.dart` file with the header in `scripts/header_template.txt`.
- Write dartdoc on every new public name, in Dart terms (`Future`, `null`, `[name]`), with an example where the call isn't obvious. Write it from the behaviour you implemented, not by translating Node's JSDoc word for word.
- Don't edit generated files; AGENTS.md lists them.

## 4. Test

Follow the `write-and-sync-tests` skill: port Node's unit tests for the feature, then add an emulator test if an emulator supports it.

## 5. Record

- **CHANGELOG:** one entry under the package's top heading, written for users: what they can now do, or what was wrong and is now right. Start a breaking entry with `**Breaking:**`. [Headings](../../knowledge/release/releases-and-versioning.md)
- **README:** update the package README if it lists the feature or shows the changed API.
- **Example:** a new product gets an example in `example/lib/`.
- **Knowledge base:** if you added a deliberate difference from Node, or made a concept untrue, follow the `update-knowledge-base` skill.

## 6. Verify

Run every check in AGENTS.md › Verify your change that applies to the files you touched. Format only the files you changed.

## 7. Report

Tell the user:

- the Node file and version you ported from;
- each place where the Dart API differs from Node, and which idiom or concept covers it;
- which checks you ran, and which you didn't (emulator, prod);
- anything you left out and why.
