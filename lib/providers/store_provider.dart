// lib/providers/store_provider.dart

import 'package:flutter/material.dart';
import '../core/constants/store_constants.dart';
import '../core/constants/subscription_type.dart';
import 'user_provider.dart';

class StoreProvider extends ChangeNotifier {
  final UserProvider _userProvider;
  bool _isLoading = false;

  DateTime? _lastAdWatchedTime;

  StoreProvider({required UserProvider userProvider}) : _userProvider = userProvider;

  bool get isLoading => _isLoading;
  int get currentCoins => _userProvider.currentUser?.coinsBalance ?? 0;

  // =========================================================
  // نظام الخصم والشراء الصارم
  // =========================================================

  bool _canAffordAndDeduct(int price) {
    final user = _userProvider.currentUser;
    if (user == null) return false;
    
    if (user.coinsBalance < price) {
      return false;
    }
    return true;
  }

  Future<bool> purchaseGroupMembersExpansion() async {
    final user = _userProvider.currentUser;
    if (user == null || !_canAffordAndDeduct(StoreConstants.domainExpansionPrice)) return false;

    _isLoading = true;
    notifyListeners();

    final updatedUser = user.copyWith(
      coinsBalance: user.coinsBalance - StoreConstants.domainExpansionPrice,
      customMaxMembersLimit: StoreConstants.expandedGroupMembersLimit,
      updatedAt: DateTime.now(),
    );

    await _userProvider.updateUser(updatedUser);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> purchaseJoinedGroupsExpansion() async {
    final user = _userProvider.currentUser;
    if (user == null || !_canAffordAndDeduct(StoreConstants.domainExpansionPrice)) return false;

    _isLoading = true;
    notifyListeners();

    final updatedUser = user.copyWith(
      coinsBalance: user.coinsBalance - StoreConstants.domainExpansionPrice,
      customMaxJoinedGroupsLimit: StoreConstants.expandedJoinedGroupsLimit,
      updatedAt: DateTime.now(),
    );

    await _userProvider.updateUser(updatedUser);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> purchaseCreatedGroupsExpansion() async {
    final user = _userProvider.currentUser;
    if (user == null || !_canAffordAndDeduct(StoreConstants.domainExpansionPrice)) return false;

    _isLoading = true;
    notifyListeners();

    final updatedUser = user.copyWith(
      coinsBalance: user.coinsBalance - StoreConstants.domainExpansionPrice,
      customMaxCreatedGroupsLimit: StoreConstants.expandedCreatedGroupsLimit,
      updatedAt: DateTime.now(),
    );

    await _userProvider.updateUser(updatedUser);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> purchasePremiumSubscription() async {
    final user = _userProvider.currentUser;
    if (user == null || !_canAffordAndDeduct(StoreConstants.premiumSubscriptionPrice)) return false;

    _isLoading = true;
    notifyListeners();

    final updatedUser = user.copyWith(
      coinsBalance: user.coinsBalance - StoreConstants.premiumSubscriptionPrice,
      subscriptionType: SubscriptionType.premium,
      premiumSince: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _userProvider.updateUser(updatedUser);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> purchaseGroupPromotion() async {
    final user = _userProvider.currentUser;
    if (user == null || !_canAffordAndDeduct(StoreConstants.groupPromotionPrice)) return false;

    _isLoading = true;
    notifyListeners();

    final updatedUser = user.copyWith(
      coinsBalance: user.coinsBalance - StoreConstants.groupPromotionPrice,
      updatedAt: DateTime.now(),
    );

    await _userProvider.updateUser(updatedUser);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  // =========================================================
  // نظام كسب المكافآت
  // =========================================================

  Future<void> _addRewardCoins(int amount) async {
    final user = _userProvider.currentUser;
    if (user == null) return;

    final updatedUser = user.copyWith(
      coinsBalance: user.coinsBalance + amount,
      updatedAt: DateTime.now(),
    );

    await _userProvider.updateUser(updatedUser);
    notifyListeners();
  }

  Future<bool> rewardForWatchingAd() async {
    final now = DateTime.now();
    if (_lastAdWatchedTime != null && now.difference(_lastAdWatchedTime!).inSeconds < 30) {
      return false; 
    }

    _lastAdWatchedTime = now;
    await _addRewardCoins(StoreConstants.rewardWatchAd);
    return true;
  }

  /// تم تعطيل هذه الدالة عمداً - المكافأة تتم الآن فقط عبر CoinService عند الفوز الحقيقي
  Future<void> rewardForEventWin() async {
    debugPrint('⚠️ rewardForEventWin تم تعطيلها - استخدم CoinService');
    return;
  }

  // ✅ تم تعطيلها - المكافأة تتم فقط بعد الرفع الفعلي عبر CoinService
  Future<void> rewardForPublishingEdit() async {
    debugPrint('⚠️ rewardForPublishingEdit معطلة - المكافأة بعد الرفع فقط عبر CoinService');
    return;
  }

  // ✅ تم إلغاؤها نهائياً - مخالفة لسياسة Google Play و Instagram/TikTok
  Future<void> rewardForFollowingAccount() async {
    debugPrint('⚠️ rewardForFollowingAccount ملغاة - ممنوع إعطاء عملات مقابل متابعة (مخالفة Google Play)');
    return;
  }

  Future<void> rewardForInvitingFriend() async {
    await _addRewardCoins(StoreConstants.rewardInviter);
  }
}