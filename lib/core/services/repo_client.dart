import 'dart:convert';

/// Abstract low-level CRUD interface for GitHub / Gitee repositories.
///
/// Concrete classes implement [getFileBase64], [listDir], [putBase64],
/// and [removeFile]. All other methods are derived.
abstract class RepoClient {
  String get branch;

  /// Returns the public raw-content URL for a repo-relative [path].
  String rawUrl(String path);

  // ── Primitives (must override) ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listDir(String path);

  /// Fetches a file and returns its SHA and raw base64-encoded content.
  Future<({String sha, String base64Content})> getFileBase64(String path);

  /// Creates ([sha] == null) or updates a file using pre-encoded base64 content.
  Future<void> putBase64(
    String path,
    String base64Content,
    String message, {
    String? sha,
  });

  Future<void> removeFile(String path, String sha, String message);

  // ── Derived convenience methods ───────────────────────────────────────────

  /// Fetches a text file, decoding base64 + UTF-8.
  Future<({String sha, String content})> getFile(String path) async {
    final (:sha, :base64Content) = await getFileBase64(path);
    final content = base64Content.isEmpty
        ? ''
        : utf8.decode(base64.decode(base64Content));
    return (sha: sha, content: content);
  }

  /// Creates or updates a UTF-8 text file.
  Future<void> putFile(
    String path,
    String textContent,
    String message, {
    String? sha,
  }) =>
      putBase64(path, base64Encode(utf8.encode(textContent)), message, sha: sha);

  /// Creates or updates a binary file.
  Future<void> putBytes(
    String path,
    List<int> bytes,
    String message, {
    String? sha,
  }) =>
      putBase64(path, base64Encode(bytes), message, sha: sha);
}

class RepoException implements Exception {
  final int statusCode;
  final String detail;
  RepoException(this.statusCode, this.detail);

  @override
  String toString() => 'RepoException($statusCode): $detail';
}
