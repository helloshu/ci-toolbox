# ci-toolbox

Build pipelines for three patched Android/iOS targets. Nothing is vendored: each
pipeline fetches its pinned source commit, applies the patch set in
`targets/<id>/patches/`, builds on GitHub Actions, and uploads artifacts.

| target | platforms | runner(s) | trigger | wall time |
|---|---|---|---|---|
| `a` | Android · Linux (deb/AppImage/tar) · Windows (msi) · macOS (dmg) | ubuntu/windows/macos matrix | tag `a-*`, manual | 18–35 min per row |
| `b` | Android | ubuntu-latest | tag `b-*`, manual | ~12 min |
| `c` | iOS (unsigned) | macos-15 | tag `c-*`, manual | ~15 min |

`a` runs a platform matrix; pick a subset at dispatch time with
`platforms=android,linux,windows,macos` (`android,linux,windows` skips the 10x macOS
row entirely). Only the arm64 dmg is produced — no Intel build. `linux` selects
both `linux-deb` and `linux-packages`; the latter builds the release tarball, the
AppImage + zsync and, best effort, the flatpak.

### Billing on GitHub Free

| runner | multiplier | `a` per full run |
|---|---|---|
| ubuntu (android, linux, source) | 1× | ~50 min |
| windows (msi) | 2× | ~44 min |
| macos-15 (dmg, arm64) | 10× | ~200 min |

Private repository: ~292 billed minutes per run (~6 runs of the 2 000 monthly
minutes). The layout is therefore **public orchestration
repository + private patch repository**:

```
ci-toolbox (public)              patch-sets (private)
  .github/workflows/*.yml   -->    a/*.patch
  scripts/                         b/*.patch
  targets/<t>/{source.env,notes}   c/*.patch
```

- builds run here, where standard runners are free — including windows and macOS;
- `scripts/fetch-patches.sh` pulls `<t>/*.patch` from the private repo with a
  fine-grained token (`vars.PATCHES_REPO`, `secrets.PATCHES_TOKEN`);
- releases go to the private repo (`vars.RELEASE_REPO`, `secrets.RELEASE_TOKEN`),
  so no artifact lands in the public repository;
- `targets/<t>/patches/` here only contains a README — an empty patch directory
  makes `prepare-upstream.sh` exit 3 instead of building pristine upstream.

## Periodic upstream watch

`watch.yml` runs **Monday and Thursday at 03:17 UTC** (Mon/Thu 11:17 Beijing time,
~3.5 day average) — native cron, no day-of-year arithmetic. A build is dispatched
only when something actually moved:

1. `git ls-remote` every pinned `REPO` and compare with `SHA` in `source.env`;
2. when a commit moved, fetch it and `git apply --check` the whole patch set;
3. applies → commit the new pin, then dispatch `build-<t>.yml`;
4. does not apply → leave the pin alone and open/append an issue titled
   `watch: patch set needs rework`.

`workflow_dispatch` with `force` rebuilds everything without waiting for a new
commit.

## Layout

```
scripts/prepare-upstream.sh <target-dir> <dest> [--check]   # pinned clone + patches
scripts/sign-apk.sh <in.apk> <out.apk> [keystore]           # zipalign + apksigner
scripts/make-keystore.sh <out.jks> [alias]                  # throwaway signing cert
scripts/make-source-tarball.sh <src-dir> <out.tar.gz>       # corresponding source

targets/kg/  source.env · patches/ · scripts/ · notes.md
targets/cmima/  source.env · patches/ · no-lint.gradle · notes.md
targets/cmi/  source.env · patches/ · scripts/ · xcode-version.txt · notes.md
```

Each `source.env` pins `REPO` + `SHA` + `NAME`; the patches were generated against
exactly that commit, so they apply cleanly (verified by the `check` workflow).

## Usage

```bash
./scripts/prepare-upstream.sh targets/cmima /tmp/src-b --check   # validate only
./scripts/prepare-upstream.sh targets/cmima /tmp/src-b           # fetch + patch
```

## Secrets / variables

| name | purpose | default when absent |
|---|---|---|
| `SIGN_KG_B64` / `SIGN_KG_PASS` / `SIGN_KG_KEY_PASS` | signing for target a | throwaway cert generated per run |
| `SIGN_CMA_B64` / `SIGN_CMA_PASS` / `SIGN_CMA_KEY_PASS` | signing for target b | throwaway cert generated per run |
| `CLOUD_SECRETS_SH` | real provider credentials for target c | placeholder values (compiles, provider login does not work) |
| `PATCHES_REPO` (variable) | `owner/patch-sets` private repository | uses the (empty) in-repo dir → build fails fast |
| `PATCHES_TOKEN` (secret) | fine-grained PAT, `contents: read` on that repo | same |
| `RELEASE_REPO` (variable) / `RELEASE_TOKEN` | publish releases to a private repo | release in this repo |
| `BUILD_CMI` (variable) | set `false` to skip the macOS job | runs |

Manual runs publish a Release only when `publish_release` is checked; otherwise
artifacts stay 14–30 days.

## Licensing

Targets b and c build GPLv3 upstreams: every release attaches the corresponding
patched source (`*-source.tar.gz`). Target a's upstream is All Rights Reserved /
personal use only — that artifact is for the owner's own devices.

See [NOTICE.md](NOTICE.md).
