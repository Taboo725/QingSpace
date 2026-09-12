/// Human-readable release history, shown in Settings → About.
///
/// The running version itself comes from [AppInfo], which reads the platform
/// package metadata — `pubspec.yaml` is the single source of truth for that.
/// This list only needs a new entry when a release ships.
class AppVersion {
  const AppVersion._();

  static const List<ChangelogEntry> changelog = [
    ChangelogEntry(
      version: '1.1.0',
      date: '2026-09-12',
      changes: [
        '新增应用内更新检查，可直接下载安装新版本',
        '全新应用图标',
        '首次启动不再等待网络探测，界面立即可用',
        '修复相册编辑会清空全部照片日期的问题',
        '修复文章分类误匹配正文内容的问题',
        '列表与网格图片改为按需缩放解码，大幅降低内存占用',
      ],
    ),
    ChangelogEntry(
      version: '1.0.3',
      date: '2026-03-02',
      changes: ['修复 GitHub 内容加载问题', '新增设置页、主题设置、调试模式开关', '新增版本信息与更新日志'],
    ),
    ChangelogEntry(version: '1.0.1', date: '2026-02-15', changes: ['随记支持修改日期']),
    ChangelogEntry(version: '1.0.0', date: '2025-02-15', changes: ['首个版本']),
  ];
}

class ChangelogEntry {
  final String version;
  final String date;
  final List<String> changes;

  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });
}
