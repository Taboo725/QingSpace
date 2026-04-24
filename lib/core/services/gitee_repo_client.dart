import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'gitee_client.dart';
import 'repo_client.dart';

/// Gitee v5 API implementation of [RepoClient].
///
/// Key difference from GitHub: file creation uses POST while updates use PUT.
/// The [putBase64] method dispatches accordingly based on whether [sha] is null.
class GiteeRepoClient extends RepoClient {
  @override
  String get branch => GiteeClient.branch;

  void _log(String method, String path) {
    debugPrint(
      'Gitee $method: https://gitee.com/api/v5/repos/${GiteeClient.user}/${GiteeClient.repo}/contents/$path?ref=$branch',
    );
  }

  String get _base =>
      'https://gitee.com/api/v5/repos/${GiteeClient.user}/${GiteeClient.repo}';

  @override
  String rawUrl(String path) {
    final clean = path.startsWith('/') ? path.substring(1) : path;
    // Web raw URL (/raw/) requires repo to be public; use the API endpoint instead.
    return GiteeClient.appendToken('$_base/raw/$clean?ref=$branch');
  }

  @override
  Future<List<Map<String, dynamic>>> listDir(String path) async {
    _log('listDir', path);
    final url = Uri.parse(
      GiteeClient.appendToken('$_base/contents/$path?ref=$branch'),
    );
    final res = await http.get(url);
    if (res.statusCode != 200) {
      debugPrint('Gitee listDir error ${res.statusCode}: ${res.body}');
      throw RepoException(res.statusCode, res.body);
    }
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<({String sha, String base64Content})> getFileBase64(String path) async {
    _log('getFile', path);
    final url = Uri.parse(
      GiteeClient.appendToken('$_base/contents/$path?ref=$branch'),
    );
    final res = await http.get(url);
    if (res.statusCode != 200) {
      debugPrint('Gitee getFile error ${res.statusCode}: ${res.body}');
      throw RepoException(res.statusCode, res.body);
    }
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

    final http.Response res;
    if (sha != null) {
      body['sha'] = sha;
      res = await http.put(url, headers: GiteeClient.writeHeaders, body: jsonEncode(body));
    } else {
      res = await http.post(url, headers: GiteeClient.writeHeaders, body: jsonEncode(body));
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw RepoException(res.statusCode, res.body);
    }
  }

  @override
  Future<void> removeFile(String path, String sha, String message) async {
    final url = Uri.parse('$_base/contents/$path');
    final res = await http.delete(
      url,
      headers: GiteeClient.writeHeaders,
      body: jsonEncode({'message': message, 'sha': sha, 'branch': branch}),
    );
    if (res.statusCode != 200) throw RepoException(res.statusCode, res.body);
  }

  Future<String> getBranchHeadSha() async {
    final url = Uri.parse(
      GiteeClient.appendToken('$_base/commits?sha=$branch&limit=1'),
    );
    final res = await http.get(url);
    if (res.statusCode != 200) throw RepoException(res.statusCode, res.body);
    final list = jsonDecode(res.body) as List;
    if (list.isEmpty) throw RepoException(0, 'No commits found');
    return (list.first as Map<String, dynamic>)['sha'] as String;
  }
}
