import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/data_source_manager.dart';

class NetImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final Duration? fadeInDuration;

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
  });

  String _resolvedUrl() {
    if (imageUrl.startsWith('http')) return imageUrl;
    return DataSourceManager.instance.rawUrl(imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _resolvedUrl(),
      httpHeaders: DataSourceManager.instance.imageHeaders,
      fadeInDuration: fadeInDuration ?? const Duration(milliseconds: 500),
      fit: fit,
      width: width,
      height: height,
      imageBuilder: borderRadius != null
          ? (context, imageProvider) => Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                image: DecorationImage(
                  image: imageProvider,
                  fit: fit ?? BoxFit.cover,
                ),
              ),
            )
          : null,
      placeholder: placeholder,
      errorWidget: errorWidget ??
          (context, url, error) => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.grey, size: 48),
                    SizedBox(height: 8),
                    Text(
                      '图片加载失败',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
    );
  }
}
