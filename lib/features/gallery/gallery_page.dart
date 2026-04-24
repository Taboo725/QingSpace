import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../../core/services/data_source_manager.dart';
import '../../core/widgets/cdn_image.dart';
import '../../core/widgets/page_state_widget.dart';
import '../../models/gallery_item.dart';
import '../../core/services/gallery_service.dart';
import 'gallery_editor_page.dart';

// Thumbnail physical pixel width used as the ResizeImage cache key everywhere.
// Must be identical in _resolveAspectRatio, _buildGridImage, shuttle, and
// photo-view placeholder so they all share the same decoded image in Flutter's
// image cache — eliminating any grey/white flash on return.
const int _kThumbWidth = 600;

// App-lifetime aspect-ratio store (url → width/height).
final _aspectRatioCache = <String, double>{};

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
  List<GalleryItem> _items = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems({bool forceFresh = false}) async {
    if (_items.isEmpty) setState(() => _isLoading = true);
    setState(() => _hasError = false);
    try {
      final items = await _service.fetchGalleryItems(forceFresh: forceFresh);
      if (mounted) setState(() { _items = items; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Future<void> _addPhoto() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GalleryEditorPage()),
    );
    if (result == true) _loadItems(forceFresh: true);
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
    if (_hasError) {
      return RefreshIndicator(
        onRefresh: () => _loadItems(forceFresh: true),
        child: ListView(children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.5,
            child: Center(
              child: PageStateWidget.error(
                message: '加载失败',
                onRetry: () => _loadItems(forceFresh: true),
              ),
            ),
          ),
        ]),
      );
    }

    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _loadItems(forceFresh: true),
      child: _items.isEmpty
          ? ListView(children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.5,
                child: Center(
                  child: PageStateWidget.empty(
                    message: '暂无照片',
                    icon: Icons.photo_library_outlined,
                  ),
                ),
              ),
            ])
          : LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth;
              int crossAxisCount = 2;
              double padding = 16.0;
              if (width > 900) {
                crossAxisCount = 4;
                padding = (width - 1200) / 2;
                if (padding < 24) padding = 24;
              } else if (width > 600) {
                crossAxisCount = 3;
                padding = 24.0;
              }
              return MasonryGridView.count(
                key: const PageStorageKey('gallery_grid'),
                cacheExtent: 3000,
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _GalleryGridItem(
                    key: ValueKey(item.url),
                    item: item,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GalleryPhotoViewPage(
                            items: _items,
                            initialIndex: index,
                            service: _service,
                          ),
                        ),
                      );
                      if (result == true) _loadItems(forceFresh: true);
                    },
                  );
                },
              );
            }),
    );
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

  String get _resolvedUrl {
    final url = widget.item.url;
    return url.startsWith('http') ? url : DataSourceManager.instance.rawUrl(url);
  }

  Map<String, String>? get _headers => DataSourceManager.instance.imageHeaders;

  /// The one thumbnail provider used everywhere for this item.
  /// Consistent cache key = no double-decode, no flash on return.
  ResizeImage get _thumbProvider => ResizeImage(
        CachedNetworkImageProvider(_resolvedUrl, headers: _headers),
        width: _kThumbWidth,
      );

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

  /// Loads the thumbnail via _thumbProvider (same key used for display).
  /// When the ImageStream resolves, the image is already in Flutter's cache,
  /// so the grid widget switches from spinner → image with no intermediate
  /// grey/white state.
  void _resolveAspectRatio() {
    if (_aspectRatioCache.containsKey(widget.item.url)) return;
    _stream = _thumbProvider.resolve(ImageConfiguration.empty);
    _streamListener = ImageStreamListener(
      (ImageInfo info, bool sync) {
        _aspectRatioCache[widget.item.url] =
            info.image.width / info.image.height;
        _cleanupStream();
        if (mounted && !sync) setState(() {});
      },
      onError: (_, __) => _cleanupStream(),
    );
    _stream!.addListener(_streamListener!);
  }

  void _cleanupStream() {
    _stream?.removeListener(_streamListener!);
    _stream = null;
    _streamListener = null;
  }

  @override
  void dispose() {
    _cleanupStream();
    super.dispose();
  }

  // ── Hero shuttle ──────────────────────────────────────────────────────────
  //
  // Using the full-res URL in the shuttle has two benefits:
  //   1. The image decodes from disk cache during the ~300 ms animation,
  //      so it is usually ready when the photo view appears — no black flash.
  //   2. No pixelated thumbnail stretched to full screen.
  // While the full-res is still decoding, the shuttle shows the cached
  // thumbnail as a placeholder so the animation never goes blank.
  Widget _buildShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    return _FullResWithThumbPlaceholder(
      resolvedUrl: _resolvedUrl,
      headers: _headers,
      thumbProvider: _thumbProvider,
      fit: BoxFit.contain,
    );
  }

  // ── Grid image ────────────────────────────────────────────────────────────

  Widget _buildGridImage(double? aspectRatio) {
    if (aspectRatio != null) {
      // AspectRatio keeps the container size stable at all times.
      // _thumbProvider uses the same key as _resolveAspectRatio(), so the
      // image is already decoded when we reach this branch — wasSynchronouslyLoaded
      // is true and frameBuilder shows the image immediately (zero flash).
      return AspectRatio(
        aspectRatio: aspectRatio,
        child: Image(
          image: _thumbProvider,
          fit: BoxFit.cover,
          frameBuilder: (_, child, frame, sync) =>
              (sync || frame != null) ? child : Container(color: Colors.grey[100]),
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[100],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    }

    // Aspect ratio not yet known (very first load ever).
    // _thumbProvider here and in _resolveAspectRatio share the same
    // ImageStreamCompleter, so once the download/decode finishes both
    // the Image widget and the aspect-ratio listener are satisfied.
    return Image(
      image: _thumbProvider,
      fit: BoxFit.cover,
      frameBuilder: (_, child, frame, sync) {
        if (sync || frame != null) return child;
        // Loading: fixed-height spinner so masonry has something to size on.
        return Container(
          color: Colors.grey[100],
          height: 200,
          child:
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        height: 200,
        color: Colors.grey[100],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final item = widget.item;
    final aspectRatio = _aspectRatioCache[item.url];

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
              child: _buildGridImage(aspectRatio),
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

/// Shows the full-resolution image, falling back to the cached thumbnail while
/// it decodes.  Used in both the Hero shuttle and the photo-view page so the
/// experience is consistent and there is never a blank/black frame.
class _FullResWithThumbPlaceholder extends StatelessWidget {
  final String resolvedUrl;
  final Map<String, String>? headers;
  final ResizeImage thumbProvider;
  final BoxFit fit;

  const _FullResWithThumbPlaceholder({
    required this.resolvedUrl,
    required this.headers,
    required this.thumbProvider,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      httpHeaders: headers,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      // Cached thumbnail is shown instantly (same _kThumbWidth key) while the
      // full-res decodes from disk.  No black frame ever.
      placeholder: (_, __) => Image(
        image: thumbProvider,
        fit: fit,
      ),
      errorWidget: (_, __, ___) => Container(
        color: Colors.black,
        child: const Icon(Icons.broken_image, color: Colors.white54, size: 48),
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
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, PhotoViewController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final controller = _controllers[_currentIndex];
      if (controller == null) return;
      final scale = ((controller.scale ?? 1.0) *
              (event.scrollDelta.dy > 0 ? 0.9 : 1.1))
          .clamp(0.1, 5.0);
      controller.scale = scale;
    }
  }

  Future<void> _editCurrent() async {
    final result = await Navigator.push(
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
            'Are you sure you want to delete this photo? This will remove it from GitHub.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await widget.service.deleteGalleryItem(widget.items[_currentIndex]);
        if (mounted) Navigator.pop(context, true);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
        }
      }
    }
  }

  String _resolvedUrl(GalleryItem item) {
    final url = item.url;
    return url.startsWith('http') ? url : DataSourceManager.instance.rawUrl(url);
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
                final controller = _controllers.putIfAbsent(
                    index, () => PhotoViewController());
                final resolved = _resolvedUrl(item);
                final headers = DataSourceManager.instance.imageHeaders;
                final thumbProvider = ResizeImage(
                  CachedNetworkImageProvider(resolved, headers: headers),
                  width: _kThumbWidth,
                );

                return PhotoViewGalleryPageOptions.customChild(
                  controller: controller,
                  heroAttributes: PhotoViewHeroAttributes(tag: item.url),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  // Full-res with cached thumbnail placeholder — no black flash
                  // when the Hero animation ends.
                  child: _FullResWithThumbPlaceholder(
                    resolvedUrl: resolved,
                    headers: headers,
                    thumbProvider: thumbProvider,
                    fit: BoxFit.contain,
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
                    icon: const Icon(Icons.more_vert,
                        color: Colors.white, size: 30),
                    onSelected: (v) {
                      if (v == 'edit') _editCurrent();
                      if (v == 'delete') _deleteCurrent();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // Bottom gradient
          Positioned(
            bottom: 0, left: 0, right: 0, height: 120,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
            ),
          ),

          // Caption
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: SafeArea(
              child: Text(
                widget.items[_currentIndex].caption,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Source Han Serif CN',
                  fontSize: 18,
                  shadows: [
                    Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black)
                  ],
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
