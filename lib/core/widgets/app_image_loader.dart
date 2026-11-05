import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../media/media_reference.dart';

/// Network image renderer for signed Cloudflare R2 URLs and existing HTTPS
/// media URLs. Bare R2 keys are resolved through the authenticated Worker.
class AppImageLoader extends StatefulWidget {
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
  State<AppImageLoader> createState() => _AppImageLoaderState();
}

class _AppImageLoaderState extends State<AppImageLoader> {
  late Future<String?> _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(AppImageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _resolve();
  }

  void _resolve() {
    _resolvedUrl = resolveMediaDownloadUrl(widget.imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.errorWidget ??
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        );
    final loading = widget.placeholder ??
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        );

    return FutureBuilder<String?>(
      future: _resolvedUrl,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) return _clip(loading);
        if (url == null) return _clip(fallback);

        final child = LayoutBuilder(
          builder: (context, constraints) {
            final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
            final logicalWidth = widget.width ??
                (constraints.hasBoundedWidth ? constraints.maxWidth : null);
            final logicalHeight = widget.height ??
                (constraints.hasBoundedHeight ? constraints.maxHeight : null);
            final cacheWidth = widget.memCacheWidth ??
                (logicalWidth != null && logicalWidth.isFinite && logicalWidth > 0
                    ? (logicalWidth * dpr).ceil()
                    : null);
            final cacheHeight = cacheWidth == null
                ? widget.memCacheHeight ??
                    (logicalHeight != null &&
                            logicalHeight.isFinite &&
                            logicalHeight > 0
                        ? (logicalHeight * dpr).ceil()
                        : null)
                : null;
            return Image.network(
              url,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
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
        return _clip(child);
      },
    );
  }

  Widget _clip(Widget child) {
    final radius = widget.borderRadius;
    return radius == null ? child : ClipRRect(borderRadius: radius, child: child);
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
