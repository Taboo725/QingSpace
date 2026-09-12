# Releasing

Releases are built by `.github/workflows/release.yml` when a `v*` tag is pushed.
The workflow builds an Android APK and a Windows zip, then publishes both as a
GitHub Release. The in-app updater reads that release, so the process below is
what keeps updates working.

## One-time setup: the Android signing key

**This must be done before the first release.** Android refuses to install an
update whose signing certificate differs from the installed app's. CI has no
persistent debug keystore — it generates a fresh one on every run — so an
unsigned release would produce a *different* signature each time and every user
would have to uninstall before updating. The release workflow therefore fails
fast if the signing secrets are missing.

### 1. Generate a keystore

Run this locally. Keep the resulting file and passwords safe: **lose them and
you can never ship an update to existing installs again.**

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias qingspace
```

`keytool` ships with the JDK that Flutter already requires. It will prompt for a
store password, a key password, and some identity fields.

### 2. Store it as repository secrets

```bash
base64 -w0 upload-keystore.jks > keystore.b64     # macOS: base64 -i upload-keystore.jks -o keystore.b64
```

Add four secrets under **Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | contents of `keystore.b64` |
| `ANDROID_KEYSTORE_PASSWORD` | the store password |
| `ANDROID_KEY_ALIAS` | `qingspace` |
| `ANDROID_KEY_PASSWORD` | the key password |

Then delete `keystore.b64` and move `upload-keystore.jks` somewhere backed up
and outside the repository. `.gitignore` already excludes `*.jks`, `*.keystore`
and `android/key.properties` so they cannot be committed by accident.

### 3. Optional: build signed releases locally

Create `android/key.properties` (git-ignored):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=qingspace
keyPassword=...
```

`android/app/build.gradle.kts` picks it up automatically and falls back to the
debug key when it is absent. Note that `storeFile` is resolved relative to
`android/app/`, so a keystore sitting in `android/` needs a `../` prefix — the
release workflow writes `storeFile=../upload-keystore.jks` for exactly that
reason.

## Cutting a release

1. **Update the version** in `pubspec.yaml`. It is the single source of truth —
   `AppInfo` reads it at runtime through `package_info_plus`.

   ```yaml
   version: 1.2.0+6      # bump the build number too; Android requires it to increase
   ```

2. **Add a changelog entry** in two places:
   - `CHANGELOG.md` — becomes the GitHub Release body.
   - `lib/core/config/version.dart` — shown in Settings → About, works offline.

3. **Verify locally.**

   ```bash
   flutter analyze && flutter test
   ```

4. **Commit, tag and push.** The tag must match `pubspec.yaml`'s version or the
   workflow stops before building.

   ```bash
   git commit -am "release: v1.2.0"
   git tag v1.2.0
   git push && git push --tags
   ```

5. **Watch the run.** On success the release appears at
   `https://github.com/Taboo725/QingSpace/releases` with two assets:

   - `QingSpace-<version>-android.apk`
   - `QingSpace-<version>-windows-x64.zip`

A tag containing `-` (such as `v1.2.0-beta.1`) is published as a pre-release.
`releases/latest` skips pre-releases, so the in-app updater will not offer them.

## How the in-app updater consumes a release

`lib/core/services/update_service.dart` queries
`api.github.com/repos/Taboo725/QingSpace/releases/latest`, unauthenticated, at
most once a day.

- It parses `tag_name` as a semantic version and compares it numerically against
  the running build.
- On Android it picks the `.apk` whose name contains the device's ABI
  (`arm64-v8a` or `armeabi-v7a`, read from `dart:ffi`'s `Abi.current()`),
  downloads it to the cache directory, and opens it with the system package
  installer. The user still has to allow "install unknown apps" and confirm.
- On Windows and other desktops it opens the release page in a browser; replacing
  a running executable in place is not something the app attempts.

Consequences for asset naming:

- **Every APK must carry its ABI in the filename.** If none matches the device,
  the updater refuses to guess and falls back to opening the release page — it
  will not install a 64-bit build on a 32-bit phone.
- A release that ships a *single* APK with no ABI in the name is still accepted
  as a universal build, which is how pre-1.1.1 releases keep working.
- Keep the `v` prefix on tags consistent (the parser accepts both, but mixing
  them makes the release list harder to read).

## Download size

Two things keep the build small; both are easy to undo by accident.

- **`--split-per-abi`.** The native libraries are ~20 MB *per architecture*. A
  universal APK carries all three and was 55% native code. Do not drop the flag.
- **Font subsetting.** `tool/subset_fonts.py` cuts each Source Han Serif CN
  weight from ~10.7 MB to ~2.1 MB. The subset fonts are what is committed; the
  full originals are not in the repo. To re-subset (after adding a weight, or
  changing the character set) put the upstream OTFs in `build/fonts_full/` and
  re-run the script — see its docstring for where to download them.

For reference, 1.1.1 measured 30.1 MB (arm64 APK) and 22.7 MB (Windows zip),
against 106.9 MB and 60.4 MB for 1.1.0.

## Re-running a failed release

Delete the tag and the draft release, then re-push:

```bash
git push --delete origin v1.2.0
git tag -d v1.2.0
# fix, commit, then tag and push again
```

Or use the workflow's `workflow_dispatch` trigger with the tag name, which
rebuilds and overwrites the release assets without touching the tag.
