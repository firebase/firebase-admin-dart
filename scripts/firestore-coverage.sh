#!/bin/bash

# Fast fail the script on failures.
set -e

# prod tests are opt-in: set GOOGLE_APPLICATION_CREDENTIALS to include them.
# export GOOGLE_APPLICATION_CREDENTIALS=service-account-key.json

# Get the script's directory and the package directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PACKAGE_DIR="$SCRIPT_DIR/../packages/google_cloud_firestore"

# Change to package directory
cd "$PACKAGE_DIR"

dart pub global activate coverage

# Run unit and emulator tests in a single pass inside the emulator.
# Unit tests ignore the emulator; this avoids needing to merge separate lcov files.
firebase emulators:exec \
  --project dart-firebase-admin \
  --only firestore \
  "dart run coverage:test_with_coverage -- --concurrency=1 -P ci"

# Prod tests are opt-in: set GOOGLE_APPLICATION_CREDENTIALS to include them.
if [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]; then
  dart test --concurrency=1 -P prod
fi

mv coverage/lcov.info coverage.lcov
