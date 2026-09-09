import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/sticker_catalog.dart';
import '../../data/sticker_store.dart';
import 'wa_colors.dart';
import 'whatsapp_chat_composer.dart';

enum WaPanelTab { stickers, gif, emoji }

class WaEmojiPanel extends StatefulWidget {
  const WaEmojiPanel({
    required this.onInsertEmoji,
    required this.onSendSticker,
    required this.onRequestGif,
    required this.onClose,
    required this.tabPrefKey,
    this.stickerStore,
    super.key,
  });

  final ValueChanged<String> onInsertEmoji;
  final Future<void> Function(String stickerKey) onSendSticker;
  final Future<void> Function() onRequestGif;
  final VoidCallback onClose;
  final String tabPrefKey;
  final StickerStore? stickerStore;

  @override
  State<WaEmojiPanel> createState() => _WaEmojiPanelState();
}

class _WaEmojiPanelState extends State<WaEmojiPanel> {
  var _tab = WaPanelTab.stickers;
  var _searching = false;
  var _query = '';
  final _search = TextEditingController();
  var _packIndex = 0;
  StickerStore? _store;

  static const _emojis = <String>[
    '😀', '😁', '😂', '🤣', '😊', '😍', '😘', '😜', '🤔', '😎',
    '😭', '😡', '👍', '👎', '🙏', '🔥', '❤️', '✨', '🎉', '👏',
    '💯', '🌙', '⭐', '🌸', '🐱', '🐶', '🍕', '⚽', '🎮', '🎵',
    '👋', '💪', '🤝', '😴', '🤯', '🥳', '😇', '🫶', '💬', '📌',
  ];

  @override
  void initState() {
    super.initState();
    _store = widget.stickerStore ?? StickerStore();
    unawaitedLoad();
  }

  Future<void> unawaitedLoad() async {
    final index = await loadWaPanelTab(widget.tabPrefKey);
    if (!mounted) return;
    setState(() {
      _tab = WaPanelTab.values[index.clamp(0, WaPanelTab.values.length - 1)];
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _selectTab(WaPanelTab tab) async {
    setState(() {
      _tab = tab;
      _searching = false;
      _query = '';
      _search.clear();
    });
    await saveWaPanelTab(widget.tabPrefKey, tab.index);
  }

  List<StickerItem> get _stickers {
    final base = List<StickerItem>.of(stickerCatalog);
    if (_query.trim().isEmpty) return base;
    final q = _query.trim().toLowerCase();
    return base
        .where(
          (item) =>
              item.name.toLowerCase().contains(q) ||
              item.category.toLowerCase().contains(q) ||
              item.key.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  List<String> get _filteredEmojis {
    if (_query.trim().isEmpty) return _emojis;
    // Simple filter: show all when searching by empty semantics; emoji has no names here.
    return _emojis;
  }

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height * 0.45).clamp(
      300.0,
      380.0,
    );
    return Material(
      color: WaColors.darkPanel,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: WaColors.handle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(
              height: 48,
              child: _searching ? _searchHeader() : _normalHeader(),
            ),
            Expanded(child: _body()),
            _packsBar(),
          ],
        ),
      ),
    );
  }

  Widget _normalHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit, size: 22, color: WaColors.iconMuted),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.55,
                height: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: WaColors.segmentIdle,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: <Widget>[
                      _segment(
                        selected: _tab == WaPanelTab.stickers,
                        onTap: () => _selectTab(WaPanelTab.stickers),
                        child: const Icon(Icons.sticky_note_2_outlined, size: 18),
                      ),
                      _segment(
                        selected: _tab == WaPanelTab.gif,
                        onTap: () => _selectTab(WaPanelTab.gif),
                        child: const Text(
                          'GIF',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      _segment(
                        selected: _tab == WaPanelTab.emoji,
                        onTap: () => _selectTab(WaPanelTab.emoji),
                        child: const Icon(Icons.emoji_emotions_outlined, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _searching = true),
            icon: const Icon(Icons.search, size: 24, color: WaColors.iconMuted),
          ),
        ],
      ),
    );
  }

  Widget _searchHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: _search,
        autofocus: true,
        style: const TextStyle(color: WaColors.textPrimary),
        cursorColor: WaColors.cursorGreen,
        onChanged: (value) => setState(() => _query = value),
        decoration: InputDecoration(
          hintText: 'بحث',
          hintStyle: const TextStyle(color: WaColors.iconMuted),
          border: InputBorder.none,
          prefixIcon: IconButton(
            onPressed: () => setState(() {
              _searching = false;
              _query = '';
              _search.clear();
            }),
            icon: const Icon(Icons.arrow_back, color: WaColors.iconMuted),
          ),
        ),
      ),
    );
  }

  Widget _segment({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? WaColors.segmentActive : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconTheme(
            data: IconThemeData(
              color: selected ? Colors.white : WaColors.iconMuted,
            ),
            child: DefaultTextStyle(
              style: TextStyle(
                color: selected ? Colors.white : WaColors.iconMuted,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return switch (_tab) {
      WaPanelTab.stickers => _stickerGrid(),
      WaPanelTab.gif => _gifPane(),
      WaPanelTab.emoji => _emojiGrid(),
    };
  }

  Widget _stickerGrid() {
    final items = _stickers;
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _createStickerCell();
        }
        final item = items[index - 1];
        return InkWell(
          key: Key('sticker-${item.key}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await _store?.remember(item.key);
            await widget.onSendSticker(item.key);
          },
          child: StickerMark(stickerKey: item.key, size: 78),
        );
      },
    );
  }

  Widget _createStickerCell() {
    return Material(
      color: WaColors.createStickerBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picker = ImagePicker();
          final file = await picker.pickImage(source: ImageSource.gallery);
          if (file == null) return;
          // Custom sticker editor is a follow-up; pick sends as image via GIF/media path.
          await widget.onRequestGif();
        },
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CircleAvatar(
              radius: 24,
              backgroundColor: WaColors.cursorGreen,
              child: Icon(Icons.edit, color: Colors.white, size: 22),
            ),
            SizedBox(height: 6),
            Text(
              'إنشاء\nملصق',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: WaColors.cursorGreen,
                fontSize: 13,
                height: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gifPane() {
    return Center(
      child: FilledButton.tonal(
        key: const Key('composer-gif'),
        onPressed: widget.onRequestGif,
        child: const Text('اختر GIF من المعرض'),
      ),
    );
  }

  Widget _emojiGrid() {
    final items = _filteredEmojis;
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final emoji = items[index];
        return InkWell(
          onTap: () => widget.onInsertEmoji(emoji),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
        );
      },
    );
  }

  Widget _packsBar() {
    final packs = stickerCategories;
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: packs.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _packChip(
              selected: false,
              child: const Icon(Icons.dashboard_customize_outlined,
                  color: WaColors.iconMuted),
              badge: Icons.add,
              badgeColor: WaColors.iconMuted,
              onTap: () {},
            );
          }
          final selected = _packIndex == index - 1;
          return _packChip(
            selected: selected,
            child: Icon(
              Icons.sticky_note_2,
              color: selected ? Colors.white : WaColors.iconMuted,
            ),
            badge: index == 1 ? Icons.star : Icons.add,
            badgeColor:
                index == 1 ? WaColors.cursorGreen : WaColors.iconMuted,
            onTap: () => setState(() => _packIndex = index - 1),
          );
        },
      ),
    );
  }

  Widget _packChip({
    required bool selected,
    required Widget child,
    required IconData badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? WaColors.segmentActive : WaColors.darkPill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: child,
          ),
        ),
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: WaColors.darkPanel,
              shape: BoxShape.circle,
              border: Border.all(color: WaColors.darkPanel),
            ),
            child: Icon(badge, size: 12, color: badgeColor),
          ),
        ),
      ],
    );
  }
}
