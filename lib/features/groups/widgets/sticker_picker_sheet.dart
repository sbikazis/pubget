import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../data/sticker_catalog.dart';
import '../data/sticker_store.dart';

class StickerPickerSheet extends StatefulWidget {
  const StickerPickerSheet({this.store, super.key});

  final StickerStore? store;

  static Future<String?> show(BuildContext context, {StickerStore? store}) {
    return PubgetBottomSheet.present<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StickerPickerSheet(store: store),
    );
  }

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet> {
  late final StickerStore _store;
  String _category = 'Reactions';
  List<String> _recent = const <String>[];
  Set<String> _favorites = const <String>{};

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? StickerStore();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final recent = await _store.recent();
    final favorites = await _store.favorites();
    if (!mounted) return;
    setState(() {
      _recent = recent;
      _favorites = favorites;
    });
  }

  List<StickerItem> get _visible {
    if (_category == 'Recent') {
      return [
        for (final key in _recent)
          if (stickerByKey(key) != null) stickerByKey(key)!,
      ];
    }
    if (_category == 'Favorites') {
      return stickerCatalog
          .where((item) => _favorites.contains(item.key))
          .toList(growable: false);
    }
    return stickerCatalog
        .where((item) => item.category == _category)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 420,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category in stickerCategories)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          key: Key('sticker-category-$category'),
                          label: Text(category),
                          selected: _category == category,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _visible.isEmpty
                  ? PubgetEmptyState(
                      title: _category == 'Recent'
                          ? 'No recent stickers'
                          : 'No favorite stickers',
                      compact: true,
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                          ),
                      itemCount: _visible.length,
                      itemBuilder: (context, index) {
                        final sticker = _visible[index];
                        final favored = _favorites.contains(sticker.key);
                        return Stack(
                          children: [
                            InkWell(
                              key: Key('sticker-${sticker.key}'),
                              onTap: () async {
                                await _store.remember(sticker.key);
                                if (context.mounted) {
                                  Navigator.pop(context, sticker.key);
                                }
                              },
                              onLongPress: () async {
                                await _store.toggleFavorite(sticker.key);
                                await _load();
                              },
                              child: StickerMark(stickerKey: sticker.key),
                            ),
                            if (favored)
                              const Align(
                                alignment: Alignment.topRight,
                                child: Icon(Icons.star, size: 16),
                              ),
                          ],
                        );
                      },
                    ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text('Hold a sticker to favorite it'),
            ),
          ],
        ),
      ),
    );
  }
}
