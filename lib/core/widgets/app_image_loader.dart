import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

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
    final fallback =
        errorWidget ??
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        );
    final isRemoteUrl =
        imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
    Widget image = isRemoteUrl
        ? Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
            cacheWidth: memCacheWidth,
            cacheHeight: memCacheHeight,
            filterQuality: FilterQuality.medium,
            frameBuilder: (context, child, frame, synchronouslyLoaded) {
              if (synchronouslyLoaded || frame != null) return child;
              return placeholder ??
                  ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  );
            },
            errorBuilder: (_, _, _) => fallback,
          )
        : FutureBuilder<Uint8List?>(
            future: imageUrl.isEmpty
                ? Future<Uint8List?>.value()
                : FirebaseStorage.instance
                      .ref(imageUrl)
                      .getData(12 * 1024 * 1024),
            builder: (context, snapshot) {
              if (snapshot.hasError) return fallback;
              final bytes = snapshot.data;
              if (bytes == null) {
                return placeholder ??
                    ColoredBox(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()),
                    );
              }
              return Image.memory(
                bytes,
                width: width,
                height: height,
                fit: fit,
                cacheWidth: memCacheWidth,
                cacheHeight: memCacheHeight,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => fallback,
              );
            },
          );
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
