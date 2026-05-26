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

  /// ✅ جديد: عدد الثواني المتبقية قبل السماح بإعلان جديد
  int get adCooldownSeconds {
    if (_lastAdWatchedTime == null) return 0;
    final diff = DateTime.now().difference(_lastAdWatchedTime!).inSeconds;
    return diff < 30 ? 30 - diff : 0;
  }

  bool _canAffordAndDeduct(int price) {
    final user = _userProvider.currentUser;
    if (user == null) return false;
    return user.coinsBalance >= price;
  }

  Future<bool> purchaseGroupMembersExpansion() async {
    final user = _userProvider.currentUser;
    if (user == null || !_canAffordAndDeduct(StoreConstants.domainExpansionPrice)) return false;
    _isLoading = true; notifyListeners();
    final updatedUser = user.copyWith(
      coinsBalance: user.coinsBalance - StoreConstants.domainExpansionPrice,
      customMaxMembersLimit: StoreConstants.expandedGroupMembersLimit,
      updatedAt: DateTime.now(),
    );
    await _userProvider.updateUser(updatedUser);
    _isLoading = false; notifyListeners();
    return true;
  }

  Future<bool> purchaseJoinedGroupsExpansion() async {
    final user = _userProvider.currentUser;
    if (user == null || !_canAffordAndDeduct(StoreConstants.domainExpansionPrice)) return false;
    _isLoading = true; notifyListeners();
    final updatedUser = user.copyWith(
      coinsBalance: user.coinsBalance - StoreConstants.domainExpansionPrice,
      customMaxJoinedGroupsLimit: StoreConstants.expandedJoinedGroupsLimit,
      updatedAt: DateTime.now(),
    );
    await _userProvider.updateUser(updatedUser);
    _isLoading = false; notifyListeners();
    return true;
  }

  Future<bool> purchaseCreatedGroupsExpansion() async {
    final user = _userProvider.currentUser;
    if (user == null || !_canAffordAndDeduct(StoreConstants.domainExpansionPrice)) return false;
    _isLoading = true; notifyListeners();
    final updatedUser = user.copyWith(
      coinsBalance: user.coinsBalance - StoreConstants.domainExpansionPrice,
      customMaxCreatedGroupsLimit: StoreConstants.expandedCreatedGroupsLimit,
      updatedAt: DateTime.now(),
    );
    await _userProvider.updateUser(updatedUser);
    _isLoading = false; notifyListeners();
    return true;
  }

  Future<bool> purchasePremiumSubscription() async {
    final user = _userProvider.currentUser;
    if (user == null || !_canAffordAndDeduct(StoreConstants.premiumSubscriptionPrice)) return false;

    _isLoading = true; notifyListeners();

    final now = DateTime.now();
    final expires = now.add(Duration(days: StoreConstants.premiumDurationDays));

    final updatedUser = user.copyWith(
      coinsBalance: user.coinsBalance - StoreConstants.premiumSubscriptionPrice,
      subscriptionType: SubscriptionType.premium,
      premiumSince: now,
      premiumExpiresAt: expires,
      autoRenewPremium: true,
      updatedAt: now,
    );
    await _userProvider.updateUser(updatedUser);
    _isLoading = false; notifyListeners();
    return true;
  }

  Future<bool> purchaseGroupPromotion() async {
    final user = _userProvider.currentUser;
    if (user == null || !_canAffordAndDeduct(StoreConstants.groupPromotionPrice)) return false;
    _isLoading = true; notifyListeners();
    final updatedUser = user.copyWith(
      coinsBalance: user.coinsBalance - StoreConstants.groupPromotionPrice,
      updatedAt: DateTime.now(),
    );
    await _userProvider.updateUser(updatedUser);
    _isLoading = false; notifyListeners();
    return true;
  }

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
    notifyListeners(); // ✅ تحديث الواجهة فوراً عشان يظهر الكولداون
    await _addRewardCoins(StoreConstants.rewardWatchAd);
    return true;
  }

  Future<void> rewardForEventWin() async {
    debugPrint('⚠️ rewardForEventWin معطلة - استخدم CoinService');
  }

  Future<void> rewardForPublishingEdit() async {
    debugPrint('⚠️ rewardForPublishingEdit معطلة');
  }

  Future<void> rewardForFollowingAccount() async {
    debugPrint('⚠️ ملغاة - مخالفة Google Play');
  }

  Future<void> rewardForInvitingFriend() async {
    await _addRewardCoins(StoreConstants.rewardInviter);
  }
}
