enum StoreItemType { frame, badge, nameplate, theme }

enum StoreItemAvailability { active, inactive }

enum StoreItemRarity { common, rare, epic }

enum StoreCurrency { coins }

enum EconomyTransactionType {
  earnEvent,
  earnGame,
  earnPublish,
  earnReferralInviter,
  earnReferralInvited,
  purchaseCosmetic,
  refund,
  adminAdjustment,
}

enum PremiumStatus { inactive, active, expired }

enum AdPlacement { homeFeed, groupEntry, storeFooter }

abstract final class EconomyStrings {
  static const storeTitle = 'Store';
  static const featured = 'Featured';
  static const categories = 'Categories';
  static const items = 'Items';
  static const owned = 'Owned';
  static const premium = 'Premium';
  static const inventory = 'Inventory';
  static const history = 'History';
  static const coins = 'Coins';
  static const buy = 'Buy';
  static const equip = 'Equip';
  static const unequip = 'Unequip';
  static const equipped = 'Equipped';
  static const premiumRequired = 'Premium required';
  static const alreadyOwned = 'Already owned';
  static const unavailable = 'Unavailable';
  static const emptyStore = 'Nothing in the store right now.';
  static const emptyOwned = 'You have not collected cosmetics yet.';
  static const emptyHistory = 'No coin activity yet.';
  static const premiumTitle = 'Pubget Premium';
  static const premiumBody =
      'Premium removes ads and unlocks exclusive cosmetics. Real payments are not connected in this build.';
  static const premiumInactive = 'Premium is not active.';
  static const premiumExpired = 'Premium has expired.';
  static const restore = 'Restore purchases';
  static const restoreDeferred =
      'Purchase restore is not available until a payment provider is configured.';
  static const offlineSensitive =
      'Purchases and rewards need a connection.';
  static const confirmBuyTitle = 'Confirm purchase';
  static String confirmBuy(String title, int price) =>
      'Buy $title for $price coins?';
  static const purchaseSuccess = 'Purchase complete.';
  static const cached = 'Showing cached coins.';
  static const adPlaceholder = 'Sponsored';
  static const adHidden = 'Ads are hidden with Premium.';
}

StoreItemType storeItemTypeFrom(Object? value) {
  return switch (value) {
    'badge' => StoreItemType.badge,
    'nameplate' => StoreItemType.nameplate,
    'theme' => StoreItemType.theme,
    _ => StoreItemType.frame,
  };
}

StoreItemAvailability storeAvailabilityFrom(Object? value) {
  return value == 'inactive'
      ? StoreItemAvailability.inactive
      : StoreItemAvailability.active;
}

StoreItemRarity storeRarityFrom(Object? value) {
  return switch (value) {
    'rare' => StoreItemRarity.rare,
    'epic' => StoreItemRarity.epic,
    _ => StoreItemRarity.common,
  };
}

EconomyTransactionType transactionTypeFrom(Object? value) {
  return switch (value) {
    'earn_game' => EconomyTransactionType.earnGame,
    'earn_publish' => EconomyTransactionType.earnPublish,
    'earn_referral_inviter' => EconomyTransactionType.earnReferralInviter,
    'earn_referral_invited' => EconomyTransactionType.earnReferralInvited,
    'purchase_cosmetic' => EconomyTransactionType.purchaseCosmetic,
    'refund' => EconomyTransactionType.refund,
    'admin_adjustment' => EconomyTransactionType.adminAdjustment,
    _ => EconomyTransactionType.earnEvent,
  };
}

String transactionTypeLabel(EconomyTransactionType type) {
  return switch (type) {
    EconomyTransactionType.earnEvent => 'Event reward',
    EconomyTransactionType.earnGame => 'Game reward',
    EconomyTransactionType.earnPublish => 'Publish reward',
    EconomyTransactionType.earnReferralInviter => 'Referral bonus',
    EconomyTransactionType.earnReferralInvited => 'Welcome bonus',
    EconomyTransactionType.purchaseCosmetic => 'Store purchase',
    EconomyTransactionType.refund => 'Refund',
    EconomyTransactionType.adminAdjustment => 'Adjustment',
  };
}
