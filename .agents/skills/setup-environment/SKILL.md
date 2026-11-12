---
name: setup-environment
description: Gets a machine ready to work on the Firebase Admin SDK for Dart. Checks and installs the Dart SDK, Java, Node.js, the Firebase CLI and addlicense, resolves the pub workspace, explains what the emulator and credential test tiers need, then proves the setup with the analyzer, a unit test and an emulator test. Use when asked to set up, install, fix or check the development environment, such as on a fresh clone or a new machine, or when a command fails because a tool is missing.
---

# Set up the environment

`scripts/doctor.sh` checks every tool and prints how to install what's missing. It changes nothing.

1. Run `./scripts/doctor.sh` from the repo root.
2. Install what it marks ✗, using the [recipes](#recipes), and rerun it until it passes.
3. Run the checks under [Prove it](#prove-it).
4. [Report](#report).

## Ground rules

- **Only when asked.** If a tool turns out to be missing while you're doing something else, run `./scripts/doctor.sh`, tell the user what's missing, and ask before installing anything.
- **Change the machine, not the repo.** Leave tracked files as they are.
- **Make PATH changes stick.** Add them to the startup file of the user's shell (`$SHELL`): `~/.zshrc` for zsh, `~/.bashrc` for bash. Add each line once: `grep -qxF "$line" "$rc" || echo "$line" >> "$rc"`. Then check from a new shell (`zsh -lic 'dart --version'`). A tool that only works in your current session isn't set up.
- **Keep the user's tool managers.** If Dart comes from Flutter, FVM or asdf, or Java from SDKMAN, fix the version there instead of installing a second copy.
- **Never type a password.** If `sudo` asks for one, or the machine blocks a package manager, stop and give the user the exact command.
- **Never set up credentials.** See [Credentials](#credentials).

## Recipes

### Dart

The minimum version is `environment.sdk` in the root `pubspec.yaml`.

- macOS: `brew install dart-lang/dart/dart`. Homebrew only trusts the tap when the formula is named in full.
- Debian or Ubuntu: the apt repository from https://dart.dev/get-dart.
- Linux without root: the SDK zip (needs `unzip`), then `export PATH="$HOME/.local/share/dart-sdk/bin:$PATH"` in the startup file:

  ```bash
  arch=$(uname -m | sed 's/x86_64/x64/; s/aarch64/arm64/')
  curl -fsSLo /tmp/dart.zip "https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-$arch-release.zip"
  mkdir -p ~/.local/share && unzip -qo /tmp/dart.zip -d ~/.local/share && rm /tmp/dart.zip
  ```

### The workspace

Run `dart pub get` from the repo root. It resolves every package. melos needs no global install: `dart run melos <command>` works from the root. [Why](../../knowledge/repo/workspace-and-melos.md)

### Java 21+ (Firestore emulator)

- macOS: `brew install --cask temurin@21`
- Debian 13+ and Ubuntu 22.04+: `apt-get install -y openjdk-21-jdk-headless`
- Older releases: Temurin, from https://adoptium.net/installation/linux/

### Node.js 20+ (Firebase CLI)

The Pipeline tools in `packages/google_cloud_firestore/tool/` need the version in their `package.json` `engines` field, which is higher.

- macOS: `brew install node`
- Linux: https://nodejs.org/en/download. Distribution packages are often too old.

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

## Emulators

Nothing to configure. `firebase emulators:exec` starts the emulators, sets the `*_EMULATOR_HOST` variables the SDK reads, and stops them afterwards. The emulator tests use the demo project `dart-firebase-admin` and need no login.

- The first run downloads the emulator binaries.
- The admin package's emulator suite needs its Cloud Tasks fixture built once: `npm install && npm run build` in `packages/firebase_admin_sdk/test/fixtures/task_queue_functions`.
- The full commands are in AGENTS.md › Verify your change. Always pass `--concurrency=1`.

## Credentials

Unit and emulator tests need none, so a working setup has none. Only the `prod` and `wif` test tiers use real credentials. [What each tier needs](../../knowledge/tests/tiers-and-tags.md)

- Don't run `firebase login`, `gcloud auth` or `gcloud iam`, and don't create or download service-account keys.
- If the user wants those tiers, tell them what the tier needs and let them supply it: a path in `GOOGLE_APPLICATION_CREDENTIALS`, set for that one command, to a key file kept outside the repo.
- Never print a credential or the content of a key file. To check that the variable is set: `[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && echo set`.
- A credential exported in the shell turns the coverage scripts into a prod run. Say so if you find one set.
- Skip gcloud unless the user wants the `wif` tier.

## Prove it

From a new shell, so the PATH changes are tested too:

```bash
./scripts/doctor.sh
cd packages/google_cloud_firestore
dart analyze --fatal-infos
dart test test/timestamp_test.dart
firebase emulators:exec --project dart-firebase-admin --only firestore \
  "dart test -P firebase-emulator --concurrency=1 test/set_options_test.dart"
```

Run the full suites only if the user asks for a full health check: `dart analyze --fatal-infos` and `dart test` in both packages, then the two emulator commands in AGENTS.md.

## Report

Tell the user:

- what you installed, with versions;
- which startup files you changed;
- what you skipped (gcloud, credentials);
- what they still have to do themselves, such as a command that needed their password.
