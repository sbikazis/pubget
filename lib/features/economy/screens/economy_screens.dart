import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/economy_models.dart';
import '../models/economy_types.dart';
import '../providers/economy_provider.dart';
import '../widgets/economy_widgets.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    final economy = context.read<EconomyProvider>();
    economy.openStore();
    Future<void>.microtask(economy.load);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(EconomyStrings.storeTitle),
        actions: <Widget>[
          CoinBalanceChip(
            balance: economy.coins,
            cached: economy.offlineCached,
            onPressed: () => AppNavigation.go(context, '/economy/history'),
          ),
          PubgetIconButton(
            icon: Icons.workspace_premium_outlined,
            tooltip: EconomyStrings.premium,
            onPressed: () => AppNavigation.go(context, '/premium'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const <Widget>[
            Tab(text: EconomyStrings.featured),
            Tab(text: EconomyStrings.categories),
            Tab(text: EconomyStrings.items),
            Tab(text: EconomyStrings.owned),
            Tab(text: EconomyStrings.premium),
          ],
        ),
      ),
      body: PubgetLoadingStateView(
        state: economy.state,
        onRetry: economy.load,
        error: PubgetErrorState(
          message: economy.failure?.message ?? 'The store could not load.',
          onRetry: economy.load,
        ),
        offline: PubgetOfflineState(onRetry: economy.load),
        empty: const PubgetEmptyState(
          title: EconomyStrings.storeTitle,
          message: EconomyStrings.emptyStore,
        ),
        child: TabBarView(
          controller: _tabs,
          children: <Widget>[
            _ItemGrid(
              items: (economy.snapshot?.catalog ?? const <StoreItem>[])
                  .where((item) => item.featured && item.isActive)
                  .toList(),
            ),
            const _CategoryList(),
            _ItemGrid(items: economy.snapshot?.catalog ?? const <StoreItem>[]),
            _ItemGrid(
              items: (economy.snapshot?.catalog ?? const <StoreItem>[])
                  .where((item) => economy.snapshot?.owns(item.id) == true)
                  .toList(),
              empty: EconomyStrings.emptyOwned,
            ),
            _ItemGrid(
              items: (economy.snapshot?.catalog ?? const <StoreItem>[])
                  .where((item) => item.premiumOnly)
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList();

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyProvider>();
    final catalog = economy.snapshot?.catalog ?? const <StoreItem>[];
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        for (final type in StoreItemType.values)
          PubgetCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            onTap: () => AppNavigation.go(
              context,
              '/store?type=${type.name}',
            ),
            child: Text(
              '${type.name} (${catalog.where((item) => item.type == type).length})',
            ),
          ),
      ],
    );
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.items, this.empty});

  final List<StoreItem> items;
  final String? empty;

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyProvider>();
    if (items.isEmpty) {
      return PubgetEmptyState(
        title: EconomyStrings.storeTitle,
        message: empty ?? EconomyStrings.emptyStore,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: StoreItemCard(
            item: item,
            owned: economy.snapshot?.owns(item.id) == true,
            equipped: economy.equipped.idFor(item.type) == item.id,
            onTap: () => AppNavigation.go(context, '/store/item?itemId=${item.id}'),
          ),
        );
      },
    );
  }
}

class StoreItemDetailsPage extends StatefulWidget {
  const StoreItemDetailsPage({required this.itemId, super.key});

  final String itemId;

  @override
  State<StoreItemDetailsPage> createState() => _StoreItemDetailsPageState();
}

class _StoreItemDetailsPageState extends State<StoreItemDetailsPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      final economy = context.read<EconomyProvider>();
      if (economy.snapshot == null) await economy.load();
      final item = economy.snapshot?.itemById(widget.itemId);
      if (item != null) economy.viewItem(item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyProvider>();
    final item = economy.snapshot?.itemById(widget.itemId);
    return Scaffold(
      appBar: AppBar(title: Text(item?.title ?? EconomyStrings.storeTitle)),
      body: PubgetLoadingStateView(
        state: economy.state,
        onRetry: economy.load,
        error: PubgetErrorState(
          message: economy.failure?.message ?? 'This item could not load.',
          onRetry: economy.load,
        ),
        offline: PubgetOfflineState(onRetry: economy.load),
        empty: const PubgetEmptyState(
          title: 'Item not found',
          message: EconomyStrings.emptyStore,
        ),
        child: item == null
            ? const PubgetEmptyState(
                title: 'Item not found',
                message: EconomyStrings.emptyStore,
              )
            : _ItemDetails(item: item),
      ),
    );
  }
}

class _ItemDetails extends StatelessWidget {
  const _ItemDetails({required this.item});

  final StoreItem item;

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyProvider>();
    final owned = economy.snapshot?.owns(item.id) == true;
    final equipped = economy.equipped.idFor(item.type) == item.id;
    final purchasing = economy.isPurchasing;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        EquippedAvatar(
          name: item.title,
          frameId: item.type == StoreItemType.frame ? item.id : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(item.description),
        const SizedBox(height: AppSpacing.md),
        Text('${item.price} ${EconomyStrings.coins}'),
        if (item.premiumOnly) ...[
          const SizedBox(height: AppSpacing.sm),
          const PubgetBadge(label: EconomyStrings.premiumRequired),
        ],
        if (owned) ...[
          const SizedBox(height: AppSpacing.sm),
          PubgetBadge(
            label: equipped ? EconomyStrings.equipped : EconomyStrings.owned,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        if (!owned)
          PubgetPrimaryButton(
            semanticLabel: 'Buy ${item.title} for ${item.price} coins',
            loading: purchasing,
            onPressed: purchasing
                ? null
                : () => _purchase(context, economy, item),
            child: Text('${EconomyStrings.buy} · ${item.price}'),
          )
        else if (equipped)
          PubgetSecondaryButton(
            semanticLabel: 'Unequip ${item.title}',
            onPressed: () => economy.unequip(item.type),
            child: const Text(EconomyStrings.unequip),
          )
        else
          PubgetPrimaryButton(
            semanticLabel: 'Equip ${item.title}',
            onPressed: () => economy.equip(item),
            child: const Text(EconomyStrings.equip),
          ),
        if (economy.purchaseFailure != null) ...[
          const SizedBox(height: AppSpacing.md),
          PubgetErrorState(message: economy.purchaseFailure!.message),
        ],
      ],
    );
  }

  Future<void> _purchase(
    BuildContext context,
    EconomyProvider economy,
    StoreItem item,
  ) async {
    final confirmed = await PubgetConfirmationDialog.show(
      context,
      title: EconomyStrings.confirmBuyTitle,
      message: EconomyStrings.confirmBuy(item.title, item.price),
      confirmLabel: EconomyStrings.buy,
      cancelLabel: 'Cancel',
    );
    if (confirmed != true) return;
    final ok = await economy.purchase(item);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(EconomyStrings.purchaseSuccess)),
      );
    }
  }
}

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(context.read<EconomyProvider>().load);
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyProvider>();
    final owned = (economy.snapshot?.catalog ?? const <StoreItem>[])
        .where((item) => economy.snapshot?.owns(item.id) == true)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text(EconomyStrings.inventory)),
      body: PubgetLoadingStateView(
        state: economy.state,
        onRetry: economy.load,
        error: PubgetErrorState(
          message: economy.failure?.message ?? 'Inventory could not load.',
          onRetry: economy.load,
        ),
        offline: PubgetOfflineState(onRetry: economy.load),
        empty: const PubgetEmptyState(
          title: EconomyStrings.inventory,
          message: EconomyStrings.emptyOwned,
        ),
        child: owned.isEmpty
            ? const PubgetEmptyState(
                title: EconomyStrings.inventory,
                message: EconomyStrings.emptyOwned,
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: owned.length,
                itemBuilder: (context, index) {
                  final item = owned[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: StoreItemCard(
                      item: item,
                      owned: true,
                      equipped: economy.equipped.idFor(item.type) == item.id,
                      onTap: () => AppNavigation.go(
                        context,
                        '/store/item?itemId=${item.id}',
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  @override
  void initState() {
    super.initState();
    final economy = context.read<EconomyProvider>();
    economy.viewPremium();
    Future<void>.microtask(economy.load);
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyProvider>();
    final premium = economy.premium;
    final statusLabel = switch (premium.status) {
      PremiumStatus.active => 'Active',
      PremiumStatus.expired => EconomyStrings.premiumExpired,
      PremiumStatus.inactive => EconomyStrings.premiumInactive,
    };
    return Scaffold(
      appBar: AppBar(title: const Text(EconomyStrings.premiumTitle)),
      body: PubgetLoadingStateView(
        state: economy.state,
        onRetry: economy.load,
        error: PubgetErrorState(
          message: economy.failure?.message ?? 'Premium could not load.',
          onRetry: economy.load,
        ),
        offline: PubgetOfflineState(onRetry: economy.load),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            Text(
              EconomyStrings.premiumBody,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            PubgetBadge(label: statusLabel),
            const SizedBox(height: AppSpacing.xl),
            PubgetSecondaryButton(
              semanticLabel: EconomyStrings.restore,
              onPressed: economy.restorePremium,
              child: const Text(EconomyStrings.restore),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              EconomyStrings.restoreDeferred,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class EconomyHistoryPage extends StatefulWidget {
  const EconomyHistoryPage({super.key});

  @override
  State<EconomyHistoryPage> createState() => _EconomyHistoryPageState();
}

class _EconomyHistoryPageState extends State<EconomyHistoryPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      final economy = context.read<EconomyProvider>();
      await economy.load();
      await economy.loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final economy = context.watch<EconomyProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(EconomyStrings.history),
        actions: <Widget>[
          CoinBalanceChip(balance: economy.coins, cached: economy.offlineCached),
        ],
      ),
      body: PubgetLoadingStateView(
        state: economy.historyState,
        onRetry: economy.loadHistory,
        error: PubgetErrorState(
          message: economy.failure?.message ?? 'History could not load.',
          onRetry: economy.loadHistory,
        ),
        offline: PubgetOfflineState(onRetry: economy.loadHistory),
        empty: const PubgetEmptyState(
          title: EconomyStrings.history,
          message: EconomyStrings.emptyHistory,
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: economy.history.length,
          itemBuilder: (context, index) {
            final tx = economy.history[index];
            final sign = tx.amount > 0 ? '+' : '';
            return PubgetCard(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(transactionTypeLabel(tx.type)),
                subtitle: Text(tx.createdAt?.toLocal().toString() ?? ''),
                trailing: Text('$sign${tx.amount}'),
              ),
            );
          },
        ),
      ),
    );
  }
}
