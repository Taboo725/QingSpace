import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/memory_service.dart';
import '../../../core/widgets/fullscreen_photo_page.dart';
import '../../../core/widgets/net_image.dart';

final DateFormat _dateFormat = DateFormat('yyyy.MM.dd');

/// Surfaces one past moment or photo on the dashboard, preferring something
/// recorded on today's date in an earlier year.
class MemoryCard extends StatefulWidget {
  const MemoryCard({super.key});

  @override
  State<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<MemoryCard> {
  final MemoryService _memoryService = MemoryService();
  MemoryItem? _item;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemory();
    AppConfig.debugDateNotifier.addListener(_loadMemory);
    AppConfig.debugModeNotifier.addListener(_loadMemory);
  }

  @override
  void dispose() {
    AppConfig.debugDateNotifier.removeListener(_loadMemory);
    AppConfig.debugModeNotifier.removeListener(_loadMemory);
    super.dispose();
  }

  Future<void> _loadMemory() async {
    if (mounted) setState(() => _isLoading = true);
    final item = await _memoryService.getDailyMemory();
    if (!mounted) return;
    setState(() {
      _item = item;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (!_isLoading && item == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isToday = item?.isOnThisDay ?? false;
    final accentColor = isToday
        ? theme.colorScheme.primary
        : theme.primaryColor;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.primaryColor.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isToday, accentColor, item),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ..._buildContent(item!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isToday, Color accentColor, MemoryItem? item) {
    final date = item?.date;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Icon(
            isToday ? Icons.calendar_today_rounded : Icons.history_edu_rounded,
            size: 16,
            color: accentColor,
          ),
          const SizedBox(width: 8),
          Text(
            isToday ? 'ON THIS DAY' : 'MEMORY LANE',
            style: TextStyle(
              fontFamily: 'Source Han Serif CN',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: accentColor,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          if (date != null)
            Text(
              _dateFormat.format(date),
              style: TextStyle(
                fontFamily: 'Source Han Serif CN',
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildContent(MemoryItem item) {
    final imageUrl = item.imageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    if (!hasImage && item.content.isEmpty) {
      return const [
        Padding(padding: EdgeInsets.all(20), child: Text('这篇记忆没有内容')),
      ];
    }

    return [
      if (hasImage)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 600, minHeight: 200),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullscreenPhotoPage(
                      imageUrl: imageUrl,
                      heroTag: imageUrl,
                    ),
                  ),
                ),
                child: Hero(
                  tag: imageUrl,
                  child: NetImage(
                    imageUrl: imageUrl,
                    borderRadius: BorderRadius.circular(24),
                    fit: BoxFit.cover,
                    // Capped at 800 logical px wide; 1600 covers 2x displays.
                    memCacheWidth: 1600,
                    placeholder: (_, _) => ImageLoadingBox(
                      borderRadius: BorderRadius.circular(24),
                      showSpinner: false,
                    ),
                    errorWidget: (_, _, _) =>
                        const ImageErrorBox(height: 200, compact: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      if (item.content.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Text(
            item.content,
            style: TextStyle(
              fontFamily: 'Source Han Serif CN',
              fontSize: 15,
              height: 1.6,
              color: Colors.grey[800],
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
  }
}
