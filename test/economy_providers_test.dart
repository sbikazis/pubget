import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/features/economy/ads/ads_service.dart';
import 'package:pubget/features/economy/entitlement/entitlement_service.dart';
import 'package:pubget/features/economy/models/economy_models.dart';
import 'package:pubget/features/economy/models/economy_types.dart';
import 'package:pubget/features/economy/providers/economy_provider.dart';
import 'package:pubget/features/economy/repositories/economy_repository.dart';

void main() {
  test('store items parse integer coin prices', () {
    final item = StoreItem.fromMap(const {
      'id': 'frame_sakura',
      'type': 'frame',
      'title': 'Sakura Frame',
      'description': 'A frame',
      'preview': 'sakura',
      'price': 80,
      'rarity': 'common',
      'availability': 'active',
      'premiumOnly': false,
    });
    expect(item.price, 80);
    expect(item.currency, StoreCurrency.coins);
    expect(item.isActive, isTrue);
  });

  test('premium entitlement expires independently of client flags', () {
    const entitlement = EntitlementService();
    final expired = PremiumEntitlement.fromMap(const {
      'userId': 'u1',
      'status': 'expired',
      'adFree': false,
    });
    expect(entitlement.isAdFree(expired), isFalse);
    expect(
      entitlement.canAccessPremiumItem(
        entitlement: expired,
        premiumOnly: true,
      ),
      isFalse,
    );
    final active = PremiumEntitlement.fromMap(const {
      'userId': 'u1',
      'status': 'active',
      'adFree': true,
    });
    expect(entitlement.isPremium(active), isTrue);
    expect(entitlement.isAdFree(active), isTrue);
  });

  test('ads honor premium exclusion, cooldown, and daily frequency', () {
    final ads = AdsService();
    const configNow = null;
    final now = DateTime(2026, 9, 2, 12);
    expect(
      ads.shouldShow(
        placement: AdPlacement.homeFeed,
        isAdFree: true,
        now: now,
        log: const AdImpressionLog(),
      ),
      isFalse,
    );
    var log = const AdImpressionLog();
    expect(
      ads.shouldShow(
        placement: AdPlacement.homeFeed,
        isAdFree: false,
        now: now,
        log: log,
      ),
      isTrue,
    );
    log = log.recorded(AdPlacement.homeFeed, now);
    expect(
      ads.shouldShow(
        placement: AdPlacement.homeFeed,
        isAdFree: false,
        now: now.add(const Duration(minutes: 1)),
        log: log,
      ),
      isFalse,
    );
    expect(
      ads.shouldShow(
        placement: AdPlacement.homeFeed,
        isAdFree: false,
        now: now.add(const Duration(minutes: 6)),
        log: log,
      ),
      isTrue,
    );
    log = log.recorded(AdPlacement.homeFeed, now.add(const Duration(minutes: 6)));
    expect(
      ads.shouldShow(
        placement: AdPlacement.homeFeed,
        isAdFree: false,
        now: now.add(const Duration(minutes: 20)),
        log: log,
      ),
      isFalse,
    );
    expect(configNow, isNull);
  });

  test('economy provider purchases through the repository and blocks double taps', () async {
    final repository = _FakeEconomyRepository()
      ..snapshot = _snapshot(balance: 200);
    final network = NetworkService(probe: () async => true);
    final provider = EconomyProvider(repository: repository, network: network);
    addTearDown(provider.dispose);
    await provider.load();
    expect(provider.coins, 200);
    final first = provider.purchase(repository.snapshot!.catalog.first);
    final second = provider.purchase(repository.snapshot!.catalog.first);
    expect(await second, isFalse);
    expect(await first, isTrue);
    expect(repository.purchases, 1);
    expect(provider.coins, 120);
  });

  test('offline mode does not purchase', () async {
    final repository = _FakeEconomyRepository()
      ..snapshot = _snapshot(balance: 200);
    final network = NetworkService(probe: () async => false);
    await network.refresh();
    final provider = EconomyProvider(repository: repository, network: network);
    addTearDown(provider.dispose);
    await provider.load();
    expect(provider.offlineCached, isTrue);
    expect(await provider.purchase(repository.snapshot!.catalog.first), isFalse);
    expect(repository.purchases, 0);
    expect(provider.purchaseFailure, isA<NetworkError>());
  });

  test('insufficient funds surface a typed failure', () async {
    final repository = _FakeEconomyRepository()
      ..snapshot = _snapshot(balance: 10)
      ..purchaseFailure = const InsufficientFundsError();
    final provider = EconomyProvider(
      repository: repository,
      network: NetworkService(probe: () async => true),
    );
    addTearDown(provider.dispose);
    await provider.load();
    expect(await provider.purchase(repository.snapshot!.catalog.first), isFalse);
    expect(provider.purchaseFailure, isA<InsufficientFundsError>());
  });
}

EconomySnapshot _snapshot({int balance = 0}) {
  const item = StoreItem(
    id: 'frame_sakura',
    type: StoreItemType.frame,
    title: 'Sakura Frame',
    description: 'A frame',
    preview: 'sakura',
    price: 80,
    currency: StoreCurrency.coins,
    rarity: StoreItemRarity.common,
    availability: StoreItemAvailability.active,
    premiumOnly: false,
  );
  return EconomySnapshot(
    balance: CoinBalance(userId: 'user-1', balance: balance),
    premium: const PremiumEntitlement(
      userId: 'user-1',
      status: PremiumStatus.inactive,
    ),
    catalog: const <StoreItem>[item],
    inventory: const <InventoryItem>[],
    equipped: const EquippedCosmetics(),
  );
}

final class _FakeEconomyRepository implements EconomyRepository {
  EconomySnapshot? snapshot;
  Failure? purchaseFailure;
  int purchases = 0;

  @override
  Future<Result<EconomySnapshot>> getEconomy() async =>
      Success(snapshot ?? _snapshot());

  @override
  Future<Result<List<EconomyTransaction>>> getTransactions() async =>
      const Success(<EconomyTransaction>[]);

  @override
  Future<Result<PremiumEntitlement>> getPremium() async =>
      Success(snapshot?.premium ?? _snapshot().premium);

  @override
  Future<Result<PremiumEntitlement>> restorePremium() async =>
      Success(snapshot?.premium ?? _snapshot().premium);

  @override
  Future<Result<void>> purchaseItem(String itemId) async {
    if (purchaseFailure != null) return FailureResult(purchaseFailure!);
    purchases += 1;
    final current = snapshot ?? _snapshot();
    snapshot = EconomySnapshot(
      balance: CoinBalance(
        userId: current.balance.userId,
        balance: current.balance.balance - 80,
      ),
      premium: current.premium,
      catalog: current.catalog,
      inventory: <InventoryItem>[
        ...current.inventory,
        const InventoryItem(itemId: 'frame_sakura', type: StoreItemType.frame),
      ],
      equipped: current.equipped,
    );
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> equipItem(String itemId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> unequipSlot(String slot) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> claimReferral() async => const Success<void>(null);
}
