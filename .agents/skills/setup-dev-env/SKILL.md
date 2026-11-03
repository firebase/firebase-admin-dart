---
name: setup-dev-env
description: Gets this machine ready to work on the Firebase Admin SDK for Dart. Installs or fixes the Dart SDK, Java 21, Node.js, the Firebase CLI and addlicense, fetches the workspace's dependencies, then proves the setup by running a unit test and a Firestore emulator test. Use when asked to set up, install or fix the development environment, such as on a fresh clone or a new machine.
---

# Set up a machine for this repo

`scripts/doctor.sh` checks every tool and prints how to install what's missing. It changes nothing.

1. Run `./scripts/doctor.sh` from the repo root.
2. Install what it marks ✗, using the recipes below, and rerun it until it passes.
3. Run the checks under [Prove it](#prove-it), then report.

## Ground rules

- **Change the machine, not the repo.** Leave tracked files as they are.
- **Only when asked.** If a tool turns out to be missing while you're doing something else, run `./scripts/doctor.sh`, tell the user what's missing and ask before installing anything.
- **Make PATH changes stick.** Add them to the startup file of the user's shell (`$SHELL`): `~/.zshrc` for zsh (the macOS default), `~/.bashrc` for bash. Add each line once, so a rerun doesn't stack copies: `grep -qxF "$line" "$rc" || echo "$line" >> "$rc"`. Then check from a new shell (`zsh -lic 'dart --version'` or `bash -lic 'dart --version'`). A tool that only works in your current session isn't set up.
- **Keep the user's tool managers.** If Dart comes from Flutter, FVM or asdf, or Java from SDKMAN, fix the version there instead of installing a second copy.
- **Never type a password.** Use `sudo` for system packages when you aren't root. If it asks for a password, or the machine blocks a package manager (managed machines often do), stop and give the user the exact command.
- **No credentials.** Don't run `firebase login` or `gcloud auth`, and don't create service accounts. Only the `-P prod` and `-P wif` tests need them; say they exist and leave them out.

## Recipes

### Dart 3.9+

- macOS: `brew install dart-lang/dart/dart`. Homebrew only trusts the tap when the formula is named in full like this.
- Debian or Ubuntu: the apt repository from https://dart.dev/get-dart.
- Linux x64 or arm64, without root: the SDK zip (needs `unzip`), then `export PATH="$HOME/.local/share/dart-sdk/bin:$PATH"` in the startup file:

  ```bash
  arch=$(uname -m | sed 's/x86_64/x64/; s/aarch64/arm64/')
  curl -fsSLo /tmp/dart.zip "https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-$arch-release.zip"
  mkdir -p ~/.local/share && unzip -qo /tmp/dart.zip -d ~/.local/share && rm /tmp/dart.zip
  ```

### The workspace

The root `pubspec.yaml` is a pub workspace, so one `dart pub get` from the repo root fetches every package's dependencies. melos isn't needed: only releases and the docs script use it.

### Java 21+ (Firestore emulator)

- macOS: `brew install --cask temurin@21`
- Debian 13+ and Ubuntu 22.04+: `apt-get install -y openjdk-21-jdk-headless`
- Debian 12 and older: Temurin, from https://adoptium.net/installation/linux/

### Node.js 20+ (Firebase CLI)

Node.js 22+ is needed only to regenerate the Pipeline golden fixtures.

- macOS: `brew install node`
- Linux: https://nodejs.org/en/download. Distribution packages are often older than 20.

### Firebase CLI

`npm install -g firebase-tools`. If npm's global folder isn't writable, don't use `sudo npm`: run `npm install -g --prefix ~/.local firebase-tools` and put `~/.local/bin` on PATH.

### addlicense (license headers, checked by CI)

- With Go: `go install github.com/google/addlicense@v1.2.0`, which installs it to `~/go/bin`.
- Without Go: the v1.2.0 release binary:

  ```bash
  os=$(uname -s | sed 's/Darwin/macOS/'); arch=$(uname -m | sed 's/aarch64/arm64/')
  mkdir -p ~/.local/bin
  curl -fsSL "https://github.com/google/addlicense/releases/download/v1.2.0/addlicense_v1.2.0_${os}_${arch}.tar.gz" | tar xz -C ~/.local/bin addlicense
  ```

  Then put `~/.local/bin` on PATH, if it isn't there already.

### gcloud

Skip it unless the user wants the `-P wif` tests.

## Prove it

From a new shell, so the PATH changes are tested too:

```bash
./scripts/doctor.sh
cd packages/google_cloud_firestore
dart analyze
dart test test/timestamp_test.dart
firebase emulators:exec --project dart-firebase-admin --only firestore \
  "dart test -P firebase-emulator test/set_options_test.dart"
```

The first emulator run downloads the Firestore emulator. CONTRIBUTING.md has the full test commands, `firebase_admin_sdk`'s emulator suite included.

## Report

Tell the user:

- what you installed, with versions;
- which startup files you changed;
- what you skipped (gcloud, credentials);
- what they still have to do themselves, such as a command that needed their password.
