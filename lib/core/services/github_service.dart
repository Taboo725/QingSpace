import 'package:flutter/foundation.dart';
import '../../models/post.dart';
import 'data_source_manager.dart';
import 'repo_client.dart';

class GithubService {
  static const _postsPath = 'data/posts';

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<Post>> fetchFiles({String? category}) async {
    final client = DataSourceManager.instance.client;
    final entries = (await client.listDir(_postsPath))
        .where((item) => (item['name'] as String).endsWith('.md'))
        .map((item) => Post.fromFile(item))
        .toList();

    final posts = <Post>[];
    await Future.wait(entries.map((entry) async {
      try {
        final (:sha, :content) = await client.getFile(entry.path);
        final post = Post.fromFile(
          {'name': entry.path.split('/').last, 'path': entry.path, 'sha': sha},
          content: content,
        );
        if (category == null || _matchesCategory(content, category)) {
          posts.add(post);
        }
      } catch (e) {
        debugPrint('Error loading ${entry.path}: $e');
        if (category == null) posts.add(entry);
      }
    }));

    posts.sort((a, b) => b.date.compareTo(a.date));
    return posts;
  }

  bool _matchesCategory(String content, String category) {
    final lower = content.toLowerCase();
    final cat = category.toLowerCase();
    return lower.contains('category: $cat') ||
        lower.contains('categories:\n- $cat') ||
        lower.contains('categories: [$cat]');
  }

  Future<String> fetchFileContent(String path) async {
    final (:sha, :content) = await DataSourceManager.instance.client.getFile(path);
    return content;
  }

  // ── Write ─────────────────────────────────────────────────────────────────
  // All mutations go to GitHub (writeClient) regardless of the active read
  // source, so Gitee sync only needs to flow one way (GitHub→Gitee) and
  // conflicts become impossible.

  Future<void> createFile(String fileName, String content) =>
      DataSourceManager.instance.writeClient.putFile(
        '$_postsPath/$fileName',
        content,
        'Create post: $fileName',
      );

  // sha parameter is intentionally ignored — we always re-fetch the current
  // GitHub SHA to avoid cross-source stale SHA conflicts.
  Future<void> updateFile(String filePath, String content, String sha) async {
    final cleanPath = filePath.startsWith('$_postsPath/')
        ? filePath
        : '$_postsPath/$filePath';
    final writeClient = DataSourceManager.instance.writeClient;
    final current = await writeClient.getFileBase64(cleanPath);
    return writeClient.putFile(
      cleanPath,
      content,
      'Update post: ${cleanPath.split('/').last}',
      sha: current.sha,
    );
  }

  Future<void> deleteFile(String filePath, String sha) async {
    final cleanPath = filePath.startsWith('$_postsPath/')
        ? filePath
        : '$_postsPath/$filePath';
    final writeClient = DataSourceManager.instance.writeClient;
    final current = await writeClient.getFileBase64(cleanPath);
    return writeClient.removeFile(
      cleanPath,
      current.sha,
      'Delete post: ${cleanPath.split('/').last}',
    );
  }

  Future<void> deleteFileByPath(String path) async {
    try {
      final writeClient = DataSourceManager.instance.writeClient;
      final (:sha, :base64Content) = await writeClient.getFileBase64(path);
      await writeClient.removeFile(path, sha, 'Delete asset: $path');
    } on RepoException catch (e) {
      if (e.statusCode == 404) return;
      rethrow;
    }
  }

  Future<void> uploadImage(String fileName, List<int> bytes) async {
    final writeClient = DataSourceManager.instance.writeClient;
    final repoPath = 'images/posts/$fileName';
    String? sha;
    try {
      final info = await writeClient.getFileBase64(repoPath);
      sha = info.sha;
    } on RepoException catch (_) {}
    await writeClient.putBytes(repoPath, bytes, 'Upload image: $fileName', sha: sha);
  }

}
