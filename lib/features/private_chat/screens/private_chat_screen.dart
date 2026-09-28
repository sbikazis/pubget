import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/models/chat_models.dart';
import '../../groups/screens/media_viewer_page.dart';
import '../../groups/widgets/chat_action_sheets.dart';
import '../../groups/widgets/chat_contrast_theme.dart';
import '../../groups/widgets/chat_message_bubble.dart';
import '../../groups/widgets/chat_message_actions_overlay.dart';
import '../../groups/widgets/chat_special_cards.dart';
import '../providers/private_chat_list_provider.dart';
import '../providers/private_chat_provider.dart';

class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({required this.chatId, this.otherUserId, super.key});

  final String chatId;
  final String? otherUserId;

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  /// Device-local favourites, shared with the group chat so a saved message is
  /// saved everywhere it appears.
  final ChatStarStore _stars = ChatStarStore();

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  final GlobalKey<_MessageListState> _messageListKey = GlobalKey<_MessageListState>();
  bool _initialized = false;
  bool _wasNearBottom = true;
  int _lastSeenMessageCount = 0;
  int _lastMarkedReadCount = -1;
  String? _lastNewestMessageId;
  int _newMessagesCount = 0;

  /// Captured while the tree is still active: reading a provider from
  /// `dispose()` looks up an ancestor on a deactivated element, which throws.
  PrivateChatProvider? _chatProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProvider = context.read<PrivateChatProvider>();
    if (_initialized) return;
    _initialized = true;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    unawaited(
      context.read<PrivateChatProvider>().open(
        chatId: widget.chatId,
        currentUserId: user.id,
      ),
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    unawaited(_chatProvider?.leaveChat());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<PrivateChatProvider>();
    final list = context.watch<PrivateChatListProvider>();
    final uid = context.watch<AuthProvider>().currentUser?.id ?? '';
    final summary = list.chats.where((item) => item.id == widget.chatId);
    final copy = AppStrings.of(context);
    final title = summary.isNotEmpty
        ? summary.first.otherDisplayName(uid)
        : (widget.otherUserId?.trim().isNotEmpty == true
              ? widget.otherUserId!
              : copy.pick('Private chat', 'محادثة خاصة'));
    final avatarUrl = summary.isNotEmpty
        ? summary.first.otherAvatarUrl(uid)
        : null;
    final contrast = ChatContrastTheme.fromBackground(null);
    _syncScrollAndReadReceipts(chat);
    return Scaffold(
      appBar: AppBar(
        leading:
            AppBackButton.maybeOf(context) ??
            AppBackButton(
              onPressed: () => AppNavigation.go(context, '/private'),
            ),
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            PubgetAvatar(
              imageUrl: avatarUrl,
              name: title,
              size: PubgetAvatarSize.small,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: copy.pick('Hide conversation', 'إخفاء المحادثة'),
            onPressed: () async {
              final result = await context
                  .read<PrivateChatProvider>()
                  .hideChat();
              if (!context.mounted) return;
              if (result.isSuccess) {
                await AppNavigation.go(context, '/private');
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: contrast.background,
        child: ColoredBox(
          color: contrast.scrim,
          child: SafeArea(
            top: false,
            child: Column(
              children: <Widget>[
                if (chat.state == LoadingState.offline ||
                    chat.failure != null && chat.messages.isNotEmpty)
                  _OfflineBanner(message: chat.failure?.message),
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      _MessageList(
                        chat: chat,
                        contrast: contrast,
                        currentUserId: uid,
                        controller: _scrollController,
                        onAction: _showActions,
                        onSwipeReply: (message) {
                          context
                              .read<PrivateChatProvider>()
                              .setReplyTarget(message);
                        },
                        onMediaTap: _openMedia,
                        messageKeys: _messageKeys,
                        stars: _stars,
                        listKey: _messageListKey,
                      ),
                      if (_newMessagesCount > 0)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: AppSpacing.sm,
                          child: Center(
                            child: Material(
                              elevation: 4,
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(22),
                              child: InkWell(
                                key: const Key('private-new-messages-chip'),
                                borderRadius: BorderRadius.circular(22),
                                onTap: _jumpToLatest,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.keyboard_double_arrow_down,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        AppStrings.of(context).pick(
                                          '$_newMessagesCount new messages',
                                          '$_newMessagesCount رسائل جديدة',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (chat.uploadProgress.isNotEmpty)
                  LinearProgressIndicator(
                    value: chat.uploadProgress.values.first,
                  ),
                if (chat.pinnedMessage case final ChatMessage pinned?)
                  ChatPinnedBanner(
                    senderName: pinned.senderName,
                    preview: pinnedPreviewText(pinned, copy),
                    onTap: () =>
                        _messageListKey.currentState?.revealMessage(pinned.id),
                    onUnpin: () => chat.pinMessage(pinned.id, false),
                  ),
                if (chat.replyTarget != null)
                  _ReplyComposerBar(
                    message: chat.replyTarget!,
                    onClear: chat.clearReplyTarget,
                  ),
                _Composer(
                  controller: _controller,
                  onSend: _sendText,
                  onMedia: _pickMedia,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _wasNearBottom =
        _scrollController.position.maxScrollExtent -
            _scrollController.position.pixels <
        180;
    if (_wasNearBottom && _newMessagesCount > 0 && mounted) {
      setState(() => _newMessagesCount = 0);
    }
    if (_scrollController.position.pixels < 180) {
      unawaited(context.read<PrivateChatProvider>().loadMore());
    }
    _queueReadReceiptCheck(context.read<PrivateChatProvider>());
  }

  void _syncScrollAndReadReceipts(PrivateChatProvider chat) {
    final count = chat.messages.length;
    final newestId = chat.messages.isEmpty ? null : chat.messages.last.id;
    final receivedNewerMessage =
        _lastNewestMessageId != null &&
        newestId != null &&
        newestId != _lastNewestMessageId;
    final shouldScroll =
        _wasNearBottom && count > 0 && count != _lastSeenMessageCount;
    _lastSeenMessageCount = count;
    _lastNewestMessageId = newestId;
    if (receivedNewerMessage && !_wasNearBottom && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _wasNearBottom) return;
        setState(() => _newMessagesCount++);
      });
    }
    if (!shouldScroll && count == _lastMarkedReadCount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (shouldScroll && _wasNearBottom) {
        _scrollToLatest();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_wasNearBottom) _scrollToLatest();
        });
      }
      _queueReadReceiptCheck(chat);
    });
  }

  bool _readCheckQueued = false;
  String? _lastVisibleReadSignature;

  void _queueReadReceiptCheck(PrivateChatProvider chat) {
    if (_readCheckQueued) return;
    _readCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readCheckQueued = false;
      if (!mounted) return;
      final visible = _visibleMessages(chat);
      if (visible.isEmpty) return;
      final signature = visible.map((message) => message.id).join('|');
      if (signature == _lastVisibleReadSignature) return;
      _lastVisibleReadSignature = signature;
      _lastMarkedReadCount = chat.messages.length;
      unawaited(chat.markAsRead(visible));
    });
  }

  List<ChatMessage> _visibleMessages(PrivateChatProvider chat) {
    if (!_scrollController.hasClients) return const <ChatMessage>[];
    final viewportObject = _scrollController.position.context.storageContext
        .findRenderObject();
    if (viewportObject is! RenderBox) return const <ChatMessage>[];
    final viewportTop = viewportObject.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewportObject.size.height;
    return chat.messages.where((message) {
      final context = _messageKeys[message.id]?.currentContext;
      final renderObject = context?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return false;
      final top = renderObject.localToGlobal(Offset.zero).dy;
      final bottom = top + renderObject.size.height;
      return bottom >= viewportTop && top <= viewportBottom;
    }).toList(growable: false);
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if ((target - current).abs() < 1) return;
    _scrollController.jumpTo(target);
  }

  void _jumpToLatest() {
    if (!mounted) return;
    setState(() {
      _newMessagesCount = 0;
      _wasNearBottom = true;
    });
    _scrollToLatest();
  }

  Future<void> _sendText() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    _wasNearBottom = true;
    unawaited(
      context.read<PrivateChatProvider>().sendText(
        chatId: widget.chatId,
        senderId: user.id,
        senderName: user.displayName?.trim().isNotEmpty == true
            ? user.displayName!
            : user.email,
        senderAvatar: user.avatarUrl ?? '',
        text: text,
      ),
    );
  }

  Future<void> _pickMedia(ImageSource source, bool video) async {
    final picker = ImagePicker();
    final selected = video
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source);
    if (selected == null || !mounted) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final bytes = await selected.readAsBytes();
    // The picker can take seconds; never attach media to a chat screen that
    // has been covered (media viewer), popped, or otherwise stopped being
    // the current route while we were away.
    if (!mounted || !ModalRoute.of(context)!.isCurrent) return;
    final extension = selected.name.split('.').last.toLowerCase();
    final contentType = video
        ? (extension == 'webm' ? 'video/webm' : 'video/mp4')
        : (extension == 'png' ? 'image/png' : 'image/jpeg');
    if (!mounted) return;
    await context.read<PrivateChatProvider>().sendMedia(
      chatId: widget.chatId,
      senderId: user.id,
      senderName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!
          : user.email,
      senderAvatar: user.avatarUrl ?? '',
      bytes: bytes,
      fileName: selected.name,
      contentType: contentType,
    );
  }

  void _openMedia(ChatMessage message) {
    final media = context
        .read<PrivateChatProvider>()
        .messages
        .where((item) => item.isMedia && !item.isDeleted)
        .toList(growable: false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewerPage(
          messages: media,
          initialIndex: media.indexWhere((item) => item.id == message.id),
        ),
      ),
    );
  }

  Future<void> _showActions(ChatMessage message, Rect bubbleRect) async {
    final user = context.read<AuthProvider>().currentUser;
    final isMine = user != null && message.senderId == user.id;
    final copy = AppStrings.of(context);
    final result = await showChatMessageActions(
      context,
      message: message,
      isMine: isMine,
      contrast: ChatContrastTheme.fromBackground(null),
      bubbleRect: bubbleRect,
      // Editing is limited to your own sent text inside the 15-minute window,
      // which the server enforces; the UI avoids offering the impossible cases.
      canEdit:
          isMine &&
          !message.isDeleted &&
          message.type == ChatMessageType.text &&
          !message.isOptimistic &&
          (message.text ?? '').trim().isNotEmpty &&
          message.createdAt != null &&
          DateTime.now().difference(message.createdAt!) <=
              const Duration(minutes: 15),
      canCopy:
          message.text?.trim().isNotEmpty == true &&
          !message.isDeleted &&
          !message.isMedia,
      canReply: !message.isDeleted,
      canForward: !message.isDeleted,
      canDelete: isMine && !message.isDeleted,
      // A 1:1 has no moderator, so only the sender may pin.
      canPin: isMine && !message.isDeleted,
      canReport: !isMine && !message.isDeleted,
      canReact: message.sendState == ChatSendState.sent,
      isStarred: _stars.isStarred(message.id),
    );
    if (!mounted || result == null) return;
    final chat = context.read<PrivateChatProvider>();
    switch (result.action) {
      case ChatMessageAction.reply:
        chat.setReplyTarget(message);
        return;
      case ChatMessageAction.copy:
        await Clipboard.setData(ClipboardData(text: message.text ?? ''));
        return;
      case ChatMessageAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(copy.pick('Delete message?', 'حذف الرسالة؟')),
            content: Text(
              copy.pick(
                'This message will be removed from the conversation.',
                'ستتم إزالة هذه الرسالة من المحادثة.',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(copy.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(copy.delete),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        final deleteResult = await chat.deleteMessage(message.id);
        if (!mounted || deleteResult.isSuccess) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deleteResult.failureOrNull?.message ??
                  copy.pick('Unable to delete message', 'تعذر حذف الرسالة'),
            ),
          ),
        );
        return;
      case ChatMessageAction.forward:
        final user2 = context.read<AuthProvider>().currentUser;
        if (user2 == null) return;
        await runForwardFlow(
          context,
          currentUserId: user2.id,
          currentChatId: widget.chatId,
          onForward: (target) async {
            final forwarded = await chat.forwardMessage(
              message.id,
              destinationGroupId: target.groupId,
              destinationChatId: target.chatId,
            );
            return forwarded.isSuccess;
          },
        );
        return;
      case ChatMessageAction.pin:
        final pinResult = await chat.pinMessage(
          message.id,
          message.pinnedAt == null,
        );
        if (!mounted || pinResult.isSuccess) return;
        _showActionError(
          pinResult.failureOrNull?.message ??
              copy.pick('Unable to update pin', 'تعذر تحديث التثبيت'),
        );
        return;
      case ChatMessageAction.star:
        await _stars.toggle(message.id);
        if (mounted) setState(() {});
        return;
      case ChatMessageAction.edit:
        await _editMessage(message);
        return;
      case ChatMessageAction.info:
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            final infoCopy = AppStrings.of(dialogContext);
            return AlertDialog(
              title: Text(infoCopy.messageDetails),
              content: ListTile(
                dense: true,
                title: Text(
                  message.text?.trim().isNotEmpty == true
                      ? message.text!.trim()
                      : chatMessageSummary(message, infoCopy),
                ),
                subtitle: Text(
                  '${message.senderName} · '
                  '${_formatTimestamp(message.createdAt, infoCopy)}',
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(infoCopy.cancel),
                ),
              ],
            );
          },
        );
        return;
      case ChatMessageAction.react:
        final reactionResult = await chat.addReaction(
          message.id,
          result.reaction ?? '❤️',
        );
        if (!mounted || reactionResult.isSuccess) return;
        _showActionError(
          reactionResult.failureOrNull?.message ??
              copy.pick('Unable to react', 'تعذر إضافة التفاعل'),
        );
        return;
      case ChatMessageAction.report:
        final reported = await runReportFlow(
          context,
          onSubmit: (reason) async {
            final reportResult = await chat.reportMessage(
              message.id,
              reason: reason,
            );
            return reportResult.isSuccess;
          },
        );
        if (!mounted || !reported) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(copy.pick('Report sent', 'تم إرسال البلاغ'))),
        );
        return;
      case ChatMessageAction.dismiss:
        return;
    }
  }

  Future<void> _editMessage(ChatMessage message) async {
    final copy = AppStrings.of(context);
    final text = await showEditMessageDialog(
      context,
      message: message,
      onSave: (value) async {
        final result = await context.read<PrivateChatProvider>().editMessage(
          message.id,
          value,
        );
        return result.isSuccess;
      },
    );
    if (text == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(copy.messageEditSuccess)));
  }

  void _showActionError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatTimestamp(DateTime? value, AppStrings copy) {
    if (value == null) return copy.pick('Sending…', 'جارٍ الإرسال…');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} $hour:$minute';
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList({
    required this.chat,
    required this.contrast,
    required this.currentUserId,
    required this.controller,
    required this.onAction,
    required this.onSwipeReply,
    required this.onMediaTap,
    required this.messageKeys,
    required this.stars,
    required this.listKey,
  });

  final PrivateChatProvider chat;
  final ChatContrastTheme contrast;
  final String currentUserId;
  final ScrollController controller;
  final void Function(ChatMessage message, Rect rect) onAction;
  final ValueChanged<ChatMessage> onSwipeReply;
  final ValueChanged<ChatMessage> onMediaTap;
  final Map<String, GlobalKey> messageKeys;
  final ChatStarStore stars;
  final GlobalKey<_MessageListState> listKey;

  @override
  State<_MessageList> createState() => _MessageListState();
}

/// Message list for a 1:1 conversation.
///
/// Mirrors the group list: rows (with day dividers) are cached against the
/// message list identity, keys are pruned, and a reveal API lets a reply quote
/// or the pinned banner scroll to and flash the original message.
class _MessageListState extends State<_MessageList> {
  List<_PrivateRow>? _cachedRows;
  DateTime? _cachedDay;
  // See the group list: `chat.messages` returns a new unmodifiable wrapper on
  // every call, so the cache is keyed on revision plus list bounds.
  int _cachedRevision = -1;
  int _cachedCount = -1;
  String? _cachedFirstId;
  String? _cachedLastId;
  Map<String, int> _rowIndexById = const <String, int>{};

  String? _highlightedId;
  _RevealRequest? _reveal;
  Timer? _seekTimer;
  Timer? _highlightTimer;

  static const Duration _highlightDuration = Duration(milliseconds: 1400);
  static const int _maxSeekAttempts = 5;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _seekTimer?.cancel();
    super.dispose();
  }

  List<_PrivateRow> _rowsFor() {
    final messages = widget.chat.messages;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final count = messages.length;
    final firstId = count == 0 ? null : messages.first.id;
    final lastId = count == 0 ? null : messages.last.id;
    if (_cachedRows != null &&
        _cachedRevision == widget.chat.contentRevision &&
        _cachedCount == count &&
        _cachedFirstId == firstId &&
        _cachedLastId == lastId &&
        _cachedDay == today) {
      return _cachedRows!;
    }
    final rows = <_PrivateRow>[];
    final indexById = <String, int>{};
    if (widget.chat.hasMore) rows.add(const _PrivateRow.loadMore());
    DateTime? lastDay;
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final createdAt = message.createdAt;
      final day = createdAt == null
          ? null
          : DateTime(createdAt.year, createdAt.month, createdAt.day);
      if (day != null && (lastDay == null || day != lastDay)) {
        rows.add(_PrivateRow.date(chatDayLabel(createdAt, now: now)));
        lastDay = day;
      }
      indexById[message.id] = rows.length;
      rows.add(_PrivateRow.message(message));
    }
    if (widget.messageKeys.length > rows.length) {
      final live = indexById.keys.toSet();
      widget.messageKeys.removeWhere((id, _) => !live.contains(id));
    }
    _cachedRows = rows;
    _cachedDay = today;
    _cachedRevision = widget.chat.contentRevision;
    _cachedCount = count;
    _cachedFirstId = firstId;
    _cachedLastId = lastId;
    _rowIndexById = indexById;
    return rows;
  }

  /// Scrolls [messageId] into view and flashes it. Flutter only reveals
  /// elements that exist, so this alternates a proportional seek with
  /// [Scrollable.ensureVisible] for the exact landing.
  void revealMessage(String messageId) {
    _rowsFor();
    final index = _rowIndexById[messageId];
    if (index == null) {
      // Target predates the loaded window: pull the next page in, then retry.
      if (widget.chat.hasMore) {
        _seekTimer?.cancel();
        _seekTimer = Timer(const Duration(milliseconds: 450), () {
          if (!mounted) return;
          unawaited(widget.chat.loadMore());
          _seekTimer = Timer(const Duration(milliseconds: 500), () {
            if (!mounted) return;
            revealMessage(messageId);
          });
        });
      }
      return;
    }
    _seekTimer?.cancel();
    _reveal = _RevealRequest(id: messageId, index: index, attempt: 0);
    _highlightedId = messageId;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(_highlightDuration, () {
      if (!mounted || _highlightedId == null) return;
      setState(() => _highlightedId = null);
    });
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _stepReveal());
  }

  void _stepReveal() {
    final request = _reveal;
    if (request == null || !mounted) return;
    if (!widget.controller.hasClients) return;

    final target = widget.messageKeys[request.id]?.currentContext;
    if (target != null && target.mounted) {
      _reveal = null;
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: 0.16,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }
    if (request.attempt >= _maxSeekAttempts) {
      _reveal = null;
      return;
    }
    final position = widget.controller.position;
    final total = _rowIndexById.length;
    if (position.maxScrollExtent <= 0 || total <= 1) {
      _reveal = null;
      return;
    }
    final estimate = (position.maxScrollExtent * ((request.index + 0.5) / total))
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    widget.controller.jumpTo(estimate);
    _reveal = _RevealRequest(
      id: request.id,
      index: request.index,
      attempt: request.attempt + 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _stepReveal());
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    if (chat.messages.isEmpty) {
      if (chat.state == LoadingState.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (chat.state == LoadingState.offline) {
        return PubgetOfflineState(
          message: chat.failure?.message ??
              AppStrings.of(context).cachedMessagesUnavailable,
        );
      }
      if (chat.state == LoadingState.error) {
        return PubgetErrorState(
          message: chat.failure?.message ??
              AppStrings.of(context).messagesCouldNotLoad,
        );
      }
      final copy = AppStrings.of(context);
      return PubgetEmptyState(
        title: copy.startConversation,
        message: copy.pick(
          'Messages in this private chat will appear here.',
          'ستظهر رسائل هذه المحادثة الخاصة هنا.',
        ),
        icon: Icons.forum_outlined,
      );
    }
    final rows = _rowsFor();
    final highlightId = _highlightedId;
    return ListView.builder(
      controller: widget.controller,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.dateLabel != null) {
          return ChatDateDivider(label: row.dateLabel!);
        }
        if (row.isLoadMore) {
          final loading = chat.state == LoadingState.loadingMore;
          return TextButton.icon(
            onPressed: loading ? null : chat.loadMore,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.history),
            label: Text(AppStrings.of(context).loadOlderMessages),
          );
        }
        final message = row.message!;
        if (message.sendState == ChatSendState.failed) {
          return _FailedMessage(message: message);
        }
        final bubble = ChatMessageBubble(
          key: widget.messageKeys.putIfAbsent(message.id, GlobalKey.new),
          message: message,
          isMine: message.senderId == widget.currentUserId,
          contrast: widget.contrast,
          showSenderRole: false,
          isStarred: widget.stars.isStarred(message.id),
          onLongPress: (rect) => widget.onAction(message, rect),
          onSwipeReply: () => widget.onSwipeReply(message),
          onReplyQuoteTap: (id) => revealMessage(id),
          onMediaTap: message.isMedia ? () => widget.onMediaTap(message) : null,
        );
        if (message.id != highlightId) return bubble;
        return ChatJumpHighlight(child: bubble);
      },
    );
  }
}

final class _RevealRequest {
  const _RevealRequest({required this.id, required this.index, this.attempt = 0});

  final String id;
  final int index;
  final int attempt;
}

final class _PrivateRow {
  const _PrivateRow.loadMore()
    : dateLabel = null,
      message = null,
      isLoadMore = true;
  const _PrivateRow.date(String label)
    : dateLabel = label,
      message = null,
      isLoadMore = false;
  const _PrivateRow.message(ChatMessage value)
    : dateLabel = null,
      message = value,
      isLoadMore = false;

  final String? dateLabel;
  final ChatMessage? message;
  final bool isLoadMore;
}

class _FailedMessage extends StatelessWidget {
  const _FailedMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final chat = context.read<PrivateChatProvider>();
    final copy = AppStrings.of(context);
    return Card(
      key: ValueKey<String>('failed-${message.id}'),
      color: Theme.of(context).colorScheme.errorContainer,
      margin: const EdgeInsets.all(AppSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(message.text ?? copy.mediaMessage),
        subtitle: Text(copy.chatSendFailureLabel(message.failureMessage)),
        trailing: Wrap(
          children: <Widget>[
            IconButton(
              tooltip: copy.retry,
              onPressed: () => chat.retry(message),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: copy.deleteFailedMessage,
              onPressed: () => chat.removeFailed(message.id),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onMedia,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final void Function(ImageSource source, bool video) onMedia;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: <Widget>[
            PopupMenuButton<String>(
               tooltip: copy.pick('Attachments', 'المرفقات'),
              icon: const Icon(Icons.add_circle_outline),
              onSelected: (value) {
                if (value == 'image') onMedia(ImageSource.gallery, false);
                if (value == 'video') onMedia(ImageSource.gallery, true);
              },
               itemBuilder: (_) => <PopupMenuEntry<String>>[
                PopupMenuItem(
                  value: 'image',
                  child: Text(copy.pick('Image', 'صورة')),
                ),
                PopupMenuItem(
                  value: 'video',
                  child: Text(copy.pick('Video', 'فيديو')),
                ),
              ],
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                 decoration: InputDecoration(
                   hintText: copy.pick('Message privately', 'راسل بشكل خاص'),
                  isDense: true,
                ),
              ),
            ),
            IconButton(
               tooltip: copy.pick('Send message', 'إرسال الرسالة'),
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyComposerBar extends StatelessWidget {
  const _ReplyComposerBar({required this.message, required this.onClear});

  final ChatMessage message;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final preview = message.replyPreview ??
        message.text ??
        (message.isMedia ? 'Media message' : 'Message');
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.reply_rounded),
         title: Text(copy.pick('Replying to message', 'الرد على الرسالة')),
        subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
           tooltip: copy.pick('Cancel reply', 'إلغاء الرد'),
          onPressed: onClear,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
         child: Text(
           message ??
               copy.pick(
                 'You are offline. Failed sends can be retried.',
                 'أنت غير متصل. يمكنك إعادة إرسال الرسائل الفاشلة.',
               ),
         ),
      ),
    );
  }
}
