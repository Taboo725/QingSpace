import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:yaml/yaml.dart';
import '../../models/moment.dart';
import 'data_source_manager.dart';
import 'yaml_helper.dart';

/// Reads and writes the moment list stored at `data/moments.yml`.
class MomentsService {
  static const _yamlPath = 'data/moments.yml';
  static const _imageDir = 'images/moments';

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<Moment>> fetchMoments() async {
    try {
      final client = await DataSourceManager.instance.readClient;
      return _parseYaml((await client.getFile(_yamlPath)).content);
    } catch (e) {
      debugPrint('fetchMoments error: $e');
      return const [];
    }
  }

  List<Moment> _parseYaml(String yaml) {
    if (yaml.trim().isEmpty) return const [];
    try {
      final parsed = loadYaml(yaml);
      if (parsed is! YamlList) return const [];
      return parsed
          .map((item) => item is Map ? Moment.tryFromYaml(item) : null)
          .whereType<Moment>()
          .toList();
    } catch (e) {
      debugPrint('Moments parse error: $e');
      return const [];
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> addMoment(Moment moment, {File? imageFile}) async {
    final imagePath = imageFile != null
        ? await _uploadImage(imageFile, moment.date)
        : null;
    await _mutate((list) => list..add(moment.copyWith(image: imagePath)));
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

    final updated = newMoment.copyWith(image: imagePath);
    await _mutate((list) {
      list[_indexOf(list, oldMoment)] = updated;
      return list;
    });
  }

  /// Deletes a moment. Returns false when the entry was removed but its image
  /// could not be — the moment is gone either way, only an orphan file remains.
  Future<bool> deleteMoment(Moment moment) async {
    String? imagePath;
    await _mutate((list) {
      final index = _indexOf(list, moment);
      imagePath = list[index].image;
      return list..removeAt(index);
    });

    final path = imagePath;
    if (path == null || path.isEmpty || path.startsWith('http')) return true;
    try {
      await _deleteRepoFile(path);
      return true;
    } catch (e) {
      debugPrint('Moment image cleanup failed for $path: $e');
      return false;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// Read-modify-write of moments.yml against the current GitHub SHA.
  Future<void> _mutate(List<Moment> Function(List<Moment>) change) async {
    final writeClient = DataSourceManager.instance.writeClient;
    final (:sha, :content) = await writeClient.getFile(_yamlPath);
    final next = change(_parseYaml(content).toList());
    await writeClient.putFile(
      _yamlPath,
      momentsToYamlString(next),
      'Update moments.yml via app',
      sha: sha,
    );
  }

  int _indexOf(List<Moment> list, Moment moment) {
    final index = list.indexWhere((m) => m.date.isAtSameMomentAs(moment.date));
    if (index == -1) throw StateError('Moment not found');
    return index;
  }

  Future<String> _uploadImage(File file, DateTime date) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last;
    final repoPath = '$_imageDir/${_imageName(date, DateTime.now())}.$ext';
    await DataSourceManager.instance.writeClient.putBytes(
      repoPath,
      bytes,
      'Upload image $repoPath',
    );
    return repoPath;
  }

  Future<void> _deleteRepoFile(String relativePath) async {
    final path = relativePath.startsWith('/')
        ? relativePath.substring(1)
        : relativePath;
    final writeClient = DataSourceManager.instance.writeClient;
    final sha = await writeClient.shaOf(path);
    if (sha == null) return;
    await writeClient.removeFile(path, sha, 'Delete image $path');
  }

  /// Keeps the `yyyy.MM.dd_HHmmss` filename in step with an edited date.
  /// Falls back to the original path when the copy fails, so a moment never
  /// ends up pointing at a file that does not exist.
  Future<String> _renameMomentImage(String oldPath, DateTime newDate) async {
    if (!oldPath.startsWith('$_imageDir/')) return oldPath;

    final oldName = oldPath.split('/').last;
    final tail = _datedPrefix.firstMatch(oldName)?.group(1) ?? oldName;
    final newPath = '$_imageDir/${_dateStamp(newDate)}_$tail';
    if (newPath == oldPath) return oldPath;

    final writeClient = DataSourceManager.instance.writeClient;
    final (:sha, :base64Content) = await writeClient.getFileBase64(oldPath);

    try {
      await writeClient.putBase64(
        newPath,
        base64Content,
        'Rename moment image to ${newPath.split('/').last}',
      );
    } catch (e) {
      debugPrint('Moment image rename failed: $e');
      return oldPath;
    }

    await writeClient.removeFile(
      oldPath,
      sha,
      'Remove old moment image $oldName',
    );
    return newPath;
  }

  static final RegExp _datedPrefix = RegExp(r'^\d{4}\.\d{2}\.\d{2}_(.+)$');

  static String _dateStamp(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.'
      '${d.day.toString().padLeft(2, '0')}';

  static String _imageName(DateTime date, DateTime now) =>
      '${_dateStamp(date)}_'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';
}

/// Serialises moments back to the YAML list stored in the repo.
String momentsToYamlString(List<Moment> moments) {
  final buffer = StringBuffer();
  for (final moment in moments) {
    buffer
      ..writeln('-')
      ..writeln('  date: ${yamlTimestamp(moment.date)}')
      ..writeln('  content: ${yamlScalar(moment.content)}');
    final image = moment.image;
    if (image != null && image.isNotEmpty) {
      buffer.writeln('  image: ${yamlScalar(image)}');
    }
    final mood = moment.mood;
    if (mood != null && mood.isNotEmpty) {
      buffer.writeln('  mood: ${yamlScalar(mood)}');
    }
  }
  return buffer.toString();
}
