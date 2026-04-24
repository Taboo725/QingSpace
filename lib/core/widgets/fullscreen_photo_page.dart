import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'cdn_image.dart';

/// Full-screen photo viewer with pinch-to-zoom, scroll-wheel zoom, and a
/// close button.  Supports Hero animations via [heroTag].
class FullscreenPhotoPage extends StatefulWidget {
  final String imageUrl;
  final String? heroTag;

  const FullscreenPhotoPage({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  @override
  State<FullscreenPhotoPage> createState() => _FullscreenPhotoPageState();
}

class _FullscreenPhotoPageState extends State<FullscreenPhotoPage> {
  late final PhotoViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PhotoViewController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
    _controller.scale = ((_controller.scale ?? 1.0) * factor).clamp(0.1, 5.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerSignal: _onScroll,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: PhotoView.customChild(
                  controller: _controller,
                  heroAttributes: widget.heroTag != null
                      ? PhotoViewHeroAttributes(tag: widget.heroTag!)
                      : null,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                  child: NetImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.contain,
                    errorWidget: (context, url, error) => const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, color: Colors.white54, size: 48),
                          SizedBox(height: 8),
                          Text(
                            '图片加载失败',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
