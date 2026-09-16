import '../../../core/errors/result.dart';
import '../models/economy_models.dart';

abstract interface class EconomyRepository {
  Future<Result<EconomySnapshot>> getEconomy();
  Future<Result<List<EconomyTransaction>>> getTransactions();
  Future<Result<PremiumEntitlement>> getPremium();
  Future<Result<PremiumEntitlement>> restorePremium();
  Future<Result<void>> purchaseItem(String itemId);
  Future<Result<void>> equipItem(String itemId);
  Future<Result<void>> unequipSlot(String slot);
  Future<Result<void>> claimReferral();
}
