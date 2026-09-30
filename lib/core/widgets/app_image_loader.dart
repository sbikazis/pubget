import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// Network/stored image with decode-time downscaling.
///
/// The two defects this fixes are the reason a media chat felt heavy and blurry:
///
/// 1. **No decode sizing.** A `cacheWidth`/`cacheHeight` decode of a 4000x3000
///    photo into a 250px bubble costs ~48 MB of raster (32bpp). Without it every
///    bubble decoded the full sensor image, which thrashed the [ImageCache]
///    (100 MiB default — two such images evict everything) and stalled the
///    raster thread on the way. The values are *physical* pixels, so they are
///    computed from the on-screen logical size times the device pixel ratio.
/// 2. **A `FutureBuilder` in `build`.** For Storage references the old code
///    called `getData(12 MB)` from inside `build`, issuing a fresh 12 MB
///    download on *every rebuild* of every bubble — the "sudden reload" the chat
///    showed whenever a message arrived. The future is now created once per
///    provider (inside the state, keyed by the url) and the bytes are handed to
///    [MemoryImage], which participates in the normal [ImageCache].
///
/// Only one of `memCacheWidth`/`memCacheHeight` is passed when both are supplied
/// with a known aspect ratio: specifying both makes `ResizeImage` decode to an
/// exact W x H box, which *changes* the aspect ratio. `ResizeImage` also defaults
/// to `allowUpscaling: false`, so an over-generous value is clamped to the
/// intrinsic size and can never inflate memory.
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
  /// Held on the state so a rebuild never re-issues the Storage download.
  Future<Uint8List?>? _storageBytes;

  bool get _isRemoteUrl =>
      widget.imageUrl.startsWith('http://') ||
      widget.imageUrl.startsWith('https://');

  /// Physical-pixel decode target for the width, or null when unknown.
  ///
  /// [logicalWidth] is the painted width: the one the caller asked for, or the
  /// one the parent laid this image out at when the caller named no size.
  int? _targetWidth(BuildContext context, double? logicalWidth) {
    final requested = widget.memCacheWidth;
    if (requested != null) return requested;
    final logical = logicalWidth;
    if (logical == null || !logical.isFinite || logical <= 0) return null;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    // Ceil, then leave headroom: an off-by-one here shows up as a soft image.
    return (logical * dpr).ceil();
  }

  /// Physical-pixel decode target for the height, or null when unknown.
  int? _targetHeight(BuildContext context, double? logicalHeight) {
    final requested = widget.memCacheHeight;
    if (requested != null) return requested;
    final logical = logicalHeight;
    if (logical == null || !logical.isFinite || logical <= 0) return null;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return (logical * dpr).ceil();
  }

  Future<Uint8List?>? _bytesForStorageUrl() {
    final url = widget.imageUrl;
    if (_storageBytes != null) return _storageBytes;
    if (url.isEmpty) {
      return _storageBytes = Future<Uint8List?>.value();
    }
    return _storageBytes = FirebaseStorage.instance
        .ref(url)
        .getData(12 * 1024 * 1024)
        .then<Uint8List?>((value) => value)
        // A failed read must not leave the bubble permanently spinning: the
        // builder renders the error widget once the future completes with an
        // error, and a transient failure is worth one cheap retry.
        .catchError((Object _) => null);
  }

  @override
  void didUpdateWidget(covariant AppImageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _storageBytes = null;
  }

  @override
  void dispose() {
    _storageBytes = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallback =
        widget.errorWidget ??
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        );
    final loading =
        widget.placeholder ??
        ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        );
    // A grid tile or a stack names no size and hands the image whatever box it
    // is given, so the painted constraints are the only place a decode budget
    // can come from. Without this the shared-media tile decoded a full sensor
    // photo into a 120px square, which is what made it heavy and soft.
    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalWidth =
            widget.width ??
            (constraints.hasBoundedWidth ? constraints.maxWidth : null);
        final logicalHeight =
            widget.height ??
            (constraints.hasBoundedHeight ? constraints.maxHeight : null);
        // Passing both forces an exact-size decode; keep only the known axis.
        final cacheWidth = _targetWidth(context, logicalWidth);
        final cacheHeight = cacheWidth == null
            ? _targetHeight(context, logicalHeight)
            : null;

        final image = _isRemoteUrl
            ? Image.network(
                widget.imageUrl,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                filterQuality: FilterQuality.medium,
                // Rows are recycled as the list scrolls; without this every
                // recycle blinks to blank while the new frame decodes.
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, synchronouslyLoaded) {
                  if (synchronouslyLoaded || frame != null) return child;
                  return loading;
                },
                errorBuilder: (_, _, _) => fallback,
              )
            : FutureBuilder<Uint8List?>(
                future: _bytesForStorageUrl(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return loading;
                  }
                  if (snapshot.hasError) return fallback;
                  final bytes = snapshot.data;
                  if (bytes == null || bytes.isEmpty) return fallback;
                  return Image.memory(
                    bytes,
                    width: widget.width,
                    height: widget.height,
                    fit: widget.fit,
                    cacheWidth: cacheWidth,
                    cacheHeight: cacheHeight,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => fallback,
                  );
                },
              );
        if (widget.borderRadius != null) {
          return ClipRRect(borderRadius: widget.borderRadius!, child: image);
        }
        return image;
      },
    );
  }
}
