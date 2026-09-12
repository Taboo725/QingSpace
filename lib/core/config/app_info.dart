import 'package:package_info_plus/package_info_plus.dart';

/// Identity of the running build, and of the repository its updates come from.
///
/// The version is read from the platform package metadata rather than being
/// declared in Dart, so `pubspec.yaml` stays the single source of truth.
class AppInfo {
  const AppInfo._();

  /// GitHub repository that publishes the releases. This is the *app's* repo —
  /// distinct from the content repository each user configures in Settings.
  static const String owner = 'Taboo725';
  static const String repo = 'QingSpace';

  static const String repoUrl = 'https://github.com/$owner/$repo';
  static const String releasesUrl = '$repoUrl/releases';
  static const String latestReleaseApi =
      'https://api.github.com/repos/$owner/$repo/releases/latest';

  static String _version = '0.0.0';
  static String _buildNumber = '0';

  /// e.g. `1.1.0`
  static String get version => _version;

  /// e.g. `5`
  static String get buildNumber => _buildNumber;

  /// e.g. `1.1.0+5`
  static String get fullVersion => '$_version+$_buildNumber';

  static Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isNotEmpty) _version = info.version;
    if (info.buildNumber.isNotEmpty) _buildNumber = info.buildNumber;
  }
}
