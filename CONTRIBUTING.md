# Contributing to Firebase Admin SDK for Dart

Thank you for contributing to the Firebase community!

- [Have a usage question?](#have-a-usage-question)
- [Think you found a bug?](#think-you-found-a-bug)
- [Have a feature request?](#have-a-feature-request)
- [Want to submit a pull request?](#want-to-submit-a-pull-request)
- [Need to get set up locally?](#need-to-get-set-up-locally)

## Have a usage question?

We get lots of those and we love helping you, but GitHub is not the best place for them. Issues which just ask about usage will be closed. Here are some resources to get help:

- Go through the [Firebase Admin SDK setup guide](https://firebase.google.com/docs/admin/setup/)
- Read the full [API reference](https://pub.dev/documentation/firebase_admin_sdk/latest/)

If the official documentation doesn't help, try asking on [Stack Overflow](https://stackoverflow.com/questions/tagged/firebase+dart).

**Please avoid double posting across multiple channels!**

## Think you found a bug?

Search through [existing issues](https://github.com/firebase/firebase-admin-dart/issues) before opening a new one — your question may have already been answered.

If your issue appears to be a bug and hasn't been reported, [open a new issue](https://github.com/firebase/firebase-admin-dart/issues/new) using the bug report template and include a minimal repro.

If you are up to the challenge, [submit a pull request](#want-to-submit-a-pull-request) with a fix!

## Have a feature request?

Share your idea through our [feature request support channel](https://firebase.google.com/support/contact/bugs-features/).

## Want to submit a pull request?

Sweet, we'd love to accept your contribution! [Open a new pull request](https://github.com/firebase/firebase-admin-dart/pulls) and fill out the provided template.

**If you want to implement a new feature, please open an issue with a proposal first so that we can figure out if the feature makes sense and how it will work.**

### Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License Agreement (CLA). You (or your employer) retain the copyright to your contribution; the CLA gives us permission to use and redistribute your contributions as part of the project.

Visit <https://cla.developers.google.com/> to see your current agreements on file or to sign a new one. You generally only need to submit a CLA once, so if you have already submitted one you probably don't need to do it again.

### Code Reviews

All submissions, including submissions by project members, require review. We use GitHub pull requests for this purpose. Consult [GitHub Help](https://help.github.com/articles/about-pull-requests/) for more information on pull requests.

### Commit Messages

- Write clear, descriptive commit messages.
- Use imperative mood (e.g., "Add App Check token verification" not "Added App Check token verification").
- Reference issues with `#number` where applicable.

## Need to get set up locally?

### Prerequisites

- **Dart SDK** >= 3.9.0
- **Java 21+** (required for the Firestore emulator)
- **Node.js** (required for the Firebase Emulator and Cloud Tasks emulator)
- **Melos** — Dart monorepo tool (`dart pub global activate melos`)
- **Firebase CLI** (`npm install -g firebase-tools`)
- **Google Cloud SDK** ([`gcloud`](https://cloud.google.com/sdk/downloads)) — required to authorise integration tests against a real Firebase project

### Setup

1. Fork and clone the repository.

2. Install Melos and bootstrap the workspace from the repo root:

   ```bash
   dart pub global activate melos
   melos bootstrap
   ```

3. Verify your setup by running the analyzer and formatter:

   ```bash
   cd packages/firebase_admin_sdk
   dart format --set-exit-if-changed .
   dart analyze
   ```

### Repo Organization

This repository is a monorepo managed by [Melos](https://melos.invertase.dev/).

```
firebase_admin_sdk/             # Workspace root
├── packages/
│   ├── firebase_admin_sdk/     # Main Firebase Admin SDK package
│   │   ├── lib/
│   │   │   ├── firebase_admin_sdk.dart  # Public API barrel file
│   │   │   ├── auth.dart                 # Auth public exports
│   │   │   ├── firestore.dart            # Firestore public exports
│   │   │   ├── messaging.dart            # Messaging public exports
│   │   │   ├── storage.dart              # Storage public exports
│   │   │   ├── app_check.dart            # App Check public exports
│   │   │   ├── security_rules.dart       # Security Rules public exports
│   │   │   ├── functions.dart            # Functions public exports
│   │   │   └── src/                      # Private implementation
│   │   └── test/
│   │       ├── auth/                     # Auth unit & integration tests
│   │       ├── app/                      # App unit & integration tests
│   │       ├── firestore/                # Firestore tests
│   │       ├── messaging/                # Messaging tests
│   │       ├── storage/                  # Storage tests
│   │       └── helpers.dart             # Shared test utilities
│   └── google_cloud_firestore/  # Standalone Firestore package
└── scripts/
    ├── coverage.sh                       # Run tests with coverage
    └── firestore-coverage.sh             # Firestore package coverage
```

## Development Workflow

### Running Tests

Tests use tag-based presets defined in each package's `dart_test.yaml`:

| Preset | Tag | What runs |
|---|---|---|
| _(default)_ | — | Unit tests only, no emulator or credentials needed |
| `-P firebase-emulator` | `firebase-emulator` | Tests that require emulators |
| `-P prod` | `prod` | Tests against real Firebase APIs (opt-in) |
| `-P wif` | `wif` | Workload Identity Federation tests (opt-in) |
| `-P ci` | — | Unit + emulator tests; excludes `prod` and `wif` |

#### Unit tests

No setup needed:

```bash
# From packages/firebase_admin_sdk or packages/google_cloud_firestore
dart test
```

#### `firebase_admin_sdk` emulator tests

Requires the [Firebase CLI](https://firebase.google.com/docs/cli) and Java 21+.
The Firebase Cloud Tasks emulator also requires the functions fixture to be built first:

```bash
cd packages/firebase_admin_sdk/test/fixtures/task_queue_functions
npm install && npm run build
cd ../../../../..
```

Then run the emulators and tests together:

```bash
# From packages/firebase_admin_sdk
firebase emulators:exec --config test/firebase.json --project dart-firebase-admin \
  --only auth,firestore,functions,tasks,storage \
  "dart test -P firebase-emulator"

# Or use the convenience script from the repo root (also collects coverage)
../../scripts/coverage.sh
```

#### `google_cloud_firestore` emulator tests

Requires the [Firebase CLI](https://firebase.google.com/docs/cli) and Java 21+.
The `firebase.json` in the package root configures the Firestore emulator on port 8080.

```bash
# From packages/google_cloud_firestore
firebase emulators:exec --project dart-firebase-admin --only firestore \
  "dart test -P firebase-emulator"

# Or use the convenience script from the repo root (also collects coverage)
../../scripts/firestore-coverage.sh
```

#### Production tests (opt-in)

Requires a service account with access to the `dart-firebase-admin` Firebase project:

```bash
GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account.json dart test -P prod
```

#### Workload Identity Federation tests (opt-in)

Requires an `external_account` JSON credential (e.g. from `gcloud auth application-default login`
or `google-github-actions/auth` in CI). Only applies to `firebase_admin_sdk`:

```bash
GOOGLE_APPLICATION_CREDENTIALS=path/to/external-account.json dart test -P wif
```

### Code Formatting and Analysis

```bash
# Check formatting (CI will reject unformatted code)
dart format --set-exit-if-changed .

# Apply formatting
dart format .

# Run the analyzer (must pass with zero issues)
dart analyze
```

### License Headers

All source files must include a license header. The project uses [addlicense](https://github.com/google/addlicense) to manage this automatically.

**Install addlicense:**

Download the binary for your platform from the [v1.2.0 release](https://github.com/google/addlicense/releases/tag/v1.2.0) and place it on your `PATH`. For example, on macOS ARM64:

```bash
curl -sL https://github.com/google/addlicense/releases/download/v1.2.0/addlicense_v1.2.0_macOS_arm64.tar.gz | tar xz
sudo mv addlicense /usr/local/bin/
```

**Add headers to new files (run from repo root):**

```bash
addlicense -f header_template.txt \
  --ignore "**/*.yml" --ignore "**/*.yaml" --ignore "**/*.xml" \
  --ignore "**/*.g.dart" --ignore "**/*.sh" --ignore "**/*.html" \
  --ignore "**/*.js" --ignore "**/*.ts" --ignore "**/*.txt" \
  --ignore "**/.dart_tool/**" \
  --ignore "LICENSE" \
  .
```

**Check headers (dry run, same as CI):**

```bash
addlicense -f header_template.txt --check \
  --ignore "**/*.yml" --ignore "**/*.yaml" --ignore "**/*.xml" \
  --ignore "**/*.g.dart" --ignore "**/*.sh" --ignore "**/*.html" \
  --ignore "**/*.js" --ignore "**/*.ts" --ignore "**/*.txt" \
  --ignore "**/.dart_tool/**" \
  --ignore "LICENSE" \
  .
```

CI will fail if any source file is missing its license header.

### Local Validation

Run the full check suite locally before pushing:

```bash
dart format --set-exit-if-changed .
dart analyze
./scripts/coverage.sh
```

## Code Standards

### Style

The project uses strict analysis settings (`strict-casts`, `strict-inference`, `strict-raw-types`). Key conventions enforced by `analysis_options.yaml`:

- **Use single quotes** for strings (`prefer_single_quotes`).
- **Use `final` for local variables** where values are not reassigned.
- **Prefer relative imports** within the package.
- **Always declare return types** on functions and methods.

### Public API

- Each Firebase product has its own barrel file (e.g., `lib/auth.dart`, `lib/firestore.dart`). Only add exports there for types that users need directly.
- The top-level `lib/firebase_admin_sdk.dart` re-exports core types. Product-specific types belong in their respective barrel files.
- Classes under `lib/src/` are implementation details and should not be exported from barrel files unless they are part of the public API.

### Documentation

- Add dartdoc (`///`) comments to all new public APIs.
- Include code examples in doc comments where they help clarify usage.

### Error Handling

- Use typed exceptions (e.g., `FirebaseAuthException`, `FirebaseMessagingException`) with appropriate error codes for user-facing errors.
- Match the behaviour of the Node.js Admin SDK where applicable.

## Testing Requirements

- **All new features and bug fixes must include tests.**
- **Unit/emulator tests** go in the appropriate subdirectory under `test/`. Use the `helpers.dart` utilities and `mocktail` for mocking where needed.
- **Integration tests** (files named `*_integration_test.dart`) run against the Firebase Emulator in CI.
- **Production tests** (files named `*_prod_test.dart`) require real credentials and are not run in CI by default — gate them behind `RUN_PROD_TESTS`.
- Maintain overall coverage above the **40% threshold** enforced by CI.

## CI/CD

The project uses a single **build.yml** GitHub Actions workflow:

| Job | Trigger | What it does |
|-----|---------|--------------|
| `check-license-header` | PRs & schedule | Validates license headers on all source files |
| `lint` | PRs & schedule | Runs `dart format` and `dart analyze` |
| `test` | PRs & schedule | Runs tests against emulators with coverage reporting |
| `test-integration` | PRs (non-fork) & schedule | Runs production integration tests with Workload Identity Federation |
| `build` | After all above pass | Validates `dart pub publish --dry-run` |

Tests run against both `stable` and `beta` Dart SDK channels. Coverage is reported as a PR comment and uploaded to Codecov. The minimum threshold is **40%**.

## License

By contributing, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).
