import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/errors/failure.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/network/network_service.dart';
import '../ads/ads_service.dart';
import '../entitlement/entitlement_service.dart';
import '../models/economy_models.dart';
import '../models/economy_types.dart';
import '../repositories/economy_repository.dart';

enum PurchasePhase { idle, purchasing, success, failure }

final class EconomyProvider extends ChangeNotifier {
  EconomyProvider({
    required EconomyRepository repository,
    required NetworkService network,
    Analytics? analytics,
    EntitlementService entitlement = const EntitlementService(),
    AdsService? ads,
  }) : _repository = repository,
       _network = network,
       _analytics = analytics,
       _entitlement = entitlement,
       _ads = ads ?? AdsService();

  final EconomyRepository _repository;
  final NetworkService _network;
  final Analytics? _analytics;
  final EntitlementService _entitlement;
  final AdsService _ads;

  EconomySnapshot? _snapshot;
  List<EconomyTransaction> _history = const <EconomyTransaction>[];
  LoadingState _state = LoadingState.initial;
  LoadingState _historyState = LoadingState.initial;
  Failure? _failure;
  Failure? _purchaseFailure;
  PurchasePhase _purchasePhase = PurchasePhase.idle;
  AdImpressionLog _adsLog = const AdImpressionLog();
  bool _offlineCached = false;
  String? _boundUserId;
  bool _disposed = false;

  EconomySnapshot? get snapshot => _snapshot;
  List<EconomyTransaction> get history => _history;
  LoadingState get state => _state;
  LoadingState get historyState => _historyState;
  Failure? get failure => _failure;
  Failure? get purchaseFailure => _purchaseFailure;
  PurchasePhase get purchasePhase => _purchasePhase;
  bool get isPurchasing => _purchasePhase == PurchasePhase.purchasing;
  bool get offlineCached => _offlineCached;
  int get coins => _snapshot?.balance.balance ?? 0;
  PremiumEntitlement get premium =>
      _snapshot?.premium ??
      const PremiumEntitlement(userId: '', status: PremiumStatus.inactive);
  EquippedCosmetics get equipped =>
      _snapshot?.equipped ?? const EquippedCosmetics();
  bool get isAdFree => _entitlement.isAdFree(premium);
  bool get isPremium => _entitlement.isPremium(premium);

  Future<void> load({bool refresh = false}) async {
    if (!refresh && _state == LoadingState.loading) return;
    _failure = null;
    if (_snapshot == null) {
      _setState(LoadingState.loading);
    } else {
      _setState(LoadingState.refreshing);
    }
    if (_network.isOffline) {
      if (_snapshot != null) {
        _offlineCached = true;
        _setState(LoadingState.loaded);
        return;
      }
      _failure = const NetworkError(EconomyStrings.offlineSensitive);
      _setState(LoadingState.offline);
      return;
    }
    final result = await _repository.getEconomy();
    if (_disposed) return;
    result.fold(
      onSuccess: (value) {
        _snapshot = value;
        _offlineCached = false;
        _setState(value.catalog.isEmpty ? LoadingState.empty : LoadingState.loaded);
      },
      onFailure: (error) {
        _failure = error;
        if (_snapshot != null) {
          _offlineCached = true;
          _setState(LoadingState.loaded);
        } else if (error is NetworkError) {
          _setState(LoadingState.offline);
        } else {
          _setState(LoadingState.error);
        }
      },
    );
  }

  Future<void> loadHistory() async {
    _historyState = LoadingState.loading;
    _notify();
    if (_network.isOffline) {
      _historyState = _history.isEmpty
          ? LoadingState.offline
          : LoadingState.loaded;
      _notify();
      return;
    }
    final result = await _repository.getTransactions();
    if (_disposed) return;
    result.fold(
      onSuccess: (items) {
        _history = items;
        _historyState = items.isEmpty ? LoadingState.empty : LoadingState.loaded;
      },
      onFailure: (error) {
        _failure = error;
        _historyState = error is NetworkError
            ? LoadingState.offline
            : LoadingState.error;
      },
    );
    _notify();
  }

  Future<bool> purchase(StoreItem item) async {
    if (isPurchasing) return false;
    _analytics?.logEvent('purchase_started', parameters: {'itemId': item.id});
    if (_network.isOffline) {
      _purchaseFailure = const NetworkError(EconomyStrings.offlineSensitive);
      _purchasePhase = PurchasePhase.failure;
      _notify();
      return false;
    }
    _purchasePhase = PurchasePhase.purchasing;
    _purchaseFailure = null;
    _notify();
    final result = await _repository.purchaseItem(item.id);
    if (_disposed) return false;
    final error = result.failureOrNull;
    if (error != null) {
      _purchaseFailure = error;
      _purchasePhase = PurchasePhase.failure;
      _analytics?.logEvent(
        'purchase_failed',
        parameters: {'itemId': item.id},
      );
      _notify();
      return false;
    }
    _purchasePhase = PurchasePhase.success;
    _analytics?.logEvent('purchase_completed', parameters: {'itemId': item.id});
    await load(refresh: true);
    _notify();
    return true;
  }

  void clearPurchasePhase() {
    _purchasePhase = PurchasePhase.idle;
    _purchaseFailure = null;
    _notify();
  }

  Future<void> equip(StoreItem item) async {
    if (_network.isOffline) return;
    final result = await _repository.equipItem(item.id);
    if (result.isSuccess) await load(refresh: true);
  }

  Future<void> unequip(StoreItemType type) async {
    if (_network.isOffline) return;
    final slot = switch (type) {
      StoreItemType.frame => 'frame',
      StoreItemType.badge => 'badge',
      StoreItemType.nameplate => 'nameplate',
      StoreItemType.theme => 'theme',
    };
    final result = await _repository.unequipSlot(slot);
    if (result.isSuccess) await load(refresh: true);
  }

  Future<void> restorePremium() async {
    if (_network.isOffline) return;
    await _repository.restorePremium();
    await load(refresh: true);
  }

  bool showAd(AdPlacement placement, [DateTime? now]) {
    final clock = now ?? DateTime.now();
    final eligible = _ads.shouldShow(
      placement: placement,
      isAdFree: isAdFree,
      now: clock,
      log: _adsLog,
    );
    if (!eligible) return false;
    _adsLog = _adsLog.recorded(placement, clock);
    _analytics?.logEvent(
      'ad_impression',
      parameters: {'placement': placement.name},
    );
    _notify();
    return true;
  }

  void openStore() {
    _analytics?.logEvent('store_open');
  }

  void viewItem(StoreItem item) {
    _analytics?.logEvent('item_view', parameters: {'itemId': item.id});
  }

  void viewPremium() {
    _analytics?.logEvent('premium_view');
  }

  void resetSession() {
    _snapshot = null;
    _history = const <EconomyTransaction>[];
    _failure = null;
    _purchaseFailure = null;
    _purchasePhase = PurchasePhase.idle;
    _adsLog = const AdImpressionLog();
    _offlineCached = false;
    _state = LoadingState.initial;
    _historyState = LoadingState.initial;
    _notify();
  }

  void bindUser(String? userId) {
    if (_boundUserId == userId) return;
    _boundUserId = userId;
    resetSession();
  }

  void _setState(LoadingState next) {
    _state = next;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

EconomyProvider? maybeEconomy(BuildContext context, {bool listen = true}) {
  try {
    return Provider.of<EconomyProvider>(context, listen: listen);
  } on ProviderNotFoundException {
    return null;
  }
}
