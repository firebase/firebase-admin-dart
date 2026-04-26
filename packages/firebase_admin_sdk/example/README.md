This package demonstrates how to use the `firebase_admin_sdk` to interact with Firebase services.

## Running the Example

We provide cross-platform Dart scripts to run the example in different modes.

### 1. Running with Emulators (Recommended for testing)

To run the example against the Firebase Emulator Suite:

1.  Ensure you have the Firebase CLI installed (`npm install -g firebase-tools`).
2.  Run the emulator script from this directory:

```bash
dart run bin/run_with_emulator.dart
```

This script will:
-   Install dependencies for the test functions used by the example.
-   Start the necessary Firebase emulators (Auth, Firestore, Functions, Tasks, Storage).
-   Run the example code in `bin/example.dart`.

### 2. Running against Production

To run the example against a real Firebase project:

1.  Download your service account key from the Firebase Console (Project Settings > Service Accounts).
2.  Save it as `service-account-key.json` in this directory.
3.  Run the production script:

```bash
dart run bin/run_with_prod.dart
```

This script will set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable and run the example code.

## Examples Included

The `bin/example.dart` file orchestrates several examples:
-   **Auth**: Creating and fetching users.
-   **Firestore**: Basic CRUD operations.
-   **Functions**: Enqueuing tasks to Cloud Tasks.
-   **Storage**: Uploading and deleting files, generating download URLs.

Some examples require a real project and credentials and are commented out by default:
-   **App Check**
-   **Messaging**
-   **Security Rules**
-   **Remote Config**

You can uncomment them in `bin/example.dart` to try them out if you have a properly configured project.
