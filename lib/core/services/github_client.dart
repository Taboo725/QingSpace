import 'package:shared_preferences/shared_preferences.dart';

/// Centralised GitHub auth and repo configuration.
/// Call [GitHubClient.init] at app startup.
class GitHubClient {
  static const _tokenKey = 'github_token';
  static const _userKey = 'github_user';
  static const _repoKey = 'github_repo';
  static const _branchKey = 'github_branch';

  static const _defaultBranch = 'main';

  static String _token = '';
  static String _user = '';
  static String _repo = '';
  static String _branch = _defaultBranch;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey) ?? '';
    _user = prefs.getString(_userKey) ?? '';
    _repo = prefs.getString(_repoKey) ?? '';
    _branch = prefs.getString(_branchKey) ?? _defaultBranch;
  }

  static String get currentToken => _token;
  static String get user => _user;
  static String get repo => _repo;
  static String get branch => _branch;

  static bool get isConfigured => _token.isNotEmpty;

  static Map<String, String> get headers => {
    'Authorization': 'Bearer $_token',
    'Accept': 'application/vnd.github.v3+json',
  };

  static Map<String, String>? get imageHeaders {
    if (_token.isEmpty) return null;
    return {
      'Authorization': 'Bearer $_token',
      'Accept': 'application/vnd.github.v3.raw',
    };
  }

  static Future<void> saveConfig({
    required String token,
    required String user,
    required String repo,
    String branch = _defaultBranch,
  }) async {
    _token = token;
    _user = user;
    _repo = repo;
    _branch = branch.isEmpty ? _defaultBranch : branch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, _token);
    await prefs.setString(_userKey, _user);
    await prefs.setString(_repoKey, _repo);
    await prefs.setString(_branchKey, _branch);
  }

  static Future<void> clearConfig() async {
    _token = '';
    _user = '';
    _repo = '';
    _branch = _defaultBranch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_repoKey);
    await prefs.remove(_branchKey);
  }

  // Keep for backward compat with any callers that only save the token.
  static Future<void> saveToken(String token) => saveConfig(
    token: token,
    user: _user,
    repo: _repo,
    branch: _branch,
  );

  static Future<void> clearToken() => clearConfig();
}
