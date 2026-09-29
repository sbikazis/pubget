import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// A remote or stored image, decoded at the size it will actually be painted.
///
/// The loader owns the decode budget on purpose. Every call site that passed
/// its own number had to remember the device pixel ratio to avoid a blurry
/// image, and most of them did not: a 48dp avatar decoded at 48 physical pixels
/// is upscaled to 144 on a 3x phone, which is the softness users were seeing.
/// When a caller states a budget, that budget wins; when it does not, the
/// budget is derived from the box the widget was given and the screen's own
/// ratio, so the decode is never smaller than what the screen can show.
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

  /// Upper bound on a derived budget. A full-screen photo on a 3x phone needs
  /// roughly 1100, so 2048 covers the largest legitimate case while still
  /// refusing to decode a 4000px source into a 40px slot.
  static const int maxDerivedBudget = 2048;

  /// Used when the widget's box is unbounded, so the budget can only be
  /// guessed. 1080 is a full-width phone portrait at 3x.
  static const int unboundedBudget = 1080;

  /// A stated budget is kept as it is; an absent one becomes the painted size
  /// in physical pixels, never smaller than the logical size, so a text-scale
  /// or accessibility change cannot make an image soft.
  static int resolveBudget({
    int? stated,
    required double? logical,
    double devicePixelRatio = 3,
  }) {
    if (stated != null && stated > 0) return stated;
    if (logical == null || !logical.isFinite || logical <= 0) {
      return unboundedBudget;
    }
    final ratio = devicePixelRatio.isFinite && devicePixelRatio > 0
        ? devicePixelRatio
        : 3.0;
    return math.min(
      math.max((logical * ratio).ceil(), logical.ceil()),
      maxDerivedBudget,
    );
  }

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
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final budgetW = resolveBudget(
          stated: memCacheWidth,
          logical: width ?? constraints.maxWidth,
          devicePixelRatio: dpr,
        );
        final budgetH = resolveBudget(
          stated: memCacheHeight,
          logical: height ?? constraints.maxHeight,
          devicePixelRatio: dpr,
        );
        final Widget image = isRemoteUrl
            ? Image.network(
                imageUrl,
                width: width,
                height: height,
                fit: fit,
                cacheWidth: budgetW,
                cacheHeight: budgetH,
                filterQuality: FilterQuality.high,
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
                    cacheWidth: budgetW,
                    cacheHeight: budgetH,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) => fallback,
                  );
                },
              );
        if (borderRadius == null) return image;
        return ClipRRect(borderRadius: borderRadius!, child: image);
      },
    );
  }
}
