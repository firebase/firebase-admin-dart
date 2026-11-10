---
type: Decision
title: Dart idioms win where Node's shape does not fit
description: Where a Node API shape does not fit Dart, the Dart idiom is used and the difference is written down; this concept holds the one table of those mappings.
tags: [architecture, node-parity, api-design, conventions]
agents_md: always
governs:
  - packages/*/lib/**
sources:
  - id: parity-options-rule
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: A Node options object
    title: The parity test's mapping rules, options objects first
  - id: parity-no-overloads
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: since Dart has no overloads
    title: The parity test on overloads
  - id: parity-string-union
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: A Node string union maps onto
    title: The parity test's string-union rule, and its plain-string exceptions
  - id: parity-type-tags
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: sealed classes and `is`
    title: The parity test on dropped type tags
  - id: parity-renames
    resource: ../../../packages/google_cloud_firestore/test/pipeline_api_parity_test.dart
    symbol: const _renames
    title: The parity test's `_renames`, `_classes` and `_enums` tables
  - id: auth-factor-type
    resource: ../../../packages/firebase_admin_sdk/lib/src/auth/auth_config_tenant.dart
    symbol: typedef AuthFactorType = String;
    title: "`AuthFactorType`, a plain-string exception"
  - id: raw-options
    resource: ../../../packages/google_cloud_firestore/lib/src/pipeline.dart
    symbol: Map<String, Object?> rawOptions = const {},
    title: The Pipeline `rawOptions` escape hatch
---

# Where it lives

- Enforced by: `pipeline_api_parity_test.dart`, for Firestore Pipelines only. Its header states the mapping rules for options objects, string unions and rest parameters,[^parity-options-rule][^parity-string-union] its tables record overloads and dropped type tags,[^parity-no-overloads][^parity-type-tags] and `_renames`, `_classes` and `_enums` record every renamed member and type.[^parity-renames] Outside Pipelines: nothing; review only.

# Decision

Node's source is the reference (see [Port of the Node.js Admin SDK](/architecture/node-port.md)), but where its shape doesn't fit Dart, the Dart idiom wins and the difference is written down. A literal transliteration, with untyped maps and Node names, is the alternative this rejects.

| Node shape | Dart idiom | Notes |
| --- | --- | --- |
| Object union, or a primitive-or-object union such as `string \| CriticalSound` | A sealed class, matched with `is` and patterns | No `type` or `expressionType` tags. |
| `T \| T[]` parameter | `List<T>` | |
| String-literal union | An enum that maps to the wire string | Exceptions take plain strings: `AuthFactorType`, for a reason nobody recorded,[^auth-factor-type] and the Pipeline `Time*` types, listed in the parity test. |
| Overloads | Separately named methods, such as `where` and `whereFilter`, or `startAt` and `startAtDocument` | Some older APIs take an `Object` path, such as `where(Object path, …)`. Don't spread it. |
| Rest parameter | A trailing `List` or `Iterable` | |
| Trailing optional positionals | Named parameters | Some required Node positionals became named too. |
| Options object | Pipelines: named parameters. Admin services: Node's options class, one to one. | Elsewhere, follow the service. |
| Untyped option map | Typed options or named parameters | The Pipeline `rawOptions` is a deliberate escape hatch beside typed options.[^raw-options] |
| Member with a Dart core-library equivalent (`toJSON`, `isEqual`, `toLower`, `deleteApp`) | The Dart name (`toJson`, `==`, `toLowerCase`, `close`) | |
| Promise, `AsyncIterable` | `Future`, `Stream` | Docs use Dart terms: `Future`, `null`, `[name]`. A stray "undefined" in a dartdoc is a leftover. Node's `Readable` APIs are a gap; see [Firestore runs over REST, with buffered streaming](/firestore/rest-transport.md). |
| JS Web SDK synonyms, such as `equalValue` | Not added | Only the Node Admin SDK is the reference. |
| (an API Node lacks) | A Dart-only convenience beside the Node API, not instead of it | |

# Why

The maintainers' stated reasons:

- The parity test states the Pipeline rules: an options object maps onto named parameters, a string union onto an enum's values, a rest parameter onto a trailing `Iterable`, overloads onto separate methods "since Dart has no overloads", and type tags give way to "sealed classes and `is`".
- Pipeline execution options became typed because a wrong key failed silently. `rawOptions` was added on purpose alongside them.
- `toLowerCase()` and `toUpperCase()` deliberately keep Dart's `String` names.
- Doc comments were cleaned up to use Dart terms instead of Node's.

The likely reasons (not recorded): `jsonEncode` calls `toJson()`, Dart's equality protocol is `operator ==` with `hashCode`, and `Stream` is Dart's `AsyncIterable`. Why the admin services keep Node's options classes, and why Dart-only conveniences sit beside the Node API, isn't recorded.

Outside the parity test, the general rule isn't stated anywhere; it is inferred from these cases.

# Rules for agents

- **Must:** model a new object union, or a union of a primitive and an object, as a sealed class. **Must not:** add `type` or `expressionType` string tags.
- **Must:** map a string-literal union onto an enum that maps to the wire string. **Ask first:** before converting an existing raw-string API to an enum. It's a breaking change.
- **Must:** port a Node overload as separately named methods, not as one `Object` parameter with runtime type checks. **Must not:** spread the older `Object`-path pattern to new APIs.
- **Must:** map Pipeline options objects onto named parameters. Elsewhere, follow the shape the surrounding service already uses. **Ask first:** before converting an existing options class to named parameters. It's a breaking change.
- **Must not:** add untyped `Map` option bags where Node has an options object. A deliberate escape hatch alongside typed options, such as the Pipeline `rawOptions`, is not this.
- **Must:** use the Dart core-library name where one exists, and record a Pipeline rename in the parity test: `_renames` for a member, `_classes` or `_enums` for a type.
- **Must:** map Promise to `Future` and `AsyncIterable` to `Stream`, and write docs in Dart terms.
- **Must not:** copy names from the JS Web SDK. Only the Node Admin SDK is the reference.
- **Should:** add a Dart-only convenience alongside the Node-equivalent API, not instead of it.
- **Must not:** add a divergence to a Firestore Pipeline API without an entry and a reason in the parity tables.
- **Ask first:** outside Pipelines there is no table. Record the difference in the dartdoc and the CHANGELOG, and ask before adding a divergence that no idiom or divergence concept already covers.

# Related

- [Port of the Node.js Admin SDK](/architecture/node-port.md)
- [Pipelines parity with Node is checked by machine](/firestore/pipelines/node-parity.md)
- [Credential is a sealed class with factories](/app/credential-sealed-hierarchy.md)
- [Firestore runs over REST, with buffered streaming](/firestore/rest-transport.md)
- [No field-value-pairs form of update()](/firestore/update-field-value-pairs.md)
- [URL casing; JSON keys stay Node's](/conventions/acronym-casing.md)
- [Public authenticated app client and transport options](/app/app-client-and-transport-options.md)

[^parity-options-rule]: The parity test's mapping rules
[^parity-string-union]: The parity test's string-union rule
[^parity-no-overloads]: The parity test on overloads
[^parity-type-tags]: The parity test on type tags
[^parity-renames]: The `_renames` table
[^auth-factor-type]: `AuthFactorType`
[^raw-options]: The Pipeline `rawOptions`
