import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:firebase_core/firebase_core.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../models/economy_models.dart';
import 'economy_repository.dart';

final class FirebaseEconomyRepository implements EconomyRepository {
  FirebaseEconomyRepository({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final FirebaseFunctions _functions;

  @override
  Future<Result<EconomySnapshot>> getEconomy() => _guard(() async {
    final result = await _functions.httpsCallable('getEconomy').call();
    return _snapshotFrom(result.data);
  });

  @override
  Future<Result<List<EconomyTransaction>>> getTransactions() =>
      _guard(() async {
        final result = await _functions
            .httpsCallable('getEconomyTransactions')
            .call();
        final raw = result.data;
        final items = raw is Map && raw['items'] is List
            ? (raw['items'] as List)
            : const <Object?>[];
        return items
            .whereType<Map>()
            .map(
              (item) => EconomyTransaction.fromMap(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false);
      });

  @override
  Future<Result<PremiumEntitlement>> getPremium() => _guard(() async {
    final result = await _functions
        .httpsCallable('getPremiumEntitlement')
        .call();
    return PremiumEntitlement.fromMap(_map(result.data));
  });

  @override
  Future<Result<PremiumEntitlement>> restorePremium() => _guard(() async {
    final result = await _functions
        .httpsCallable('restorePremiumPurchases')
        .call();
    return PremiumEntitlement.fromMap(_map(result.data));
  });

  @override
  Future<Result<void>> purchaseItem(String itemId) =>
      _call('purchaseStoreItem', {'itemId': itemId});

  @override
  Future<Result<void>> equipItem(String itemId) =>
      _call('equipCosmetic', {'itemId': itemId});

  @override
  Future<Result<void>> unequipSlot(String slot) =>
      _call('unequipCosmetic', {'slot': slot});

  @override
  Future<Result<void>> claimReferral() =>
      _call('claimEconomyReward', {'source': 'referral'});

  Future<Result<void>> _call(String name, Map<String, dynamic> data) =>
      _guard(() async {
        await _functions.httpsCallable(name).call(data);
      });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success<T>(await action());
    } on Object catch (error) {
      return FailureResult<T>(_economyFailure(error));
    }
  }

  EconomySnapshot _snapshotFrom(Object? raw) {
    final data = _map(raw);
    final balance = CoinBalance.fromMap(_map(data['balance']));
    final premium = PremiumEntitlement.fromMap(_map(data['premium']));
    final catalog = _list(data['catalog'])
        .map((item) => StoreItem.fromMap(_map(item)))
        .toList(growable: false);
    final inventory = _list(data['inventory'])
        .map((item) => InventoryItem.fromMap(_map(item)))
        .toList(growable: false);
    return EconomySnapshot(
      balance: balance,
      premium: premium,
      catalog: catalog,
      inventory: inventory,
      equipped: EquippedCosmetics.fromMap(_map(data['equipped'])),
    );
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : const <Object?>[];
}

Failure _economyFailure(Object error) {
  if (error is FirebaseFunctionsException) {
    final detailsCode = _detailsCode(error.details);
    return switch (detailsCode ?? error.code) {
      'insufficient_funds' => InsufficientFundsError(
        error.message ?? 'You do not have enough coins.',
      ),
      'already_owned' || 'already-exists' => AlreadyOwnedError(
        error.message ?? 'You already own this item.',
      ),
      'premium_required' => PremiumRequiredError(
        error.message ?? 'Premium is required for this item.',
      ),
      'item_unavailable' => ItemUnavailableError(
        error.message ?? 'This item is not available.',
      ),
      'not_eligible' => NotEligibleError(
        error.message ?? 'You are not eligible for this action.',
      ),
      'rate_limited' || 'resource-exhausted' => RateLimitedError(
        error.message ?? 'Too many requests. Please wait a moment.',
      ),
      'aborted' => TransactionConflictError(
        error.message ?? 'Please try that purchase again.',
      ),
      'unauthenticated' || 'permission-denied' || 'unauthorized' =>
        PermissionError(error.message ?? "You don't have permission."),
      'unavailable' || 'deadline-exceeded' => NetworkError(
        error.message ?? 'Check your connection and try again.',
      ),
      'not-found' => NotFoundError(error.message ?? 'Not found.'),
      _ => ValidationError(error.message ?? 'That economy action failed.'),
    };
  }
  if (error is FirebaseException &&
      (error.code == 'unavailable' || error.code == 'deadline-exceeded')) {
    return const NetworkError('Check your connection and try again.');
  }
  return const UnknownError('Something went wrong. Try again.');
}

String? _detailsCode(Object? details) {
  if (details is Map && details['code'] is String) {
    return details['code'] as String;
  }
  return null;
}
