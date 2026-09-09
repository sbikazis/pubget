import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/emoji_library.dart';
import '../../data/user_sticker_store.dart';
import 'wa_colors.dart';
import 'whatsapp_chat_composer.dart';

enum WaPanelTab { stickers, emoji }

class WaEmojiPanel extends StatefulWidget {
  const WaEmojiPanel({
    required this.onInsertEmoji,
    required this.onSendCustomSticker,
    required this.onClose,
    required this.tabPrefKey,
    required this.currentUserId,
    required this.currentUserName,
    this.userStickerStore,
    super.key,
  });

  final ValueChanged<String> onInsertEmoji;
  final Future<void> Function({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String stickerCreatorId,
    required String stickerCreatorName,
  })
  onSendCustomSticker;
  final VoidCallback onClose;
  final String tabPrefKey;
  final String currentUserId;
  final String currentUserName;
  final UserStickerStore? userStickerStore;

  @override
  State<WaEmojiPanel> createState() => _WaEmojiPanelState();
}

class _WaEmojiPanelState extends State<WaEmojiPanel> {
  var _tab = WaPanelTab.stickers;
  var _searching = false;
  var _query = '';
  final _search = TextEditingController();
  var _emojiCategoryIndex = 0;
  late final UserStickerStore _store;
  List<UserStickerEntry> _stickers = const <UserStickerEntry>[];
  var _loadingStickers = true;

  @override
  void initState() {
    super.initState();
    _store = widget.userStickerStore ?? UserStickerStore();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final raw = await loadWaPanelTab(widget.tabPrefKey);
      // Legacy tabs: stickers=0, gif=1, emoji=2 → map gif→emoji, emoji→emoji.
      final tab = switch (raw) {
        2 => WaPanelTab.emoji,
        1 => WaPanelTab.emoji,
        _ => WaPanelTab.stickers,
      };
      final stickers = await _store.entries();
      if (!mounted) return;
      setState(() {
        _tab = tab;
        _stickers = stickers;
        _loadingStickers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStickers = false);
    }
  }

  Future<void> _reloadStickers() async {
    final stickers = await _store.entries();
    if (!mounted) return;
    setState(() => _stickers = stickers);
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
    await saveWaPanelTab(widget.tabPrefKey, tab == WaPanelTab.emoji ? 1 : 0);
  }

  List<UserStickerEntry> get _filteredStickers {
    if (_query.trim().isEmpty) return _stickers;
    final q = _query.trim().toLowerCase();
    return _stickers
        .where(
          (item) =>
              item.creatorName.toLowerCase().contains(q) ||
              item.path.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  List<EmojiCategory> get _emojiCategories {
    if (_query.trim().isEmpty) return emojiLibrary;
    final q = _query.trim();
    return emojiLibrary
        .map(
          (cat) => EmojiCategory(
            id: cat.id,
            labelAr: cat.labelAr,
            emojis: cat.emojis.where((e) => e.contains(q)).toList(growable: false),
          ),
        )
        .where((cat) => cat.emojis.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _createSticker() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    String path = picked.path;
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressFormat: ImageCompressFormat.png,
        compressQuality: 92,
        maxWidth: 512,
        maxHeight: 512,
        uiSettings: <PlatformUiSettings>[
          AndroidUiSettings(
            toolbarTitle: 'قص الملصق',
            toolbarColor: WaColors.cursorGreen,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
            hideBottomControls: false,
            aspectRatioPresets: const <CropAspectRatioPresetData>[
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
          IOSUiSettings(
            title: 'قص الملصق',
            aspectRatioPresets: const <CropAspectRatioPresetData>[
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
          if (kIsWeb)
            WebUiSettings(
              context: context,
              presentStyle: WebPresentStyle.dialog,
              size: const CropperSize(width: 520, height: 520),
            ),
        ],
      );
      if (cropped != null) path = cropped.path;
    } catch (_) {
      // Desktop/tests: cropper may be unavailable — use original image.
    }

    if (!mounted) return;
    final file = File(path);
    if (!file.existsSync()) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final action = await showModalBottomSheet<_StickerSaveAction>(
      context: context,
      backgroundColor: WaColors.darkPanel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _StickerPreviewSheet(bytes: bytes),
    );
    if (action == null || !mounted) return;

    final saved = await _store.addFromBytes(
      bytes,
      extension: 'png',
      creatorId: widget.currentUserId,
      creatorName: widget.currentUserName,
    );
    await _reloadStickers();
    if (action == _StickerSaveAction.saveAndSend) {
      final name = saved.path.split(Platform.pathSeparator).last;
      await widget.onSendCustomSticker(
        bytes: bytes,
        fileName: name,
        contentType: 'image/png',
        stickerCreatorId: widget.currentUserId,
        stickerCreatorName: widget.currentUserName,
      );
    }
  }

  Future<void> _sendStickerEntry(UserStickerEntry entry) async {
    final file = File(entry.path);
    if (!file.existsSync()) return;
    final bytes = await file.readAsBytes();
    final lower = entry.path.toLowerCase();
    final contentType = lower.endsWith('.jpg') || lower.endsWith('.jpeg')
        ? 'image/jpeg'
        : lower.endsWith('.webp')
        ? 'image/webp'
        : 'image/png';
    final creatorId = entry.creatorId.trim().isNotEmpty
        ? entry.creatorId
        : widget.currentUserId;
    final creatorName = entry.creatorName.trim().isNotEmpty
        ? entry.creatorName
        : widget.currentUserName;
    await widget.onSendCustomSticker(
      bytes: bytes,
      fileName: entry.path.split(Platform.pathSeparator).last,
      contentType: contentType,
      stickerCreatorId: creatorId,
      stickerCreatorName: creatorName,
    );
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
            if (_tab == WaPanelTab.emoji) _emojiCategoriesBar(),
            if (_tab == WaPanelTab.stickers) _stickerPacksBar(),
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
            key: const Key('composer-create-sticker-header'),
            onPressed: _createSticker,
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
                        child: const Icon(
                          Icons.sticky_note_2_outlined,
                          size: 18,
                        ),
                      ),
                      _segment(
                        selected: _tab == WaPanelTab.emoji,
                        onTap: () => _selectTab(WaPanelTab.emoji),
                        child: const Icon(
                          Icons.emoji_emotions_outlined,
                          size: 18,
                        ),
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
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
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
      WaPanelTab.stickers => _stickerBody(),
      WaPanelTab.emoji => _emojiGrid(),
    };
  }

  Widget _stickerBody() {
    if (_loadingStickers) {
      return const Center(
        child: CircularProgressIndicator(color: WaColors.cursorGreen),
      );
    }
    final items = _filteredStickers;
    if (items.isEmpty) {
      return _emptyStickers();
    }
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
        if (index == 0) return _createStickerCell();
        final entry = items[index - 1];
        return InkWell(
          key: Key('user-sticker-$index'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _sendStickerEntry(entry),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(entry.path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: WaColors.darkPill,
                child: Icon(Icons.broken_image, color: WaColors.iconMuted),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyStickers() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text(
            'ليس لديك ملصقات بعد',
            key: Key('stickers-empty-message'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: WaColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'أنشئ ملصقك الأول من صورة',
            textAlign: TextAlign.center,
            style: TextStyle(color: WaColors.iconMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 112,
            height: 112,
            child: _createStickerCell(),
          ),
        ],
      ),
    );
  }

  Widget _createStickerCell() {
    return Material(
      key: const Key('composer-create-sticker'),
      color: WaColors.createStickerBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _createSticker,
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

  Widget _emojiGrid() {
    final cats = _emojiCategories;
    if (cats.isEmpty) {
      return const Center(
        child: Text('لا نتائج', style: TextStyle(color: WaColors.iconMuted)),
      );
    }
    final safeIndex = _emojiCategoryIndex.clamp(0, cats.length - 1);
    final items = cats[safeIndex].emojis;
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
          key: Key('emoji-$emoji'),
          onTap: () => widget.onInsertEmoji(emoji),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
        );
      },
    );
  }

  Widget _emojiCategoriesBar() {
    final cats = _emojiCategories;
    if (cats.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: cats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final selected = _emojiCategoryIndex == index;
          final cat = cats[index];
          return InkWell(
            key: Key('emoji-cat-${cat.id}'),
            onTap: () => setState(() => _emojiCategoryIndex = index),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? WaColors.segmentActive : WaColors.darkPill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                cat.labelAr,
                style: TextStyle(
                  color: selected ? Colors.white : WaColors.iconMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _stickerPacksBar() {
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: <Widget>[
          _packChip(
            selected: true,
            child: const Icon(Icons.sticky_note_2, color: Colors.white),
            badge: Icons.star,
            badgeColor: WaColors.cursorGreen,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _packChip(
            selected: false,
            child: const Icon(
              Icons.add,
              color: WaColors.iconMuted,
            ),
            badge: Icons.add,
            badgeColor: WaColors.iconMuted,
            onTap: _createSticker,
          ),
        ],
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

enum _StickerSaveAction { save, saveAndSend }

class _StickerPreviewSheet extends StatelessWidget {
  const _StickerPreviewSheet({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: WaColors.handle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'معاينة الملصق',
              style: TextStyle(
                color: WaColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                bytes,
                width: 160,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    key: const Key('sticker-save'),
                    onPressed: () =>
                        Navigator.pop(context, _StickerSaveAction.save),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WaColors.cursorGreen,
                      side: const BorderSide(color: WaColors.cursorGreen),
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: const Text('حفظ'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('sticker-save-send'),
                    onPressed: () =>
                        Navigator.pop(context, _StickerSaveAction.saveAndSend),
                    style: FilledButton.styleFrom(
                      backgroundColor: WaColors.cursorGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: const Text('حفظ وإرسال'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
