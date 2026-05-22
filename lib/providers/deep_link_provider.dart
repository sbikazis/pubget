import 'dart:async';
import 'package:flutter/material.dart';

import '../services/deep_link_service.dart';

class DeepLinkProvider extends ChangeNotifier {
  final DeepLinkService _service = DeepLinkService();

  StreamSubscription<Uri>? _sub;

  DeepLinkResult? _pendingLink;
  DeepLinkResult? get pendingLink => _pendingLink;

  Future<void> init() async {
    // 1. رابط فتح التطبيق وهو مغلق
    final initial = await _service.getInitialLink();
    if (initial != null) {
      _handleUri(initial);
    }

    // 2. روابط أثناء عمل التطبيق
    _sub = _service.linkStream.listen(
      _handleUri,
      onError: (_) {},
    );
  }

  void _handleUri(Uri uri) {
    final result = _service.parseLink(uri);
    if (result != null) {
      _pendingLink = result;
      notifyListeners();
    }
  }

  void clearPendingLink() {
    _pendingLink = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}