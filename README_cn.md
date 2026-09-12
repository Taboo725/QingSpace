<div align="center">

<img src="assets/icon/icon.png" width="120" alt="QingSpace" />

# QingSpace 晴空

**一款以 Git 仓库为后端的情侣共同纪念应用 —— 你们的回忆、瞬间与纪念日，都存在自己的仓库里。**

[![CI](https://github.com/Taboo725/QingSpace/actions/workflows/ci.yml/badge.svg)](https://github.com/Taboo725/QingSpace/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Taboo725/QingSpace?label=release)](https://github.com/Taboo725/QingSpace/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[English](README.md) · [下载](#-下载) · [功能](#-主要功能) · [快速上手](#-快速上手)

</div>

---

## 📦 下载

前往 [**Releases**](https://github.com/Taboo725/QingSpace/releases/latest) 下载最新版本。

| 平台 | 文件 | 说明 |
|------|------|------|
| Android | `QingSpace-<版本>-android.apk` | 直接安装，需允许「安装未知来源应用」 |
| Windows | `QingSpace-<版本>-windows-x64.zip` | 解压到任意目录后运行 `qing_space.exe`，无需安装 |

应用每天最多检查一次更新。Android 可在应用内直接下载安装；Windows 会提示并跳转到下载页面。
可在 **设置 → 关于 → 启动时自动检查** 中关闭。

iOS / macOS 可自行从源码构建，但因 Apple 要求付费开发者账号签名，未提供预编译包。

## ✨ 主要功能

- **主页**：恋爱天数、纪念日倒计时、随机「那年今日」回忆卡片
- **随记**：带情绪 emoji 和图片的日常记录，按月份分组
- **日记**：Markdown 长文，支持分类、标签、自定义字段
- **相册**：瀑布流图片墙，支持手势缩放
- **双历支持**：同时支持公历与农历，不错过任何农历生日和节日
- **双数据源**：GitHub 为唯一写入源；可选 Gitee 镜像加速国内读取
- **应用内更新**：从 GitHub Releases 检查并安装新版本
- **多主题**：内置六套配色，持久化保存
- **数据自持**：内容存在你自己的仓库里，没有第三方服务器，没有厂商锁定

## 🚀 快速上手

### 准备

- Flutter SDK 3.x
- 一个 GitHub [Personal Access Token](https://github.com/settings/tokens)（需要 `repo` 权限）
- 一个用于存放数据的 GitHub 仓库 —— **建议设为私有**

### 从源码运行

```bash
git clone https://github.com/Taboo725/QingSpace.git
cd QingSpace
flutter pub get
flutter run
```

首次启动按引导填写双方姓名、纪念日与生日；随后在 **设置 → 数据源** 填入
Token、用户名与仓库名即可。

### 常用命令

```bash
flutter analyze    # 代码检查，应当零问题
flutter test       # 运行测试
dart format lib test
flutter build apk  # 构建 Android 包
```

## 🗂️ 数据结构

内容存放在你自己创建的数据仓库中，结构如下（应用会按需创建）：

```
<你的数据仓库>/
├── data/
│   ├── posts/           # 每篇日记一个 .md 文件（含 YAML frontmatter）
│   ├── moments.yml      # 随记列表
│   └── gallery.yml      # 相册条目列表
└── images/
    ├── posts/
    ├── moments/
    └── gallery/
```

全部是纯文本的 Markdown 与 YAML。即使有一天不再使用 QingSpace，
这些回忆依然是你仓库里可读的文本文件。

## 🔒 数据与隐私

QingSpace 没有自己的后端。Token 仅存于本地 SharedPreferences，
只会发送给它所属的代码托管平台。更新检查以**匿名方式**访问
`api.github.com/repos/Taboo725/QingSpace/releases/latest`，不会附带你的 Token。

## 🤝 参与贡献

欢迎提交 Issue 与 Pull Request，详见 [CONTRIBUTING.md](CONTRIBUTING.md)。
较大的改动请先开 Issue 讨论。

## 📄 许可证

[MIT](LICENSE)。内置的思源宋体遵循 SIL Open Font License 1.1。
