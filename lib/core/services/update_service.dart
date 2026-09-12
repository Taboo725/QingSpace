import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_info.dart';

/// A dotted version, compared numerically rather than as a string.
///
/// Tolerates a leading `v` and any `-suffix` build metadata; a version with a
/// pre-release suffix sorts *before* the same version without one, per semver.
@immutable
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;

  /// The `-beta.1` part, empty for a final release.
  final String preRelease;

  const SemanticVersion(
    this.major,
    this.minor,
    this.patch, [
    this.preRelease = '',
  ]);

  static final RegExp _pattern = RegExp(
    r'^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:[-+](.*))?$',
  );

  /// Parses `1.2.3`, `v1.2`, `1.2.3-beta.1`; returns null for anything else.
  static SemanticVersion? tryParse(String raw) {
    final match = _pattern.firstMatch(raw.trim());
    if (match == null) return null;
    return SemanticVersion(
      int.parse(match.group(1)!),
      int.tryParse(match.group(2) ?? '') ?? 0,
      int.tryParse(match.group(3) ?? '') ?? 0,
      match.group(4) ?? '',
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // 1.0.0-beta precedes 1.0.0.
    if (preRelease == other.preRelease) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;
    return preRelease.compareTo(other.preRelease);
  }

  bool operator >(SemanticVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch &&
      preRelease == other.preRelease;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);

  @override
  String toString() =>
      '$major.$minor.$patch${preRelease.isEmpty ? '' : '-$preRelease'}';
}

/// A published release, as far as the updater cares about it.
@immutable
class ReleaseInfo {
  final SemanticVersion version;
  final String tagName;

  /// Release notes, in Markdown.
  final String notes;

  /// Human-facing page, used when the app cannot install the update itself.
  final String pageUrl;

  /// Direct download for the Android package, absent on releases that only
  /// ship desktop builds.
  final String? apkUrl;

  /// Size of [apkUrl] in bytes, 0 when unknown.
  final int apkSize;

  const ReleaseInfo({
    required this.version,
    required this.tagName,
    required this.notes,
    required this.pageUrl,
    this.apkUrl,
    this.apkSize = 0,
  });

  /// True when this build can be fetched and handed to the OS installer.
  bool get canInstallInApp => Platform.isAndroid && apkUrl != null;

  static ReleaseInfo? fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name']?.toString() ?? '';
    final version = SemanticVersion.tryParse(tag);
    if (version == null) return null;

    String? apkUrl;
    var apkSize = 0;
    for (final raw in (json['assets'] as List? ?? const [])) {
      final asset = raw as Map<String, dynamic>;
      final name = asset['name']?.toString().toLowerCase() ?? '';
      if (name.endsWith('.apk')) {
        apkUrl = asset['browser_download_url']?.toString();
        apkSize = (asset['size'] as num?)?.toInt() ?? 0;
        break;
      }
    }

    return ReleaseInfo(
      version: version,
      tagName: tag,
      notes: json['body']?.toString().trim() ?? '',
      pageUrl: json['html_url']?.toString() ?? AppInfo.releasesUrl,
      apkUrl: apkUrl,
      apkSize: apkSize,
    );
  }
}

/// Why a check did not produce an update.
enum UpdateOutcome { available, upToDate, skipped, failed }

@immutable
class UpdateCheck {
  final UpdateOutcome outcome;
  final ReleaseInfo? release;
  final String? error;

  const UpdateCheck._(this.outcome, {this.release, this.error});

  const UpdateCheck.available(ReleaseInfo release)
    : this._(UpdateOutcome.available, release: release);
  const UpdateCheck.upToDate() : this._(UpdateOutcome.upToDate);
  const UpdateCheck.skipped() : this._(UpdateOutcome.skipped);
  const UpdateCheck.failed(String error)
    : this._(UpdateOutcome.failed, error: error);
}

/// Checks GitHub Releases for a newer build, and applies it where the platform
/// allows.
///
/// The check is unauthenticated on purpose: the release repo is public, so no
/// token is needed and the updater works before the user has configured one.
/// GitHub's anonymous limit is 60 requests/hour per IP, far above what a
/// once-a-day check uses.
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _lastCheckKey = 'update_last_check';
  static const _skippedVersionKey = 'update_skipped_version';
  static const _autoCheckKey = 'update_auto_check';
  static const _autoCheckInterval = Duration(hours: 24);
  static const _timeout = Duration(seconds: 15);

  // ── Checking ──────────────────────────────────────────────────────────────

  /// Queries the latest release.
  ///
  /// [respectSkip] honours a version the user chose to ignore; a manual check
  /// from Settings passes false so the result is never silently swallowed.
  Future<UpdateCheck> check({bool respectSkip = false}) async {
    try {
      final response = await _client
          .get(
            Uri.parse(AppInfo.latestReleaseApi),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(_timeout);

      if (response.statusCode == 404) {
        // No release published yet — not an error worth showing.
        return const UpdateCheck.upToDate();
      }
      if (response.statusCode != 200) {
        return UpdateCheck.failed('HTTP ${response.statusCode}');
      }

      final release = ReleaseInfo.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
      if (release == null) return const UpdateCheck.upToDate();

      await _recordCheckTime();

      final current = SemanticVersion.tryParse(AppInfo.version);
      if (current == null || !(release.version > current)) {
        return const UpdateCheck.upToDate();
      }
      if (respectSkip && await _isSkipped(release.version)) {
        return const UpdateCheck.skipped();
      }
      return UpdateCheck.available(release);
    } on TimeoutException {
      return const UpdateCheck.failed('请求超时');
    } catch (e) {
      debugPrint('Update check failed: $e');
      return const UpdateCheck.failed('无法连接到更新服务');
    }
  }

  /// A day-throttled check for app startup. Returns null when it is too soon,
  /// auto-check is off, or there is nothing to report.
  Future<ReleaseInfo?> checkInBackground() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_autoCheckKey) ?? true)) return null;

    final last = prefs.getInt(_lastCheckKey);
    if (last != null) {
      final elapsed = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(last),
      );
      if (elapsed < _autoCheckInterval) return null;
    }

    final result = await check(respectSkip: true);
    return result.outcome == UpdateOutcome.available ? result.release : null;
  }

  // ── Applying ──────────────────────────────────────────────────────────────

  /// Downloads the APK and hands it to the system package installer.
  ///
  /// Android only; call sites should gate on [ReleaseInfo.canInstallInApp].
  /// [onProgress] receives 0.0–1.0, or -1 while the total size is unknown.
  Future<void> downloadAndInstall(
    ReleaseInfo release, {
    required void Function(double progress) onProgress,
    CancellationToken? cancel,
  }) async {
    final url = release.apkUrl;
    if (url == null) throw StateError('Release has no APK asset');

    final file = await _apkFile(release);
    final request = http.Request('GET', Uri.parse(url));
    final response = await _client.send(request).timeout(_timeout);

    if (response.statusCode != 200) {
      throw HttpException('下载失败：HTTP ${response.statusCode}', uri: request.url);
    }

    final total = response.contentLength ?? release.apkSize;
    final sink = file.openWrite();
    var received = 0;

    try {
      await for (final chunk in response.stream) {
        if (cancel?.isCancelled ?? false) {
          await sink.close();
          await file.delete();
          return;
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress(total > 0 ? received / total : -1);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (total > 0 && received < total) {
      await file.delete();
      throw const HttpException('下载中断，文件不完整');
    }

    // Opening the APK raises the system installer prompt; the user still has to
    // confirm, and Android will refuse unless install-from-this-source is
    // allowed for QingSpace.
    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw StateError('无法启动安装程序：${result.message}');
    }
  }

  /// Opens the release page in the browser, for platforms the app cannot
  /// update in place.
  Future<bool> openReleasePage(ReleaseInfo release) => launchUrl(
    Uri.parse(release.pageUrl),
    mode: LaunchMode.externalApplication,
  );

  /// Downloaded packages land in the app cache, which the OS may reclaim — the
  /// right place for a file that is disposable once installed. A stale download
  /// of the same version is replaced rather than resumed.
  Future<File> _apkFile(ReleaseInfo release) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/QingSpace-${release.tagName}.apk');
    if (file.existsSync()) await file.delete();
    await file.create(recursive: true);
    return file;
  }

  // ── Preferences ───────────────────────────────────────────────────────────

  Future<bool> isAutoCheckEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_autoCheckKey) ?? true;

  Future<void> setAutoCheckEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_autoCheckKey, value);

  Future<void> skipVersion(SemanticVersion version) async =>
      (await SharedPreferences.getInstance()).setString(
        _skippedVersionKey,
        version.toString(),
      );

  Future<bool> _isSkipped(SemanticVersion version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_skippedVersionKey) == version.toString();
  }

  Future<void> _recordCheckTime() async =>
      (await SharedPreferences.getInstance()).setInt(
        _lastCheckKey,
        DateTime.now().millisecondsSinceEpoch,
      );

  void dispose() => _client.close();
}

/// Lets the download UI abandon an in-flight transfer.
class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}
