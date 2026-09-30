import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../events/widgets/event_widgets.dart';
import '../../games/widgets/game_widgets.dart';
import '../data/sticker_store.dart';
import '../data/user_sticker_store.dart';
import '../models/chat_models.dart';
import '../models/group_models.dart';
import '../providers/chat_provider.dart';
import '../providers/group_provider.dart';
import '../services/chat_audio_player.dart';
import '../services/default_voice_capture.dart';
import '../services/voice_capture.dart';
import '../widgets/chat_contrast_theme.dart';
import '../widgets/chat_action_sheets.dart';
import '../widgets/chat_message_actions_overlay.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_special_cards.dart';
import '../widgets/event_center_sheet.dart';
import '../widgets/sticker_detail_sheet.dart';
import '../widgets/wa_composer/whatsapp_chat_composer.dart';
import 'chat_background_picker_page.dart';
import 'media_viewer_page.dart';

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({
    required this.groupId,
    this.voiceCapture,
    this.audioPlayer,
    this.stickerStore,
    this.userStickerStore,
    super.key,
  });

  final String groupId;
  final VoiceCapture? voiceCapture;
  final ChatAudioPlayer? audioPlayer;
  final StickerStore? stickerStore;
  final UserStickerStore? userStickerStore;

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _stars = ChatStarStore();
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};

  /// Drives the list's reveal/highlight API (reply quote taps, pinned banner).
  final GlobalKey<_MessageListState> _messageListKey =
      GlobalKey<_MessageListState>();
  ChatProvider? _chatProvider;
  late final UserStickerStore _userStickers =
      widget.userStickerStore ?? UserStickerStore();
  bool _initialized = false;
  bool _reopenScheduled = false;
  bool _wasNearBottom = true;
  int _lastSeenMessageCount = 0;
  int _lastMarkedReadCount = -1;
  bool _loadingOlder = false;
  bool _readCheckQueued = false;
  String? _lastVisibleReadSignature;
  String? _lastNewestMessageId;
  int _newMessagesCount = 0;
  double? _olderPixels;
  double? _olderMaxExtent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProvider ??= context.read<ChatProvider>();
    if (_initialized) return;
    _initialized = true;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().currentUser;
      if (user == null) return;
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.group?.id != widget.groupId) {
        unawaited(groupProvider.load(groupId: widget.groupId, userId: user.id));
      }
      unawaited(
        context.read<ChatProvider>().open(
          groupId: widget.groupId,
          currentUserId: user.id,
        ),
      );
    });
  }

  @override
  void dispose() {
    unawaited(_chatProvider?.leaveGroup(groupId: widget.groupId));
    _scrollController.removeListener(_onScroll);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final group = groupProvider.group;
    final contrast = ChatContrastTheme.fromBackground(group?.chatBackgroundUrl);
    // Self-heal the shared (app-scoped) ChatProvider after a stacked chat page
    // replaced our session: if we became visible again but no longer own a
    // session for [widget.groupId], reopen it. Safe because open() early-returns
    // when the same group+user is already active.
    final chatProvider = context.read<ChatProvider>();
    if (chatProvider.groupId != widget.groupId && !_reopenScheduled) {
      _reopenScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reopenScheduled = false;
        if (!mounted) return;
        final user = context.read<AuthProvider>().currentUser;
        if (user == null) return;
        unawaited(
          context.read<ChatProvider>().open(
            groupId: widget.groupId,
            currentUserId: user.id,
          ),
        );
      });
    }
    return Scaffold(
      endDrawer: _GroupMenu(
        groupId: widget.groupId,
        group: group,
        isFounder: groupProvider.isFounder,
        canManageSettings: groupProvider.canManageSettings,
        canManageMembers: groupProvider.canManageMembers,
      ),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading:
            AppBackButton.maybeOf(context) ??
            AppBackButton(
              onPressed: () => AppNavigation.go(context, '/groups'),
            ),
        titleSpacing: 4,
        title: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () =>
              AppNavigation.go(context, '/group?groupId=${widget.groupId}'),
          child: Row(
            children: <Widget>[
              PubgetAvatar(
                imageUrl: group?.imageUrl,
                name: group?.name ?? AppStrings.of(context).groupChat,
                size: PubgetAvatarSize.small,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MarqueeTitle(
                  group?.name ?? AppStrings.of(context).groupChat,
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          Builder(
            builder: (context) => IconButton(
              key: const Key('group-chat-menu'),
              tooltip: AppStrings.of(context).groupMenu,
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: contrast.background,
        child: ColoredBox(
          color: contrast.scrim,
          child: SafeArea(
            top: false,
            child: Selector<ChatProvider, _ChatChromeSlice>(
              selector: (_, chat) {
                // Derived here, not in the enclosing build: the enclosing build
                // only runs on provider *changes*, so capturing a pin outside
                // the selector would leave the banner stale after a pin/unpin.
                final pinned = newestPinnedMessage(chat.messages);
                return _ChatChromeSlice(
                  revision: chat.contentRevision,
                  state: chat.state,
                  hasMore: chat.hasMore,
                  failureMessage: chat.failure?.message,
                  replyId: chat.replyTarget?.id,
                  pinnedId: pinned?.id,
                  pinnedSender: pinned?.senderName,
                  pinnedPreview: pinned == null
                      ? null
                      : pinnedPreviewText(pinned, AppStrings.of(context)),
                );
              },
              builder: (context, slice, _) {
                final chat = context.read<ChatProvider>();
                _syncScrollAndReadReceipts(chat);
                return Column(
                  children: <Widget>[
                    if (slice.state == LoadingState.offline ||
                        (slice.failureMessage != null &&
                            chat.messages.isNotEmpty))
                      _OfflineBanner(message: slice.failureMessage),
                    Expanded(
                      child: Stack(
                        children: <Widget>[
                          _MessageList(
                            key: _messageListKey,
                            chat: chat,
                            contrast: contrast,
                            currentUserId:
                                context.read<AuthProvider>().currentUser?.id ??
                                '',
                            controller: _scrollController,
                            stars: _stars,
                            onAction: _showActions,
                            onSwipeReply: (message) {
                              context.read<ChatProvider>().setReplyTarget(
                                message,
                              );
                            },
                            onAvatarTap: (message) {
                              final uid = message.senderId.trim();
                              if (uid.isEmpty || uid == 'system') return;
                              AppNavigation.go(context, '/profile?uid=$uid');
                            },
                            onMediaTap: _openMedia,
                            onStickerTap: (message) {
                              unawaited(
                                StickerDetailSheet.show(
                                  context,
                                  message: message,
                                  store: _userStickers,
                                ),
                              );
                            },
                            onAudioTap: _playAudio,
                            onEventTap: (eventId) =>
                                EventLinks.open(context, eventId),
                            onGameTap: _openGameCard,
                            onLoadMore: _loadMorePreservingAnchor,
                            messageKeys: _messageKeys,
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
                                    key: const Key('new-messages-chip'),
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
                    if (slice.pinnedId != null)
                      _PinnedMessageBar(
                        senderName: slice.pinnedSender ?? '',
                        preview: slice.pinnedPreview ?? '',
                        onTap: () =>
                            _messageListKey.currentState?.revealMessage(
                              slice.pinnedId!,
                            ),
                        onUnpin: () => unawaited(
                          context.read<ChatProvider>().pinMessage(
                            slice.pinnedId!,
                            false,
                          ),
                        ),
                      ),
                    if (chat.replyTarget != null)
                      _ReplyComposerBar(
                        message: chat.replyTarget!,
                        onClear: chat.clearReplyTarget,
                      ),
                    WhatsAppChatComposer(
                      controller: _controller,
                      focusNode: _focusNode,
                      groupId: widget.groupId,
                      stickerStore: widget.stickerStore,
                      userStickerStore: _userStickers,
                      currentUserId:
                          context.read<AuthProvider>().currentUser?.id ?? '',
                      currentUserName: () {
                        final user = context.read<AuthProvider>().currentUser;
                        final member = context.read<GroupProvider>().membership;
                        if (user == null) return 'Pubget user';
                        if (member == null) {
                          return (user.displayName ?? '').trim().isNotEmpty
                              ? user.displayName!.trim()
                              : 'Pubget user';
                        }
                        return _senderName(
                          user.displayName,
                          user.email,
                          member,
                        );
                      }(),
                      voiceCapture:
                          widget.voiceCapture ?? createDeviceVoiceCapture(),
                      hintText: AppStrings.of(
                        context,
                      ).pick('Message', 'مراسلة'),
                      onSendText: _sendText,
                      onSendMedia:
                          ({
                            required Uint8List bytes,
                            required String fileName,
                            required String contentType,
                          }) => _sendPickedBytes(
                            bytes: bytes,
                            fileName: fileName,
                            contentType: contentType,
                          ),
                      onSendCustomSticker:
                          ({
                            required Uint8List bytes,
                            required String fileName,
                            required String contentType,
                            required String stickerCreatorId,
                            required String stickerCreatorName,
                          }) async {
                            final user = context
                                .read<AuthProvider>()
                                .currentUser;
                            final member = context
                                .read<GroupProvider>()
                                .membership;
                            if (user == null || member == null) return;
                            _wasNearBottom = true;
                            await context
                                .read<ChatProvider>()
                                .sendCustomSticker(
                                  groupId: widget.groupId,
                                  senderId: user.id,
                                  senderName: _senderName(
                                    user.displayName,
                                    user.email,
                                    member,
                                  ),
                                  senderAvatar: user.avatarUrl ?? '',
                                  senderRole: member.role.name,
                                  bytes: bytes,
                                  fileName: fileName,
                                  contentType: contentType,
                                  stickerCreatorId: stickerCreatorId,
                                  stickerCreatorName: stickerCreatorName,
                                );
                          },
                      onSendSticker: (key) async {
                        final user = context.read<AuthProvider>().currentUser;
                        final member = context.read<GroupProvider>().membership;
                        if (user == null || member == null) return;
                        _wasNearBottom = true;
                        await context.read<ChatProvider>().sendSticker(
                          groupId: widget.groupId,
                          senderId: user.id,
                          senderName: _senderName(
                            user.displayName,
                            user.email,
                            member,
                          ),
                          senderAvatar: user.avatarUrl ?? '',
                          senderRole: member.role.name,
                          stickerKey: key,
                        );
                      },
                      onSendVoice: (clip) async {
                        if (clip.exceedsLimits) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppStrings.of(context).voiceNoteLimits,
                              ),
                            ),
                          );
                          return;
                        }
                        await _sendPickedBytes(
                          bytes: clip.bytes,
                          fileName: clip.fileName,
                          contentType: clip.contentType,
                        );
                      },
                    ),
                  ],
                );
              },
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
      unawaited(_loadMorePreservingAnchor());
    }
    final chat = _chatProvider;
    if (chat != null) _queueReadReceiptCheck(chat);
  }

  Future<void> _loadMorePreservingAnchor() async {
    if (_loadingOlder || !_scrollController.hasClients) return;
    _loadingOlder = true;
    _olderPixels = _scrollController.position.pixels;
    _olderMaxExtent = _scrollController.position.maxScrollExtent;
    try {
      await context.read<ChatProvider>().loadMore();
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final oldPixels = _olderPixels;
        final oldExtent = _olderMaxExtent;
        if (oldPixels == null || oldExtent == null) return;
        final delta = _scrollController.position.maxScrollExtent - oldExtent;
        final target = (oldPixels + delta).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.jumpTo(target);
      });
    } finally {
      _loadingOlder = false;
    }
  }

  /// Scroll/read only when the message list actually changes while pinned —
  /// never from every Provider rebuild (that stacked 240ms animations = jitter).
  void _syncScrollAndReadReceipts(ChatProvider chat) {
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
        // List extent often settles one frame later after the new bubble layouts.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_wasNearBottom) _scrollToLatest();
        });
      }
      _queueReadReceiptCheck(chat);
    });
  }

  void _queueReadReceiptCheck(ChatProvider chat) {
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

  void _jumpToLatest() {
    if (!mounted) return;
    setState(() {
      _newMessagesCount = 0;
      _wasNearBottom = true;
    });
    _scrollToLatest();
  }

  List<ChatMessage> _visibleMessages(ChatProvider chat) {
    if (!_scrollController.hasClients) return const <ChatMessage>[];
    final viewportObject = _scrollController.position.context.storageContext
        .findRenderObject();
    if (viewportObject is! RenderBox) return const <ChatMessage>[];
    final viewportTop = viewportObject.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewportObject.size.height;
    // Message rows are keyed by message id, so use their actual render bounds
    // instead of estimating visibility from variable bubble heights.
    return chat.messages
        .where((message) {
          final context = _messageKeys[message.id]?.currentContext;
          final renderObject = context?.findRenderObject();
          if (renderObject is! RenderBox || !renderObject.hasSize) return false;
          final topLeft = renderObject.localToGlobal(Offset.zero);
          final bottomRight = renderObject.localToGlobal(
            renderObject.size.bottomRight(Offset.zero),
          );
          return bottomRight.dy >= viewportTop && topLeft.dy <= viewportBottom;
        })
        .toList(growable: false);
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if ((target - current).abs() < 1) return;
    // Instant jump — avoids overlapping easeOut animations fighting layout growth.
    _scrollController.jumpTo(target);
  }

  Future<void> _sendText() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    final user = context.read<AuthProvider>().currentUser;
    final member = context.read<GroupProvider>().membership;
    if (user == null || member == null) return;
    _wasNearBottom = true;
    unawaited(
      context.read<ChatProvider>().sendText(
        groupId: widget.groupId,
        senderId: user.id,
        senderName: _senderName(user.displayName, user.email, member),
        senderAvatar: user.avatarUrl ?? '',
        senderRole: member.role.name,
        text: text,
        replyToMessageId: context.read<ChatProvider>().replyTarget?.id,
      ),
    );
  }

  Future<void> _sendPickedBytes({
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    final user = context.read<AuthProvider>().currentUser;
    final member = context.read<GroupProvider>().membership;
    if (user == null || member == null) return;
    _wasNearBottom = true;
    await context.read<ChatProvider>().sendMedia(
      groupId: widget.groupId,
      senderId: user.id,
      senderName: _senderName(user.displayName, user.email, member),
      senderAvatar: user.avatarUrl ?? '',
      senderRole: member.role.name,
      bytes: Uint8List.fromList(bytes),
      fileName: fileName,
      contentType: contentType,
    );
  }

  Future<void> _playAudio(ChatMessage message) async {
    final path = message.mediaUrl;
    if (path == null || path.isEmpty) return;
    final player = widget.audioPlayer ?? StorageChatAudioPlayer();
    try {
      await player.play(path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).voicePlayFailed)),
      );
    }
  }

  String _senderName(String? displayName, String email, GroupMember member) {
    final character = member.roleplayCharacter;
    if (character != null && character['name'] is String) {
      return character['name'] as String;
    }
    return displayName?.trim().isNotEmpty == true ? displayName! : email;
  }

  void _openGameCard(ChatMessage message) {
    final gameId = (message.mediaId ?? '').trim();
    if (gameId.isEmpty) return;
    if (message.gameActivity?.isMafia == true) {
      GameLinks.openMafia(context, gameId);
      return;
    }
    GameLinks.open(context, gameId);
  }

  void _openMedia(ChatMessage message) {
    final media = context
        .read<ChatProvider>()
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
    final permissions = context.read<GroupProvider>().viewerPermissions;
    final canDelete =
        isMine || permissions.contains(GroupPermission.deleteMessages);
    final canPin =
        permissions.contains(GroupPermission.deleteMessages) ||
        (isMine && permissions.contains(GroupPermission.pinOwnMessages));
    final canEdit =
        isMine &&
        !message.isDeleted &&
        message.type == ChatMessageType.text &&
        !message.isOptimistic &&
        message.createdAt != null &&
        DateTime.now().difference(message.createdAt!) <=
            const Duration(minutes: 15);
    final canCopy =
        message.text?.trim().isNotEmpty == true &&
        !message.isDeleted &&
        !message.isMedia &&
        message.type != ChatMessageType.sticker &&
        message.type != ChatMessageType.audio;
    await _stars.ensureLoaded();
    if (!mounted) return;
    final contrast = ChatContrastTheme.fromBackground(
      context.read<GroupProvider>().group?.chatBackgroundUrl,
    );
    final result = await showChatMessageActions(
      context,
      message: message,
      isMine: isMine,
      contrast: contrast,
      bubbleRect: bubbleRect == Rect.zero
          ? Rect.fromCenter(
              center: Offset(
                MediaQuery.sizeOf(context).width / 2,
                MediaQuery.sizeOf(context).height / 2,
              ),
              width: 220,
              height: 80,
            )
          : bubbleRect,
      canEdit: canEdit,
      canCopy: canCopy,
      canReply: !message.isDeleted,
      canForward: !message.isDeleted,
      canDelete: canDelete && !message.isDeleted,
      canPin: canPin && !message.isDeleted,
      canReport: !isMine && !message.isDeleted,
      canReact: message.sendState == ChatSendState.sent,
      isStarred: _stars.isStarred(message.id),
    );
    if (!mounted || result == null) return;
    if (result.action == ChatMessageAction.dismiss) return;
    if (message.isDeleted &&
        (result.action == ChatMessageAction.reply ||
            result.action == ChatMessageAction.forward ||
            result.action == ChatMessageAction.copy ||
            result.action == ChatMessageAction.pin ||
            result.action == ChatMessageAction.edit ||
            result.action == ChatMessageAction.delete ||
            result.action == ChatMessageAction.react ||
            result.action == ChatMessageAction.report)) {
      return;
    }

    final chat = context.read<ChatProvider>();
    switch (result.action) {
      case ChatMessageAction.reply:
        chat.setReplyTarget(message);
        return;
      case ChatMessageAction.copy:
        try {
          await Clipboard.setData(ClipboardData(text: message.text ?? ''));
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppStrings.of(
                  context,
                ).pick('Could not copy message', 'تعذّر نسخ الرسالة'),
              ),
            ),
          );
        }
        return;
      case ChatMessageAction.forward:
        await _forwardMessage(message);
        return;
      case ChatMessageAction.pin:
        final result = await chat.pinMessage(
          message.id,
          message.pinnedAt == null,
        );
        if (!mounted || result.isSuccess) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.failureOrNull?.message ??
                  AppStrings.of(
                    context,
                  ).pick('Unable to update pin', 'تعذر تحديث التثبيت'),
            ),
          ),
        );
        return;
      case ChatMessageAction.star:
        await _stars.toggle(message.id);
        setState(() {});
        return;
      case ChatMessageAction.edit:
        await _editMessage(message);
        return;
      case ChatMessageAction.info:
        await _showMessageInfo(message);
        return;
      case ChatMessageAction.delete:
        final confirmed = await confirmDeleteMessage(context);
        if (confirmed != true || !mounted) return;
        final result = await chat.deleteMessage(message.id);
        if (!mounted || result.isSuccess) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.failureOrNull?.message ??
                  AppStrings.of(
                    context,
                  ).pick('Unable to delete message', 'تعذر حذف الرسالة'),
            ),
          ),
        );
        return;
      case ChatMessageAction.react:
        final emoji = result.reaction ?? '❤️';
        final reactionResult = await chat.addReaction(message.id, emoji);
        if (!mounted || reactionResult.isSuccess) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reactionResult.failureOrNull?.message ??
                  AppStrings.of(
                    context,
                  ).pick('Unable to react', 'تعذر إضافة التفاعل'),
            ),
          ),
        );
        return;
      case ChatMessageAction.report:
        await _reportMessage(message);
        return;
      case ChatMessageAction.dismiss:
        return;
    }
  }

  Future<void> _reportMessage(ChatMessage message) async {
    final copy = AppStrings.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(copy.reportMessage),
        children: reportReasons
            .map(
              (value) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, value),
                child: Text(copy.reportReasonLabel(value)),
              ),
            )
            .toList(growable: false),
      ),
    );
    if (reason == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var submitting = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(copy.confirmReport),
            content: Text(
              copy.confirmReportContent(copy.reportReasonLabel(reason)),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: Text(copy.cancel),
              ),
              FilledButton(
                key: const Key('confirm-report'),
                onPressed: submitting
                    ? null
                    : () async {
                        setState(() => submitting = true);
                        final result = await context
                            .read<ChatProvider>()
                            .reportMessage(
                              messageId: message.id,
                              reason: reason,
                            );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, result.isSuccess);
                        }
                      },
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(copy.submitReport),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(confirmed ? copy.reportSubmitted : copy.reportFailed),
      ),
    );
  }

  Future<void> _showMessageInfo(ChatMessage message) async {
    final copy = AppStrings.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('chat-message-info'),
        title: Text(copy.pick('Message info', 'معلومات الرسالة')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${copy.pick('From', 'من')}: ${message.senderName}'),
            const SizedBox(height: 6),
            Text(
              '${copy.pick('Sent', 'أُرسلت')}: ${message.createdAt?.toLocal() ?? '-'}',
            ),
            const SizedBox(height: 6),
            Text(
              '${copy.delivered}: ${message.deliveredCount}/${message.recipientCount}',
            ),
            const SizedBox(height: 6),
            Text(
              '${copy.read}: ${message.readCount}/${message.recipientCount}',
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(copy.pick('Close', 'إغلاق')),
          ),
        ],
      ),
    );
  }

  Future<void> _editMessage(ChatMessage message) async {
    final copy = AppStrings.of(context);
    final text = await showEditMessageDialog(
      context,
      message: message,
      onSave: (value) async {
        final result = await context.read<ChatProvider>().editMessage(
          messageId: message.id,
          text: value,
        );
        return result.isSuccess;
      },
    );
    if (text == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(copy.messageEditSuccess)),
    );
  }

  Future<void> _forwardMessage(ChatMessage message) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    await runForwardFlow(
      context,
      currentUserId: user.id,
      currentGroupId: widget.groupId,
      onForward: (target) async {
        final result = await context.read<ChatProvider>().forwardMessage(
          messageId: message.id,
          destinationGroupId: target.groupId,
          destinationChatId: target.chatId,
        );
        return result.isSuccess;
      },
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList({
    super.key,
    required this.chat,
    required this.contrast,
    required this.currentUserId,
    required this.controller,
    required this.stars,
    required this.onAction,
    required this.onSwipeReply,
    required this.onAvatarTap,
    required this.onMediaTap,
    required this.onStickerTap,
    required this.onAudioTap,
    required this.onEventTap,
    required this.onGameTap,
    required this.onLoadMore,
    required this.messageKeys,
    required this.listKey,
  });

  final ChatProvider chat;
  final ChatContrastTheme contrast;
  final String currentUserId;
  final ScrollController controller;
  final ChatStarStore stars;
  final void Function(ChatMessage message, Rect rect) onAction;
  final ValueChanged<ChatMessage> onSwipeReply;
  final ValueChanged<ChatMessage> onAvatarTap;
  final ValueChanged<ChatMessage> onMediaTap;
  final ValueChanged<ChatMessage> onStickerTap;
  final ValueChanged<ChatMessage> onAudioTap;
  final ValueChanged<String> onEventTap;
  final ValueChanged<ChatMessage> onGameTap;
  final VoidCallback onLoadMore;
  final Map<String, GlobalKey> messageKeys;

  /// Lets the owning screen call [revealMessage] without another GlobalKey.
  final GlobalKey<_MessageListState> listKey;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {

  /// Row model is derived from [ChatProvider.messages], so it only has to be
  /// recomputed when that list actually changes. Rebuilding it on every chrome
  /// update (send progress, read receipts, reply bar) walked every loaded
  /// message and allocated a [DateTime] per row — the "chat gets heavy the more
  /// you scroll" behaviour.
  List<_ChatListRow>? _cachedRows;
  DateTime? _cachedDay;
  // Fingerprint of the row inputs. `chat.messages` hands out a fresh
  // unmodifiable wrapper on every call and the backing list is mutated in
  // place, so identity and length alone both miss changes: the provider's
  // revision covers field updates (pin, reactions, send state) and the bounds
  // cover adds and removes.
  int _cachedRevision = -1;
  int _cachedCount = -1;
  String? _cachedFirstId;
  String? _cachedLastId;

  /// messageId -> row index, produced by the same pass so jumping to a replied
  /// message needs no second scan.
  Map<String, int> _rowIndexById = const <String, int>{};

  /// Message to flash after an automatic jump (reply quote, pinned banner).
  String? _highlightedId;
  Timer? _highlightTimer;

  static const Duration _highlightDuration = Duration(milliseconds: 1400);

  /// Reveal in flight, if any. A single slot is enough: jumps replace each
  /// other, and two competing seeks would fight over the scroll position.
  _RevealRequest? _reveal;
  Timer? _seekTimer;

  /// How many proportional seeks to try before giving up on a target that the
  /// viewport never manages to build.
  static const int _maxSeekAttempts = 5;
  static const double _revealAlignment = 0.16;
  static const Duration _revealDuration = Duration(milliseconds: 320);

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _seekTimer?.cancel();
    super.dispose();
  }

  /// Row model derived from [ChatProvider.messages]; recomputed only when that
  /// list changes. Walking every message (and allocating a [DateTime] per row)
  /// on every chrome update was the "chat gets heavier the more you scroll" part.
  List<_ChatListRow> _rowsFor() {
    final messages = widget.chat.messages;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final count = messages.length;
    final firstId = count == 0 ? null : messages.first.id;
    final lastId = count == 0 ? null : messages.last.id;
    // Day dividers are relative ("Today"/"Yesterday"), so the cache has to
    // expire when the calendar day rolls over or the label reads stale.
    if (_cachedRows != null &&
        _cachedRevision == widget.chat.contentRevision &&
        _cachedCount == count &&
        _cachedFirstId == firstId &&
        _cachedLastId == lastId &&
        _cachedDay == today) {
      return _cachedRows!;
    }
    final chat = widget.chat;
    // item slots: [encryption] + optional load-more + (date? + message)*
    final rows = <_ChatListRow>[];
    final indexById = <String, int>{};
    rows.add(const _ChatListRow.encryption());
    if (chat.hasMore) rows.add(const _ChatListRow.loadMore());
    DateTime? lastDay;
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final createdAt = message.createdAt;
      final day = createdAt == null
          ? null
          : DateTime(createdAt.year, createdAt.month, createdAt.day);
      if (day != null && (lastDay == null || day != lastDay)) {
        rows.add(_ChatListRow.date(chatDayLabel(createdAt, now: now)));
        lastDay = day;
      }
      final prev = i > 0 ? messages[i - 1] : null;
      final next = i + 1 < messages.length ? messages[i + 1] : null;
      final samePrev =
          prev != null && _sameChatCluster(prev, message) && !message.isDeleted;
      final sameNext =
          next != null && _sameChatCluster(message, next) && !next.isDeleted;
      indexById[message.id] = rows.length;
      rows.add(
        _ChatListRow.message(
          message,
          showAvatar: !sameNext,
          showHeader: !samePrev,
          showTail: !sameNext,
        ),
      );
    }

    // A key is only useful while its row exists. Without this the map kept a
    // GlobalKey for every message ever scrolled past, for the life of the screen.
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

  /// Scrolls [messageId] into view and flashes it. Backs both the reply-quote
  /// tap and the pinned banner.
  ///
  /// The target may be far outside the built window, and Flutter only reveals
  /// elements that exist, so this alternates a proportional seek (which moves
  /// the cache window toward the target) with [Scrollable.ensureVisible] for the
  /// final, exact landing. Two or three rounds are enough in practice because
  /// the seek is proportional to the real scroll extent, not a guess.
  void revealMessage(String messageId) {
    _rowsFor();
    final index = _rowIndexById[messageId];
    if (index == null) {
      // Target predates the loaded window: pull the next page in, then retry.
      final alreadyPullingOlder = _reveal?.loadingOlder ?? false;
      if (widget.chat.hasMore && !alreadyPullingOlder) {
        _seekTimer?.cancel();
        _seekTimer = Timer(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          widget.onLoadMore();
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
      if (!mounted) return;
      if (_highlightedId == null) return;
      setState(() => _highlightedId = null);
    });
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _stepReveal());
  }

  void _stepReveal() {
    final request = _reveal;
    if (request == null || !mounted) return;
    final controller = widget.controller;
    if (!controller.hasClients) return;

    final target = widget.messageKeys[request.id]?.currentContext;
    if (target != null && target.mounted) {
      _reveal = null;
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: _revealAlignment,
          duration: _revealDuration,
          curve: Curves.easeOutCubic,
        ),
      );
      return;
    }

    if (request.attempt >= _maxSeekAttempts) {
      _reveal = null;
      return;
    }
    final position = controller.position;
    if (position.maxScrollExtent <= 0) {
      _reveal = null;
      return;
    }
    // Rows include date dividers and banners, but they are a small share of the
    // list, so the message index is a good enough fraction of the extent.
    final total = _rowIndexById.length;
    if (total <= 1) {
      _reveal = null;
      return;
    }
    final fraction = (request.index + 0.5) / total;
    final estimate = (position.maxScrollExtent * fraction).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    controller.jumpTo(estimate);
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
      final copy = AppStrings.of(context);
      if (chat.state == LoadingState.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (chat.state == LoadingState.offline) {
        return PubgetOfflineState(
          message: chat.failure?.message ?? copy.cachedMessagesUnavailable,
        );
      }
      if (chat.state == LoadingState.error) {
        return PubgetErrorState(
          message: chat.failure?.message ?? copy.messagesCouldNotLoad,
        );
      }
      return PubgetEmptyState(
        title: copy.startConversation,
        message: copy.messagesWillAppear,
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
        switch (row.kind) {
          case _ChatListKind.encryption:
            return const ChatEncryptionBanner();
          case _ChatListKind.loadMore:
            final loading = chat.state == LoadingState.loadingMore;
            return TextButton.icon(
              onPressed: loading ? null : widget.onLoadMore,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.history),
              label: Text(AppStrings.of(context).loadOlderMessages),
            );
          case _ChatListKind.date:
            return ChatDateDivider(label: row.dateLabel!);
          case _ChatListKind.message:
            final message = row.message!;
            if (message.sendState == ChatSendState.failed) {
              return _FailedMessage(message: message);
            }
            final bubble = ChatMessageBubble(
              key: widget.messageKeys.putIfAbsent(message.id, GlobalKey.new),
              message: message,
              isMine: message.senderId == widget.currentUserId,
              contrast: widget.contrast,
              showAvatar: row.showAvatar,
              showHeader: row.showHeader,
              showTail: row.showTail,
              isStarred: widget.stars.isStarred(message.id),
              mediaHost: widget.chat,
              onRetryMedia: widget.chat.retry,
              onLongPress: (rect) => widget.onAction(message, rect),
              onSwipeReply: () => widget.onSwipeReply(message),
              onReplyQuoteTap: (id) => revealMessage(id),
              onAvatarTap: () => widget.onAvatarTap(message),
              onMediaTap:
                  message.isMedia && message.type != ChatMessageType.sticker
                  ? () => widget.onMediaTap(message)
                  : null,
              onStickerTap: message.type == ChatMessageType.sticker
                  ? () => widget.onStickerTap(message)
                  : null,
              onAudioTap: message.type == ChatMessageType.audio
                  ? () => widget.onAudioTap(message)
                  : null,
              onWelcomeMember: message.isMemberJoinedCard
                  ? () async {
                      final user = context.read<AuthProvider>().currentUser;
                      final member = context.read<GroupProvider>().membership;
                      final groupId = chat.groupId;
                      if (user == null || member == null || groupId == null) {
                        return;
                      }
                      await context.read<ChatProvider>().sendSticker(
                        groupId: groupId,
                        senderId: user.id,
                        senderName: user.displayName ?? user.email,
                        senderAvatar: user.avatarUrl ?? '',
                        senderRole: member.role.name,
                        stickerKey: 'gestures/wave',
                      );
                    }
                  : null,
              onEventTap:
                  message.type == ChatMessageType.event &&
                      (message.mediaId ?? '').isNotEmpty
                  ? () => widget.onEventTap(message.mediaId!)
                  : null,
              onGameTap:
                  message.type == ChatMessageType.game &&
                      (message.mediaId ?? '').isNotEmpty
                  ? () => widget.onGameTap(message)
                  : null,
            );
            if (message.id != highlightId) return bubble;
            return ChatJumpHighlight(child: bubble);
        }
      },
    );
  }
}

final class _RevealRequest {
  const _RevealRequest({required this.id, required this.index, this.attempt = 0});

  final String id;
  final int index;
  final int attempt;
  final bool loadingOlder = false;
}

bool _sameChatCluster(ChatMessage first, ChatMessage second) {
  if (first.senderId != second.senderId || first.type != second.type) {
    return false;
  }
  if (first.type == ChatMessageType.system ||
      first.type == ChatMessageType.game ||
      first.type == ChatMessageType.event) {
    return false;
  }
  final firstCreatedAt = first.createdAt;
  final secondCreatedAt = second.createdAt;
  if (firstCreatedAt == null || secondCreatedAt == null) return true;
  return secondCreatedAt.difference(firstCreatedAt).abs() <=
      const Duration(minutes: 5);
}

enum _ChatListKind { encryption, loadMore, date, message }

final class _ChatListRow {
  const _ChatListRow.encryption()
    : kind = _ChatListKind.encryption,
      message = null,
      dateLabel = null,
      showAvatar = true,
      showHeader = true,
      showTail = true;

  const _ChatListRow.loadMore()
    : kind = _ChatListKind.loadMore,
      message = null,
      dateLabel = null,
      showAvatar = true,
      showHeader = true,
      showTail = true;

  const _ChatListRow.date(this.dateLabel)
    : kind = _ChatListKind.date,
      message = null,
      showAvatar = true,
      showHeader = true,
      showTail = true;

  const _ChatListRow.message(
    this.message, {
    required this.showAvatar,
    required this.showHeader,
    required this.showTail,
  }) : kind = _ChatListKind.message,
       dateLabel = null;

  final _ChatListKind kind;
  final ChatMessage? message;
  final String? dateLabel;
  final bool showAvatar;
  final bool showHeader;
  final bool showTail;
}

class _FailedMessage extends StatelessWidget {
  const _FailedMessage({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final chat = context.read<ChatProvider>();
    final copy = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          key: ValueKey<String>('failed-${message.id}'),
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                message.text ?? copy.mediaMessage,
                textWidthBasis: TextWidthBasis.longestLine,
                style: TextStyle(color: scheme.onErrorContainer, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                copy.chatSendFailureLabel(message.failureMessage),
                style: TextStyle(
                  color: scheme.onErrorContainer.withValues(alpha: 0.8),
                  fontSize: 11.5,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: copy.retry,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => chat.retry(message),
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                  IconButton(
                    tooltip: copy.deleteFailedMessage,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => chat.removeFailed(message.id),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupMenu extends StatelessWidget {
  const _GroupMenu({
    required this.groupId,
    required this.group,
    required this.isFounder,
    required this.canManageSettings,
    required this.canManageMembers,
  });

  final String groupId;
  final Group? group;
  final bool isFounder;
  final bool canManageSettings;
  final bool canManageMembers;

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.read<GroupProvider>();
    final copy = AppStrings.of(context);
    final current = group;
    return Drawer(
      child: PubgetAtmosphere(
        child: SafeArea(
          child: ListView(
            children: <Widget>[
              ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                leading: PubgetAvatar(
                  imageUrl: current?.imageUrl,
                  name: current?.name ?? copy.groupChat,
                  size: PubgetAvatarSize.medium,
                ),
                title: Text(
                  current?.name ?? copy.groupChat,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: current == null
                    ? null
                    : Text(copy.groupTypeLabel(current.type.name)),
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.person_add_alt,
                label: copy.addMembers,
                onTap: () => AppNavigation.go(
                  context,
                  '/group-members?groupId=$groupId&invite=1',
                ),
              ),
              _MenuTile(
                icon: Icons.link,
                label: copy.copyGroupLink,
                onTap: () => PubgetLinks.copy(
                  context,
                  PubgetLinks.group(groupId),
                  type: 'group',
                ),
              ),
              _MenuTile(
                icon: Icons.info_outline,
                label: copy.groupInformation,
                onTap: () =>
                    AppNavigation.go(context, '/group?groupId=$groupId'),
              ),
              _MenuTile(
                icon: Icons.perm_media_outlined,
                label: copy.groupMedia,
                onTap: () =>
                    AppNavigation.go(context, '/group-media?groupId=$groupId'),
              ),
              _MenuTile(
                icon: Icons.groups_outlined,
                label: copy.members,
                onTap: () => AppNavigation.go(
                  context,
                  '/group-members?groupId=$groupId',
                ),
              ),
              _MenuTile(
                icon: Icons.auto_awesome_mosaic_outlined,
                label: copy.eventCenter,
                onTap: () {
                  // closeEndDrawer is the safe API for Scaffold endDrawer.
                  Scaffold.of(context).closeEndDrawer();
                  // Show the sheet after the drawer close animation begins so
                  // the context remains mounted and the sheet renders above the
                  // drawer overlay cleanly.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!context.mounted) return;
                    EventCenterSheet.show(context, groupId: groupId);
                  });
                },
              ),
              if (canManageSettings || isFounder) ...[
                _MenuTile(
                  icon: Icons.edit_outlined,
                  label: copy.editGroup,
                  onTap: () => AppNavigation.go(
                    context,
                    '/group-settings?groupId=$groupId',
                  ),
                ),
                _MenuTile(
                  icon: Icons.wallpaper_outlined,
                  label: copy.chatBackground,
                  onTap: () {
                    Scaffold.of(context).closeEndDrawer();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatBackgroundPickerPage(
                            current: current?.chatBackgroundUrl,
                          ),
                        ),
                      );
                    });
                  },
                ),
              ],
              if (canManageMembers)
                _MenuTile(
                  icon: Icons.block_outlined,
                  label: copy.bannedUsers,
                  onTap: () =>
                      AppNavigation.go(context, '/group-bans?groupId=$groupId'),
                ),
              if (!isFounder)
                _MenuTile(
                  icon: Icons.exit_to_app,
                  label: copy.leaveGroup,
                  onTap: () async {
                    final confirmed = await PubgetConfirmationDialog.show(
                      context,
                      title: copy.leaveGroup,
                      message: copy.leaveGroupMessage,
                      confirmLabel: copy.leave,
                      cancelLabel: copy.cancel,
                    );
                    if (confirmed != true || !context.mounted) return;
                    groupProvider.leaveOptimistically(groupId);
                    AppNavigation.go(context, '/groups');
                  },
                ),
              if (isFounder)
                _MenuTile(
                  icon: Icons.delete_forever_outlined,
                  label: copy.disbandGroup,
                  onTap: () async {
                    final first = await PubgetConfirmationDialog.show(
                      context,
                      title: copy.disbandTitle(current?.name ?? copy.groupChat),
                      message: copy.disbandMessage,
                      confirmLabel: copy.continueLabel,
                      cancelLabel: copy.cancel,
                    );
                    if (first != true || !context.mounted) return;
                    final second = await PubgetConfirmationDialog.show(
                      context,
                      title: copy.finalConfirmation,
                      message: copy.disbandFinalMessage,
                      confirmLabel: copy.disband,
                      cancelLabel: copy.keepGroup,
                    );
                    if (second == true && context.mounted) {
                      await groupProvider.disband(groupId);
                      if (context.mounted) {
                        await AppNavigation.go(context, '/groups');
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(leading: Icon(icon), title: Text(label), onTap: onTap);
  }
}

class _MarqueeTitle extends StatefulWidget {
  const _MarqueeTitle(this.text);

  final String text;

  @override
  State<_MarqueeTitle> createState() => _MarqueeTitleState();
}

class _MarqueeTitleState extends State<_MarqueeTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addListener(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients && _scroll.position.maxScrollExtent > 0) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _MarqueeTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scroll.hasClients && _scroll.position.maxScrollExtent > 0) {
          _controller
            ..duration = Duration(
              milliseconds: (2400 + _scroll.position.maxScrollExtent * 18)
                  .round(),
            )
            ..repeat(reverse: true);
        } else {
          _controller.stop();
        }
      });
    }
  }

  void _onTick() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    _scroll.jumpTo(max * _controller.value);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Text(
              widget.text,
              maxLines: 1,
              softWrap: false,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        );
      },
    );
  }
}

/// One-line summary of a pinned message for the banner.

/// Sticky notice for the newest pinned message.
///
/// It sits outside the scroll view, so revealing a pin never changes the list's
/// scroll extent — the earlier banner stole a row and nudged the thread.
class _PinnedMessageBar extends StatelessWidget {
  const _PinnedMessageBar({
    required this.senderName,
    required this.preview,
    required this.onTap,
    required this.onUnpin,
  });

  final String senderName;
  final String preview;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        key: const Key('pinned-message-bar'),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: scheme.outlineVariant),
            ),
          ),
          padding: const EdgeInsetsDirectional.only(
            start: 14,
            end: 4,
            top: 8,
            bottom: 8,
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.push_pin_outlined, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      copy.pick('Pinned message', 'رسالة مثبتة'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      senderName.isEmpty ? preview : '$senderName: $preview',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('pinned-message-unpin'),
                tooltip: copy.pick('Unpin', 'إلغاء التثبيت'),
                visualDensity: VisualDensity.compact,
                onPressed: onUnpin,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
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
    final preview =
        message.replyPreview ??
        message.text ??
        (message.isCatalogSticker ? '[sticker]' : '[${message.type.name}]');
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        key: const Key('reply-composer-bar'),
        dense: true,
        leading: const Icon(Icons.reply),
        title: Text(
          AppStrings.of(context).replyingToLabel(message.senderName),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          key: const Key('reply-composer-clear'),
          tooltip: AppStrings.of(context).cancelReply,
          onPressed: onClear,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }
}

class _ChatChromeSlice {
  const _ChatChromeSlice({
    required this.revision,
    required this.state,
    required this.hasMore,
    required this.failureMessage,
    required this.replyId,
    required this.pinnedId,
    required this.pinnedSender,
    required this.pinnedPreview,
  });

  final int revision;
  final LoadingState state;
  final bool hasMore;
  final String? failureMessage;
  final String? replyId;

  /// Newest live pinned message, surfaced as a banner above the composer.
  final String? pinnedId;
  final String? pinnedSender;
  final String? pinnedPreview;

  @override
  bool operator ==(Object other) =>
      other is _ChatChromeSlice &&
      revision == other.revision &&
      state == other.state &&
      hasMore == other.hasMore &&
      failureMessage == other.failureMessage &&
      replyId == other.replyId &&
      pinnedId == other.pinnedId &&
      pinnedSender == other.pinnedSender &&
      pinnedPreview == other.pinnedPreview;

  @override
  int get hashCode => Object.hash(
    revision,
    state,
    hasMore,
    failureMessage,
    replyId,
    pinnedId,
    pinnedSender,
    pinnedPreview,
  );
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.cloud_off_outlined),
        title: Text(AppStrings.of(context).offlineCachedBanner),
        subtitle: message == null ? null : Text(message!),
      ),
    );
  }
}
