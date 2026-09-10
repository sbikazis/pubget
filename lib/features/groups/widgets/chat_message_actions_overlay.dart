import 'dart:async';

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
  const ChatMessageActionResult.action(this.action) : reaction = null;

  const ChatMessageActionResult.reaction(this.reaction)
      : action = ChatMessageAction.react;

  final ChatMessageAction action;
  final String? reaction;
}

/// WhatsApp quick reactions (order matches the product bar).
const kChatQuickReactions = <String>[
  '👍',
  '❤️',
  '😂',
  '😮',
  '😥',
  '🙏',
  '✌️',
];

const _kReactionBarColor = Color(0xFF232D36);
const _kDimScrim = Color(0x99000000); // black ~60%

/// Shows the WhatsApp-style long-press reaction overlay via [OverlayEntry].
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
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<ChatMessageActionResult?>();
  late OverlayEntry entry;

  void finish(ChatMessageActionResult? result) {
    if (entry.mounted) entry.remove();
    if (!completer.isCompleted) completer.complete(result);
  }

  entry = OverlayEntry(
    builder: (overlayContext) {
      return ReactionOverlay(
        message: message,
        isMine: isMine,
        contrast: contrast,
        bubbleRect: bubbleRect,
        canEdit: canEdit,
        canCopy: canCopy,
        isStarred: isStarred,
        onResult: finish,
      );
    },
  );
  overlay.insert(entry);
  return completer.future;
}

/// Complete WhatsApp-style reaction overlay.
///
/// Stack order (bottom → top / lowest → highest z-index):
/// 1. Dim scrim (tap to dismiss)
/// 2. Elevated message bubble copy
/// 3. Selection AppBar
/// 4. Overflow / secondary menu (optional)
/// 5. Emoji reaction bar (**always last** — never covered)
class ReactionOverlay extends StatefulWidget {
  const ReactionOverlay({
    required this.message,
    required this.isMine,
    required this.contrast,
    required this.bubbleRect,
    required this.canEdit,
    required this.canCopy,
    required this.isStarred,
    required this.onResult,
    super.key,
  });

  final ChatMessage message;
  final bool isMine;
  final ChatContrastTheme contrast;
  final Rect bubbleRect;
  final bool canEdit;
  final bool canCopy;
  final bool isStarred;
  final ValueChanged<ChatMessageActionResult?> onResult;

  @override
  State<ReactionOverlay> createState() => _ReactionOverlayState();
}

class _ReactionOverlayState extends State<ReactionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  var _showOverflow = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.88, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete(ChatMessageActionResult? result) async {
    try {
      await _controller.reverse();
    } catch (_) {}
    widget.onResult(result);
  }

  void _select(ChatMessageAction action) {
    unawaited(
      _complete(ChatMessageActionResult.action(action)),
    );
  }

  void _react(String emoji) {
    unawaited(
      _complete(ChatMessageActionResult.reaction(emoji)),
    );
  }

  Future<void> _pickMoreEmoji() async {
    final extra = await _showMoreEmojiSheet(context);
    if (extra == null || !mounted) return;
    _react(extra);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final bubble = _clampBubbleRect(widget.bubbleRect, size, padding);

    const barHeight = 52.0;
    const preferredGap = 60.0; // message.dy - 60
    final spaceAbove = bubble.top - padding.top - kToolbarHeight - 8;
    final showAbove = spaceAbove >= barHeight + 8;
    final barTop = showAbove
        ? (bubble.top - preferredGap).clamp(
            padding.top + kToolbarHeight + 4,
            bubble.top - barHeight - 8,
          )
        : bubble.bottom + 10;

    // Keep bar horizontally near the bubble, clamped to screen.
    const barApproxWidth = 320.0;
    final barLeft = (bubble.center.dx - barApproxWidth / 2).clamp(
      10.0,
      size.width - barApproxWidth - 10,
    );

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // 1) Dim background — dismiss on tap.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(
                    _complete(
                      const ChatMessageActionResult.action(
                        ChatMessageAction.dismiss,
                      ),
                    ),
                  ),
                  child: FadeTransition(
                    opacity: _fade,
                    child: const ColoredBox(color: _kDimScrim),
                  ),
                ),
              ),

              // 2) Elevated copy of the pressed message.
              Positioned(
                left: bubble.left.clamp(8.0, size.width - 48),
                top: bubble.top.clamp(padding.top + 4, size.height - 80),
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    alignment: widget.isMine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: IgnorePointer(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: size.width * 0.78,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x40000000),
                                blurRadius: 28,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ChatMessageBubble(
                            message: widget.message,
                            isMine: widget.isMine,
                            contrast: widget.contrast,
                            showAvatar: false,
                            showHeader: true,
                            showTail: true,
                            onLongPress: (_) {},
                            onMediaTap: null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3) WhatsApp-style selection AppBar (does not cover the emoji bar).
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fade,
                  child: _SelectionAppBar(
                    isStarred: widget.isStarred,
                    canCopy: widget.canCopy,
                    canEdit: widget.canEdit,
                    pinned: widget.message.pinnedAt != null,
                    showOverflow: _showOverflow,
                    onToggleOverflow: () =>
                        setState(() => _showOverflow = !_showOverflow),
                    onClose: () => unawaited(
                      _complete(
                        const ChatMessageActionResult.action(
                          ChatMessageAction.dismiss,
                        ),
                      ),
                    ),
                    onSelect: _select,
                  ),
                ),
              ),

              // 4) Overflow panel anchored under the AppBar (never over the emoji bar).
              if (_showOverflow)
                Positioned(
                  top: padding.top + kToolbarHeight + 4,
                  right: 8,
                  child: FadeTransition(
                    opacity: _fade,
                    child: _OverflowActionsMenu(
                      canCopy: widget.canCopy,
                      canEdit: widget.canEdit,
                      isStarred: widget.isStarred,
                      pinned: widget.message.pinnedAt != null,
                      onSelect: (action) {
                        setState(() => _showOverflow = false);
                        _select(action);
                      },
                    ),
                  ),
                ),

              // 5) Emoji reaction bar — LAST child = highest z-index.
              Positioned(
                key: const Key('chat-reaction-bar'),
                left: barLeft,
                top: barTop,
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: _ReactionPill(
                      onPick: _react,
                      onMore: _pickMoreEmoji,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Rect _clampBubbleRect(Rect rect, Size size, EdgeInsets padding) {
    if (rect == Rect.zero || !rect.isFinite || rect.width <= 0) {
      return Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 220,
        height: 80,
      );
    }
    final top = rect.top.clamp(padding.top + 8, size.height - 100);
    final left = rect.left.clamp(8.0, size.width - 40);
    return Rect.fromLTWH(left, top, rect.width, rect.height);
  }
}

class _SelectionAppBar extends StatelessWidget {
  const _SelectionAppBar({
    required this.isStarred,
    required this.canCopy,
    required this.canEdit,
    required this.pinned,
    required this.showOverflow,
    required this.onToggleOverflow,
    required this.onClose,
    required this.onSelect,
  });

  final bool isStarred;
  final bool canCopy;
  final bool canEdit;
  final bool pinned;
  final bool showOverflow;
  final VoidCallback onToggleOverflow;
  final VoidCallback onClose;
  final ValueChanged<ChatMessageAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Material(
      color: const Color(0xFF1F2C34),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.only(top: padding.top),
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            children: <Widget>[
              IconButton(
                key: const Key('chat-action-close'),
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                key: const Key('chat-action-reply'),
                tooltip: 'Reply',
                onPressed: () => onSelect(ChatMessageAction.reply),
                icon: const Icon(Icons.reply_rounded, color: Colors.white),
              ),
              IconButton(
                key: const Key('chat-action-star'),
                tooltip: 'Star',
                onPressed: () => onSelect(ChatMessageAction.star),
                icon: Icon(
                  isStarred ? Icons.star : Icons.star_border,
                  color: Colors.white,
                ),
              ),
              IconButton(
                key: const Key('chat-action-delete'),
                tooltip: 'Delete',
                onPressed: () => onSelect(ChatMessageAction.delete),
                icon: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              IconButton(
                key: const Key('chat-action-forward'),
                tooltip: 'Forward',
                onPressed: () => onSelect(ChatMessageAction.forward),
                icon: const Icon(Icons.shortcut_rounded, color: Colors.white),
              ),
              IconButton(
                key: const Key('chat-action-more'),
                tooltip: 'More',
                onPressed: onToggleOverflow,
                icon: Icon(
                  showOverflow ? Icons.close : Icons.more_vert,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverflowActionsMenu extends StatelessWidget {
  const _OverflowActionsMenu({
    required this.canCopy,
    required this.canEdit,
    required this.isStarred,
    required this.pinned,
    required this.onSelect,
  });

  final bool canCopy;
  final bool canEdit;
  final bool isStarred;
  final bool pinned;
  final ValueChanged<ChatMessageAction> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (canCopy)
        _overflowItem(
          key: const Key('chat-action-copy'),
          label: 'نسخ',
          icon: Icons.copy_all_outlined,
          action: ChatMessageAction.copy,
        ),
      _overflowItem(
        key: const Key('chat-action-pin'),
        label: pinned ? 'إلغاء التثبيت' : 'تثبيت',
        icon: pinned ? Icons.push_pin : Icons.push_pin_outlined,
        action: ChatMessageAction.pin,
      ),
      if (canEdit)
        _overflowItem(
          key: const Key('chat-action-edit'),
          label: 'تعديل',
          icon: Icons.edit_outlined,
          action: ChatMessageAction.edit,
        ),
      _overflowItem(
        key: const Key('chat-action-info'),
        label: 'معلومات',
        icon: Icons.info_outline,
        action: ChatMessageAction.info,
      ),
    ];

    return Material(
      color: const Color(0xFF233138),
      elevation: 12,
      shadowColor: const Color(0x66000000),
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: items),
        ),
      ),
    );
  }

  Widget _overflowItem({
    required Key key,
    required String label,
    required IconData icon,
    required ChatMessageAction action,
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFE9EDEF),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, size: 20, color: const Color(0xFF8696A0)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.onPick,
    required this.onMore,
  });

  final ValueChanged<String> onPick;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kReactionBarColor,
      elevation: 10,
      shadowColor: const Color(0x66000000),
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final emoji in kChatQuickReactions)
                SizedBox(
                  width: 38,
                  height: 38,
                  child: IconButton(
                    key: Key('chat-react-$emoji'),
                    padding: EdgeInsets.zero,
                    onPressed: () => onPick(emoji),
                    icon: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              const SizedBox(width: 2),
              Material(
                color: const Color(0xFF1F2C34),
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('chat-react-more'),
                  customBorder: const CircleBorder(),
                  onTap: onMore,
                  child: const SizedBox(
                    width: 34,
                    height: 34,
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

Future<String?> _showMoreEmojiSheet(BuildContext context) {
  const extras = <String>[
    '🔥',
    '👏',
    '🎉',
    '💯',
    '😍',
    '🤔',
    '🙌',
    '✨',
    '😎',
    '🤝',
    '😡',
    '👀',
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
