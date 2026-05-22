// lib/providers/deep_link_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';

import '../services/deep_link_service.dart';

class DeepLinkProvider extends ChangeNotifier {
  final DeepLinkService _service = DeepLinkService();

  StreamSubscription<Uri>? _sub;

  /// آخر نتيجة رابط واردة لم تُعالج بعد
  DeepLinkResult? _pendingLink;
  DeepLinkResult? get pendingLink => _pendingLink;

  // ══════════════════════════════════════════════
  // ── تهيئة الاستماع
  // ══════════════════════════════════════════════

  /// يُستدعى مرة واحدة عند بدء التطبيق
  Future<void> init() async {
    // 1. رابط بدء التطبيق (كان مغلقاً)
    final initial = await _service.getInitialLink();
    if (initial != null) {
      _handleUri(initial);
    }

    // 2. الاستماع للروابط اللاحقة (التطبيق في الخلفية)
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

  // ══════════════════════════════════════════════
  // ── تصفير الرابط بعد المعالجة
  // ══════════════════════════════════════════════

  /// يُستدعى بعد التنقل للشاشة الصحيحة
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