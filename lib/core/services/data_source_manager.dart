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
/// Call [init] at startup (after [GitHubClient.init] and [GiteeClient.init]).
/// Use [setPreference] to persist and apply a new user preference.
class DataSourceManager {
  DataSourceManager._();
  static final DataSourceManager instance = DataSourceManager._();

  static const _prefKey = 'data_source';

  final _githubClient = GitHubRepoClient();
  final _giteeClient = GiteeRepoClient();

  DataSource _preference = DataSource.auto;
  DataSource _resolved = DataSource.github;

  /// Notifies listeners whenever the active source changes.
  final resolvedNotifier = ValueNotifier<DataSource>(DataSource.github);

  /// Read client — uses whichever source is faster (may be Gitee).
  RepoClient get client =>
      _resolved == DataSource.gitee ? _giteeClient : _githubClient;

  /// Write client — always GitHub, the single source of truth for all mutations.
  RepoClient get writeClient => _githubClient;

  DataSource get preference => _preference;
  DataSource get resolved => _resolved;

  Map<String, String>? get imageHeaders =>
      _resolved == DataSource.gitee
          ? GiteeClient.imageHeaders
          : _githubClient.imageHeaders;

  String rawUrl(String path) => client.rawUrl(path);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    _preference = DataSource.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => DataSource.auto,
    );
    await _resolve();
  }

  Future<void> setPreference(DataSource src) async {
    _preference = src;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, src.name);
    await _resolve();
  }

  Future<void> _resolve() async {
    final DataSource next;
    if (_preference == DataSource.auto) {
      next = await _detectFaster();
    } else if (_preference == DataSource.gitee && GiteeClient.isConfigured) {
      next = DataSource.gitee;
    } else {
      next = DataSource.github;
    }
    _resolved = next;
    resolvedNotifier.value = next;
    debugPrint('DataSourceManager: using ${next.name}');
  }

  /// Compares the branch HEAD commit SHA on both platforms.
  /// Each request has a 12-second timeout and is resolved independently so a
  /// slow GitHub connection does not block the Gitee result.
  Future<({SyncStatus status, String? githubSha, String? giteeSha, String? error})>
      checkSyncStatus() async {
    if (!GiteeClient.isConfigured) {
      return (
        status: SyncStatus.unknown,
        githubSha: null,
        giteeSha: null,
        error: 'Gitee not configured',
      );
    }

    String? githubSha;
    String? giteeSha;
    final errors = <String>[];

    await Future.wait([
      _githubClient
          .getBranchHeadSha()
          .timeout(const Duration(seconds: 12))
          .then((sha) { githubSha = sha; })
          .catchError((e) {
        errors.add('GitHub unreachable');
        debugPrint('getBranchHeadSha GitHub failed: $e');
      }),
      _giteeClient
          .getBranchHeadSha()
          .timeout(const Duration(seconds: 12))
          .then((sha) { giteeSha = sha; })
          .catchError((e) {
        errors.add('Gitee unreachable');
        debugPrint('getBranchHeadSha Gitee failed: $e');
      }),
    ]);

    if (githubSha != null && giteeSha != null) {
      return (
        status: githubSha == giteeSha ? SyncStatus.synced : SyncStatus.outOfSync,
        githubSha: githubSha!.substring(0, 7),
        giteeSha: giteeSha!.substring(0, 7),
        error: null,
      );
    }

    return (
      status: SyncStatus.unknown,
      githubSha: githubSha?.substring(0, 7),
      giteeSha: giteeSha?.substring(0, 7),
      error: errors.join(' · '),
    );
  }

  /// Races both endpoints and returns whichever responds first.
  Future<DataSource> _detectFaster() async {
    if (!GiteeClient.isConfigured) return DataSource.github;

    final completer = Completer<DataSource>();
    int failures = 0;

    void succeed(DataSource src) {
      if (!completer.isCompleted) completer.complete(src);
    }

    void fail() {
      if (++failures == 2 && !completer.isCompleted) {
        completer.complete(DataSource.github);
      }
    }

    _githubClient.listDir('data').then(
      (_) => succeed(DataSource.github),
      onError: (_) => fail(),
    );
    _giteeClient.listDir('data').then(
      (_) => succeed(DataSource.gitee),
      onError: (_) => fail(),
    );

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => DataSource.github,
    );
  }
}
