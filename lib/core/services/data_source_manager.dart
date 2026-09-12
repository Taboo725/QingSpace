import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gitee_client.dart';
import 'gitee_repo_client.dart';
import 'github_repo_client.dart';
import 'repo_client.dart';

enum DataSource { github, gitee, auto }

enum SyncStatus { synced, outOfSync, unknown }

/// Singleton that owns the active [RepoClient] and handles source selection.
///
/// [init] is cheap and never blocks on the network: it reads the stored
/// preference and, for `auto`, kicks off endpoint probing in the background.
/// Callers that are about to issue a request should await [ready] (or use
/// [readClient]) so the probe result is honoured for the very first fetch.
class DataSourceManager {
  DataSourceManager._();
  static final DataSourceManager instance = DataSourceManager._();

  static const _prefKey = 'data_source';
  static const _probeTimeout = Duration(seconds: 8);
  static const _shaTimeout = Duration(seconds: 12);

  final _githubClient = GitHubRepoClient();
  final _giteeClient = GiteeRepoClient();

  DataSource _preference = DataSource.auto;
  DataSource _resolved = DataSource.github;
  Future<void> _resolution = Future.value();

  /// Notifies listeners whenever the active source changes.
  final resolvedNotifier = ValueNotifier<DataSource>(DataSource.github);

  /// Read client — uses whichever source is faster (may be Gitee).
  RepoClient get client =>
      _resolved == DataSource.gitee ? _giteeClient : _githubClient;

  /// Write client — always GitHub, the single source of truth for all mutations.
  RepoClient get writeClient => _githubClient;

  /// Completes once source resolution has settled. Safe to await repeatedly.
  Future<void> get ready => _resolution;

  /// [client], but only after resolution has settled.
  Future<RepoClient> get readClient async {
    await _resolution;
    return client;
  }

  DataSource get preference => _preference;
  DataSource get resolved => _resolved;

  Map<String, String>? get imageHeaders => client.imageHeaders;

  String rawUrl(String path) => client.rawUrl(path);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    _preference = DataSource.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => DataSource.auto,
    );
    // Apply the offline-decidable answer now so the first frame has a source,
    // then refine in the background if the preference is `auto`.
    _applyOfflineDefault();
    _resolution = _resolve();
  }

  Future<void> setPreference(DataSource src) async {
    _preference = src;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, src.name);
    _resolution = _resolve();
    return _resolution;
  }

  void _applyOfflineDefault() {
    _setResolved(
      _preference == DataSource.gitee && GiteeClient.isConfigured
          ? DataSource.gitee
          : DataSource.github,
    );
  }

  Future<void> _resolve() async {
    if (_preference == DataSource.auto) {
      _setResolved(await _detectFaster());
    } else {
      _applyOfflineDefault();
    }
  }

  void _setResolved(DataSource next) {
    if (_resolved == next) return;
    _resolved = next;
    resolvedNotifier.value = next;
    debugPrint('DataSourceManager: using ${next.name}');
  }

  /// Compares the branch HEAD commit SHA on both platforms.
  /// Each request is resolved independently so a slow GitHub connection does
  /// not hide the Gitee result.
  Future<
    ({SyncStatus status, String? githubSha, String? giteeSha, String? error})
  >
  checkSyncStatus() async {
    if (!GiteeClient.isConfigured) {
      return (
        status: SyncStatus.unknown,
        githubSha: null,
        giteeSha: null,
        error: 'Gitee not configured',
      );
    }

    final results = await Future.wait([
      _headSha(_githubClient, 'GitHub'),
      _headSha(_giteeClient, 'Gitee'),
    ]);
    final githubSha = results[0];
    final giteeSha = results[1];

    if (githubSha != null && giteeSha != null) {
      return (
        status: githubSha == giteeSha
            ? SyncStatus.synced
            : SyncStatus.outOfSync,
        githubSha: _shortSha(githubSha),
        giteeSha: _shortSha(giteeSha),
        error: null,
      );
    }

    return (
      status: SyncStatus.unknown,
      githubSha: _shortSha(githubSha),
      giteeSha: _shortSha(giteeSha),
      error: [
        if (githubSha == null) 'GitHub unreachable',
        if (giteeSha == null) 'Gitee unreachable',
      ].join(' · '),
    );
  }

  Future<String?> _headSha(RepoClient client, String label) async {
    try {
      return await client.getBranchHeadSha().timeout(_shaTimeout);
    } catch (e) {
      debugPrint('getBranchHeadSha $label failed: $e');
      return null;
    }
  }

  static String? _shortSha(String? sha) =>
      sha?.substring(0, sha.length < 7 ? sha.length : 7);

  /// Races both endpoints and returns whichever responds first.
  Future<DataSource> _detectFaster() async {
    if (!GiteeClient.isConfigured) return DataSource.github;

    final completer = Completer<DataSource>();
    var failures = 0;

    void succeed(DataSource src) {
      if (!completer.isCompleted) completer.complete(src);
    }

    void fail() {
      if (++failures == 2 && !completer.isCompleted) {
        completer.complete(DataSource.github);
      }
    }

    // Deliberately not awaited: whichever probe answers first wins the race.
    unawaited(
      _githubClient
          .listDir('data')
          .then((_) => succeed(DataSource.github), onError: (_) => fail()),
    );
    unawaited(
      _giteeClient
          .listDir('data')
          .then((_) => succeed(DataSource.gitee), onError: (_) => fail()),
    );

    return completer.future.timeout(
      _probeTimeout,
      onTimeout: () => DataSource.github,
    );
  }
}
