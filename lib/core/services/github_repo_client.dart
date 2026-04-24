import 'dart:convert';
import 'package:http/http.dart' as http;
import 'github_client.dart';
import 'repo_client.dart';

class GitHubRepoClient extends RepoClient {
  @override
  String get branch => GitHubClient.branch;

  String get _base =>
      'https://api.github.com/repos/${GitHubClient.user}/${GitHubClient.repo}';

  @override
  String rawUrl(String path) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    final encoded = clean.split('/').map(Uri.encodeComponent).join('/');
    return 'https://raw.githubusercontent.com/${GitHubClient.user}/${GitHubClient.repo}/$branch/$encoded';
  }

  Map<String, String>? get imageHeaders => GitHubClient.imageHeaders;

  @override
  Future<List<Map<String, dynamic>>> listDir(String path) async {
    final url = Uri.parse('$_base/contents/$path?ref=$branch');
    final res = await http.get(url, headers: GitHubClient.headers);
    if (res.statusCode != 200) throw RepoException(res.statusCode, res.body);
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<({String sha, String base64Content})> getFileBase64(String path) async {
    final url = Uri.parse('$_base/contents/$path?ref=$branch');
    final res = await http.get(url, headers: GitHubClient.headers);
    if (res.statusCode != 200) throw RepoException(res.statusCode, res.body);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      sha: data['sha'] as String,
      base64Content: (data['content'] as String? ?? '').replaceAll('\n', ''),
    );
  }

  @override
  Future<void> putBase64(
    String path,
    String base64Content,
    String message, {
    String? sha,
  }) async {
    final url = Uri.parse('$_base/contents/$path');
    final body = <String, dynamic>{
      'message': message,
      'content': base64Content,
      'branch': branch,
    };
    if (sha != null) body['sha'] = sha;
    final res = await http.put(url, headers: GitHubClient.headers, body: jsonEncode(body));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw RepoException(res.statusCode, res.body);
    }
  }

  @override
  Future<void> removeFile(String path, String sha, String message) async {
    final url = Uri.parse('$_base/contents/$path');
    final res = await http.delete(
      url,
      headers: GitHubClient.headers,
      body: jsonEncode({'message': message, 'sha': sha, 'branch': branch}),
    );
    if (res.statusCode != 200) throw RepoException(res.statusCode, res.body);
  }

  Future<String> getBranchHeadSha() async {
    final url = Uri.parse('$_base/branches/$branch');
    final res = await http.get(url, headers: GitHubClient.headers);
    if (res.statusCode != 200) throw RepoException(res.statusCode, res.body);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['commit'] as Map<String, dynamic>)['sha'] as String;
  }
}
