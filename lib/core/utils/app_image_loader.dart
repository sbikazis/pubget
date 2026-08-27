import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppImageLoader extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;
  final Widget Function(BuildContext context, String url)? placeholderBuilder;
  final Widget Function(BuildContext context, String url, Object error)? errorBuilder;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Map<String, String>? headers;

  const AppImageLoader({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallback,
    this.placeholderBuilder,
    this.errorBuilder,
    this.memCacheWidth,
    this.memCacheHeight,
    this.headers,
  });

  @override
  Widget build(BuildContext context) {
    final safeUrl = (url ?? '').trim();
    if (safeUrl.isEmpty) {
      return fallback ??
          const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.broken_image_outlined, color: Colors.grey),
          );
    }

    return CachedNetworkImage(
      imageUrl: safeUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth ?? (width != null ? (width! * 2).round() : null),
      memCacheHeight: memCacheHeight ?? (height != null ? (height! * 2).round() : null),
      httpHeaders: headers ?? {'Cache-Control': 'max-age=300'},
      placeholder: (context, _) =>
          placeholderBuilder?.call(context, safeUrl) ??
          SizedBox(
            width: width ?? 48,
            height: height ?? 48,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget: (context, _, __) =>
          errorBuilder?.call(context, safeUrl, __) ??
          fallback ??
          SizedBox(
            width: width ?? 48,
            height: height ?? 48,
            child: const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.grey),
            ),
          ),
    );
  }
}
