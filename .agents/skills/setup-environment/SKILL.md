---
name: setup-environment
description: Checks, sets up or repairs the tools this repo needs (Dart, Java, Node.js, Firebase CLI, addlicense) and proves the setup with a smoke test. Use on a fresh clone or a new machine, or when a command fails because a tool is missing.
---

# Set up the environment

1. Run `./scripts/doctor.sh`. It checks each tool, prints how to install what's missing, and changes nothing. If the user only asked to check, or you came here because a tool was missing mid-task, report its output and stop.
2. Show the user what you plan to install and which commands you'll run, and wait for a yes.
3. Install, one attempt per tool. If an attempt fails, report it and move on; don't loop.
4. Rerun the doctor, run the [smoke test](#smoke-test), and report: what you installed, with versions; what you skipped; what the user still has to run.

## Rules

- **System package managers are the user's.** For `sudo`, `apt-get` or adding a package repository, give the user the exact command instead of running it. Never type a password.
- **Prefer installs under the home directory** when Homebrew isn't available: the Dart SDK zip from https://dart.dev/get-dart into `~/.local/share`, `npm install -g --prefix ~/.local firebase-tools` (never `sudo npm`), the addlicense v1.2.0 release binary into `~/.local/bin`.
- **Keep the user's version managers.** If a tool comes from Flutter, FVM, asdf, SDKMAN, nvm, fnm or volta, fix the version there. Don't install a second copy.
- **PATH changes:** show the line and the startup file (`~/.zshrc`; for bash, `~/.bashrc` on Linux and `~/.bash_profile` on macOS), and ask before appending. Append it once. A tool that works only in your current session isn't set up.
- **Credentials:** none are needed. Don't run `firebase login` or `gcloud auth`. The emulator tests run without logging in. Skip gcloud unless the user wants the `wif` tests.
- **Leave tracked files alone.**

## Smoke test

```bash
cd packages/google_cloud_firestore
dart analyze --fatal-infos
dart test test/timestamp_test.dart
firebase emulators:exec --project dart-firebase-admin --only firestore \
  "dart test -P firebase-emulator --concurrency=1 test/set_options_test.dart"
```

The first emulator run downloads the emulator. Run full suites only if the user asks.
