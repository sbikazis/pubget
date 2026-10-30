import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../storage/r2_config.dart';

class AppImageLoader extends StatelessWidget {
  const AppImageLoader({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    super.key,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  String _resolveUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    // Try R2
    try {
      return R2Config.publicUrl(url);
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolveUrl(imageUrl);
    final fallback =
        errorWidget ??
        placeholder ??
        const ColoredBox(color: Color(0xFF140C22));
    Widget image;
    if (url.isEmpty) {
      image = fallback;
    } else {
      image = Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: memCacheWidth,
        cacheHeight: memCacheHeight,
        errorBuilder: (_, _, _) => fallback,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return placeholder ??
              SizedBox(width: width, height: height, child: null);
        },
      );
    }
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

/// Bytes-backed variant for avatars captured locally before upload.
class AppMemoryImageLoader extends StatelessWidget {
  const AppMemoryImageLoader({
    required this.bytes,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    super.key,
  });

  final Uint8List? bytes;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final data = bytes;
    if (data == null || data.isEmpty) {
      return SizedBox(width: width, height: height);
    }
    Widget image = Image.memory(data, width: width, height: height, fit: fit);
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
