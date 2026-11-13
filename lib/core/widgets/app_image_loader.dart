import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../media/media_reference.dart';

/// The one shared image surface for every avatar, group cover, chat photo and
/// reel thumbnail in the product.
///
/// Axis Zero — "revive images from the roots". Four things used to be missing:
///
/// 1. **One resolver.** Firestore holds two shapes: a full `https://…` URL
///    (legacy records, events, CDN/R2-era links) and a bare Firebase Storage
///    object path (chat media, reels). Screens that called `Image.network`
///    directly fed object paths to a URL parser and got "No host specified in
///    URI". Every reference now goes through the same normalization helpers.
/// 2. **A real fallback path.** Minting a download URL can fail (deleted
///    object, IAM/signing trouble, stale deployed rules). In that case we
///    still try an authenticated byte read before giving up on the image.
///    Legacy `http://` links are upgraded to TLS because release Android
///    blocks cleartext traffic.
/// 3. **Disk cache.** [CachedNetworkImage] keeps the file between cold starts;
///    the old `Image.network` refetched on every rebuild.
/// 4. **Decode sizing + honest states.** A 4000x3000 photo decoded into a
///    250px bubble costs ~48 MB of raster. Physical-pixel `memCacheWidth`
///    bounds it, and every state has a real placeholder / error widget.
///
/// Only one of `memCacheWidth`/`memCacheHeight` is passed when both could be
/// derived: specifying both makes `ResizeImage` decode to an exact W x H box
/// and silently changes the aspect ratio.
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

/// A resolved image is either a fetchable URL (disk-cacheable) or raw bytes
/// (the Storage fallback when a download URL could not be minted).
sealed class _ImageSource {
  const _ImageSource();
}

final class _UrlSource extends _ImageSource {
  const _UrlSource(this.url);
  final String url;
}

final class _BytesSource extends _ImageSource {
  const _BytesSource(this.bytes);
  final Uint8List bytes;
}

class _AppImageLoaderState extends State<AppImageLoader> {
  static const int _maxStorageBytes = 12 * 1024 * 1024;

  /// Held on the state so a rebuild never re-issues the Storage lookup.
  Future<_ImageSource?>? _source;

  int? _targetWidth(BuildContext context, double? logicalWidth) {
    final requested = widget.memCacheWidth;
    if (requested != null) return requested;
    if (logicalWidth == null || !logicalWidth.isFinite || logicalWidth <= 0) {
      return null;
    }
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    // Ceil, then leave headroom: an off-by-one here shows up as a soft image.
    return (logicalWidth * dpr).ceil();
  }

  int? _targetHeight(BuildContext context, double? logicalHeight) {
    final requested = widget.memCacheHeight;
    if (requested != null) return requested;
    if (logicalHeight == null ||
        !logicalHeight.isFinite ||
        logicalHeight <= 0) {
      return null;
    }
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return (logicalHeight * dpr).ceil();
  }

  Future<_ImageSource?> _resolve() {
    final reference = widget.imageUrl.trim();
    if (reference.isEmpty || isOpaqueMediaReference(reference)) {
      return Future<_ImageSource?>.value();
    }
    if (isRemoteMediaUrl(reference)) {
      return Future<_ImageSource?>.value(
        _UrlSource(secureMediaUrl(reference)),
      );
    }
    return _resolveStorage(reference);
  }

  Future<_ImageSource?> _resolveStorage(String path) async {
    final ref = FirebaseStorage.instance.ref(path);
    try {
      final url = await ref.getDownloadURL();
      return _UrlSource(secureMediaUrl(url));
    } on Object {
      // Fallback path: an authenticated byte read still works when URL minting
      // fails (IAM signing, stale rules, revoked token). Keep the image alive.
      try {
        final bytes = await ref.getData(_maxStorageBytes);
        if (bytes == null || bytes.isEmpty) return null;
        return _BytesSource(bytes);
      } on Object {
        return null;
      }
    }
  }

  @override
  void didUpdateWidget(covariant AppImageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _source = null;
  }

  @override
  void dispose() {
    _source = null;
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
    // is given, so the painted constraints are the only decode budget we have.
    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalWidth =
            widget.width ??
            (constraints.hasBoundedWidth ? constraints.maxWidth : null);
        final logicalHeight =
            widget.height ??
            (constraints.hasBoundedHeight ? constraints.maxHeight : null);
        final cacheWidth = _targetWidth(context, logicalWidth);
        final cacheHeight = cacheWidth == null
            ? _targetHeight(context, logicalHeight)
            : null;

        final image = FutureBuilder<_ImageSource?>(
          future: _source ??= _resolve(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                snapshot.hasError) {
              return snapshot.hasError ? fallback : loading;
            }
            final source = snapshot.data;
            if (source == null) return fallback;

            if (source is _BytesSource) {
              return Image.memory(
                source.bytes,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
              );
            }

            final url = (source as _UrlSource).url;
            return CachedNetworkImage(
              imageUrl: url,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              memCacheWidth: cacheWidth,
              memCacheHeight: cacheHeight,
              filterQuality: FilterQuality.medium,
              // Rows are recycled as a list scrolls; keep the old frame until
              // the new one is decoded instead of blinking to blank.
              useOldImageOnUrlChange: true,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (_, _) => loading,
              errorWidget: (_, _, _) => fallback,
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
