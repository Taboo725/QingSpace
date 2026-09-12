# Contributing

Thanks for taking an interest in QingSpace. This is a small personal project, so
the bar is simple: keep the codebase easy to read and don't break anyone's data.

## Getting set up

```bash
flutter pub get
flutter run
```

You will need a GitHub personal access token with `repo` scope and a content
repository of your own — see the README for the layout the app expects. Nothing
in this repo talks to a server the maintainers control; your data stays in your
own repository.

## Before you open a pull request

```bash
dart format lib test
flutter analyze      # must report zero issues
flutter test
```

CI runs exactly these three, plus a check that `assets/icon/` matches what
`tool/generate_icon.py` produces. `analysis_options.yaml` escalates unused
imports, unused locals, unused elements and dead code to **errors** — that is
deliberate, please don't downgrade them to get a branch green.

**CI tracks the latest stable Flutter**, and analyzes with `--fatal-infos`. A
local toolchain that has fallen behind will miss deprecations that fail the
build; run `flutter upgrade` if CI flags something you cannot reproduce.

## Things worth knowing

- **Never write through a caller-supplied blob SHA.** Reads may come from the
  Gitee mirror, whose SHAs lag GitHub's. Write paths re-read the live GitHub SHA
  first. See `GithubService` for the pattern.
- **YAML is written by hand.** Route every string value through `yamlScalar()`
  in `core/services/yaml_helper.dart`. A bare `"$value"` breaks on quotes,
  backslashes and newlines, and silently corrupts the user's file.
- **Round-trip every field you parse.** The 1.1.0 release fixed a bug where
  gallery dates were read but not written, so every edit quietly erased them.
  If a model has a field, the serialiser must emit it.
- **Use `NetImage`, not `CachedNetworkImage` directly**, and pass `memCacheWidth`
  in any list or grid. A full-size decode of a phone photo costs tens of
  megabytes.
- **Read "today" through `AppConfig.effectiveNow`**, never `DateTime.now()`.
  The debug date override is how the "on this day" and countdown features are
  tested without waiting a year.
- **Prefer a test over a manual check** for anything in `core/utils`,
  `core/services` or `models`. Those are pure enough to test cheaply, and the
  existing suite is fast.

## Changing the icon

Edit the constants at the top of `tool/generate_icon.py`, then:

```bash
python tool/generate_icon.py     # needs Pillow
dart run flutter_launcher_icons  # fans the masters out to every platform
```

Commit both `assets/icon/` and the regenerated platform files. CI verifies the
committed masters against the generator (`tool/verify_icon.py`). Do not hand-edit
the PNGs or `icon.svg`; they are build products and CI will notice.

## Changing the bundled fonts

`assets/fonts/` holds *subset* Source Han Serif CN weights — GB2312 plus
punctuation, Latin and every character in the app's own Dart string literals.
The full upstream weights are ~10.7 MB each and are deliberately not in the
repo.

If you add UI text using a character outside that set it will still render, but
in the platform's fallback face rather than the serif. To fold new characters in
(or add a weight), download the upstream OTFs into `build/fonts_full/` and:

```bash
python -m pip install fonttools
python tool/subset_fonts.py
```

## Commit messages

Conventional-ish prefixes (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`) are
appreciated but not enforced. A sentence explaining *why* beats a perfect prefix.

## Releases

See [docs/RELEASING.md](docs/RELEASING.md). Maintainers only — it needs the
Android signing secrets.
