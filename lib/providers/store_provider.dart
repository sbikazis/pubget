// lib/providers/store_provider.dart

import 'package:flutter/material.dart';
import '../core/constants/store_constants.dart';
import '../core/constants/subscription_type.dart';
import 'user_provider.dart';

class StoreProvider extends ChangeNotifier {
  final UserProvider _userProvider;
  bool _isLoading = false;

  // آلية صارمة ضد الغش: حفظ طابع زمني محلي لآخر إعلان اختياري تمت مشاهدته لمنع استدعاء الدالة بشكل متكرر عبر الهندسة العكسية
  DateTime? _lastAdWatchedTime;

  StoreProvider({required UserProvider userProvider}) : _userProvider = userProvider;

  bool get isLoading => _isLoading;
  int get currentCoins => _userProvider.currentUser?.coinsBalance ?? 0;

  // =========================================================
  // نظام الخصم والشراء الصارم (Purchase Operations)
  // =========================================================

  /// دالة عامة موحدة لفحص الرصيد وخصم العملات برمجياً لمنع التلاعب
  bool _canAffordAndDeduct(int price) {
    final user = _userProvider.currentUser;
    if (user == null) return false;
    
    if (user.coinsBalance < price) {
      return false; // رصيد غير كافٍ، ترفض العملية فوراً
    }
    return true;
  }

  /// 1. شراء ميزة توسيع حد أعضاء المجموعة (200 عملة)
  Future<bool> purchaseGroupMembersExpansion() async {
    final user = _userProvider.currentUser;
    if (user == null || !_canAffordAndDeduct(StoreConstants.domainExpansionPrice)) return false;

    _isLoading = true;
    notifyListeners();

    final updatedUser = user.copyWith(
      coinsBalance: user.coinsBalance - StoreConstants.domainExpansionPrice,
      customMaxMembersLimit: StoreConstants.expandedGroupMembersLimit, // رفع الحد إلى 350
      updatedAt: DateTime.now(),
    );

    await _userProvider.updateUser(updatedUser);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// 2. شراء ميزة توسيع نطاق الانضمام للمجموعات (200 عملة)
  Future<bool> purchaseJoinedGroupsExpansion() async {
    final user = _userProvider.currentUser;
    if (user == null || !_canAffordAndDeduct(StoreConstants.domainExpansionPrice)) return false;

    _isLoading = true;
    notifyListeners();

    final updatedUser = user.copyWith(
      coinsBalance: user.coinsBalance - StoreConstants.domainExpansionPrice,
      customMaxJoinedGroupsLimit: StoreConstants.expandedJoinedGroupsLimit, // رفع الحد إلى 7 مجموعات
      updatedAt: DateTime.now(),
    );

    await _userProvider.updateUser(updatedUser);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// 3. شراء ميزة تأسيس إمبراطوريات جديدة وإنشاء مجموعات أكثر (200 عملة)
  Future<bool> purchaseCreatedGroupsExpansion() async {
    final user = _userProvider.currentUser;
    if (user == null || !_canAffordAndDeduct(StoreConstants.domainExpansionPrice)) return false;

    _isLoading = true;
    notifyListeners();

    final updatedUser = user.copyWith(
      coinsBalance: user.coinsBalance - StoreConstants.domainExpansionPrice,
      customMaxCreatedGroupsLimit: StoreConstants.expandedCreatedGroupsLimit, // رفع حد الإنشاء إلى 3 مجموعات
      updatedAt: DateTime.now(),
    );

    await _userProvider.updateUser(updatedUser);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// 4. شراء اشتراك بريميوم الحصري (500 عملة)
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

  /// 5. شراء ترويج للمجموعة الحالية (150 عملة)
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
  // نظام كسب ومكافآت العملات (Reward Operations) + جدار الحماية ضد الغش
  // =========================================================

  /// دالة إضافة المكافآت العامة
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

  /// 1. مكافأة الإعلان الاختياري (+20) مع جدار حماية زمني صارم لمنع الغش بالتكرار المتتالي
  Future<bool> rewardForWatchingAd() async {
    final now = DateTime.now();
    // جدار حماية: منع تشغيل أو احتساب إعلانين في غضون أقل من 30 ثانية (حماية من ثغرات استدعاء الدالة المباشر)
    if (_lastAdWatchedTime != null && now.difference(_lastAdWatchedTime!).inSeconds < 30) {
      return false; 
    }

    _lastAdWatchedTime = now;
    await _addRewardCoins(StoreConstants.rewardWatchAd);
    return true;
  }

  /// 2. مكافأة الفوز في الفعالية (+10)
  Future<void> rewardForEventWin() async {
    await _addRewardCoins(StoreConstants.rewardEventWin);
  }

  /// 3. مكافأة نشر مقطع إديت إبداعي جديد (+10)
  Future<void> rewardForPublishingEdit() async {
    await _addRewardCoins(StoreConstants.rewardPublishEdit);
  }

  /// 4. مكافأة متابعة حساب التطبيق الرسمي (+50)
  Future<void> rewardForFollowingAccount() async {
    await _addRewardCoins(StoreConstants.rewardFollowAccount);
  }

  /// 5. مكافأة نظام الإحالة ودعوة الأصدقاء (70 لك و 30 للصديق المسجل)
  Future<void> rewardForInvitingFriend() async {
    await _addRewardCoins(StoreConstants.rewardInviter);
  }
}