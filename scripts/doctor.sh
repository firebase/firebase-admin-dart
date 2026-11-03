#!/bin/bash

# Checks this machine has the tools working on the SDK needs, and says how to
# install what's missing. It changes nothing. Exits 1 if a required tool is
# missing or too old.
#
# Usage (from anywhere): ./scripts/doctor.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

case "$(uname -s)" in
  Darwin) platform=macos ;;
  Linux)
    platform=linux
    if grep -qsE '^ID(_LIKE)?=.*(debian|ubuntu)' /etc/os-release; then
      platform=debian
    fi
    ;;
  *) platform=other ;;
esac

problems=0

ok() { echo "✓ $1"; }
note() { echo "- $1"; }
fail() {
  echo "✗ $1"
  echo "    $2"
  problems=$((problems + 1))
}

# how <macOS> <Debian or Ubuntu> <elsewhere>: the install hint for this machine.
how() {
  case $platform in
    macos) echo "$1" ;;
    debian) echo "$2" ;;
    *) echo "$3" ;;
  esac
}

# at_least <version> <minimum>: whether version >= minimum, comparing the
# numeric start of each dot-separated part ("3.10.0-1.0.dev" >= "3.9.0").
at_least() {
  local IFS=.
  local -a have=($1) want=($2)
  local i h w
  for i in 0 1 2; do
    h=${have[i]:-0}
    h=${h%%[!0-9]*}
    h=${h:-0}
    w=${want[i]:-0}
    if ((10#$h > w)); then return 0; fi
    if ((10#$h < w)); then return 1; fi
  done
  return 0
}

# Dart: the workspace's pubspec.yaml requires ^3.9.0.
if command -v dart >/dev/null; then
  version=$(dart --version 2>&1 | sed -nE 's/^Dart SDK version: ([^ ]+).*/\1/p')
  if [ -z "$version" ]; then
    fail "Dart: $(command -v dart) doesn't report a version" \
      "run dart --version to see why; if a version manager (FVM, asdf) provides it, fix it there"
  elif at_least "$version" 3.9.0; then
    ok "Dart $version"
  else
    fail "Dart $version: the packages need 3.9.0 or later" \
      "$(how 'brew upgrade dart-lang/dart/dart' 'install a newer SDK: https://dart.dev/get-dart' 'install a newer SDK: https://dart.dev/get-dart')"
  fi
else
  fail "Dart: not found" \
    "$(how 'brew install dart-lang/dart/dart' 'https://dart.dev/get-dart (apt, or the SDK zip)' 'https://dart.dev/get-dart')"
fi

# The root pubspec.yaml is a pub workspace: one `dart pub get` covers every
# package.
if [ -f "$PROJECT_ROOT/.dart_tool/package_config.json" ]; then
  ok "Workspace dependencies"
else
  fail "Workspace: dependencies not fetched" "dart pub get, from the repo root"
fi

# Java: the Firestore emulator needs 21+. macOS has a /usr/bin/java stub that
# fails when no JDK is installed.
if command -v java >/dev/null && java -version >/dev/null 2>&1; then
  version=$(java -version 2>&1 | sed -nE 's/.*version "([^"]+)".*/\1/p' | head -n 1)
  if at_least "$version" 21; then
    ok "Java $version"
  else
    fail "Java $version: the Firestore emulator needs 21 or later" \
      "$(how 'brew install --cask temurin@21' 'apt-get install openjdk-21-jdk-headless (Debian 13+, Ubuntu 22.04+); older releases: https://adoptium.net/installation/linux/' 'https://adoptium.net/temurin/releases/?version=21')"
  fi
else
  fail "Java: not found (the Firestore emulator needs 21+)" \
    "$(how 'brew install --cask temurin@21' 'apt-get install openjdk-21-jdk-headless (Debian 13+, Ubuntu 22.04+); older releases: https://adoptium.net/installation/linux/' 'https://adoptium.net/temurin/releases/?version=21')"
fi

# Node.js: the Firebase CLI needs 20+; regenerating the Pipeline golden
# fixtures needs 22+.
if command -v node >/dev/null; then
  version=$(node --version)
  version=${version#v}
  if at_least "$version" 22; then
    ok "Node.js $version"
  elif at_least "$version" 20; then
    ok "Node.js $version (regenerating the Pipeline golden fixtures needs 22+)"
  else
    fail "Node.js $version: the Firebase CLI needs 20 or later" \
      "$(how 'brew install node' 'https://nodejs.org/en/download' 'https://nodejs.org/en/download')"
  fi
else
  fail "Node.js: not found" \
    "$(how 'brew install node' 'https://nodejs.org/en/download' 'https://nodejs.org/en/download')"
fi

if version=$(firebase --version 2>/dev/null) && [ -n "$version" ]; then
  ok "Firebase CLI $version"
elif command -v firebase >/dev/null; then
  fail "Firebase CLI: $(command -v firebase) doesn't run" \
    "run firebase --version to see why; it needs Node.js 20+"
else
  fail "Firebase CLI: not found (runs the emulators)" "npm install -g firebase-tools"
fi

# CI rejects source files without the license header.
if command -v addlicense >/dev/null; then
  ok "addlicense"
else
  fail "addlicense: not found (adds and checks license headers)" \
    "go install github.com/google/addlicense@v1.2.0, or a v1.2.0 binary from https://github.com/google/addlicense/releases/tag/v1.2.0"
fi

if command -v melos >/dev/null; then
  ok "melos"
else
  note "melos: not found. Only releases and the docs script need it: dart pub global activate melos"
fi

if command -v gcloud >/dev/null; then
  ok "gcloud"
else
  note "gcloud: not found. Only the -P wif tests need it: https://cloud.google.com/sdk/docs/install"
fi

echo
if ((problems > 0)); then
  echo "$problems problem(s). Fix them, then rerun ./scripts/doctor.sh."
  exit 1
fi
echo "Ready. CONTRIBUTING.md says how to run the unit and emulator tests."
