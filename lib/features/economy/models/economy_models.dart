import 'economy_types.dart';

final class CoinBalance {
  const CoinBalance({
    required this.userId,
    required this.balance,
    this.updatedAt,
    this.version = 0,
  });

  final String userId;
  final int balance;
  final DateTime? updatedAt;
  final int version;

  factory CoinBalance.fromMap(Map<String, dynamic> map, {String? userId}) {
    return CoinBalance(
      userId: userId ?? map['userId'] as String? ?? '',
      balance: _int(map['balance']),
      updatedAt: _date(map['updatedAt']),
      version: _int(map['version']),
    );
  }

  static int _int(Object? value) => value is num ? value.toInt() : 0;

  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

final class StoreItem {
  const StoreItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.preview,
    required this.price,
    required this.currency,
    required this.rarity,
    required this.availability,
    required this.premiumOnly,
    this.featured = false,
    this.version = 1,
    this.createdAt,
  });

  final String id;
  final StoreItemType type;
  final String title;
  final String description;
  final String preview;
  final int price;
  final StoreCurrency currency;
  final StoreItemRarity rarity;
  final StoreItemAvailability availability;
  final bool premiumOnly;
  final bool featured;
  final int version;
  final DateTime? createdAt;

  bool get isActive => availability == StoreItemAvailability.active;

  factory StoreItem.fromMap(Map<String, dynamic> map, {String? id}) {
    return StoreItem(
      id: id ?? map['id'] as String? ?? '',
      type: storeItemTypeFrom(map['type']),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      preview: map['preview'] as String? ?? '',
      price: map['price'] is num ? (map['price'] as num).toInt() : 0,
      currency: StoreCurrency.coins,
      rarity: storeRarityFrom(map['rarity']),
      availability: storeAvailabilityFrom(map['availability']),
      premiumOnly: map['premiumOnly'] == true,
      featured: map['featured'] == true,
      version: map['schemaVersion'] is num
          ? (map['schemaVersion'] as num).toInt()
          : 1,
    );
  }
}

final class InventoryItem {
  const InventoryItem({
    required this.itemId,
    required this.type,
    this.acquiredAt,
    this.source = 'purchase',
  });

  final String itemId;
  final StoreItemType type;
  final DateTime? acquiredAt;
  final String source;

  factory InventoryItem.fromMap(Map<String, dynamic> map, {String? itemId}) {
    return InventoryItem(
      itemId: itemId ?? map['itemId'] as String? ?? '',
      type: storeItemTypeFrom(map['type']),
      acquiredAt: CoinBalance._date(map['acquiredAt']),
      source: map['source'] as String? ?? 'purchase',
    );
  }
}

final class EquippedCosmetics {
  const EquippedCosmetics({
    this.frameId,
    this.badgeId,
    this.nameplateId,
    this.themeId,
  });

  final String? frameId;
  final String? badgeId;
  final String? nameplateId;
  final String? themeId;

  factory EquippedCosmetics.fromMap(Map<String, dynamic> map) {
    return EquippedCosmetics(
      frameId: _id(map['frameId'] ?? map['equippedFrameId']),
      badgeId: _id(map['badgeId'] ?? map['equippedBadgeId']),
      nameplateId: _id(map['nameplateId'] ?? map['equippedNameplateId']),
      themeId: _id(map['themeId'] ?? map['equippedThemeId']),
    );
  }

  String? idFor(StoreItemType type) {
    return switch (type) {
      StoreItemType.frame => frameId,
      StoreItemType.badge => badgeId,
      StoreItemType.nameplate => nameplateId,
      StoreItemType.theme => themeId,
    };
  }

  static String? _id(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

final class EconomyTransaction {
  const EconomyTransaction({
    required this.transactionId,
    required this.userId,
    required this.type,
    required this.amount,
    this.balanceBefore,
    this.balanceAfter,
    this.source,
    this.referenceId,
    this.createdAt,
    this.idempotencyKey,
    this.schemaVersion = 1,
  });

  final String transactionId;
  final String userId;
  final EconomyTransactionType type;
  final int amount;
  final int? balanceBefore;
  final int? balanceAfter;
  final String? source;
  final String? referenceId;
  final DateTime? createdAt;
  final String? idempotencyKey;
  final int schemaVersion;

  factory EconomyTransaction.fromMap(
    Map<String, dynamic> map, {
    String? id,
  }) {
    return EconomyTransaction(
      transactionId: id ?? map['transactionId'] as String? ?? map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      type: transactionTypeFrom(map['type']),
      amount: map['amount'] is num ? (map['amount'] as num).toInt() : 0,
      balanceBefore: map['balanceBefore'] is num
          ? (map['balanceBefore'] as num).toInt()
          : null,
      balanceAfter: map['balanceAfter'] is num
          ? (map['balanceAfter'] as num).toInt()
          : null,
      source: map['source'] as String?,
      referenceId: map['referenceId'] as String?,
      createdAt: CoinBalance._date(map['createdAt'] ?? map['timestamp']),
      idempotencyKey: map['idempotencyKey'] as String?,
      schemaVersion: map['schemaVersion'] is num
          ? (map['schemaVersion'] as num).toInt()
          : 1,
    );
  }
}

final class PremiumEntitlement {
  const PremiumEntitlement({
    required this.userId,
    required this.status,
    this.tier = 'free',
    this.startedAt,
    this.expiresAt,
    this.providerReference,
    this.adFree = false,
    this.paymentConfigured = false,
  });

  final String userId;
  final PremiumStatus status;
  final String tier;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final String? providerReference;
  final bool adFree;
  final bool paymentConfigured;

  bool get isActive => status == PremiumStatus.active && adFree;

  factory PremiumEntitlement.fromMap(
    Map<String, dynamic> map, {
    String? userId,
  }) {
    final statusName = map['status'] as String? ?? 'inactive';
    return PremiumEntitlement(
      userId: userId ?? map['userId'] as String? ?? '',
      status: switch (statusName) {
        'active' => PremiumStatus.active,
        'expired' => PremiumStatus.expired,
        _ => PremiumStatus.inactive,
      },
      tier: map['tier'] as String? ?? 'free',
      startedAt: CoinBalance._date(map['startedAt']),
      expiresAt: CoinBalance._date(map['expiresAt']),
      providerReference: map['providerReference'] as String?,
      adFree: map['adFree'] == true,
      paymentConfigured: map['paymentConfigured'] == true,
    );
  }
}

final class EconomySnapshot {
  const EconomySnapshot({
    required this.balance,
    required this.premium,
    required this.catalog,
    required this.inventory,
    required this.equipped,
    this.cached = false,
  });

  final CoinBalance balance;
  final PremiumEntitlement premium;
  final List<StoreItem> catalog;
  final List<InventoryItem> inventory;
  final EquippedCosmetics equipped;
  final bool cached;

  bool owns(String itemId) =>
      inventory.any((item) => item.itemId == itemId);

  StoreItem? itemById(String id) {
    for (final item in catalog) {
      if (item.id == id) return item;
    }
    return null;
  }
}

final class AdPlacementConfig {
  const AdPlacementConfig({
    required this.placement,
    this.enabled = true,
    this.frequencyPerDay = 2,
    this.cooldown = const Duration(minutes: 5),
    this.premiumExcluded = true,
  });

  final AdPlacement placement;
  final bool enabled;
  final int frequencyPerDay;
  final Duration cooldown;
  final bool premiumExcluded;
}

final class AdImpressionLog {
  const AdImpressionLog({this.shownAt = const <AdPlacement, List<DateTime>>{}});

  final Map<AdPlacement, List<DateTime>> shownAt;

  AdImpressionLog recorded(AdPlacement placement, DateTime at) {
    final next = <AdPlacement, List<DateTime>>{
      for (final entry in shownAt.entries)
        entry.key: List<DateTime>.from(entry.value),
    };
    next.putIfAbsent(placement, () => <DateTime>[]).add(at);
    return AdImpressionLog(shownAt: next);
  }
}
