import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../../models/gallery_item.dart';
import 'data_source_manager.dart';
import 'repo_client.dart';

class GalleryService {
  static const _yamlPath = 'data/gallery.yml';

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<GalleryItem>> fetchGalleryItems({bool forceFresh = false}) async {
    try {
      final (:sha, :content) =
          await DataSourceManager.instance.client.getFile(_yamlPath);
      return _parseYaml(content);
    } catch (e) {
      debugPrint('GalleryService fetch error: $e');
      return [];
    }
  }

  List<GalleryItem> _parseYaml(String content) {
    if (content.isEmpty) return [];
    try {
      final dynamic yaml = loadYaml(content);
      if (yaml is! YamlList) return [];
      return yaml
          .map((item) {
            if (item is Map || item is YamlMap) {
              return GalleryItem.fromMap(Map<String, dynamic>.from(item as Map));
            }
            return null;
          })
          .whereType<GalleryItem>()
          .toList();
    } catch (e) {
      debugPrint('Gallery YAML parse error: $e');
      return [];
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> addGalleryItem(GalleryItem item, {File? imageFile}) async {
    final imageUrl =
        imageFile != null ? await _uploadImage(imageFile) : item.url;

    final writeClient = DataSourceManager.instance.writeClient;
    final (:sha, :content) = await writeClient.getFile(_yamlPath);
    final list = _parseYaml(content);
    list.insert(0, GalleryItem(url: imageUrl, caption: item.caption));
    await _saveAllItems(list, sha);
  }

  Future<void> updateGalleryItem(
    GalleryItem oldItem,
    GalleryItem newItem, {
    File? newImageFile,
  }) async {
    final newUrl =
        newImageFile != null ? await _uploadImage(newImageFile) : newItem.url;

    final writeClient = DataSourceManager.instance.writeClient;
    final (:sha, :content) = await writeClient.getFile(_yamlPath);
    final list = _parseYaml(content);
    final index = list.indexWhere((e) => e.url == oldItem.url);
    if (index == -1) throw Exception('Gallery item not found');
    list[index] = GalleryItem(url: newUrl, caption: newItem.caption);
    await _saveAllItems(list, sha);
  }

  Future<void> deleteGalleryItem(GalleryItem item) async {
    final writeClient = DataSourceManager.instance.writeClient;
    final (:sha, :content) = await writeClient.getFile(_yamlPath);
    final list = _parseYaml(content);
    list.removeWhere((e) => e.url == item.url);
    await _saveAllItems(list, sha);

    if (item.url.startsWith('/')) {
      await _deleteImage(item.url);
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<String> _uploadImage(File imageFile) async {
    final fileName = p.basename(imageFile.path);
    final repoPath = 'images/gallery/$fileName';
    final bytes = await imageFile.readAsBytes();

    final writeClient = DataSourceManager.instance.writeClient;
    String? sha;
    try {
      final info = await writeClient.getFileBase64(repoPath);
      sha = info.sha;
    } on RepoException catch (_) {}

    await writeClient.putBytes(repoPath, bytes, 'Upload gallery image: $fileName', sha: sha);
    return '/images/gallery/$fileName';
  }

  Future<void> _deleteImage(String relativePath) async {
    final clean = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    try {
      final writeClient = DataSourceManager.instance.writeClient;
      final (:sha, :base64Content) = await writeClient.getFileBase64(clean);
      await writeClient.removeFile(clean, sha, 'Delete gallery image: $clean');
    } catch (e) {
      debugPrint('Error deleting gallery image: $e');
    }
  }

  Future<void> _saveAllItems(List<GalleryItem> items, String sha) =>
      DataSourceManager.instance.writeClient.putFile(
        _yamlPath,
        _toYaml(items),
        'Update gallery via app',
        sha: sha,
      );

  String _toYaml(List<GalleryItem> items) {
    final buf = StringBuffer();
    for (final item in items) {
      buf.writeln('-');
      buf.writeln('  url: ${item.url}');
      buf.writeln('  caption: ${jsonEncode(item.caption)}');
      buf.writeln();
    }
    return buf.toString();
  }
}
