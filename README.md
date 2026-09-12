<div align="center">

<img src="assets/icon/icon.png" width="120" alt="QingSpace" />

# QingSpace

**A personal couple's app that uses a Git repository as its backend — store your memories, moments, and milestones together, forever.**

*QingSpace (晴空) is a Flutter application for couples to capture daily moments, write diaries, build a shared photo gallery, and track anniversaries — all backed by a repository you own and control.*

[![CI](https://github.com/Taboo725/QingSpace/actions/workflows/ci.yml/badge.svg)](https://github.com/Taboo725/QingSpace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Taboo725/QingSpace?label=release)](https://github.com/Taboo725/QingSpace/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)

[中文说明](README_cn.md) · [Download](#-download) · [Features](#-features) · [Getting Started](#-getting-started) · [Architecture](#-architecture) · [Contributing](CONTRIBUTING.md)

</div>

---

## 📦 Download

Grab the latest build from the [**Releases**](https://github.com/Taboo725/QingSpace/releases/latest) page.

| Platform | File | Notes |
|----------|------|-------|
| Android (almost every phone) | `QingSpace-<version>-android-arm64-v8a.apk` | Sideload it; you will need to allow installs from unknown sources. |
| Android (32-bit, pre-2015) | `QingSpace-<version>-android-armeabi-v7a.apk` | Only if the arm64 build refuses to install. |
| Windows | `QingSpace-<version>-windows-x64.zip` | Unzip anywhere and run `qing_space.exe`. No installer. |

Not sure which Android build? Take `arm64-v8a`. The in-app updater picks the
right architecture on its own.

The app checks for updates once a day and can install them for you on Android.
Turn it off in **Settings → About → 启动时自动检查**.

iOS and macOS build from source but are not published — Apple requires a paid
developer account to distribute signed builds.

## ✨ Features

- **Dashboard** — Days-together counter, countdown cards for anniversaries & birthdays, and a random "On This Day" memory card
- **Moments** — A timestamped feed of daily snippets with mood emojis and photos
- **Posts** — Long-form Markdown diaries with categories and cover abstracts
- **Gallery** — A staggered photo grid with captions
- **Dual calendar** — Full support for both Gregorian and Chinese lunar calendar dates, so lunar birthdays and festivals are never missed
- **Dual data source** — GitHub as the single source of truth; optional Gitee mirror for faster reads inside China
- **In-app updates** — Checks GitHub Releases; downloads and installs on Android
- **Themes** — Multiple color modes, persisted across sessions
- **Self-hosted** — Your data lives in *your* repository. No third-party server, no vendor lock-in.

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x |
| State management | Provider |
| Backend | GitHub REST API (+ optional Gitee v5 mirror) |
| Local persistence | SharedPreferences |
| Image caching | cached_network_image |
| Markdown rendering | flutter_markdown |
| Lunar calendar | lunar package |
| Typography | Source Han Serif CN (bundled, 5 weights, subset to GB2312) |

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.x
- A GitHub account with a [Personal Access Token](https://github.com/settings/tokens) (requires `repo` scope)
- A GitHub repository to store your data — **make it private**

### Run from source

```bash
git clone https://github.com/Taboo725/QingSpace.git
cd QingSpace
flutter pub get
flutter run
```

On first launch, onboarding walks you through both names, your start date and
your birthdays. Open **Settings → Data Sources** to enter your token, username
and repository name.

### Build

```bash
flutter build apk        # Android
flutter build windows    # Windows desktop
flutter build ios        # iOS (needs a signing identity)
```

### Develop

```bash
flutter analyze          # must report zero issues
flutter test
dart format lib test
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the conventions this codebase holds
itself to, and [docs/RELEASING.md](docs/RELEASING.md) for how releases are cut.

## 🗂️ Data Layout

Your content lives in a separate repository that you create and configure in
Settings. QingSpace expects this layout and will create the paths as you go:

```
<your-data-repo>/
├── data/
│   ├── posts/           # One .md file per diary post (with YAML frontmatter)
│   ├── moments.yml      # Dated list of moments
│   └── gallery.yml      # Gallery item list
└── images/
    ├── posts/
    ├── moments/
    └── gallery/
```

Everything is plain Markdown and YAML. If you ever stop using QingSpace, your
memories are still readable text files in a repository you own.

## 🏗️ Architecture

```
lib/
├── main.dart                       # App entry; parallel local init, then Provider setup
├── core/
│   ├── config/                     # app_config (nav + debug date), app_info, version
│   ├── services/                   # All repository I/O
│   │   ├── repo_client.dart        #   abstract CRUD; GitHub and Gitee implement it
│   │   ├── data_source_manager.dart#   owns the active client, races both hosts
│   │   └── update_service.dart     #   GitHub Releases updater
│   ├── theme/                      # ThemeProvider + colour modes
│   ├── utils/                      # frontmatter parser, lunar labels
│   └── widgets/                    # net_image, page_state_widget, photo_zoom
├── features/                       # One directory per screen
│   ├── home/                       # Dashboard + shell
│   ├── moment/ post/ gallery/      # Content screens
│   ├── settings/ onboarding/       # Configuration
│   └── update/                     # Update dialog
└── models/                         # Post, Moment, GalleryItem
```

**Two backends, one direction of travel.** GitHub is the source of truth; Gitee
is an optional read mirror. Reads go through whichever source the user picked
(`auto` races both at startup); **writes always go to GitHub**, so sync only
ever flows one way and conflicts cannot arise.

**Startup is not gated on the network.** Host probing runs in the background and
services await it before their first request, so the UI paints immediately.

**State management:** Provider throughout — pages call services directly, no
intermediate ViewModels or BLoCs.

**Navigation:** `NavigationRail` on desktop (≥600 px), `NavigationBar` on mobile.

## ⚙️ Configuration

| Setting | Where |
|---------|-------|
| GitHub token, username, repo, branch | Settings → Data Sources. Stored in SharedPreferences, never committed. |
| Gitee mirror (optional) | Settings → Data Sources. `Auto` races both endpoints and keeps the faster one. |
| Mirror sync status | Settings → Data Sources → Mirror Sync Status compares branch HEADs. |
| Theme | Settings → Appearance |
| Automatic update checks | Settings → About |
| Debug date override | Settings → Development (used to test "On This Day" and countdowns) |

## 🔒 Privacy

QingSpace has no backend of its own. Your token is stored locally and is only
ever sent to the host it belongs to. The update check talks to
`api.github.com/repos/Taboo725/QingSpace/releases/latest` **unauthenticated** —
your token is never attached to it.

## 🤝 Contributing

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
Please open an issue first to discuss significant changes.

## 📄 License

[MIT](LICENSE). Bundled third-party assets are listed in [NOTICE](NOTICE) — Source Han Serif CN is under the SIL Open Font License 1.1.
