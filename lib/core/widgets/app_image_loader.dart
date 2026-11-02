import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Network image renderer for signed media URLs (including Cloudflare R2).
///
/// Legacy opaque Firebase Storage object paths are intentionally not fetched
/// from the client: old buckets may be inaccessible, and the widget must fail
/// closed with a placeholder instead of issuing repeated Storage reads.
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

  @override
  Widget build(BuildContext context) {
    final fallback = errorWidget ??
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        );
    final loading = placeholder ??
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        );

    final uri = Uri.tryParse(imageUrl.trim());
    final isHttpUrl = uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    final child = !isHttpUrl
        ? fallback
        : LayoutBuilder(
            builder: (context, constraints) {
              final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
              final logicalWidth = width ??
                  (constraints.hasBoundedWidth ? constraints.maxWidth : null);
              final logicalHeight = height ??
                  (constraints.hasBoundedHeight ? constraints.maxHeight : null);
              final cacheWidth = memCacheWidth ??
                  (logicalWidth != null && logicalWidth.isFinite && logicalWidth > 0
                      ? (logicalWidth * dpr).ceil()
                      : null);
              final cacheHeight = cacheWidth == null
                  ? memCacheHeight ??
                      (logicalHeight != null &&
                              logicalHeight.isFinite &&
                              logicalHeight > 0
                          ? (logicalHeight * dpr).ceil()
                          : null)
                  : null;

              return Image.network(
                imageUrl,
                width: width,
                height: height,
                fit: fit,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                frameBuilder: (context, image, frame, synchronouslyLoaded) {
                  if (synchronouslyLoaded || frame != null) return image;
                  return loading;
                },
                errorBuilder: (_, _, _) => fallback,
              );
            },
          );

    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
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
    Widget image = Image.memory(
      data,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
    );
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
