---
name: run-release
description: Prepares and runs a release of google_cloud_firestore and firebase_admin_sdk. Runs the pre-flight checks, chooses the versions, finalizes the CHANGELOGs, regenerates version.g.dart, validates the packages with the publish dry run, drafts the release PR, and after it merges walks a maintainer through publishing to pub.dev and tagging. Use only when the user explicitly asks to prepare, cut, publish or tag a release, or to check whether the repository is ready for one.
---

# Run a release

Releases are made by hand, by maintainers with publish rights on pub.dev. There is no publish workflow. Read [Releases, versioning, CHANGELOG and version.g.dart](../../knowledge/release/releases-and-versioning.md) and [the publish dry run](../../knowledge/release/publish-dry-run.md) before you start.

## Ground rules

- **Only on an explicit request.** A request to release covers [phase 1](#phase-1-prepare-the-release-pr). Publishing and tagging can't be undone, so each needs its own confirmation, at the moment you reach it.
- **Never push, publish or tag on your own.** You prepare and check; the maintainer runs `git push`, `dart pub publish` and `git push --tags`, or tells you to run that exact command.
- **Never handle pub.dev credentials.** If `dart pub publish` asks to log in, stop and hand over to the user.
- **Stop on the first failed check.** Report it; don't work around it.

## Phase 1: prepare the release PR

### 1. Pre-flight

1. Work on a new branch from an up-to-date `main`, with a clean tree: `git fetch origin && git status --short`.
2. CI is green on `main`: `gh run list --branch main --limit 10`. Look at every workflow, not only `build`.
3. Find the last release of each package: the top numbered heading of its CHANGELOG, checked against pub.dev (`dart pub deps` won't show it; use `curl -s https://pub.dev/api/packages/<package> | jq -r .latest.version`). Tags named `<package>-v<version>` exist for most releases, but not all.
4. List what merged since: `git log --oneline <last release commit>..origin/main -- packages/<package>`.
5. Decide which packages to release. A package with no user-visible change since its last release is left out. Either package can be released alone.
6. Ask the user about any open PR or issue they want in the release before going on.

### 2. Check the CHANGELOGs

The CHANGELOGs are written by hand, one entry per PR. Nothing generates them. Your job is to check them, not to rewrite them.

- For each commit from step 1.4, decide whether users can see the change (`feat`, `fix`, a dependency range, a deprecation). Each one needs an entry under the package's top heading. `chore`, `ci`, `docs` and `test` commits usually need none.
- Add the entries that are missing, written for users, in the style of the entries around them. Show the user the entries you added.
- Check that breaking entries start with `**Breaking:**`, and that no entry was added under an already released heading.

### 3. Choose the versions

Both packages are on 0.x. Propose versions and get the user's agreement before editing:

- only fixes and additions: the next patch;
- a `**Breaking:**` entry: the next minor;
- never 1.0 without a GA decision.

For `firebase_admin_sdk`, the proposed version is normally its `-wip` version without the suffix. Bump it further if a breaking change landed after the `-wip` heading was created.

### 4. Edit

`google_cloud_firestore`, if released:

- `version:` in its `pubspec.yaml`;
- `## Unreleased` in its `CHANGELOG.md` becomes `## <version>`.

`firebase_admin_sdk`, if released:

- `version:` in its `pubspec.yaml`, without `-wip`;
- `## <version>-wip` in its `CHANGELOG.md` becomes `## <version>`;
- its range on `google_cloud_firestore`: raise the lower bound to the Firestore version being released if the admin package uses an API added since the last Firestore release (search the admin `lib/` for the Firestore APIs the new Firestore entries add). Local resolution won't tell you: inside the workspace, the range always resolves to the local package. Keep the upper bound valid for the new Firestore version;
- then run `./scripts/gen-version.sh` from the repo root. Never edit `version.g.dart` by hand.

Don't add a new `-wip` or `Unreleased` heading. The first change after the release adds it.

Change nothing else in a release PR. If a check below needs a code fix, that fix is a separate PR, merged first.

### 5. Validate the packages

From the repo root, then in each package being released:

```bash
dart pub get
./scripts/gen-version.sh && git diff --exit-code packages/firebase_admin_sdk/lib/src/version.g.dart
```

Commit the edits before the dry run, or pub warns about modified files. The `git diff` must be empty: the committed `version.g.dart` matches the pubspec.

```bash
# In packages/google_cloud_firestore, then packages/firebase_admin_sdk
dart analyze --fatal-infos
dart test
dart pub publish --dry-run
```

Then run both emulator suites and the license and knowledge-base checks from AGENTS.md › Verify your change.

Read the dry run's output, don't only check its exit code:

- **The file list is the package.** Look for anything that shouldn't ship: key files (`service-account*.json`), `.env` files, coverage output, `node_modules`. The admin package's `.pubignore` makes pub skip its `.gitignore`, so a git-ignored key file in that package is listed.
- **Warnings fail the release.** The publish-dry-run concept lists the usual ones and what the dry run doesn't catch, such as the description length.

Don't run `-P prod` or `-P wif` unless the user asks and supplies credentials.

### 6. Commit and hand over

- One commit, titled `chore(release): prepare firestore v<A> and admin v<B>`, or naming the one package released.
- Draft the PR description from the repository's template: the versions, and each package's new CHANGELOG section. Say whether the admin package's lower bound on Firestore was raised.
- Stop here. Give the user the branch, the commit and the PR description. They push and open the PR.

## Phase 2: publish and tag

Do this only after the release PR has merged, and only when the user asks.

1. Check out the merge commit on `main`, with a clean tree, and rerun `dart pub publish --dry-run` in each package being released.
2. **Publish `google_cloud_firestore` first.** Ask the user to confirm, naming the package and version. Then they run, or tell you to run, in `packages/google_cloud_firestore`:

   ```bash
   dart pub publish
   ```

3. Wait until pub.dev serves the new version (the `curl` command from pre-flight). The admin package can't be published before its Firestore lower bound exists on pub.dev.
4. **Publish `firebase_admin_sdk`** the same way, after a separate confirmation.
5. **Tag**, after confirmation. One annotated tag per released package, on the merge commit:

   ```bash
   git tag -a google_cloud_firestore-v<A> -m "google_cloud_firestore v<A>" <merge commit>
   git tag -a firebase_admin_sdk-v<B> -m "firebase_admin_sdk v<B>" <merge commit>
   ```

   The user pushes the tags. Don't create GitHub Releases: the repository has none.
6. **Verify.** Both versions are on pub.dev, and a scratch project outside the repo resolves them: `dart create -t console /tmp/release-check && cd /tmp/release-check && dart pub add firebase_admin_sdk:<B> google_cloud_firestore:<A>`.

A published version can't be replaced. If something is wrong after publishing, don't retract or republish: tell the user, and prepare a new patch release.

## Report

After each phase, tell the user:

- the versions, and what each package's release contains;
- every check you ran and its result, and the checks you didn't run;
- CHANGELOG entries you added, and anything in the dry run's file list you questioned;
- what is left for them to do: push, open the PR, publish, push tags.
