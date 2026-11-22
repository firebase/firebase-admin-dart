#!/bin/bash

# Fast fail the script on failures.
set -e

# prod/wif tests are opt-in: set GOOGLE_APPLICATION_CREDENTIALS to include them.
# export GOOGLE_APPLICATION_CREDENTIALS=service-account-key.json
#
# To also run the refresh token credential integration tests, set:
# export FIREBASE_REFRESH_TOKEN_CREDENTIALS=~/.config/gcloud/application_default_credentials.json
# (run `gcloud auth application-default login` first if the file doesn't exist)

# Get the script's directory and the package directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PACKAGE_DIR="$SCRIPT_DIR/../packages/firebase_admin_sdk"

# Change to package directory
cd "$PACKAGE_DIR"

# Build test functions for Cloud Tasks emulator
cd test/fixtures/task_queue_functions
npm install
npm run build
cd ../../..

dart pub global activate coverage

# Use test_with_coverage which supports workspaces (dart test --coverage doesn't work with resolution: workspace)
firebase emulators:exec \
  --config test/firebase.json \
  --project dart-firebase-admin \
  --only auth,firestore,functions,tasks,storage \
  "dart run coverage:test_with_coverage -- --concurrency=1 -P ci"

# Prod tests are opt-in: set GOOGLE_APPLICATION_CREDENTIALS to include them.
# wif tests are handled separately by the test-wif CI job.
if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  dart test --concurrency=1 -P prod
fi

# test_with_coverage already generates lcov.info, just move it
mv coverage/lcov.info coverage.lcov
