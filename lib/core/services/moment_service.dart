import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:yaml/yaml.dart';
import '../../models/moment.dart';
import 'data_source_manager.dart';
import 'yaml_helper.dart';

class MomentsService {
  static const _yamlPath = 'data/moments.yml';

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<Moment>> fetchMoments() async {
    try {
      final (:sha, :content) =
          await DataSourceManager.instance.client.getFile(_yamlPath);
      return _parseYaml(content);
    } catch (e) {
      debugPrint('fetchMoments error: $e');
      return [];
    }
  }

  List<Moment> _parseYaml(String yaml) {
    try {
      final parsed = loadYaml(yaml);
      if (parsed is! YamlList) return [];
      return parsed
          .map((item) {
            try {
              if (item is Map || item is YamlMap) return Moment.fromYaml(item);
            } catch (_) {}
            return null;
          })
          .whereType<Moment>()
          .toList();
    } catch (e) {
      debugPrint('Moments parse error: $e');
      return [];
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> addMoment(Moment moment, {File? imageFile}) async {
    final imagePath =
        imageFile != null ? await _uploadImage(imageFile, moment.date) : null;

    final fullMoment = Moment(
      date: moment.date,
      content: moment.content,
      image: imagePath,
      mood: moment.mood,
    );

    final writeClient = DataSourceManager.instance.writeClient;
    final (:sha, :content) = await writeClient.getFile(_yamlPath);
    final list = _parseYaml(content)..add(fullMoment);
    await _saveAll(list, sha);
  }

  Future<void> updateMoment(
    Moment oldMoment,
    Moment newMoment, {
    File? newImage,
  }) async {
    String? imagePath;
    if (newImage != null) {
      imagePath = await _uploadImage(newImage, newMoment.date);
    } else {
      imagePath = newMoment.image;
      if (imagePath != null &&
          imagePath.isNotEmpty &&
          !oldMoment.date.isAtSameMomentAs(newMoment.date)) {
        imagePath = await _renameMomentImage(imagePath, newMoment.date);
      }
    }

    final finalMoment = Moment(
      date: newMoment.date,
      content: newMoment.content,
      image: imagePath,
      mood: newMoment.mood,
    );

    final writeClient = DataSourceManager.instance.writeClient;
    final (:sha, :content) = await writeClient.getFile(_yamlPath);
    final list = _parseYaml(content);
    final index =
        list.indexWhere((m) => m.date.isAtSameMomentAs(oldMoment.date));
    if (index == -1) throw Exception('Moment not found');
    list[index] = finalMoment;
    await _saveAll(list, sha);
  }

  Future<void> deleteMoment(Moment moment) async {
    final writeClient = DataSourceManager.instance.writeClient;
    final (:sha, :content) = await writeClient.getFile(_yamlPath);
    final list = _parseYaml(content);
    final index =
        list.indexWhere((m) => m.date.isAtSameMomentAs(moment.date));
    if (index == -1) throw Exception('Moment not found');

    final imagePath = list[index].image;
    list.removeAt(index);
    await _saveAll(list, sha);

    if (imagePath != null &&
        imagePath.isNotEmpty &&
        !imagePath.startsWith('http')) {
      try {
        await _deleteRepoFile(imagePath);
      } catch (e) {
        throw Exception('Moment deleted but image removal failed: $e');
      }
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _saveAll(List<Moment> moments, String sha) =>
      DataSourceManager.instance.writeClient.putFile(
        _yamlPath,
        momentsToYamlString(moments),
        'Update moments.yml via app',
        sha: sha,
      );

  Future<String> _uploadImage(File file, DateTime date) async {
    final bytes = await file.readAsBytes();
    final datePrefix = DateFormat('yyyy.MM.dd').format(date);
    final timeSuffix = DateFormat('HHmmss').format(DateTime.now());
    final ext = file.path.split('.').last;
    final fileName = '${datePrefix}_$timeSuffix.$ext';
    final repoPath = 'images/moments/$fileName';
    await DataSourceManager.instance.writeClient.putBytes(
      repoPath,
      bytes,
      'Upload image $fileName',
    );
    return repoPath;
  }

  Future<void> _deleteRepoFile(String relativePath) async {
    final path =
        relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
    final writeClient = DataSourceManager.instance.writeClient;
    final (:sha, :base64Content) = await writeClient.getFileBase64(path);
    await writeClient.removeFile(path, sha, 'Delete image $path');
  }

  Future<String> _renameMomentImage(String oldPath, DateTime newDate) async {
    if (!oldPath.startsWith('images/moments/')) return oldPath;

    final oldName = oldPath.split('/').last;
    final datePrefix = DateFormat('yyyy.MM.dd').format(newDate);
    final tail =
        RegExp(r'^\d{4}\.\d{2}\.\d{2}_(.+)$').firstMatch(oldName)?.group(1) ??
        oldName;
    final newName = '${datePrefix}_$tail';
    final newPath = 'images/moments/$newName';
    if (newPath == oldPath) return oldPath;

    final writeClient = DataSourceManager.instance.writeClient;
    final (:sha, :base64Content) = await writeClient.getFileBase64(oldPath);

    try {
      await writeClient.putBase64(
        newPath,
        base64Content,
        'Rename moment image to $newName',
      );
    } catch (_) {
      return oldPath;
    }

    await writeClient.removeFile(oldPath, sha, 'Remove old moment image $oldName');
    return newPath;
  }

  String getImageUrl(String relativePath) {
    if (relativePath.startsWith('http')) return relativePath;
    return DataSourceManager.instance.rawUrl(relativePath);
  }
}
