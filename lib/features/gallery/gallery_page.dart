import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../core/services/data_source_manager.dart';
import '../../core/services/gallery_service.dart';
import '../../core/widgets/net_image.dart';
import '../../core/widgets/page_state_widget.dart';
import '../../core/widgets/photo_zoom.dart';
import '../../models/gallery_item.dart';
import 'gallery_editor_page.dart';

// Thumbnail width in physical pixels, used as the ResizeImage cache key
// everywhere. It must be identical in the aspect-ratio probe, the grid image,
// the Hero shuttle and the photo-view placeholder so they all share one decoded
// bitmap — that is what removes the grey flash when returning from the viewer.
const int _kThumbWidth = 600;

/// Aspect ratios (url → width/height) resolved so far, so a revisit lays the
/// masonry grid out correctly on the first frame.
final _aspectRatioCache = <String, double>{};

/// The single thumbnail provider for [resolvedUrl]. Shared by every call site.
ResizeImage _thumbProviderFor(String resolvedUrl) => ResizeImage(
  CachedNetworkImageProvider(
    resolvedUrl,
    headers: DataSourceManager.instance.imageHeaders,
  ),
  width: _kThumbWidth,
);

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  final GalleryService _service = GalleryService();
  List<GalleryItem> _items = const [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = _items.isEmpty;
      _hasError = false;
    });
    try {
      final items = await _service.fetchGalleryItems();
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _addPhoto() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GalleryEditorPage()),
    );
    if (result == true) await _loadItems();
  }

  Future<void> _openViewer(int index) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryPhotoViewPage(
          items: _items,
          initialIndex: index,
          service: _service,
        ),
      ),
    );
    if (result == true) await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPhoto,
        tooltip: '上传照片',
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError || _items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadItems,
        child: PageStateWidget.pullToRefreshBody(
          context,
          _hasError
              ? PageStateWidget.error(onRetry: _loadItems)
              : PageStateWidget.empty(
                  message: '暂无照片',
                  icon: Icons.photo_library_outlined,
                ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadItems,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final (crossAxisCount, padding) = _gridMetrics(constraints.maxWidth);
          return MasonryGridView.count(
            key: const PageStorageKey('gallery_grid'),
            cacheExtent: 1200,
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
            itemCount: _items.length,
            itemBuilder: (context, index) => _GalleryGridItem(
              key: ValueKey(_items[index].url),
              item: _items[index],
              onTap: () => _openViewer(index),
            ),
          );
        },
      ),
    );
  }

  /// Column count and horizontal padding for a grid [width] logical pixels wide.
  static (int, double) _gridMetrics(double width) {
    if (width > 900) {
      return (4, ((width - 1200) / 2).clamp(24, double.infinity));
    }
    if (width > 600) return (3, 24);
    return (2, 16);
  }
}

// ---------------------------------------------------------------------------
// Grid item
// ---------------------------------------------------------------------------

class _GalleryGridItem extends StatefulWidget {
  final GalleryItem item;
  final VoidCallback onTap;

  const _GalleryGridItem({super.key, required this.item, required this.onTap});

  @override
  State<_GalleryGridItem> createState() => _GalleryGridItemState();
}

class _GalleryGridItemState extends State<_GalleryGridItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  ImageStream? _stream;
  ImageStreamListener? _streamListener;

  String get _resolvedUrl => NetImage.resolveUrl(widget.item.url);

  ResizeImage get _thumbProvider => _thumbProviderFor(_resolvedUrl);

  @override
  void initState() {
    super.initState();
    _resolveAspectRatio();
  }

  @override
  void didUpdateWidget(_GalleryGridItem old) {
    super.didUpdateWidget(old);
    if (old.item.url != widget.item.url) {
      _cleanupStream();
      _resolveAspectRatio();
    }
  }

  @override
  void dispose() {
    _cleanupStream();
    super.dispose();
  }

  /// Loads the thumbnail through the shared provider, so by the time the aspect
  /// ratio is known the bitmap is already decoded and the grid can swap from
  /// spinner to image without an intermediate blank frame.
  void _resolveAspectRatio() {
    if (_aspectRatioCache.containsKey(widget.item.url)) return;
    final stream = _thumbProvider.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, synchronousCall) {
      _aspectRatioCache[widget.item.url] = info.image.width / info.image.height;
      _cleanupStream();
      if (mounted && !synchronousCall) setState(() {});
    }, onError: (_, _) => _cleanupStream());
    _stream = stream;
    _streamListener = listener;
    stream.addListener(listener);
  }

  void _cleanupStream() {
    final listener = _streamListener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _streamListener = null;
  }

  /// Hero shuttle. Flying the full-resolution image means it decodes from the
  /// disk cache during the ~300 ms animation and is usually ready when the
  /// viewer appears; the cached thumbnail stands in until then, so the flight
  /// is never blank and never a stretched low-res frame.
  Widget _buildShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) => _FullResWithThumbPlaceholder(resolvedUrl: _resolvedUrl);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final item = widget.item;
    final aspectRatio = _aspectRatioCache[item.url];

    // With the ratio known the tile size is stable from the first frame and the
    // decoded thumbnail is already cached, so `frameBuilder` hands back the
    // image synchronously. Without it, reserve a fixed height for the masonry
    // layout to size on.
    Widget image = Image(
      image: _thumbProvider,
      fit: BoxFit.cover,
      frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
          (wasSynchronouslyLoaded || frame != null)
          ? child
          : ImageLoadingBox(
              height: aspectRatio == null ? 200 : null,
              showSpinner: aspectRatio == null,
            ),
      errorBuilder: (_, _, _) => ImageErrorBox(
        height: aspectRatio == null ? 200 : null,
        compact: true,
      ),
    );
    if (aspectRatio != null) {
      image = AspectRatio(aspectRatio: aspectRatio, child: image);
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: item.url,
            flightShuttleBuilder: _buildShuttle,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: image,
            ),
          ),
          const SizedBox(height: 12),
          if (item.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.caption,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: 'Source Han Serif CN',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  height: 1.2,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helper: full-res image with thumbnail placeholder
// ---------------------------------------------------------------------------

/// Shows the full-resolution image, falling back to the already-cached
/// thumbnail while it decodes. Used by both the Hero shuttle and the viewer so
/// the transition never shows a black frame.
class _FullResWithThumbPlaceholder extends StatelessWidget {
  final String resolvedUrl;

  const _FullResWithThumbPlaceholder({required this.resolvedUrl});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      httpHeaders: DataSourceManager.instance.imageHeaders,
      fit: BoxFit.contain,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) =>
          Image(image: _thumbProviderFor(resolvedUrl), fit: BoxFit.contain),
      errorWidget: (_, _, _) => const ColoredBox(
        color: Colors.black,
        child: ImageErrorBox(onDarkBackground: true),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo viewer
// ---------------------------------------------------------------------------

class GalleryPhotoViewPage extends StatefulWidget {
  final List<GalleryItem> items;
  final int initialIndex;
  final GalleryService service;

  const GalleryPhotoViewPage({
    super.key,
    required this.items,
    this.initialIndex = 0,
    required this.service,
  });

  @override
  State<GalleryPhotoViewPage> createState() => _GalleryPhotoViewPageState();
}

class _GalleryPhotoViewPageState extends State<GalleryPhotoViewPage> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _currentIndex = widget.initialIndex;
  final Map<int, PhotoViewController> _controllers = {};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) =>
      applyScrollZoom(event, _controllers[_currentIndex]);

  Future<void> _editCurrent() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GalleryEditorPage(editItem: widget.items[_currentIndex]),
      ),
    );
    if (result == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteCurrent() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text(
          'Are you sure you want to delete this photo? This will remove it from GitHub.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.service.deleteGalleryItem(widget.items[_currentIndex]);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Listener(
            onPointerSignal: _onPointerSignal,
            child: PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              pageController: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              builder: (context, index) {
                final item = widget.items[index];
                return PhotoViewGalleryPageOptions.customChild(
                  controller: _controllers.putIfAbsent(
                    index,
                    () => PhotoViewController(),
                  ),
                  heroAttributes: PhotoViewHeroAttributes(tag: item.url),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  child: _FullResWithThumbPlaceholder(
                    resolvedUrl: NetImage.resolveUrl(item.url),
                  ),
                );
              },
            ),
          ),

          // Top controls
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 30,
                    ),
                    onSelected: (value) =>
                        value == 'edit' ? _editCurrent() : _deleteCurrent(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // Bottom gradient
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: SizedBox.expand(),
              ),
            ),
          ),

          // Caption
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Text(
                widget.items[_currentIndex].caption,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Source Han Serif CN',
                  fontSize: 18,
                  shadows: [Shadow(offset: Offset(0, 1), blurRadius: 4)],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
