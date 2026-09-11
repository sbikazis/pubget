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
import '../../private_chat/providers/private_chat_list_provider.dart';
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
  ChatProvider? _chatProvider;
  late final UserStickerStore _userStickers =
      widget.userStickerStore ?? UserStickerStore();
  bool _initialized = false;
  bool _wasNearBottom = true;
  int _lastSeenMessageCount = 0;
  int _lastMarkedReadCount = -1;
  bool _loadingOlder = false;
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
    unawaited(_chatProvider?.leaveGroup());
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
              selector: (_, chat) => _ChatChromeSlice(
                revision: chat.contentRevision,
                state: chat.state,
                hasMore: chat.hasMore,
                failureMessage: chat.failure?.message,
                replyId: chat.replyTarget?.id,
              ),
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
                      child: _MessageList(
                        chat: chat,
                        contrast: contrast,
                        currentUserId:
                            context.read<AuthProvider>().currentUser?.id ?? '',
                        controller: _scrollController,
                        stars: _stars,
                        onAction: _showActions,
                        onSwipeReply: (message) {
                          context.read<ChatProvider>().setReplyTarget(message);
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
    if (_scrollController.position.pixels < 180) {
      unawaited(_loadMorePreservingAnchor());
    }
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
    final shouldScroll =
        _wasNearBottom && count > 0 && count != _lastSeenMessageCount;
    final shouldMarkRead = count != _lastMarkedReadCount;
    _lastSeenMessageCount = count;
    if (!shouldScroll && !shouldMarkRead) return;
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
      if (shouldMarkRead) {
        _lastMarkedReadCount = count;
        unawaited(chat.markAsRead(chat.messages));
      }
    });
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
    final canPin = permissions.contains(GroupPermission.pinOwnMessages);
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
        await Clipboard.setData(ClipboardData(text: message.text ?? ''));
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
        await chat.addReaction(message.id, emoji);
        return;
      case ChatMessageAction.report:
        await _reportMessage(message);
        return;
      case ChatMessageAction.dismiss:
        return;
    }
  }

  Future<void> _reportMessage(ChatMessage message) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Report message'),
        children: reportReasons
            .map(
              (value) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, value),
                child: Text(value),
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
            title: const Text('Confirm report'),
            content: Text('Submit this message report for “$reason”?'),
            actions: <Widget>[
              TextButton(
                onPressed: submitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
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
                    : const Text('Submit report'),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed == null || !mounted) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          confirmed ? 'Report submitted' : 'Unable to submit report',
        ),
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
    final controller = TextEditingController(text: message.text ?? '');
    final next = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Edit message'),
            content: TextField(
              key: const Key('chat-edit-field'),
              controller: controller,
              autofocus: true,
              maxLines: 4,
              enabled: !saving,
              decoration: const InputDecoration(
                hintText: 'Update your message',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final value = controller.text.trim();
                  if (value.isEmpty || value == message.text?.trim()) return;
                  setState(() => saving = true);
                  final result = await context.read<ChatProvider>().editMessage(
                    messageId: message.id,
                    text: value,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, result.isSuccess);
                  }
                },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (next == null || !mounted || next) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to edit message')));
  }

  Future<void> _forwardMessage(ChatMessage message) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final groups = context.read<GroupProvider>();
    final chats = context.read<PrivateChatListProvider>();
    await Future.wait<void>([groups.loadJoined(user.id), chats.open(user.id)]);
    if (!mounted) return;
    final destination = await PubgetBottomSheet.present<_ForwardTarget>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ForwardSheet(
        currentGroupId: widget.groupId,
        groups: groups,
        chats: chats,
        currentUserId: user.id,
      ),
    );
    if (destination == null || !mounted) return;
    final result = await context.read<ChatProvider>().forwardMessage(
      messageId: message.id,
      destinationGroupId: destination.groupId,
      destinationChatId: destination.chatId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? AppStrings.of(context).messageForwarded
              : result.failureOrNull?.message ??
                    AppStrings.of(context).forwardFailed,
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
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

  @override
  Widget build(BuildContext context) {
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
    final messages = chat.messages;
    final now = DateTime.now();
    // item slots: [encryption?] + optional load-more + (date? + message)*
    final rows = <_ChatListRow>[];
    rows.add(const _ChatListRow.encryption());
    if (chat.hasMore) rows.add(const _ChatListRow.loadMore());
    DateTime? lastDay;
    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      final day = message.createdAt == null
          ? null
          : DateTime(
              message.createdAt!.year,
              message.createdAt!.month,
              message.createdAt!.day,
            );
      if (day != null && (lastDay == null || day != lastDay)) {
        rows.add(_ChatListRow.date(chatDayLabel(message.createdAt, now: now)));
        lastDay = day;
      }
      final prev = i > 0 ? messages[i - 1] : null;
      final next = i + 1 < messages.length ? messages[i + 1] : null;
      final samePrev =
          prev != null &&
          prev.senderId == message.senderId &&
          prev.type == message.type &&
          !message.isDeleted &&
          prev.type != ChatMessageType.system &&
          prev.type != ChatMessageType.game &&
          prev.type != ChatMessageType.event;
      final sameNext =
          next != null &&
          next.senderId == message.senderId &&
          next.type == message.type &&
          !next.isDeleted;
      rows.add(
        _ChatListRow.message(
          message,
          showAvatar: !sameNext,
          showHeader: !samePrev,
          showTail: !sameNext,
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        switch (row.kind) {
          case _ChatListKind.encryption:
            return const ChatEncryptionBanner();
          case _ChatListKind.loadMore:
            return TextButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.history),
              label: Text(AppStrings.of(context).loadOlderMessages),
            );
          case _ChatListKind.date:
            return ChatDateDivider(label: row.dateLabel!);
          case _ChatListKind.message:
            final message = row.message!;
            if (message.sendState == ChatSendState.failed) {
              return _FailedMessage(message: message);
            }
            return ChatMessageBubble(
              key: ValueKey<String>(message.id),
              message: message,
              isMine: message.senderId == currentUserId,
              contrast: contrast,
              showAvatar: row.showAvatar,
              showHeader: row.showHeader,
              showTail: row.showTail,
              isStarred: stars.isStarred(message.id),
              onLongPress: (rect) => onAction(message, rect),
              onSwipeReply: () => onSwipeReply(message),
              onAvatarTap: () => onAvatarTap(message),
              onMediaTap:
                  message.isMedia && message.type != ChatMessageType.sticker
                  ? () => onMediaTap(message)
                  : null,
              onStickerTap: message.type == ChatMessageType.sticker
                  ? () => onStickerTap(message)
                  : null,
              onAudioTap: message.type == ChatMessageType.audio
                  ? () => onAudioTap(message)
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
                  ? () => onEventTap(message.mediaId!)
                  : null,
              onGameTap:
                  message.type == ChatMessageType.game &&
                      (message.mediaId ?? '').isNotEmpty
                  ? () => onGameTap(message)
                  : null,
            );
        }
      },
    );
  }
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
                  Navigator.pop(context);
                  EventCenterSheet.show(context, groupId: groupId);
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
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatBackgroundPickerPage(
                        current: current?.chatBackgroundUrl,
                      ),
                    ),
                  ),
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
          'Replying to ${message.senderName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          key: const Key('reply-composer-clear'),
          tooltip: 'Cancel reply',
          onPressed: onClear,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }
}

final class _ForwardTarget {
  const _ForwardTarget({this.groupId, this.chatId});

  final String? groupId;
  final String? chatId;
}

class _ForwardSheet extends StatelessWidget {
  const _ForwardSheet({
    required this.currentGroupId,
    required this.groups,
    required this.chats,
    required this.currentUserId,
  });

  final String currentGroupId;
  final GroupProvider groups;
  final PrivateChatListProvider chats;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[groups, chats]),
        builder: (context, _) {
          final destinations = <Widget>[
            const ListTile(title: Text('Forward to')),
            ...groups.joinedGroups
                .where((group) => group.id != currentGroupId)
                .map(
                  (group) => ListTile(
                    key: Key('forward-group-${group.id}'),
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(group.name),
                    onTap: () => Navigator.pop(
                      context,
                      _ForwardTarget(groupId: group.id),
                    ),
                  ),
                ),
            ...chats.chats.map(
              (chat) => ListTile(
                key: Key('forward-chat-${chat.id}'),
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(chat.otherDisplayName(currentUserId)),
                onTap: () =>
                    Navigator.pop(context, _ForwardTarget(chatId: chat.id)),
              ),
            ),
          ];
          if (destinations.length == 1) {
            destinations.add(
              const ListTile(title: Text('No other groups or chats available')),
            );
          }
          return ListView(shrinkWrap: true, children: destinations);
        },
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
  });

  final int revision;
  final LoadingState state;
  final bool hasMore;
  final String? failureMessage;
  final String? replyId;

  @override
  bool operator ==(Object other) =>
      other is _ChatChromeSlice &&
      revision == other.revision &&
      state == other.state &&
      hasMore == other.hasMore &&
      failureMessage == other.failureMessage &&
      replyId == other.replyId;

  @override
  int get hashCode =>
      Object.hash(revision, state, hasMore, failureMessage, replyId);
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
