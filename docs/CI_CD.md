# CI/CD rules

## Branches

```
feature/*, fix/*, chore/*, docs/*  ──PR──▶  dev  ──PR──▶  main  ──▶ build + release
                                   hotfix/* ──PR──▶ main (emergency only, then merge main back into dev)
```

| Branch | Purpose | Direct push | Merges in from |
|---|---|---|---|
| `dev` | Default branch. Integration of all work. | No (PR only) | feature/fix/chore/docs branches |
| `main` | Released code only. Every merge = Android build. | No (PR only) | `dev`, `hotfix/*` |
| `feature/<milestone>-<topic>` etc. | One unit of work, TDD | Yes | — (branch from `dev`) |

Merge style: **squash** into `dev` (one Conventional Commit per PR; sync PRs from `main` use a merge commit), **merge commit** from `dev` into `main` (keeps history of what shipped).

## What runs when

| Event | Workflow | Runs | Builds? | Time |
|---|---|---|---|---|
| Push to a feature branch | — | nothing | no | 0 |
| PR → `dev` | `dev-checks` | format, analyze, engine tests, app tests | no | ~2–3 min |
| PR → `main` | `main-gate` | source-branch rule (`dev`/`hotfix/*` only), all checks, engine coverage ≥ 90 %, release preview notice | no | ~4 min |
| Push to `main` (merge) | `main-release` | tests → signed APKs (universal + per-ABI) + AAB → artifact (30 days) → release if new version → Play internal (if configured) | **yes** | ~10–15 min |
| Manual | `main-release` (`workflow_dispatch`) | same as push to main | yes | |
| Tag pushed by hand | — | nothing. Tags are created by CI only. | no | |

Web is **not** built in CI. Test web locally: `tool/web.sh` (hot reload, LAN) or `tool/web.sh release`.

## Versions and tags

- Single source of truth: `version:` in `pubspec.yaml`, e.g. `0.0.1-alpha+1`.
- The part before `+` is the release version. The `+N` build number is ignored: CI sets it to the
  workflow run number (always increasing → valid Android `versionCode`).
- Merge to `main` with a version that has **no tag yet** → CI creates tag `v<version>` and a GitHub
  Release with APKs, AAB and `SHA256SUMS.txt`. Versions containing `-` (e.g. `-alpha`, `-beta.2`)
  are marked pre-release.
- Merge to `main` with an **already released** version → artifacts only, no new release.
- To release: on `dev`, bump `pubspec.yaml` version and add a `## [x.y.z]` section to `CHANGELOG.md`
  (release notes are taken from it), then PR `dev` → `main`.
- Sequence: `0.0.1-alpha` → `0.0.2-alpha` … → `0.1.0-beta` (feature complete) → `1.0.0` (Play production).
  Semver note: pre-release is written `-alpha`, not `+alpha` (`+` is build metadata and is used by Flutter for the build number).

## After every release: sync main back into dev

`dev → main` uses a merge commit, so `main` gains a commit `dev` lacks, and `main` requires PR
branches to be up to date. A PR with head `main` can go stale (`dev` requires up-to-date too), so sync
through a branch cut from `dev`:

```bash
git fetch origin
git switch -c chore/sync-main origin/dev
git merge --no-edit origin/main
git push -u origin chore/sync-main
gh pr create --base dev --title "chore: sync main into dev after vX.Y.Z" --body "Post-release sync."
gh pr merge <n> --merge      # merge commit, NOT squash (keeps ancestry)
```

Done by Claude as part of every release.

## Required checks (branch protection)

- `dev`: PR required, `checks` must pass, branch up to date, no force-push/deletion.
- `main`: PR required, `source-branch` and `full-checks` must pass, no force-push/deletion.
- 0 approvals required (solo project); admins may bypass in an emergency.

## Secrets

| Secret | Used for | If missing |
|---|---|---|
| `WCALC_KEYSTORE_BASE64` | Android upload keystore (base64 of `.jks`) | debug-signed build + warning |
| `WCALC_KEYSTORE_PASSWORD`, `WCALC_KEY_ALIAS`, `WCALC_KEY_PASSWORD` | keystore access | — |
| `PLAY_SERVICE_ACCOUNT_JSON` | upload AAB to Play internal track (draft) | Play step skipped |

The upload keystore is kept outside the repo. Losing it is recoverable once Play App Signing is on
(Play can reset the upload key), but back it up anyway.

Play prerequisites (one-time, manual): developer account, create the app in Play Console, upload the
first AAB by hand, enable Play App Signing, create a service account with release permissions.

## Local commands

```bash
flutter pub get && (cd packages/wcalc_engine && dart pub get)
dart format lib test packages                      # format
flutter analyze && (cd packages/wcalc_engine && dart analyze --fatal-infos)
(cd packages/wcalc_engine && dart test)            # engine (fast, TDD loop)
flutter test                                       # widgets
tool/web.sh                                        # try it in a browser / on your phone
flutter build apk --release                        # local APK (debug-signed unless android/key.properties exists)
```
