import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
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
    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}
