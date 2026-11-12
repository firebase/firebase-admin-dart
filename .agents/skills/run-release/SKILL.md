---
name: run-release
description: Prepares the release PR for google_cloud_firestore and firebase_admin_sdk, then gives the maintainer the publish and tag commands. Use only when explicitly asked to prepare, publish or tag a release, or to check release readiness.
---

# Run a release

Read [Releases, versioning, CHANGELOG and version.g.dart](../../knowledge/release/releases-and-versioning.md) and [the publish dry run](../../knowledge/release/publish-dry-run.md) first. They say what a release PR changes; this is the order and the checks.

**You never run `git push`, `git tag` or `dart pub publish` without `--dry-run`.** You prepare, check and hand the maintainer the exact commands. Stop at the first failed check and report it.

## 1. Readiness (read-only)

1. `git fetch origin`. Check CI on `main`, every workflow: `gh run list --branch main --limit 10`.
2. Find each package's last release: the top numbered heading of its CHANGELOG, and pub.dev (`curl -s https://pub.dev/api/packages/<package> | jq -r .latest.version`). Its commit: `git log -1 --format=%h -S'## <version>' -- packages/<package>/CHANGELOG.md`. Don't rely on tags; some releases have none.
3. List what merged since: `git log --oneline <that commit>..origin/main -- packages/<package>`. For each change users can see, check it has an entry under the package's top CHANGELOG heading.
4. Report which packages have unreleased changes, the missing entries, and the versions you propose: the next patch, or the next minor if an entry starts with `**Breaking:**`. Never 1.0.

If the user asked only about readiness, stop here.

## 2. Prepare the PR

Get the user's agreement on the packages and versions first. A package with no user-visible change is left out.

1. `git switch -c release/<versions> origin/main`. Stop if the tree isn't clean.
2. Add the missing CHANGELOG entries, in the style of the entries around them.
3. Make the edits the release concept lists, for the packages being released. Two things it doesn't say:
   - Whether to raise the admin package's lower bound on `google_cloud_firestore` can't be seen from local resolution. Search the admin `lib/` for the APIs the new Firestore entries add.
   - Don't add a new `-wip` or `Unreleased` heading.
4. Ask before including any other change.
5. Commit as `chore(release): prepare firestore v<A> and admin v<B>`, or naming the one package. The dry run warns about uncommitted files, so commit before validating.
6. Validate:
   - from the root, `./scripts/gen-version.sh && git diff --exit-code` must print nothing;
   - in each released package, `dart analyze --fatal-infos`, `dart test` and `dart pub publish --dry-run`;
   - both emulator suites, the license check and the knowledge-base check, as in AGENTS.md.

   Read the dry run's file list, not only its exit code: no key files, `.env` files, coverage output or `node_modules`.
7. If a check needed a fix, commit it on the branch and rerun step 6.
8. Hand over the branch, the commits and a PR description from the repo's template: the versions, each package's new CHANGELOG section, and whether the Firestore lower bound was raised. The user pushes and opens the PR.

## 3. Publish and tag

Only after the release PR has merged, and only when the user asks. On the merge commit, with a clean tree:

1. Rerun `dart pub publish --dry-run` in each released package.
2. Give the user the commands, in this order, for the packages being released:
   1. `dart pub publish` in `packages/google_cloud_firestore`.
   2. `dart pub publish` in `packages/firebase_admin_sdk`, once pub.dev serves the new Firestore version. Check with the `curl` command above, every 30 seconds for up to 10 minutes.
   3. One tag per package: `git tag -a <package>-v<version> -m "<package> v<version>" <merge commit>`, then the push.
3. Check that pub.dev serves both versions.

A published version can't be replaced. If something is wrong afterwards, prepare a new patch release.

## Report

The versions and what each contains, every check with its result, the checks you didn't run, and what is left for the user to do.
