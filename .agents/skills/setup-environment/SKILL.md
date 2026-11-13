---
name: setup-environment
description: Checks or installs the tools this repo needs and smoke-tests them. Use on a fresh clone or a new machine, or when a command fails because a tool is missing.
---

# Set up the environment

1. Run `./scripts/doctor.sh` from the repo root. It prints, for each missing tool, a command that installs it on this machine. If the user only asked to check, or you came here because a tool was missing mid-task, report its output and stop.
2. A request to set up or fix the machine is the go-ahead: say what you will install, then install it. One attempt per tool, prerequisites first (`unzip` before Dart, Node.js before the Firebase CLI). If an attempt fails, report it, skip what depends on it, and move on.
3. Put new tool directories on PATH: export them in your current shell, and append the same line once to the shell's startup file (`~/.zshrc`; for bash, `~/.bashrc` on Linux and `~/.bash_profile` on macOS). A tool that works only in your current session isn't set up.
4. Run `dart pub get` from the repo root, rerun the doctor, and run the [smoke test](#smoke-test).
5. Report what you installed, with versions, the startup file you changed, what you skipped, and what the user still has to run.

## Install rules

- **Never type a password.** If you are root, or `sudo -n true` succeeds, run system package managers yourself (`apt-get update` first, and `-y`). Otherwise give the user the exact command; that covers `sudo`, Homebrew casks and installing Homebrew itself.
- **Prefer installs under the home directory** when there is no package manager you can run: the doctor's hints for Dart and addlicense install under `~/.local`. If npm's global folder isn't writable, use `npm install -g --prefix ~/.local firebase-tools`, never `sudo npm`.
- **Keep the user's version managers.** Check where a tool comes from (`which -a dart`) before using the doctor's hint. If it comes from Flutter, FVM, asdf, SDKMAN, nvm, fnm or volta, fix the version there. Don't install a second copy.
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
