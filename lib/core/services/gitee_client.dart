import 'package:shared_preferences/shared_preferences.dart';

/// Centralised Gitee auth and repo configuration.
/// Call [GiteeClient.init] at app startup.
class GiteeClient {
  static const _tokenKey = 'gitee_token';
  static const _userKey = 'gitee_user';
  static const _repoKey = 'gitee_repo';

  static const _branchKey = 'gitee_branch';

  static String _token = '';
  static String _user = '';
  static String _repo = '';
  static String _branch = 'main';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey) ?? '';
    _user = prefs.getString(_userKey) ?? '';
    _repo = prefs.getString(_repoKey) ?? '';
    _branch = prefs.getString(_branchKey) ?? 'main';
  }

  static String get currentToken => _token;
  static String get user => _user;
  static String get repo => _repo;
  static String get branch => _branch;

  static bool get isConfigured =>
      _token.isNotEmpty && _user.isNotEmpty && _repo.isNotEmpty;

  // Used for POST / PUT / DELETE — JSON body requests.
  static Map<String, String> get writeHeaders => {
    'Authorization': 'token $_token',
    'Content-Type': 'application/json',
  };

  // For GET requests Gitee recommends the access_token query param rather than
  // the Authorization header, which can silently return 404 on private repos.
  // Call [appendToken] to build the query string instead of using headers.
  static String appendToken(String url) {
    if (_token.isEmpty) return url;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}access_token=$_token';
  }

  // Raw image URLs embed the token as a query param — no extra headers needed.
  static Map<String, String>? get imageHeaders => null;

  static Future<void> saveConfig({
    required String token,
    required String user,
    required String repo,
    String branch = 'main',
  }) async {
    _token = token;
    _user = user;
    _repo = repo;
    _branch = branch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, user);
    await prefs.setString(_repoKey, repo);
    await prefs.setString(_branchKey, branch);
  }

  static Future<void> clearConfig() async {
    _token = '';
    _user = '';
    _repo = '';
    _branch = 'main';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_repoKey);
    await prefs.remove(_branchKey);
  }
}
