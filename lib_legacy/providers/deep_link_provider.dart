// lib/providers/deep_link_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/deep_link_service.dart';

class DeepLinkProvider extends ChangeNotifier {
  final DeepLinkService _service = DeepLinkService();
  StreamSubscription<Uri>? _sub;

  DeepLinkResult? _pendingLink;
  DeepLinkResult? get pendingLink => _pendingLink;

  String? _deferredReferrerId;
  String? get deferredReferrerId => _deferredReferrerId;

  DeepLinkProvider() {
    _sub = _service.linkStream.listen(
      _handleUri,
      onError: (_) {},
    );
    // تفعيل فحص متجر قوقل فور تهيئة الـ Provider
    checkForDeferredReferrer();
  }

  /// 🔥 فحص المتجر والتقاط كود الشخص الداعي للمستخدم الجديد
  Future<void> checkForDeferredReferrer() async {
    final referrerId = await _service.getDeferredReferrerId();
    if (referrerId != null && referrerId.isNotEmpty) {
      _deferredReferrerId = referrerId;
      notifyListeners();
    }
  }

  void _handleUri(Uri uri) {
    final result = _service.parseLink(uri);
    if (result != null) {
      _pendingLink = result;
      notifyListeners();
    }
  }

  void clearDeferredReferrer() {
    _deferredReferrerId = null;
    notifyListeners();
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
