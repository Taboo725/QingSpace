import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/data_source_manager.dart';

/// Shared "image failed to load" box. Used by every image call-site so the
/// failure state looks the same everywhere.
class ImageErrorBox extends StatelessWidget {
  final double? height;
  final bool onDarkBackground;
  final bool compact;

  const ImageErrorBox({
    super.key,
    this.height,
    this.onDarkBackground = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = onDarkBackground ? Colors.white54 : Colors.grey;
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      color: onDarkBackground ? null : Colors.grey[50],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: color,
            size: compact ? 24 : 48,
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text('图片加载失败', style: TextStyle(color: color, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

/// Neutral placeholder shown while an image is downloading.
class ImageLoadingBox extends StatelessWidget {
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final bool showSpinner;

  const ImageLoadingBox({
    super.key,
    this.height = 200,
    this.borderRadius,
    this.showSpinner = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: borderRadius,
      ),
      child: showSpinner
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}

/// Network image bound to the active [DataSourceManager] source.
///
/// Accepts either an absolute `http(s)` URL or a repo-relative path, and
/// attaches the auth headers required by the active source.
///
/// [memCacheWidth] downscales the decoded bitmap. Pass it whenever the image is
/// shown in a list or grid — a 4000 px photo decoded at full size costs ~64 MB
/// of RAM, versus ~2 MB at 600 px.
class NetImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final Duration? fadeInDuration;
  final int? memCacheWidth;

  const NetImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration,
    this.memCacheWidth,
  });

  /// Resolves a repo-relative path against the active data source.
  static String resolveUrl(String url) =>
      url.startsWith('http') ? url : DataSourceManager.instance.rawUrl(url);

  @override
  Widget build(BuildContext context) {
    // Source probing can finish after the first frames are already on screen,
    // so re-resolve whenever the active host changes rather than pinning the
    // URL to whichever source happened to be current at first build.
    return ValueListenableBuilder<DataSource>(
      valueListenable: DataSourceManager.instance.resolvedNotifier,
      builder: (context, _, _) => _buildImage(),
    );
  }

  Widget _buildImage() {
    return CachedNetworkImage(
      imageUrl: resolveUrl(imageUrl),
      httpHeaders: DataSourceManager.instance.imageHeaders,
      fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 300),
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      imageBuilder: borderRadius == null
          ? null
          : (context, imageProvider) => Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                image: DecorationImage(
                  image: imageProvider,
                  fit: fit ?? BoxFit.cover,
                ),
              ),
            ),
      placeholder: placeholder,
      errorWidget:
          errorWidget ?? (context, url, error) => const ImageErrorBox(),
    );
  }
}
