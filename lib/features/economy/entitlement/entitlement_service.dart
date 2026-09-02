import '../models/economy_models.dart';

final class EntitlementService {
  const EntitlementService();

  bool isPremium(PremiumEntitlement entitlement) => entitlement.isActive;

  bool isAdFree(PremiumEntitlement entitlement) => entitlement.adFree;

  bool canAccessPremiumItem({
    required PremiumEntitlement entitlement,
    required bool premiumOnly,
  }) {
    return !premiumOnly || entitlement.isActive;
  }
}
