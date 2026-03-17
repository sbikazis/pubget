import 'dart:async';
import 'package:flutter/material.dart';

import '../models/group_model.dart';
import '../models/user_model.dart';

import '../services/firebase/firestore_service.dart';
import '../services/monetization/promotion_service.dart';
import '../services/monetization/ad_service.dart';

import '../core/constants/firestore_paths.dart';
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

  List<GroupModel> _myGroups = [];
  List<GroupModel> get myGroups => _myGroups;

  List<GroupModel> _joinedGroups = [];
  List<GroupModel> get joinedGroups => _joinedGroups;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  StreamSubscription? _promotedSub;

  // =====================================================
  // INITIALIZE
  // =====================================================

  Future<void> initialize({required UserModel currentUser}) async {
    _setLoading(true);
    _currentUser = currentUser;

    await Future.wait([_loadPromotedGroups(), _loadUserGroups(currentUser.id)]);

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
  // USER GROUPS
  // =====================================================

  Future<void> _loadUserGroups(String userId) async {
    final snapshot = await _firestore.getCollection(
      path: FirestorePaths.groups,
    );

    final groups = snapshot.docs
        .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
        .toList();

    _myGroups = groups.where((g) => g.founderId == userId).toList();

    _joinedGroups = groups.where((g) => g.founderId != userId).toList();

    notifyListeners();
  }

  // =====================================================
  // SEARCH
  // =====================================================

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    notifyListeners();
  }

  List<GroupModel> get filteredPromotedGroups {
    if (_searchQuery.isEmpty) return _promotedGroups;

    return _promotedGroups
        .where((group) => group.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  List<GroupModel> get filteredMyGroups {
    if (_searchQuery.isEmpty) return _myGroups;

    return _myGroups
        .where((group) => group.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  List<GroupModel> get filteredJoinedGroups {
    if (_searchQuery.isEmpty) return _joinedGroups;

    return _joinedGroups
        .where((group) => group.name.toLowerCase().contains(_searchQuery))
        .toList();
  }

  // =====================================================
  // JOIN GROUP
  // =====================================================

  Future<String?> joinGroup({
    required UserModel user,
    required GroupModel group,
    String? characterName,
    String? characterImage,
  }) async {
    // Subscription limit check
    final limitResult = SubscriptionLimitsLogic.canJoinGroup(
      subscriptionType: user.subscriptionType,
      currentJoinedGroups: _joinedGroups.length,
    );

    if (!limitResult.isAllowed) {
      return limitResult.message;
    }

    // Roleplay validation
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

    // Add member document
    await _firestore.createDocument(
      path: FirestorePaths.groupMembers(group.id),
      docId: user.id,
      data: {'userId': user.id, 'joinedAt': DateTime.now()},
    );

    // Update member count
    await _firestore.updateDocument(
      path: FirestorePaths.groups,
      docId: group.id,
      data: {'membersCount': group.membersCount + 1},
    );

    return null;
  }

  // =====================================================
  // ADS
  // =====================================================

  Future<void> tryShowMorningAd({required bool isPremium}) async {
    await _adService.tryShowMorningAd(isPremium: isPremium);
  }

  Future<void> tryShowGroupAd({required bool isPremium}) async {
    await _adService.tryShowGroupAd(isPremium: isPremium);
  }

  // =====================================================
  // REFRESH
  // =====================================================

  Future<void> refresh(UserModel user) async {
    await initialize(currentUser: user);
  }

  // =====================================================
  // LOADING
  // =====================================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    _promotedSub?.cancel();
    super.dispose();
  }
}
