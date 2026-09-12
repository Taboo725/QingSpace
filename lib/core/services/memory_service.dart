import 'dart:math';
import '../../models/gallery_item.dart';
import '../../models/moment.dart';
import '../config/app_config.dart';
import 'gallery_service.dart';
import 'moment_service.dart';

enum MemorySource { moment, gallery }

class MemoryItem {
  final String content;
  final String? imageUrl;
  final DateTime? date;
  final MemorySource source;

  /// True when [date] falls on today's month and day in a previous year.
  final bool isOnThisDay;

  const MemoryItem({
    required this.content,
    this.imageUrl,
    this.date,
    required this.source,
    required this.isOnThisDay,
  });
}

/// Picks one memory to surface on the dashboard, preferring entries recorded on
/// today's date in an earlier year.
class MemoryService {
  MemoryService({
    GalleryService? galleryService,
    MomentsService? momentsService,
    Random? random,
  }) : _galleryService = galleryService ?? GalleryService(),
       _momentsService = momentsService ?? MomentsService(),
       _random = random ?? Random();

  final GalleryService _galleryService;
  final MomentsService _momentsService;
  final Random _random;

  Future<MemoryItem?> getDailyMemory() async {
    final now = AppConfig.effectiveNow;

    // Both services already swallow their own errors and return an empty list.
    final results = await Future.wait([
      _momentsService.fetchMoments(),
      _galleryService.fetchGalleryItems(),
    ]);
    final moments = results[0] as List<Moment>;
    final gallery = results[1] as List<GalleryItem>;

    final all = <MemoryItem>[
      for (final m in moments)
        MemoryItem(
          content: m.content,
          imageUrl: m.image,
          date: m.date,
          source: MemorySource.moment,
          isOnThisDay: _isSameDayOfYear(m.date, now),
        ),
      for (final g in gallery)
        MemoryItem(
          content: g.caption,
          imageUrl: g.url,
          date: g.date,
          source: MemorySource.gallery,
          isOnThisDay: _isSameDayOfYear(g.date, now),
        ),
    ];

    final onThisDay = all.where((item) => item.isOnThisDay).toList();
    final pool = onThisDay.isNotEmpty ? onThisDay : all;
    return pool.isEmpty ? null : pool[_random.nextInt(pool.length)];
  }

  static bool _isSameDayOfYear(DateTime? date, DateTime now) =>
      date != null && date.month == now.month && date.day == now.day;
}
