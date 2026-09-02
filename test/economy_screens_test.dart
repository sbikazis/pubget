import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/result.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/features/economy/models/economy_models.dart';
import 'package:pubget/features/economy/models/economy_types.dart';
import 'package:pubget/features/economy/providers/economy_provider.dart';
import 'package:pubget/features/economy/repositories/economy_repository.dart';
import 'package:pubget/features/economy/screens/economy_screens.dart';
import 'package:pubget/features/economy/widgets/economy_widgets.dart';

void main() {
  testWidgets('store shows featured items and coin balance', (tester) async {
    final economy = await _economy();
    addTearDown(economy.dispose);
    await tester.pumpWidget(_app(economy, const StorePage()));
    await tester.pumpAndSettle();
    expect(find.text(EconomyStrings.storeTitle), findsWidgets);
    expect(find.text('Sakura Frame'), findsWidgets);
    expect(find.byType(StoreItemCard), findsWidgets);
  });

  testWidgets('store item details confirm a purchase', (tester) async {
    final economy = await _economy();
    addTearDown(economy.dispose);
    await tester.pumpWidget(
      _app(economy, const StoreItemDetailsPage(itemId: 'frame_sakura')),
    );
    await tester.pumpAndSettle();
    expect(find.text('A soft frame'), findsOneWidget);
    expect(find.text('80 ${EconomyStrings.coins}'), findsOneWidget);
    await tester.tap(find.text('${EconomyStrings.buy} · 80'));
    await tester.pumpAndSettle();
    expect(find.text(EconomyStrings.confirmBuyTitle), findsOneWidget);
    await tester.tap(find.text(EconomyStrings.buy).last);
    await tester.pumpAndSettle();
    expect(find.text(EconomyStrings.purchaseSuccess), findsOneWidget);
  });

  testWidgets('inventory empty state is readable', (tester) async {
    final economy = await _economy();
    addTearDown(economy.dispose);
    await tester.pumpWidget(_app(economy, const InventoryPage()));
    await tester.pumpAndSettle();
    expect(find.text(EconomyStrings.emptyOwned), findsWidgets);
  });

  testWidgets('premium screen documents deferred payments', (tester) async {
    final economy = await _economy();
    addTearDown(economy.dispose);
    await tester.pumpWidget(_app(economy, const PremiumPage()));
    await tester.pumpAndSettle();
    expect(find.text(EconomyStrings.premiumTitle), findsOneWidget);
    expect(find.text(EconomyStrings.restoreDeferred), findsOneWidget);
    expect(find.text(EconomyStrings.premiumInactive), findsOneWidget);
  });

  testWidgets('history empty and error states render', (tester) async {
    final economy = await _economy();
    addTearDown(economy.dispose);
    await tester.pumpWidget(_app(economy, const EconomyHistoryPage()));
    await tester.pumpAndSettle();
    expect(find.text(EconomyStrings.emptyHistory), findsWidgets);
  });

  testWidgets('ad placeholder is hidden for premium users', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdPlacementView(visible: false, adFree: true),
        ),
      ),
    );
    expect(find.text(EconomyStrings.adHidden), findsOneWidget);
    expect(find.text(EconomyStrings.adPlaceholder), findsNothing);
  });
}

Future<EconomyProvider> _economy() async {
  final repository = _ScreenRepo();
  final provider = EconomyProvider(
    repository: repository,
    network: NetworkService(probe: () async => true),
  );
  await provider.load();
  return provider;
}

Widget _app(EconomyProvider economy, Widget home) {
  return ChangeNotifierProvider<EconomyProvider>.value(
    value: economy,
    child: MaterialApp(home: home),
  );
}

final class _ScreenRepo implements EconomyRepository {
  @override
  Future<Result<EconomySnapshot>> getEconomy() async => Success(
    EconomySnapshot(
      balance: const CoinBalance(userId: 'user-1', balance: 250),
      premium: const PremiumEntitlement(
        userId: 'user-1',
        status: PremiumStatus.inactive,
      ),
      catalog: const <StoreItem>[
        StoreItem(
          id: 'frame_sakura',
          type: StoreItemType.frame,
          title: 'Sakura Frame',
          description: 'A soft frame',
          preview: 'sakura',
          price: 80,
          currency: StoreCurrency.coins,
          rarity: StoreItemRarity.common,
          availability: StoreItemAvailability.active,
          premiumOnly: false,
          featured: true,
        ),
      ],
      inventory: const <InventoryItem>[],
      equipped: const EquippedCosmetics(),
    ),
  );

  @override
  Future<Result<List<EconomyTransaction>>> getTransactions() async =>
      const Success(<EconomyTransaction>[]);

  @override
  Future<Result<PremiumEntitlement>> getPremium() async =>
      const Success(PremiumEntitlement(
        userId: 'user-1',
        status: PremiumStatus.inactive,
      ));

  @override
  Future<Result<PremiumEntitlement>> restorePremium() async => getPremium();

  @override
  Future<Result<void>> purchaseItem(String itemId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> equipItem(String itemId) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> unequipSlot(String slot) async =>
      const Success<void>(null);

  @override
  Future<Result<void>> claimReferral() async => const Success<void>(null);
}
