---
name: setup-environment
description: Checks or installs the tools this repo needs and smoke-tests them. Use on a fresh clone or a new machine, or when a command fails because a tool is missing.
---

# Set up the environment

1. Run `./scripts/doctor.sh`. If the user only asked to check, or you came here because a tool was missing mid-task, report its output and stop.
2. Show the user what you plan to install and which commands you'll run, and wait for a yes.
3. Install, one attempt per tool, prerequisites first (Node.js before the Firebase CLI). If an attempt fails, report it, skip what depends on it, and move on. Then run `dart pub get` from the repo root.
4. Rerun the doctor, run the [smoke test](#smoke-test), and report: what you installed, with versions; what you skipped; what the user still has to run.

## Install rules

- **System package managers are the user's.** For `sudo`, `apt-get`, a Homebrew cask, adding a package repository, or anything else that asks for a password, give the user the exact command instead of running it.
- **Prefer installs under the home directory** when Homebrew isn't available: the Dart SDK zip from https://dart.dev/get-dart into `~/.local/share`, `npm install -g --prefix ~/.local firebase-tools` (never `sudo npm`), the addlicense v1.2.0 release binary into `~/.local/bin`.
- **Keep the user's version managers.** Check where a tool comes from (`which -a dart`) before using the doctor's hint. If it comes from Flutter, FVM, asdf, SDKMAN, nvm, fnm or volta, fix the version there. Don't install a second copy.
- **PATH changes:** show the line and the startup file (`~/.zshrc`; for bash, `~/.bashrc` on Linux and `~/.bash_profile` on macOS), and ask before appending. Append it once. A tool that works only in your current session isn't set up.
- **Credentials:** none are needed; the emulator tests run without logging in. Skip gcloud unless the user wants the `wif` tests.

## Smoke test

```bash
cd packages/google_cloud_firestore
dart analyze --fatal-infos
dart test test/timestamp_test.dart
firebase emulators:exec --project dart-firebase-admin --only firestore \
  "dart test -P firebase-emulator --concurrency=1 test/set_options_test.dart"
```

The first emulator run downloads the emulator. Run full suites only if the user asks.
