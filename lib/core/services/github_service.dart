import 'package:flutter/foundation.dart';
import '../../models/post.dart';
import 'data_source_manager.dart';
import 'repo_client.dart';

/// Reads and writes the Markdown posts under `data/posts/`.
///
/// Reads go through the active data source; every mutation goes to GitHub so
/// the mirror only ever has to flow one way and conflicts cannot arise.
class GithubService {
  static const _postsPath = 'data/posts';
  static const _imagesPath = 'images/posts';

  /// Maximum number of post bodies fetched at once. The repo API rate-limits
  /// aggressively, and an unbounded `Future.wait` over a large post list both
  /// trips that limit and starves image requests on the same connection pool.
  static const _maxConcurrentFetches = 6;

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Lists posts, optionally keeping only those whose frontmatter declares
  /// [category]. Bodies are fetched in bounded batches.
  Future<List<Post>> fetchFiles({String? category}) async {
    final client = await DataSourceManager.instance.readClient;
    final entries = (await client.listDir(_postsPath))
        .where(
          (item) =>
              (item['name'] as String?)?.toLowerCase().endsWith('.md') ?? false,
        )
        .toList();

    final wanted = category?.toLowerCase();
    final posts = <Post>[];

    for (var i = 0; i < entries.length; i += _maxConcurrentFetches) {
      final batch = entries.skip(i).take(_maxConcurrentFetches);
      final loaded = await Future.wait(
        batch.map((entry) => _loadPost(client, entry)),
      );
      for (final post in loaded) {
        if (post == null) continue;
        if (wanted == null ||
            Post.categoriesOf(post.content).contains(wanted)) {
          posts.add(post);
        }
      }
    }

    posts.sort((a, b) => b.date.compareTo(a.date));
    return posts;
  }

  /// Number of posts in the repo, without downloading any bodies.
  Future<int> countPosts() async {
    final client = await DataSourceManager.instance.readClient;
    return (await client.listDir(_postsPath))
        .where(
          (item) =>
              (item['name'] as String?)?.toLowerCase().endsWith('.md') ?? false,
        )
        .length;
  }

  Future<Post?> _loadPost(RepoClient client, Map<String, dynamic> entry) async {
    try {
      final (:sha, :content) = await client.getFile(entry['path'] as String);
      return Post.fromFile({...entry, 'sha': sha}, content: content);
    } catch (e) {
      debugPrint('Error loading ${entry['path']}: $e');
      // Keep the stub so the post still appears in the unfiltered list; a
      // category filter cannot be evaluated without a body, so drop it there.
      return Post.fromFile(entry);
    }
  }

  Future<String> fetchFileContent(String path) async {
    final client = await DataSourceManager.instance.readClient;
    return (await client.getFile(path)).content;
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> createFile(String fileName, String content) => DataSourceManager
      .instance
      .writeClient
      .putFile('$_postsPath/$fileName', content, 'Create post: $fileName');

  /// Updates a post. The current GitHub SHA is always re-fetched rather than
  /// trusting a caller-supplied one, which may come from the Gitee mirror and
  /// therefore be stale.
  Future<void> updateFile(String filePath, String content) async {
    final path = _postPath(filePath);
    final writeClient = DataSourceManager.instance.writeClient;
    final sha = await writeClient.shaOf(path);
    return writeClient.putFile(
      path,
      content,
      'Update post: ${path.split('/').last}',
      sha: sha,
    );
  }

  Future<void> deleteFile(String filePath) async {
    final path = _postPath(filePath);
    final writeClient = DataSourceManager.instance.writeClient;
    final sha = await writeClient.shaOf(path);
    if (sha == null) return; // already gone
    return writeClient.removeFile(
      path,
      sha,
      'Delete post: ${path.split('/').last}',
    );
  }

  /// Deletes any repo file by path; a missing file is not an error.
  Future<void> deleteFileByPath(String path) async {
    final writeClient = DataSourceManager.instance.writeClient;
    final sha = await writeClient.shaOf(path);
    if (sha == null) return;
    await writeClient.removeFile(path, sha, 'Delete asset: $path');
  }

  Future<void> uploadImage(String fileName, List<int> bytes) async {
    final writeClient = DataSourceManager.instance.writeClient;
    final repoPath = '$_imagesPath/$fileName';
    await writeClient.putBytes(
      repoPath,
      bytes,
      'Upload image: $fileName',
      sha: await writeClient.shaOf(repoPath),
    );
  }

  static String _postPath(String filePath) =>
      filePath.startsWith('$_postsPath/') ? filePath : '$_postsPath/$filePath';
}
