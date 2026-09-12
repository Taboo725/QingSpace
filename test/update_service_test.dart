import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qing_space/core/config/app_info.dart';
import 'package:qing_space/core/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The version the tests pretend to be running.
const String kCurrentVersion = '1.1.0';

SemanticVersion v(String raw) => SemanticVersion.tryParse(raw)!;

Map<String, dynamic> releaseJson({
  String tag = 'v9.9.9',
  String body = 'notes',
  List<Map<String, dynamic>> assets = const [],
}) => {
  'tag_name': tag,
  'body': body,
  'html_url': 'https://github.com/Taboo725/QingSpace/releases/tag/$tag',
  'assets': assets,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'QingSpace',
      packageName: 'com.qingspace.app',
      version: kCurrentVersion,
      buildNumber: '5',
      buildSignature: '',
    );
    await AppInfo.init();
  });

  group('SemanticVersion.tryParse', () {
    test('accepts tags with and without a v prefix', () {
      expect(v('1.2.3').toString(), '1.2.3');
      expect(v('v1.2.3').toString(), '1.2.3');
      expect(v('  v1.2.3  ').toString(), '1.2.3');
    });

    test('fills in omitted components', () {
      expect(v('2'), const SemanticVersion(2, 0, 0));
      expect(v('2.5'), const SemanticVersion(2, 5, 0));
    });

    test('keeps a pre-release suffix', () {
      expect(v('1.2.3-beta.1').preRelease, 'beta.1');
      expect(v('1.2.3+7').preRelease, '7');
    });

    test('rejects non-versions', () {
      expect(SemanticVersion.tryParse('latest'), isNull);
      expect(SemanticVersion.tryParse(''), isNull);
      expect(SemanticVersion.tryParse('v'), isNull);
    });
  });

  group('SemanticVersion ordering', () {
    test('compares numerically, not lexically', () {
      // The bug this guards: '10' < '9' as a string.
      expect(v('1.10.0') > v('1.9.0'), isTrue);
      expect(v('2.0.0') > v('1.99.99'), isTrue);
      expect(v('1.0.10') > v('1.0.9'), isTrue);
    });

    test('treats equal versions as not newer', () {
      expect(v('1.2.3') > v('1.2.3'), isFalse);
      expect(v('1.2.3') > v('1.2.4'), isFalse);
    });

    test('sorts a pre-release before its final release', () {
      expect(v('1.0.0') > v('1.0.0-beta'), isTrue);
      expect(v('1.0.0-beta') > v('1.0.0'), isFalse);
    });

    test('ignores a v prefix when comparing', () {
      expect(v('v1.1.0') > v('1.0.3'), isTrue);
    });
  });

  group('ReleaseInfo.fromJson', () {
    test('collects every APK asset and ignores the rest', () {
      final release = ReleaseInfo.fromJson(
        releaseJson(
          assets: [
            {
              'name': 'QingSpace-1.1.0-windows-x64.zip',
              'browser_download_url': 'https://example.test/w.zip',
              'size': 11,
            },
            {
              'name': 'QingSpace-1.1.0-android-arm64-v8a.apk',
              'browser_download_url': 'https://example.test/a64.apk',
              'size': 2048,
            },
            {
              'name': 'QingSpace-1.1.0-android-armeabi-v7a.apk',
              'browser_download_url': 'https://example.test/a32.apk',
              'size': 1024,
            },
          ],
        ),
      )!;

      expect(release.apkAssets.map((a) => a.name), [
        'QingSpace-1.1.0-android-arm64-v8a.apk',
        'QingSpace-1.1.0-android-armeabi-v7a.apk',
      ]);
      expect(release.apkAssets.first.size, 2048);
      expect(release.version, v('9.9.9'));
    });

    test('tolerates a release with no APK', () {
      final release = ReleaseInfo.fromJson(releaseJson())!;
      expect(release.apkAssets, isEmpty);
      expect(release.canInstallInApp, isFalse);
    });

    test('skips assets with no download URL', () {
      final release = ReleaseInfo.fromJson(
        releaseJson(
          assets: [
            {'name': 'broken.apk', 'size': 1},
          ],
        ),
      )!;
      expect(release.apkAssets, isEmpty);
    });

    test('returns null when the tag is not a version', () {
      expect(ReleaseInfo.fromJson(releaseJson(tag: 'nightly')), isNull);
    });

    test('falls back to the releases page when html_url is missing', () {
      final json = releaseJson()..remove('html_url');
      expect(ReleaseInfo.fromJson(json)!.pageUrl, AppInfo.releasesUrl);
    });
  });

  group('selectApkAsset', () {
    ReleaseAsset asset(String name) =>
        ReleaseAsset(name: name, url: 'https://example.test/$name');

    final perAbi = [
      asset('QingSpace-1.1.0-android-arm64-v8a.apk'),
      asset('QingSpace-1.1.0-android-armeabi-v7a.apk'),
      asset('QingSpace-1.1.0-android-x86_64.apk'),
    ];

    test('picks the build matching the device ABI', () {
      expect(selectApkAsset(perAbi, 'arm64-v8a')!.name, contains('arm64-v8a'));
      expect(
        selectApkAsset(perAbi, 'armeabi-v7a')!.name,
        contains('armeabi-v7a'),
      );
      expect(selectApkAsset(perAbi, 'x86_64')!.name, contains('x86_64'));
    });

    test('does not confuse arm64-v8a with armeabi-v7a', () {
      // Substring matching on a bare "arm" would hand a 32-bit device the
      // 64-bit build, which installs and then fails to launch.
      final only64 = [asset('QingSpace-1.1.0-android-arm64-v8a.apk')];
      expect(selectApkAsset(only64, 'armeabi-v7a'), isNull);
    });

    test('refuses to guess when the ABI is unknown', () {
      expect(selectApkAsset(perAbi, null), isNull);
      expect(selectApkAsset(perAbi, 'riscv64'), isNull);
    });

    test('accepts a lone universal APK regardless of ABI', () {
      final universal = [asset('QingSpace-1.1.0-android.apk')];
      expect(selectApkAsset(universal, 'arm64-v8a')!.name, contains('android'));
      expect(selectApkAsset(universal, null)!.name, contains('android'));
      expect(selectApkAsset(universal, 'riscv64')!.name, contains('android'));
    });

    test('returns null for an empty asset list', () {
      expect(selectApkAsset(const [], 'arm64-v8a'), isNull);
    });
  });

  group('UpdateService.check', () {
    UpdateService serviceReturning(
      Object body, {
      int status = 200,
      void Function(http.Request)? onRequest,
    }) => UpdateService(
      client: MockClient((request) async {
        onRequest?.call(request);
        return http.Response(
          body is String ? body : jsonEncode(body),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    test('reports an update when the release is newer', () async {
      final result = await serviceReturning(releaseJson(tag: 'v9.9.9')).check();
      expect(result.outcome, UpdateOutcome.available);
      expect(result.release!.version, v('9.9.9'));
    });

    test('reports up to date for an older release', () async {
      final result = await serviceReturning(releaseJson(tag: 'v1.0.3')).check();
      expect(result.outcome, UpdateOutcome.upToDate);
    });

    test('reports up to date for the running version', () async {
      final result = await serviceReturning(
        releaseJson(tag: 'v$kCurrentVersion'),
      ).check();
      expect(result.outcome, UpdateOutcome.upToDate);
      expect(result.release, isNull);
    });

    test('treats a missing release as up to date, not an error', () async {
      final result = await serviceReturning('{}', status: 404).check();
      expect(result.outcome, UpdateOutcome.upToDate);
    });

    test('surfaces an unexpected status as a failure', () async {
      final result = await serviceReturning('{}', status: 403).check();
      expect(result.outcome, UpdateOutcome.failed);
      expect(result.error, contains('403'));
    });

    test('does not fail on malformed JSON', () async {
      final result = await serviceReturning('not json').check();
      expect(result.outcome, UpdateOutcome.failed);
    });

    test('sends no authorization header', () async {
      // The release repo is public; the user's content-repo token must never
      // be attached to this request.
      http.Request? seen;
      await serviceReturning(releaseJson(), onRequest: (r) => seen = r).check();
      expect(
        seen!.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
    });

    test('honours a skipped version only when asked to', () async {
      final service = serviceReturning(releaseJson(tag: 'v9.9.9'));
      await service.skipVersion(v('9.9.9'));

      expect(
        (await service.check(respectSkip: true)).outcome,
        UpdateOutcome.skipped,
      );
      // A manual check must still surface it.
      expect((await service.check()).outcome, UpdateOutcome.available);
    });
  });

  group('UpdateService.checkInBackground', () {
    test('stays quiet when auto-check is disabled', () async {
      final service = UpdateService(
        client: MockClient(
          (_) async => fail('should not hit the network when disabled'),
        ),
      );
      await service.setAutoCheckEnabled(false);
      expect(await service.checkInBackground(), isNull);
    });

    test('does not re-check within the throttle window', () async {
      var calls = 0;
      final service = UpdateService(
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode(releaseJson(tag: 'v9.9.9')), 200);
        }),
      );

      expect(await service.checkInBackground(), isNotNull);
      expect(calls, 1);
      // The first check recorded a timestamp, so the second is throttled out.
      expect(await service.checkInBackground(), isNull);
      expect(calls, 1);
    });
  });

  group('auto-check preference', () {
    test('defaults to on and round-trips', () async {
      final service = UpdateService(
        client: MockClient((_) async => fail('n/a')),
      );
      expect(await service.isAutoCheckEnabled(), isTrue);
      await service.setAutoCheckEnabled(false);
      expect(await service.isAutoCheckEnabled(), isFalse);
    });
  });
}
