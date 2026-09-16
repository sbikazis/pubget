import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/economy_models.dart';
import 'economy_repository.dart';

final class UnavailableEconomyRepository implements EconomyRepository {
  UnavailableEconomyRepository(this.message);

  final String message;

  Failure get _failure => UnavailableError(message);

  @override
  Future<Result<EconomySnapshot>> getEconomy() async =>
      FailureResult(_failure);

  @override
  Future<Result<List<EconomyTransaction>>> getTransactions() async =>
      FailureResult(_failure);

  @override
  Future<Result<PremiumEntitlement>> getPremium() async =>
      FailureResult(_failure);

  @override
  Future<Result<PremiumEntitlement>> restorePremium() async =>
      FailureResult(_failure);

  @override
  Future<Result<void>> purchaseItem(String itemId) async =>
      FailureResult(_failure);

  @override
  Future<Result<void>> equipItem(String itemId) async =>
      FailureResult(_failure);

  @override
  Future<Result<void>> unequipSlot(String slot) async =>
      FailureResult(_failure);

  @override
  Future<Result<void>> claimReferral() async => FailureResult(_failure);
}
