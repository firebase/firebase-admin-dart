---
name: run-release
description: Prepares the release PR for google_cloud_firestore and firebase_admin_sdk, then gives the maintainer the publish and tag commands. Use only when explicitly asked to prepare, publish or tag a release, or to check release readiness.
---

# Run a release

Read `.agents/knowledge/release/releases-and-versioning.md` first. It says what a release PR changes; this is the order and the checks. A release PR is the one place that removes `-wip` and adds a numbered heading. Its edits are prescribed, so this skill replaces AGENTS.md's `knowledge.sh for` step for the release files.

**You never run `git push`, `git tag` or `dart pub publish` without `--dry-run`.** You prepare, check and hand the maintainer the exact commands. When a check fails, stop and report it. Fix only a mistake in the release edits themselves; anything else is a separate PR.

## 1. Readiness (read-only)

1. Find the remote whose URL is `firebase/firebase-admin-dart` (`git remote -v`); it is `<remote>` below, and may not be `origin`. `git fetch <remote>`. If `git rev-parse --is-shallow-repository` prints `true`, run `git fetch --unshallow <remote>` first: the lookups below need history.
2. Check that the latest run on `main` of each workflow in `.github/workflows/` passed: `gh run list -R firebase/firebase-admin-dart --branch main --workflow <file>.yml --limit 1`. If `gh` is missing or not signed in, report CI as not checked and go on. Never run `gh auth login`.
3. Find each package's last release: the top CHANGELOG heading that is a plain version, without `-wip`, and pub.dev (`curl -s https://pub.dev/api/packages/<package>`, field `latest.version`). Its commit: `git log -1 --format=%h -G'^## <version>$' -- packages/<package>/CHANGELOG.md`. Don't rely on tags; some releases have none. If the CHANGELOG is ahead of pub.dev, a release is waiting to be published: go to "Publish and tag".
4. List what merged since: `git log --oneline <that commit>..<remote>/main -- packages/<package>`. For each change users can see, check it has an entry under the package's top CHANGELOG heading.
5. Report which packages have unreleased changes, the missing entries, and the versions you propose: the next patch, or the next minor if an entry starts with `**Breaking:**`. Never 1.0. For a breaking release, ask the user whether `firebase_functions`, which depends on these packages, is affected.

If the user asked only about readiness, stop here.

## 2. Prepare the PR

Get the user's agreement on the packages and versions first. A package with no user-visible change is left out.

1. Stop if `git status --short` prints anything. Then `git switch --no-track -c release/<versions> <remote>/main`.
2. Add the missing CHANGELOG entries, in the style of the entries around them.
3. Edit, for each released package:
   - `google_cloud_firestore`: `version:` in its pubspec, and `## Unreleased` becomes `## <version>`.
   - `firebase_admin_sdk`: `version:` in its pubspec without `-wip`, and `## <version>-wip` becomes `## <version>`. Then run `./scripts/gen-version.sh` from the root.
   - The admin package's range on `google_cloud_firestore`: local resolution hides a lower bound that is too low, so search the admin `lib/` for the APIs the new Firestore entries add. The upper bound must admit the new Firestore version.
   - A new Firestore minor: set `google_cloud_firestore: ^<version>` in `packages/firebase_admin_sdk/example/pubspec.yaml`, or the workspace stops resolving. A new admin minor: do the same for `firebase_admin_sdk` there and in `example_server_app/pubspec.yaml`.
   - Don't add a new `-wip` or `Unreleased` heading.
4. Run `dart pub get` from the root. It must resolve.
5. Ask before including any other change.
6. Commit as `chore(release): prepare firestore v<A> and admin v<B>`, or naming the one package. The dry run warns about uncommitted files, so commit before validating.
7. Validate:
   - from the root, run `./scripts/gen-version.sh` again; `git diff --exit-code` must exit 0;
   - in each released package, `dart analyze --fatal-infos`, `dart test` and `dart pub publish --dry-run`;
   - the emulator suite of each released package, the license check and the knowledge-base check, as in AGENTS.md. If `firebase` or Java is missing, report the emulator suite as not run.

   Read the dry run's file list, not only its exit code: no key files, `.env` files, coverage output or `node_modules`. The task-queue fixture's compiled JS and the `package-lock.json` files are expected. If it fails or lists a file you don't expect, read "Constraint" in `.agents/knowledge/release/publish-dry-run.md`.

   The emulator suite's fixture build must leave `git status` clean. Restore any lockfile or compiled-JS change it makes.
8. Hand over the branch, the commits and a PR description from the repo's template: the versions, each package's new CHANGELOG section with the entries you wrote marked, and whether the Firestore lower bound was raised. The user pushes and opens the PR.

## 3. Publish and tag

Only after the release PR has merged, and only when the user asks. Fetch, then `git switch --detach` to the merge commit (`git log -1 --format=%H -G'^## <version>$' <remote>/main -- packages/<package>/CHANGELOG.md`), with a clean tree:

1. Rerun `dart pub publish --dry-run` in each released package.
2. Give the user the commands, in this order, for the packages being released:
   1. `dart pub publish` in `packages/google_cloud_firestore`.
   2. `dart pub publish` in `packages/firebase_admin_sdk`, only once pub.dev serves the new Firestore version: the dry run doesn't check that. After the user says Firestore is published, check with the `curl` command from "Readiness", every 30 seconds for up to 10 minutes.
   3. One tag per package: `git tag -a <package>-v<version> -m "<package> v<version>" <merge commit>`, then `git push <remote> <tag>`.
3. Check that pub.dev serves each released version.

A published version can't be replaced. If something is wrong afterwards, prepare a new patch release.

## Report

The versions and what each contains, every check with its result, the checks you didn't run, and what is left for the user to do.
