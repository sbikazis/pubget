// lib/providers/home_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../models/group_model.dart';
import '../models/user_model.dart';
import '../models/member_model.dart'; 
import '../models/notification_model.dart'; // 🔥 تم الإضافة لدعم الإشعارات

import '../services/firebase/firestore_service.dart';
import '../services/monetization/promotion_service.dart';
import '../services/monetization/ad_service.dart';

import '../core/constants/firestore_paths.dart';
import '../core/constants/roles.dart'; 
import '../core/logic/group_join_validator.dart';
import '../core/logic/subscription_limits_logic.dart';

class HomeProvider extends ChangeNotifier {
  final FirestoreService _firestore;
  final PromotionService _promotionService;
  final AdService _adService;
  final GroupJoinValidator _joinValidator;

  HomeProvider({
    required FirestoreService firestore,
    required PromotionService promotionService,
    required AdService adService,
    required GroupJoinValidator joinValidator,
  }) : _firestore = firestore,
       _promotionService = promotionService,
       _adService = adService,
       _joinValidator = joinValidator;

  // =====================================================
  // STATE
  // =====================================================

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  List<GroupModel> _promotedGroups = [];
  List<GroupModel> get promotedGroups => _promotedGroups;

  List<GroupModel> _suggestedGroups = []; 
  List<GroupModel> get suggestedGroups => _suggestedGroups;

  List<GroupModel> _myGroups = [];
  List<GroupModel> get myGroups => _myGroups;

  List<GroupModel> _joinedGroups = [];
  List<GroupModel> get joinedGroups => _joinedGroups;

  List<GroupModel> _globalSearchResults = [];
  List<GroupModel> get globalSearchResults => _globalSearchResults;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  StreamSubscription? _promotedSub;

  // =====================================================
  // INITIALIZE
  // =====================================================

  Future<void> initialize({required UserModel currentUser}) async {
    _setLoading(true);
    _currentUser = currentUser;

    await Future.wait([
      _loadPromotedGroups(),
      _loadUserGroups(currentUser.id),
      _loadSuggestedGroups(currentUser.id),
    ]);

    _setLoading(false);
  }

  // =====================================================
  // PROMOTED GROUPS
  // =====================================================

  Future<void> _loadPromotedGroups() async {
    _promotedSub?.cancel();
    _promotedSub = _promotionService.getPromotedGroups().listen((groups) {
      _promotedGroups = groups;
      notifyListeners();
    });
  }

  // =====================================================
  // SUGGESTED GROUPS
  // =====================================================

  Future<void> _loadSuggestedGroups(String userId) async {
    try {
      final snapshot = await _firestore.getCollection(
        path: FirestorePaths.groups,
        query: _firestore.buildQuery(
          path: FirestorePaths.groups,
          conditions: [
            QueryCondition(field: 'membersCount', isGreaterThan: 9),
            QueryCondition(field: 'membersCount', isLessThan: 80),
          ],
        ),
      );

      final fetchedGroups = snapshot.docs
          .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
          .where((group) => 
              group.founderId != userId && 
              !_joinedGroups.any((jg) => jg.id == group.id)
          ).toList();

      _suggestedGroups = fetchedGroups;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading suggested groups: $e");
    }
  }

  // =====================================================
  // USER GROUPS
  // =====================================================

  Future<void> _loadUserGroups(String userId) async {
    try {
      final myGroupsQuery = await _firestore.getCollection(
        path: FirestorePaths.groups,
        query: _firestore.buildQuery(
          path: FirestorePaths.groups,
          conditions: [QueryCondition(field: 'founderId', isEqualTo: userId)],
        ),
      );

      _myGroups = myGroupsQuery.docs
          .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
          .toList();

      final List<GroupModel> joined = [];
      final allGroupsSnapshot = await _firestore.getCollection(path: FirestorePaths.groups);
      
      for (var doc in allGroupsSnapshot.docs) {
        if (doc.data()['founderId'] != userId) {
          final memberDoc = await _firestore.getDocument(
            path: FirestorePaths.groupMembers(doc.id),
            docId: userId,
          );
          
          if (memberDoc != null) {
            joined.add(GroupModel.fromMap(doc.id, doc.data()));
          }
        }
      }
      
      _joinedGroups = joined;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading user groups: $e");
    }
  }

  // =====================================================
  // JOIN GROUP (التعديل لإرسال إشعار للمؤسس)
  // =====================================================

  Future<String?> joinGroup({
    required UserModel user,
    required GroupModel group,
    String? characterName,
    String? characterImage,
    String? characterReason,
    String? invitedByUserId,
  }) async {
    final limitResult = SubscriptionLimitsLogic.canJoinGroup(
      subscriptionType: user.subscriptionType,
      currentJoinedGroups: _joinedGroups.length,
    );

    if (!limitResult.isAllowed) {
      return limitResult.message;
    }

    final validation = await _joinValidator.validateJoin(
      groupId: group.id,
      groupType: group.type,
      characterName: characterName,
      characterImageUrl: characterImage,
      animeName: group.animeName,
    );

    if (!validation.isValid) {
      return validation.errorMessage;
    }

    try {
      final requestMember = MemberModel(
        userId: user.id,
        groupId: group.id,
        role: Roles.member,
        joinedAt: DateTime.now(),
        displayName: user.nickname,
        characterName: characterName,
        characterImageUrl: characterImage,
        characterReason: characterReason,
      );

      // 1. إنشاء وثيقة طلب الانضمام
      await _firestore.createDocument(
        path: FirestorePaths.groupJoinRequests(group.id),
        docId: user.id,
        data: requestMember.toMap(),
      );

      // 🔥 2. إنشاء إشعار للمؤسس (الشوكُن)
      final notification = NotificationModel(
        id: '', // سيتم توليده تلقائياً أو استبداله بـ Firestore
        title: 'طلب انضمام جديد',
        body: 'يريد ${user.username} الانضمام إلى مجموعتك "${group.name}"',
        type: NotificationTypes.joinRequest,
        refId: group.id, // groupId للتوجه لصفحة الطلبات
        senderId: user.id,
        createdAt: DateTime.now(),
        isRead: false,
      );

      await _firestore.createDocument(
        path: FirestorePaths.userNotifications(group.founderId),
        docId: DateTime.now().millisecondsSinceEpoch.toString(), // ID فريد للإشعار
        data: notification.toMap(),
      );

      return null; 
    } catch (e) {
      return "حدث خطأ أثناء إرسال الطلب: ${e.toString()}";
    }
  }

  // =====================================================
  // SEARCH & SMART FILTERING
  // =====================================================

  void setSearchQuery(String query) async {
    _searchQuery = query;
    
    if (_searchQuery.isEmpty) {
      _globalSearchResults = [];
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      final snapshot = await _firestore.getCollection(
        path: FirestorePaths.groups,
        query: _firestore.buildQuery(
          path: FirestorePaths.groups,
          conditions: [
            QueryCondition(field: 'name', isGreaterThanOrEqualTo: _searchQuery),
            QueryCondition(field: 'name', isLessThanOrEqualTo: '$_searchQuery\uf8ff'),
          ],
          limit: 20,
        ),
      );

      _globalSearchResults = snapshot.docs
          .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint("Error searching groups: $e");
    } finally {
      _setLoading(false);
    }
  }

  List<GroupModel> get allDiscoveryGroups {
    final list = List<GroupModel>.from(_promotedGroups);
    for (var suggested in _suggestedGroups) {
      if (!list.any((g) => g.id == suggested.id)) {
        list.add(suggested);
      }
    }

    if (_searchQuery.isEmpty) return list;
    return list.where((g) => g.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  List<GroupModel> get filteredPromotedGroups => _searchQuery.isEmpty 
      ? _promotedGroups 
      : _globalSearchResults.where((g) => g.isPromoted).toList();

  List<GroupModel> get filteredMyGroups => _searchQuery.isEmpty 
      ? _myGroups 
      : _myGroups.where((g) => g.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

  List<GroupModel> get filteredJoinedGroups => _searchQuery.isEmpty 
      ? _joinedGroups 
      : _joinedGroups.where((g) => g.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

  // =====================================================
  // ADS & HELPERS
  // =====================================================

  Future<void> tryShowMorningAd({required bool isPremium}) async {
    await _adService.tryShowMorningAd(isPremium: isPremium);
  }

  Future<void> tryShowGroupAd({required bool isPremium}) async {
    await _adService.tryShowGroupAd(isPremium: isPremium);
  }

  Future<void> refresh(UserModel user) async {
    await initialize(currentUser: user);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _promotedSub?.cancel();
    super.dispose();
  }
}