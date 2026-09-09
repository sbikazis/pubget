import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';
import 'chat_contrast_theme.dart';
import 'chat_message_bubble.dart';

enum ChatMessageAction {
  reply,
  copy,
  forward,
  pin,
  star,
  edit,
  info,
  delete,
  react,
  dismiss,
}

final class ChatMessageActionResult {
  const ChatMessageActionResult.action(this.action)
      : reaction = null;

  const ChatMessageActionResult.reaction(this.reaction)
      : action = ChatMessageAction.react;

  final ChatMessageAction action;
  final String? reaction;
}

const kChatQuickReactions = <String>['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// WhatsApp-style long-press overlay: dim, elevate bubble, reaction pill, menu.
Future<ChatMessageActionResult?> showChatMessageActions(
  BuildContext context, {
  required ChatMessage message,
  required bool isMine,
  required ChatContrastTheme contrast,
  required Rect bubbleRect,
  required bool canEdit,
  required bool canCopy,
  required bool isStarred,
}) {
  HapticFeedback.lightImpact();
  return Navigator.of(context).push<ChatMessageActionResult>(
    PageRouteBuilder<ChatMessageActionResult>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 100),
      pageBuilder: (context, animation, secondary) {
        return FadeTransition(
          opacity: animation,
          child: _ChatMessageActionsOverlay(
            message: message,
            isMine: isMine,
            contrast: contrast,
            bubbleRect: bubbleRect,
            canEdit: canEdit,
            canCopy: canCopy,
            isStarred: isStarred,
            animation: animation,
          ),
        );
      },
    ),
  );
}

class _ChatMessageActionsOverlay extends StatelessWidget {
  const _ChatMessageActionsOverlay({
    required this.message,
    required this.isMine,
    required this.contrast,
    required this.bubbleRect,
    required this.canEdit,
    required this.canCopy,
    required this.isStarred,
    required this.animation,
  });

  final ChatMessage message;
  final bool isMine;
  final ChatContrastTheme contrast;
  final Rect bubbleRect;
  final bool canEdit;
  final bool canCopy;
  final bool isStarred;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    const pillHeight = 48.0;
    const pillGap = 8.0;
    final menuWidth = size.width >= 420 ? 250.0 : 220.0;

    // Prefer reaction pill above the bubble; flip below if near top.
    final spaceAbove = bubbleRect.top - padding.top;
    final pillAbove = spaceAbove >= pillHeight + pillGap + 12;
    final pillTop = pillAbove
        ? bubbleRect.top - pillGap - pillHeight
        : bubbleRect.bottom + pillGap;

    // Menu below bubble by default; flip above if not enough room.
    final estimatedMenuHeight = _estimateMenuHeight(
      canCopy: canCopy,
      canEdit: canEdit,
    );
    final spaceBelow = size.height - padding.bottom - bubbleRect.bottom;
    final menuBelow = spaceBelow >= estimatedMenuHeight + 16;
    final menuTop = menuBelow
        ? (pillAbove ? bubbleRect.bottom + pillGap : pillTop + pillHeight + 8)
        : bubbleRect.top - estimatedMenuHeight - pillGap;

    final pillLeft = (bubbleRect.center.dx - 160).clamp(
      12.0,
      size.width - 320 - 12,
    );
    final menuLeft = isMine
        ? (bubbleRect.right - menuWidth).clamp(12.0, size.width - menuWidth - 12)
        : bubbleRect.left.clamp(12.0, size.width - menuWidth - 12);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(
                context,
                const ChatMessageActionResult.action(ChatMessageAction.dismiss),
              ),
              child: const ColoredBox(color: Color(0x66000000)),
            ),
          ),
          Positioned(
            left: bubbleRect.left.clamp(8.0, size.width - 48),
            top: bubbleRect.top.clamp(padding.top + 4, size.height - 80),
            child: IgnorePointer(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: size.width * 0.78),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ChatMessageBubble(
                    message: message,
                    isMine: isMine,
                    contrast: contrast,
                    showAvatar: false,
                    showHeader: !isMine,
                    showTail: true,
                    onLongPress: (_) {},
                    onMediaTap: null,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: pillLeft,
            top: pillTop.clamp(padding.top + 4, size.height - pillHeight - 8),
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: _ReactionPill(
                dark: dark,
                onPick: (emoji) => Navigator.pop(
                  context,
                  ChatMessageActionResult.reaction(emoji),
                ),
                onMore: () async {
                  final extra = await _pickMoreEmoji(context);
                  if (extra == null || !context.mounted) return;
                  Navigator.pop(
                    context,
                    ChatMessageActionResult.reaction(extra),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: menuLeft,
            top: menuTop.clamp(
              padding.top + 4,
              size.height - estimatedMenuHeight - padding.bottom - 8,
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: FadeTransition(
                opacity: animation,
                child: _ActionsMenu(
                  width: menuWidth,
                  dark: dark,
                  canCopy: canCopy,
                  canEdit: canEdit,
                  isStarred: isStarred,
                  pinned: message.pinnedAt != null,
                  onSelect: (action) => Navigator.pop(
                    context,
                    ChatMessageActionResult.action(action),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _estimateMenuHeight({required bool canCopy, required bool canEdit}) {
    var items = 6; // reply forward pin star info delete
    if (canCopy) items++;
    if (canEdit) items++;
    return 16 + items * 44.0 + 2; // padding + items + dividers approx
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.dark,
    required this.onPick,
    required this.onMore,
  });

  final bool dark;
  final ValueChanged<String> onPick;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? const Color(0xFF263843) : Colors.white,
      elevation: 8,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final emoji in kChatQuickReactions)
                SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    key: Key('chat-react-$emoji'),
                    padding: EdgeInsets.zero,
                    onPressed: () => onPick(emoji),
                    icon: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              const SizedBox(width: 2),
              Material(
                color: dark
                    ? const Color(0xFF1F2C34)
                    : const Color(0xFFE9EDEF),
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('chat-react-more'),
                  customBorder: const CircleBorder(),
                  onTap: onMore,
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.add,
                      size: 20,
                      color: Color(0xFF8696A0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({
    required this.width,
    required this.dark,
    required this.canCopy,
    required this.canEdit,
    required this.isStarred,
    required this.pinned,
    required this.onSelect,
  });

  final double width;
  final bool dark;
  final bool canCopy;
  final bool canEdit;
  final bool isStarred;
  final bool pinned;
  final ValueChanged<ChatMessageAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final iconColor = dark ? const Color(0xFF8696A0) : const Color(0xFF667781);
    final divider = dark ? const Color(0xFF222D34) : const Color(0xFFE9EDEF);
    final textColor = dark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);

    Widget item({
      required Key key,
      required String label,
      required IconData icon,
      required ChatMessageAction action,
      Color? danger,
    }) {
      return InkWell(
        key: key,
        onTap: () => onSelect(action),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: danger ?? textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(icon, size: 20, color: danger ?? iconColor),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget hairline() => Container(height: 1, color: divider);

    return Material(
      color: dark ? const Color(0xFF233138) : Colors.white,
      elevation: 10,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              item(
                key: const Key('chat-action-reply'),
                label: 'الرد',
                icon: Icons.reply_rounded,
                action: ChatMessageAction.reply,
              ),
              if (canCopy) ...[
                hairline(),
                item(
                  key: const Key('chat-action-copy'),
                  label: 'نسخ النص',
                  icon: Icons.copy_all_outlined,
                  action: ChatMessageAction.copy,
                ),
              ],
              hairline(),
              item(
                key: const Key('chat-action-forward'),
                label: 'إعادة توجيه',
                icon: Icons.shortcut_rounded,
                action: ChatMessageAction.forward,
              ),
              hairline(),
              item(
                key: const Key('chat-action-pin'),
                label: pinned ? 'إلغاء التثبيت' : 'تثبيت',
                icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
                action: ChatMessageAction.pin,
              ),
              hairline(),
              item(
                key: const Key('chat-action-star'),
                label: isStarred ? 'إزالة النجمة' : 'تمييز بنجمة',
                icon: isStarred ? Icons.star : Icons.star_border,
                action: ChatMessageAction.star,
              ),
              if (canEdit) ...[
                hairline(),
                item(
                  key: const Key('chat-action-edit'),
                  label: 'تعديل',
                  icon: Icons.edit_outlined,
                  action: ChatMessageAction.edit,
                ),
              ],
              hairline(),
              item(
                key: const Key('chat-action-info'),
                label: 'معلومات',
                icon: Icons.info_outline,
                action: ChatMessageAction.info,
              ),
              hairline(),
              item(
                key: const Key('chat-action-delete'),
                label: 'حذف',
                icon: Icons.delete_outline,
                action: ChatMessageAction.delete,
                danger: const Color(0xFFEA0038),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _pickMoreEmoji(BuildContext context) {
  const extras = <String>[
    '🔥', '👏', '🎉', '💯', '😍', '🤔', '🙌', '✨', '😎', '🤝', '😡', '👀',
  ];
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: const Color(0xFF111B21),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: GridView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: extras.length,
          itemBuilder: (context, index) {
            final emoji = extras[index];
            return InkWell(
              onTap: () => Navigator.pop(context, emoji),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            );
          },
        ),
      );
    },
  );
}

/// Local starred-message store (device-side favorites).
final class ChatStarStore {
  ChatStarStore({SharedPreferences? preferences}) : _preferences = preferences;

  SharedPreferences? _preferences;
  static const _key = 'pubget.chat.starred_messages';
  final Set<String> _cache = <String>{};
  var _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _preferences ??= await SharedPreferences.getInstance();
    _cache
      ..clear()
      ..addAll(_preferences!.getStringList(_key) ?? const <String>[]);
    _loaded = true;
  }

  bool isStarred(String messageId) => _cache.contains(messageId);

  Future<void> toggle(String messageId) async {
    await ensureLoaded();
    if (!_cache.add(messageId)) {
      _cache.remove(messageId);
    }
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setStringList(_key, _cache.toList(growable: false));
  }

  @visibleForTesting
  void seed(Iterable<String> ids) {
    _cache
      ..clear()
      ..addAll(ids);
    _loaded = true;
  }
}
