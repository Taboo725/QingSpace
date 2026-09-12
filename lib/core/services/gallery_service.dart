import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import '../../models/gallery_item.dart';
import 'data_source_manager.dart';
import 'yaml_helper.dart';

/// Reads and writes the photo list stored at `data/gallery.yml`.
class GalleryService {
  static const _yamlPath = 'data/gallery.yml';
  static const _imageDir = 'images/gallery';

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<GalleryItem>> fetchGalleryItems() async {
    try {
      final client = await DataSourceManager.instance.readClient;
      return _parseYaml((await client.getFile(_yamlPath)).content);
    } catch (e) {
      debugPrint('GalleryService fetch error: $e');
      return const [];
    }
  }

  List<GalleryItem> _parseYaml(String content) {
    if (content.trim().isEmpty) return const [];
    try {
      final yaml = loadYaml(content);
      if (yaml is! YamlList) return const [];
      return yaml
          .map((item) => item is Map ? GalleryItem.fromMap(item) : null)
          .whereType<GalleryItem>()
          .where((item) => item.url.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Gallery YAML parse error: $e');
      return const [];
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> addGalleryItem(GalleryItem item, {File? imageFile}) async {
    final url = imageFile != null ? await _uploadImage(imageFile) : item.url;
    final entry = GalleryItem(
      url: url,
      caption: item.caption,
      date: item.date ?? DateTime.now(),
    );
    await _mutate((list) => list..insert(0, entry));
  }

  Future<void> updateGalleryItem(
    GalleryItem oldItem,
    GalleryItem newItem, {
    File? newImageFile,
  }) async {
    final url = newImageFile != null
        ? await _uploadImage(newImageFile)
        : newItem.url;

    await _mutate((list) {
      final index = list.indexWhere((e) => e.url == oldItem.url);
      if (index == -1) throw StateError('Gallery item not found');
      // Preserve the stored date: the editor never surfaces it, so a caller
      // round-tripping an item must not silently drop it.
      list[index] = GalleryItem(
        url: url,
        caption: newItem.caption,
        date: newItem.date ?? list[index].date,
      );
      return list;
    });
  }

  Future<void> deleteGalleryItem(GalleryItem item) async {
    await _mutate((list) => list..removeWhere((e) => e.url == item.url));
    if (!item.url.startsWith('http')) await _deleteImage(item.url);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Read-modify-write of gallery.yml against the current GitHub SHA.
  Future<void> _mutate(
    List<GalleryItem> Function(List<GalleryItem>) change,
  ) async {
    final writeClient = DataSourceManager.instance.writeClient;
    final (:sha, :content) = await writeClient.getFile(_yamlPath);
    final next = change(_parseYaml(content).toList());
    await writeClient.putFile(
      _yamlPath,
      _toYaml(next),
      'Update gallery via app',
      sha: sha,
    );
  }

  Future<String> _uploadImage(File imageFile) async {
    final fileName = p.basename(imageFile.path);
    final repoPath = '$_imageDir/$fileName';
    final bytes = await imageFile.readAsBytes();

    final writeClient = DataSourceManager.instance.writeClient;
    await writeClient.putBytes(
      repoPath,
      bytes,
      'Upload gallery image: $fileName',
      sha: await writeClient.shaOf(repoPath),
    );
    return '/$repoPath';
  }

  Future<void> _deleteImage(String relativePath) async {
    final path = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    try {
      final writeClient = DataSourceManager.instance.writeClient;
      final sha = await writeClient.shaOf(path);
      if (sha == null) return;
      await writeClient.removeFile(path, sha, 'Delete gallery image: $path');
    } catch (e) {
      debugPrint('Error deleting gallery image: $e');
    }
  }

  String _toYaml(List<GalleryItem> items) {
    final buf = StringBuffer();
    for (final item in items) {
      buf
        ..writeln('-')
        ..writeln('  url: ${yamlScalar(item.url)}')
        ..writeln('  caption: ${yamlScalar(item.caption)}');
      if (item.date != null) buf.writeln('  date: ${yamlDate(item.date!)}');
      buf.writeln();
    }
    return buf.toString();
  }
}
