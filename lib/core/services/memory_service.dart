import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../models/gallery_item.dart';
import '../../models/moment.dart';
import '../config/app_config.dart';
import 'gallery_service.dart';
import 'moment_service.dart';

class MemoryItem {
  final String content;
  final String? imageUrl;
  final DateTime? date;
  final String type; // 'moment' or 'gallery'
  final bool isOnThisDay;

  MemoryItem({
    required this.content,
    this.imageUrl,
    this.date,
    required this.type,
    required this.isOnThisDay,
  });
}

class MemoryService {
  final _galleryService = GalleryService();
  final _momentsService = MomentsService();
  final _random = Random();

  Future<MemoryItem?> getDailyMemory() async {
    final now = AppConfig.effectiveNow;

    List<Moment> moments = [];
    List<GalleryItem> gallery = [];

    await Future.wait([
      _momentsService.fetchMoments().then((v) => moments = v).onError((e, _) {
        debugPrint('MemoryService: moments error: $e');
        return [];
      }),
      _galleryService.fetchGalleryItems().then((v) => gallery = v).onError((e, _) {
        debugPrint('MemoryService: gallery error: $e');
        return [];
      }),
    ]);

    final onThisDay = <MemoryItem>[];
    final all = <MemoryItem>[];

    for (final m in moments) {
      final sameDay = m.date.month == now.month && m.date.day == now.day;
      final item = MemoryItem(
        content: m.content,
        imageUrl: m.image,
        date: m.date,
        type: 'moment',
        isOnThisDay: sameDay,
      );
      if (sameDay) onThisDay.add(item);
      all.add(item);
    }

    for (final g in gallery) {
      final sameDay = g.date != null &&
          g.date!.month == now.month &&
          g.date!.day == now.day;
      final item = MemoryItem(
        content: g.caption,
        imageUrl: g.url,
        date: g.date,
        type: 'gallery',
        isOnThisDay: sameDay,
      );
      if (sameDay) onThisDay.add(item);
      all.add(item);
    }

    if (onThisDay.isNotEmpty) {
      return onThisDay[_random.nextInt(onThisDay.length)];
    }
    if (all.isNotEmpty) {
      return all[_random.nextInt(all.length)];
    }
    return null;
  }
}
