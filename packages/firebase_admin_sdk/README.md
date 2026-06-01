## Table of Contents

 - [Overview](#overview)
 - [Supported Services](#supported-services)
 - [Installation](#installation)
 - [Add the Firebase Admin SDK to your server](#add-the-firebase-admin-sdk-to-your-server)
   - [Prerequisites](#prerequisites)
   - [Set up a Firebase project and service account](#set-up-a-firebase-project-and-service-account)
   - [Add the SDK](#add-the-sdk)
   - [Initialize the SDK](#initialize-the-sdk)
   - [Using an OAuth 2.0 refresh token](#using-an-oauth-20-refresh-token)
   - [Initialize the SDK in non-Google environments](#initialize-the-sdk-in-non-google-environments)
     - [Using Workload Identity Federation](#using-workload-identity-federation)
   - [Initialize multiple apps](#initialize-multiple-apps)
   - [Testing with gcloud end user credentials](#testing-with-gcloud-end-user-credentials)
 - [Usage](#usage)
   - [Authentication](#authentication)
   - [App Check](#app-check)
   - [Firestore](#firestore)
   - [Functions](#functions)
   - [Remote Config](#remote-config)
   - [Messaging](#messaging)
   - [Storage](#storage)
   - [Security Rules](#security-rules)
 - [Contributing](#contributing)
 - [License](#license)

## Overview

[Firebase](https://firebase.google.com) provides the tools and infrastructure
you need to develop your app, grow your user base, and earn money. The Firebase
Admin Dart SDK enables access to Firebase services from privileged environments
(such as servers or cloud) in Dart.

For more information, visit the
[Firebase Admin SDK setup guide](https://firebase.google.com/docs/admin/setup/).

## Supported Services

The Firebase Admin Dart SDK currently supports the following Firebase services:

- 🟢 - Fully supported
- 🟡 - Partially supported / Work in progress
- 🔴 - Not supported

| Service            | Status | Notes                                |
|--------------------|:------:|--------------------------------------|
| App                | 🟢     |                                      |
| App Check          | 🟢     |                                      |
| Authentication     | 🟢     |                                      |
| Data Connect       | 🔴     |                                      |
| Realtime Database  | 🔴     |                                      |
| Event Arc          | 🔴     |                                      |
| Extensions         | 🔴     |                                      |
| Firestore          | 🟢     | Via [package:google_cloud_firestore] |
| Functions          | 🟢     |                                      |
| Installations      | 🔴     |                                      |
| Machine Learning   | 🔴     |                                      |
| Messaging          | 🟢     |                                      |
| Project Management | 🔴     |                                      |
| Remote Config      | 🟢     |                                      |
| Security Rules     | 🟢     |                                      |
| Storage            | 🟢     | Via [package:google_cloud_storage]   |

## Installation

The Firebase Admin Dart SDK is available on [pub.dev](https://pub.dev/) as `firebase_admin_sdk`:

```bash
$ dart pub add firebase_admin_sdk
```

To use the SDK in your application, `import` it from any Dart file:

```dart
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
```

## Add the Firebase Admin SDK to your server

### Prerequisites

Make sure that you have a server app.

Make sure that your server runs **Dart SDK 3.9 or higher**.

### Set up a Firebase project and service account

To use the Firebase Admin SDK, you'll need the following:

- A Firebase project.
- A Firebase Admin SDK service account to communicate with Firebase. This service account is created automatically when you create a Firebase project or add Firebase to a Google Cloud project.
- A configuration file with your service account's credentials.

If you don't already have a Firebase project, you need to create one in the [Firebase console](https://console.firebase.google.com/). Visit [Understand Firebase Projects](https://firebase.google.com/docs/projects/learn-more) to learn more about Firebase projects.

### Add the SDK

If you are setting up a new project, you need to install the SDK for the language of your choice.

The Firebase Admin Dart SDK is available on [pub.dev](https://pub.dev/) as `firebase_admin_sdk`:

```bash
$ dart pub add firebase_admin_sdk
```

To use the module in your application, `import` it from any Dart file:

```dart
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
```

### Initialize the SDK

Once you have created a Firebase project, you can initialize the SDK with Google Application Default Credentials. Because default credentials lookup is fully automated in Google environments, with no need to supply environment variables or other configuration, this way of initializing the SDK is strongly recommended for applications running in Google environments such as Firebase App Hosting, Cloud Run, App Engine, and Cloud Functions for Firebase.

```dart
final app = FirebaseApp.initializeApp();
```

To optionally specify initialization options for services such as Realtime Database, Cloud Storage, or Cloud Functions, use the `FIREBASE_CONFIG` environment variable. If the content of the `FIREBASE_CONFIG` variable begins with a `{` it will be parsed as a JSON object. Otherwise the SDK assumes that the string is the path of a JSON file containing the options.

> [!NOTE]
> The `FIREBASE_CONFIG` environment variable is included automatically in App Hosting backends and Cloud Functions for Firebase functions.

```bash
export FIREBASE_CONFIG='{"projectId":"my-project"}'
```

```dart
// Options are read automatically from FIREBASE_CONFIG
final app = FirebaseApp.initializeApp();
```

### Using an OAuth 2.0 refresh token

The Admin SDK also supports authenticating with a Google OAuth 2.0 refresh token.
You can provide credentials either from a refresh token JSON file or directly
from individual parameters.

**From a refresh token JSON file** (e.g. `~/.config/gcloud/application_default_credentials.json`
generated by `gcloud auth application-default login`):

```dart
final app = FirebaseApp.initializeApp(
  options: AppOptions(
    credential: Credential.fromRefreshToken(
      File('/path/to/refresh_token.json'),
    ),
    projectId: '<FIREBASE_PROJECT_ID>',
  ),
);
```

The JSON file must contain non-empty string fields: `client_id`,
`client_secret`, `refresh_token`, and `type`.

**From individual parameters:**

```dart
final app = FirebaseApp.initializeApp(
  options: AppOptions(
    credential: Credential.fromRefreshTokenParams(
      clientId: '<client-id>',
      clientSecret: '<client-secret>',
      refreshToken: '<refresh-token>',
    ),
    projectId: '<FIREBASE_PROJECT_ID>',
  ),
);
```

> [!NOTE]
> OAuth 2.0 refresh tokens are not supported for connecting to Cloud Firestore.

### Initialize the SDK in non-Google environments

If you are working in a non-Google server environment in which default credentials lookup can't be fully automated, you can initialize the SDK with an exported service account key file.

> **Important:** Extremely high security awareness is required when working with service account keys, as they are vulnerable to certain types of threats. See [Best practices for managing service account keys](https://cloud.google.com/iam/docs/best-practices-for-managing-service-account-keys).

Firebase projects support Google service accounts, which you can use to call Firebase server APIs from your app server or trusted environment. If you're developing code locally or deploying your application on-premises, you can use credentials obtained via this service account to authorize server requests.

To generate a private key file for your service account:

1. In the Firebase console, open **Settings > Service Accounts**.
2. Click **Generate New Private Key**, then confirm by clicking **Generate Key**.
3. Securely store the JSON file containing the key.

When authorizing via a service account, you have two choices for providing the credentials to your application. You can either set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable, or you can explicitly pass the path to the service account key in code. The first option is more secure and is strongly recommended.

To set the environment variable:

Set the environment variable `GOOGLE_APPLICATION_CREDENTIALS` to the file path of the JSON file that contains your service account key. This variable only applies to your current shell session, so if you open a new session, set the variable again.

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/home/user/Downloads/service-account-file.json"
```

After you've completed the above steps, Application Default Credentials (ADC) is able to implicitly determine your credentials, allowing you to use service account credentials when testing or running in non-Google environments.

The `initializeApp` method allows for creating multiple named app instances and specifying a custom credential, project ID and other options:

```dart
final app = FirebaseApp.initializeApp(
  options: AppOptions(
    credential: Credential.fromServiceAccount(File("path/to/credential.json")),
    projectId: "custom-project-id",
  ),
  name: "CUSTOM_APP",
);
```

The following `Credential` constructors are available:

- `Credential.fromApplicationDefaultCredentials({String? serviceAccountId})` — Uses [Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials) (recommended for Google environments). Optionally accepts a `serviceAccountId` to override the service account email.
- `Credential.fromServiceAccount(File)` — Loads credentials from a service account JSON file downloaded from the Firebase Console.
- `Credential.fromServiceAccountParams({required String privateKey, required String email, required String projectId, String? clientId})` — Builds credentials from individual service account fields directly.

#### Using Workload Identity Federation

[Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation) lets external workloads (such as GitHub Actions, AWS, or Azure) authenticate as a Google service account without a long-lived key file.

Once your WIF credential configuration file is generated, point `GOOGLE_APPLICATION_CREDENTIALS` to it:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/wif-credential-config.json"
```

Then initialize the SDK with ADC, providing the impersonated service account email via `serviceAccountId`. This is required because WIF credential configs do not embed a `client_email` field, unlike service account key files:

```dart
final app = FirebaseApp.initializeApp(
  options: AppOptions(
    credential: Credential.fromApplicationDefaultCredentials(
      serviceAccountId: 'my-service-account@my-project.iam.gserviceaccount.com',
    ),
    projectId: 'my-project',
  ),
);
```

### Initialize multiple apps

In most cases, you only have to initialize a single default app:

```dart
// Initialize the default app
final defaultApp = FirebaseApp.initializeApp();

print(defaultApp.name); // '[DEFAULT]'

// Access services from the default app
final defaultAuth = defaultApp.auth();
final defaultFirestore = defaultApp.firestore();
```

Some use cases require you to create multiple apps at the same time. For example, you might want to read data from the Realtime Database of one Firebase project and mint custom tokens for another project. Or you might want to authenticate two apps with separate credentials. The Firebase SDK allows you create multiple apps at the same time, each with their own configuration information.

```dart
// Each AppOptions points to a different Firebase project
final defaultApp = FirebaseApp.initializeApp(
  options: AppOptions(
    credential: Credential.fromServiceAccount(File('path/to/default-service-account.json')),
    projectId: 'my-default-project',
  ),
);

// Initialize another app with a different config
final otherApp = FirebaseApp.initializeApp(
  options: AppOptions(
    credential: Credential.fromServiceAccount(File('path/to/other-service-account.json')),
    projectId: 'my-other-project',
  ),
  name: 'other',
);

print(defaultApp.name); // '[DEFAULT]'
print(otherApp.name);   // 'other'

// Access services from each app
final defaultAuth = defaultApp.auth();
final defaultFirestore = defaultApp.firestore();

final otherAuth = otherApp.auth();
final otherFirestore = otherApp.firestore();
```

> [!NOTE]
> Each app instance has its own configuration options and authentication state.

### Testing with gcloud end user credentials

When testing the Admin SDK locally with Google Application Default Credentials obtained by running `gcloud auth application-default login`, additional changes are needed to use Firebase Authentication due to the following:

- Firebase Authentication does not accept gcloud end user credentials generated using the gcloud OAuth client ID.
- Firebase Authentication requires the project ID to be provided on initialization for these type of end user credentials.

You can specify the project ID explicitly on app initialization or just use the `GOOGLE_CLOUD_PROJECT` environment variable. The latter avoids the need to make any additional changes to test your code.

To explicitly specify the project ID:

```dart
final app = FirebaseApp.initializeApp(
  options: AppOptions(
    credential: Credential.fromApplicationDefaultCredentials(),
    projectId: '<FIREBASE_PROJECT_ID>',
  ),
);
```

Alternatively, set the `GOOGLE_CLOUD_PROJECT` environment variable to avoid changing your code:

```bash
export GOOGLE_CLOUD_PROJECT="<FIREBASE_PROJECT_ID>"
```

## Usage

Once you have initialized an app instance with a credential, you can use any of the [supported services](#supported-services) to interact with Firebase.

### Authentication

```dart
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:firebase_admin_sdk/auth.dart';

final app = FirebaseApp.initializeApp();
final auth = app.auth();
```

#### getUser / getUserByEmail

```dart
// Get user by UID
final userById = await auth.getUser('<user-id>');
print(userById.displayName);

// Get user by email
final userByEmail = await auth.getUserByEmail('user@example.com');
print(userByEmail.displayName);
```

#### createUser

```dart
final user = await auth.createUser(
  CreateRequest(
    email: 'user@example.com',
    password: 'password123',
    displayName: 'John Doe',
  ),
);
print(user.uid);
```

#### updateUser

```dart
final updatedUser = await auth.updateUser(
  '<user-id>',
  UpdateRequest(
    displayName: 'Jane Doe',
    disabled: false,
  ),
);
print(updatedUser.displayName);
```

#### deleteUser / listUsers

```dart
// Delete a user
await auth.deleteUser('<user-id>');

// List users (max 1000 per page)
final result = await auth.listUsers(maxResults: 100);
final users = result.users;
final nextPageToken = result.pageToken;
```

#### verifyIdToken

```dart
// Verify an ID token from a client application (e.g. from request headers)
final idToken = req.headers['Authorization'].split(' ')[1];
final decodedToken = await auth.verifyIdToken(idToken, checkRevoked: true);
print(decodedToken.uid);

// Access custom claims
if (decodedToken.claims['isAdmin'] == true) {
  print('User is an admin');
}
```

#### createCustomToken

```dart
final customToken = await auth.createCustomToken(
  '<user-id>',
  developerClaims: {'role': 'admin'},
);
```

#### setCustomUserClaims

```dart
await auth.setCustomUserClaims('<user-id>', customUserClaims: {'role': 'admin'});
```

### App Check

```dart
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';

final app = FirebaseApp.initializeApp();
```

#### verifyToken

```dart
final response = await app.appCheck().verifyToken('<app-check-token>');
print('App ID: ${response.appId}');
```

#### createToken

```dart
final result = await app.appCheck().createToken('<app-id>');
print('Token: ${result.token}');
```

### Firestore

> [!NOTE]
> The core firestore API is provided by [package:google_cloud_firestore].

```dart
import 'dart:async';
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:google_cloud_firestore/google_cloud_firestore.dart';

final app = FirebaseApp.initializeApp();
final firestore = app.firestore();
```

#### set / update / delete

```dart
final ref = firestore.collection('users').doc('<user-id>');

// Set a document (creates or overwrites)
await ref.set({'name': 'John Doe', 'age': 27});

// Update specific fields
await ref.update({'age': 28});

// Delete a document
await ref.delete();
```

#### get / query

```dart
// Get a single document
final snapshot = await firestore.collection('users').doc('<user-id>').get();
print(snapshot.data());

// Query a collection
final querySnapshot = await firestore
    .collection('users')
    .where('age', WhereFilter.greaterThan, 18)
    .orderBy('age', descending: true)
    .get();
print(querySnapshot.docs);
```

#### getAll

```dart
// Fetch multiple documents at once
final snapshots = await firestore.getAll([
  firestore.collection('users').doc('user-1'),
  firestore.collection('users').doc('user-2'),
]);
for (final snap in snapshots) {
  print(snap.data());
}
```

#### batch

```dart
final batch = firestore.batch();
batch.set(firestore.collection('users').doc('user-1'), {'name': 'Alice'});
batch.update(firestore.collection('users').doc('user-2'), {FieldPath(const ['age']): 30});
batch.delete(firestore.collection('users').doc('user-3'));
await batch.commit();
```

#### bulkWriter

```dart
final bulkWriter = firestore.bulkWriter();
for (var i = 0; i < 10; i++) {
  unawaited(
    bulkWriter.set(
      firestore.collection('items').doc('item-$i'),
      {'index': i},
    ),
  );
}
await bulkWriter.close();
```

#### runTransaction

```dart
final balance = await firestore.runTransaction((tsx) async {
  final ref = firestore.collection('users').doc('<user-id>');
  final snapshot = await tsx.get(ref);
  final currentBalance = snapshot.exists ? snapshot.data()?['balance'] ?? 0 : 0;
  final newBalance = currentBalance + 10;
  tsx.update(ref, {'balance': newBalance});
  return newBalance;
});
```

### Functions

```dart
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:firebase_admin_sdk/functions.dart';

final app = FirebaseApp.initializeApp();
final queue = app.functions().taskQueue('<task-name>');
```

#### enqueue

```dart
await queue.enqueue({'userId': 'user-123', 'action': 'sendWelcomeEmail'});
```

#### enqueue with TaskOptions

```dart
// Delay delivery by 1 hour
await queue.enqueue(
  {'action': 'cleanupTempFiles'},
  TaskOptions(schedule: DelayDelivery(3600)),
);

// Schedule at a specific time
await queue.enqueue(
  {'action': 'sendReport'},
  TaskOptions(schedule: AbsoluteDelivery(DateTime.now().add(Duration(hours: 1)))),
);

// Use a custom ID for deduplication
await queue.enqueue(
  {'orderId': 'order-456', 'action': 'processPayment'},
  TaskOptions(id: 'payment-order-456'),
);
```

#### enqueue with TaskOptionsExperimental

```dart
// Route the task to a custom URI (beta feature)
await queue.enqueue(
  {'action': 'customHandler'},
  TaskOptions(
    experimental: TaskOptionsExperimental(
      uri: 'https://my-service.example.com/task-handler',
    ),
  ),
);
```

#### delete

```dart
await queue.delete('payment-order-456');
```

### Remote Config

```dart
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:firebase_admin_sdk/remote_config.dart';

final app = FirebaseApp.initializeApp();
final remoteConfig = app.remoteConfig();
```

#### getTemplate / publishTemplate

```dart
// Read the active template, edit one parameter, and publish.
final template = await remoteConfig.getTemplate();
final updated = RemoteConfigTemplate(
  etag: template.etag,
  conditions: template.conditions,
  parameters: {
    ...template.parameters,
    'welcome_message': RemoteConfigParameter(
      defaultValue: const ExplicitParameterValue(value: 'Hello'),
      description: 'Updated greeting',
    ),
  },
  parameterGroups: template.parameterGroups,
  version: template.version,
);
final published = await remoteConfig.publishTemplate(updated);
print('Published version: ${published.version?.versionNumber}');
```

#### validateTemplate

```dart
// Server-side validation without publishing.
final validated = await remoteConfig.validateTemplate(template);
print('Template OK; etag: ${validated.etag}');
```

#### listVersions / rollback

```dart
final versions = await remoteConfig.listVersions(
  ListVersionsOptions(pageSize: 10),
);
for (final v in versions.versions) {
  print('v${v.versionNumber}: ${v.description}');
}

// Roll back to a previous version.
await remoteConfig.rollback('5');
```

#### Server-side evaluation

Use [`getServerTemplate`](https://firebase.google.com/docs/remote-config/server-side-config) to fetch a template that the SDK can evaluate locally — useful for runtime feature flags, A/B test bucketing, and server-rendered configuration.

```dart
final template = await remoteConfig.getServerTemplate(
  defaultConfig: {'enable_new_ui': false, 'max_items': 50},
);

// Evaluate against an EvaluationContext: randomizationId is used by percent
// conditions, custom signals are used by string/numeric/semver conditions.
final config = template.evaluate(
  EvaluationContext(
    randomizationId: '<user-id>',
    customSignals: {'app_version': '2.3.1', 'country': 'US'},
  ),
);

if (config.getBoolean('enable_new_ui')) {
  // ...
}
print('max items: ${config.getInt('max_items')}');
```

### Messaging

```dart
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:firebase_admin_sdk/messaging.dart';

final app = FirebaseApp.initializeApp();
final messaging = app.messaging();
```

#### send

```dart
// Send to a specific device
await messaging.send(
  TokenMessage(
    token: '<device-token>',
    notification: Notification(title: 'Hello', body: 'World!'),
    data: {'key': 'value'},
  ),
);

// Send to a topic
await messaging.send(
  TopicMessage(
    topic: '<topic-name>',
    notification: Notification(title: 'Hello', body: 'World!'),
  ),
);

// Send to a condition
await messaging.send(
  ConditionMessage(
    condition: "'stock-GOOG' in topics || 'industry-tech' in topics",
    notification: Notification(title: 'Hello', body: 'World!'),
  ),
);
```

#### sendEach

```dart
// Send up to 500 messages in a single call
final response = await messaging.sendEach([
  TopicMessage(topic: 'topic-1', notification: Notification(title: 'Message 1')),
  TopicMessage(topic: 'topic-2', notification: Notification(title: 'Message 2')),
]);
print('Sent: ${response.successCount}, Failed: ${response.failureCount}');
```

#### sendEachForMulticast

```dart
// Send one message to multiple device tokens
final response = await messaging.sendEachForMulticast(
  MulticastMessage(
    tokens: ['<token-1>', '<token-2>', '<token-3>'],
    notification: Notification(title: 'Hello', body: 'World!'),
  ),
);
print('Sent: ${response.successCount}, Failed: ${response.failureCount}');
```

#### subscribeToTopic / unsubscribeFromTopic

```dart
// Subscribe tokens to a topic
await messaging.subscribeToTopic(['<token-1>', '<token-2>'], 'news');

// Unsubscribe tokens from a topic
await messaging.unsubscribeFromTopic(['<token-1>', '<token-2>'], 'news');
```

### Storage

> [!NOTE]
> The core storage API is provided by [package:google_cloud_storage].

```dart
import 'dart:typed_data';
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';
import 'package:google_cloud_storage/google_cloud_storage.dart' as gcs;

final app = FirebaseApp.initializeApp();
final storage = app.storage();
final bucket = storage.bucket('<bucket-name>');
```

#### insertObject (upload)

```dart
await bucket.storage.uploadObject(
  bucket.name,
  'path/to/file.txt',
  Uint8List.fromList('Hello, world!'.codeUnits),
  metadata: gcs.ObjectMetadata(contentType: 'text/plain'),
);
```

#### downloadObject

```dart
final bytes = await bucket.storage.downloadObject(bucket.name, 'path/to/file.txt');
print(String.fromCharCodes(bytes));
```

#### objectMetadata

```dart
final metadata = await bucket.storage.objectMetadata(bucket.name, 'path/to/file.txt');
print('Size: ${metadata.size} bytes');
print('Content type: ${metadata.contentType}');
```

#### deleteObject

```dart
await bucket.storage.deleteObject(bucket.name, 'path/to/file.txt');
```

#### getDownloadURL

Returns a long-lived public download URL backed by a Firebase download token, suitable for sharing with end-users.

```dart
final url = await storage.getDownloadURL(bucket, 'path/to/file.txt');
print('Download URL: $url');
```

### Security Rules

```dart
import 'package:firebase_admin_sdk/firebase_admin_sdk.dart';

final app = FirebaseApp.initializeApp();
final securityRules = app.securityRules();
```

#### getFirestoreRuleset

```dart
final ruleset = await securityRules.getFirestoreRuleset();
print(ruleset.name);
```

#### releaseFirestoreRulesetFromSource

```dart
final source = '''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
''';

final ruleset = await securityRules.releaseFirestoreRulesetFromSource(source);
print('Applied ruleset: ${ruleset.name}');
```

#### getStorageRuleset

```dart
final ruleset = await securityRules.getStorageRuleset();
print(ruleset.name);
```

#### releaseStorageRulesetFromSource

```dart
final source = '''
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
''';

final ruleset = await securityRules.releaseStorageRulesetFromSource(source);
print('Applied ruleset: ${ruleset.name}');
```

#### createRuleset / deleteRuleset

```dart
// Create a ruleset without applying it
const source = "rules_version = '2'; service cloud.firestore { match /databases/{database}/documents { match /{document=**} { allow read, write: if false; } } }";
final rulesFile = RulesFile(name: 'firestore.rules', content: source);
final ruleset = await securityRules.createRuleset(rulesFile);
print('Created ruleset: ${ruleset.name}');

// Delete a ruleset by name
await securityRules.deleteRuleset(ruleset.name);
```


## Contributing

Contributions are welcome! Please read the
[contributing guide](https://github.com/firebase/firebase-admin-dart/blob/main/CONTRIBUTING.md)
to get started.

## License

[Apache License Version 2.0](LICENSE)

[package:google_cloud_firestore]: https://pub.dev/packages/google_cloud_firestore
[package:google_cloud_storage]: https://pub.dev/packages/google_cloud_storage

## Package history

### The package source

The code in this package evolved from [package:dart_firebase_admin](https://pub.dev/packages/dart_firebase_admin)
by [Invertase](https://invertase.io/).

### The package name 

❤️👍🙏 A big thank you to [Muhammad Usman](https://github.com/OttomanDeveloper) for
letting us take over the `firebase_admin_sdk` name for this package! 🙏👍❤️

Historical versions &mdash; [v0.0.6](https://pub.dev/packages/firebase_admin_sdk/versions/0.0.6)
and earlier &mdash; were his work.
