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

# Recipes that need no package manager, for the hints below.
arch=$(uname -m)
case $arch in x86_64) dart_arch=x64 ;; aarch64 | arm64) dart_arch=arm64 ;; *) dart_arch= ;; esac
dart_zip="https://dart.dev/get-dart"
if [ "$platform" != macos ] && [ "$platform" != other ] && [ -n "$dart_arch" ]; then
  dart_zip="with unzip installed: curl -fsSLo /tmp/dart.zip https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-$dart_arch-release.zip && mkdir -p ~/.local/share && unzip -qo /tmp/dart.zip -d ~/.local/share; then put ~/.local/share/dart-sdk/bin on PATH"
fi
java_apt='apt-get update && apt-get install -y --no-install-recommends openjdk-21-jdk-headless (Debian 13+, Ubuntu 22.04+); older releases: https://adoptium.net/installation/linux/'
addlicense_os=$(uname -s | sed 's/Darwin/macOS/')
addlicense_arch=${arch/aarch64/arm64}

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
    macos) echo "${1:-}" ;;
    debian) echo "${2:-}" ;;
    *) echo "${3:-}" ;;
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
    w=${w%%[!0-9]*}
    w=${w:-0}
    if ((10#$h > 10#$w)); then return 0; fi
    if ((10#$h < 10#$w)); then return 1; fi
  done
  return 0
}

# Dart: the minimum is `environment.sdk` in the root pubspec.yaml.
# Read from a caret (^3.9.0) or range ('>=3.9.0 <4.0.0') constraint.
dart_min=$(sed -nE "s/^[[:space:]]*sdk:[[:space:]]*[\"']?(\^|>=)?[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\2/p" "$PROJECT_ROOT/pubspec.yaml" | head -n 1)
if command -v dart >/dev/null; then
  version=$(dart --version 2>&1 | sed -nE 's/^Dart SDK version: ([^ ]+).*/\1/p')
  if [ -z "$version" ]; then
    fail "Dart: $(command -v dart) doesn't report a version" \
      "run dart --version to see why; if a version manager (FVM, asdf) provides it, fix it there"
  elif [ -z "$dart_min" ]; then
    fail "Dart $version: can't read the minimum version from pubspec.yaml" \
      "check environment.sdk in the root pubspec.yaml, then update this script"
  elif [ "${version%%-*}" = "$dart_min" ] && [ "$version" != "$dart_min" ]; then
    # Pub sorts a pre-release below its release, so ^3.9.0 excludes 3.9.0-1.0.dev.
    fail "Dart $version: a pre-release of $dart_min, which the packages exclude" \
      "$(how 'brew upgrade dart-lang/dart/dart' "$dart_zip" "$dart_zip")"
  elif at_least "$version" "$dart_min"; then
    ok "Dart $version"
  else
    fail "Dart $version: the packages need $dart_min or later" \
      "$(how 'brew upgrade dart-lang/dart/dart' "$dart_zip" "$dart_zip")"
  fi
else
  fail "Dart: not found" \
    "$(how 'brew install dart-lang/dart/dart' "$dart_zip" "$dart_zip")"
fi

# The root pubspec.yaml is a pub workspace: one `dart pub get` covers every
# package.
if [ ! -f "$PROJECT_ROOT/.dart_tool/package_config.json" ]; then
  fail "Workspace: dependencies not fetched" "dart pub get, from the repo root"
elif ! command -v dart >/dev/null; then
  note "Workspace: can't check the dependencies without Dart"
else
  # A dry run writes nothing; --offline keeps it to the local cache.
  resolution=$(cd "$PROJECT_ROOT" && dart pub get --dry-run --offline 2>&1)
  case $resolution in
    *'No dependencies would change'*) ok "Workspace dependencies" ;;
    *) fail "Workspace: dependencies out of date" "dart pub get, from the repo root" ;;
  esac
fi

# Java: the Firestore emulator needs 21+. macOS has a /usr/bin/java stub that
# fails when no JDK is installed.
if command -v java >/dev/null && java -version >/dev/null 2>&1; then
  version=$(java -version 2>&1 | sed -nE 's/.*version "([^"]+)".*/\1/p' | head -n 1)
  if at_least "$version" 21; then
    ok "Java $version"
  else
    fail "Java $version: the Firestore emulator needs 21 or later" \
      "$(how 'brew install --cask temurin@21' "$java_apt" 'https://adoptium.net/temurin/releases/?version=21')"
  fi
else
  fail "Java: not found (the Firestore emulator needs 21+)" \
    "$(how 'brew install --cask temurin@21' "$java_apt" 'https://adoptium.net/temurin/releases/?version=21')"
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
    "mkdir -p ~/.local/bin && curl -fsSL https://github.com/google/addlicense/releases/download/v1.2.0/addlicense_v1.2.0_${addlicense_os}_${addlicense_arch}.tar.gz | tar xz -C ~/.local/bin addlicense, then put ~/.local/bin on PATH"
fi

if command -v melos >/dev/null; then
  ok "melos"
else
  note "melos: no global install. Optional: 'dart run melos <command>' works from the repo root"
fi

if command -v gcloud >/dev/null; then
  ok "gcloud"
else
  note "gcloud: not found. Only the -P wif tests need it: https://cloud.google.com/sdk/docs/install"
fi

if [ "$platform" = macos ] && ((problems > 0)) && ! command -v brew >/dev/null; then
  note "Homebrew: not found, and the hints above use it. Installing it needs your password: https://brew.sh"
fi

echo
if ((problems > 0)); then
  echo "$problems problem(s). Fix them, then rerun ./scripts/doctor.sh."
  exit 1
fi
echo "Ready. AGENTS.md says how to run the unit and emulator tests."
