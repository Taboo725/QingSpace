import '../../../core/widgets/cdn_image.dart';
import '../../../core/widgets/fullscreen_photo_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qing_space/core/services/memory_service.dart';
import 'package:qing_space/core/config/app_config.dart';

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
    setState(() => _isLoading = true);
    final item = await _memoryService.getDailyMemory();
    if (mounted) {
      setState(() {
        _item = item;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _item == null) {
      return const SizedBox.shrink();
    }

    final isToday = _item?.isOnThisDay ?? false;
    final title = _isLoading
        ? "Memory Lane"
        : (isToday ? "On This Day" : "Memory Lane");

    final accentColor = isToday
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).primaryColor;

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
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Row(
                  children: [
                    Icon(
                      isToday
                          ? Icons.calendar_today_rounded
                          : Icons.history_edu_rounded,
                      size: 16,
                      color: accentColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Source Han Serif CN',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                        letterSpacing: 1,
                      ),
                    ),
                    const Spacer(),
                    if (!_isLoading && _item!.date != null)
                      Text(
                        DateFormat('yyyy.MM.dd').format(_item!.date!),
                        style: TextStyle(
                          fontFamily: 'Source Han Serif CN',
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                  ],
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_isLoading) ...[
                if (_item!.imageUrl != null && _item!.imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 600,
                          minHeight: 200,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullscreenPhotoPage(
                                  imageUrl: _item!.imageUrl!,
                                  heroTag: _item!.imageUrl!,
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: _item!.imageUrl!,
                            child: NetImage(
                              borderRadius: BorderRadius.circular(24),
                              imageUrl: _item!.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 200,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) {
                                debugPrint(
                                  "Image failed to load: $url, error: $error",
                                );
                                return Container(
                                  height: 200,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "图片加载失败",
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (_item!.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Text(
                      _item!.content,
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

                if (_item!.content.isEmpty &&
                    (_item!.imageUrl == null || _item!.imageUrl!.isEmpty))
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("这篇记忆没有内容"),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
