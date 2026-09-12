import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'net_image.dart';
import 'photo_zoom.dart';

/// Full-screen photo viewer with pinch-to-zoom, scroll-wheel zoom, and a
/// close button. Supports Hero animations via [heroTag].
class FullscreenPhotoPage extends StatefulWidget {
  final String imageUrl;
  final String? heroTag;

  const FullscreenPhotoPage({super.key, required this.imageUrl, this.heroTag});

  @override
  State<FullscreenPhotoPage> createState() => _FullscreenPhotoPageState();
}

class _FullscreenPhotoPageState extends State<FullscreenPhotoPage> {
  final PhotoViewController _controller = PhotoViewController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroTag = widget.heroTag;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerSignal: (event) => applyScrollZoom(event, _controller),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: PhotoView.customChild(
                  controller: _controller,
                  heroAttributes: heroTag == null
                      ? null
                      : PhotoViewHeroAttributes(tag: heroTag),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.black,
                  ),
                  child: NetImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.contain,
                    errorWidget: (_, _, _) =>
                        const ImageErrorBox(onDarkBackground: true),
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
