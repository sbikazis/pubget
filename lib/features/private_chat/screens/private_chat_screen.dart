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
import '../../groups/widgets/chat_contrast_theme.dart';
import '../../groups/widgets/chat_message_bubble.dart';
import '../../groups/widgets/chat_message_actions_overlay.dart';
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
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  bool _initialized = false;
  bool _wasNearBottom = true;
  int _lastSeenMessageCount = 0;
  int _lastMarkedReadCount = -1;
  String? _lastNewestMessageId;
  int _newMessagesCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    unawaited(context.read<PrivateChatProvider>().leaveChat());
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
      canEdit: false,
      canCopy:
          message.text?.trim().isNotEmpty == true &&
          !message.isDeleted &&
          !message.isMedia,
      canReply: !message.isDeleted,
      canForward: false,
      canDelete: isMine && !message.isDeleted,
      canPin: false,
      canReport: false,
      canReact: false,
      isStarred: false,
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
      case ChatMessageAction.dismiss:
      case ChatMessageAction.forward:
      case ChatMessageAction.pin:
      case ChatMessageAction.star:
      case ChatMessageAction.edit:
      case ChatMessageAction.info:
      case ChatMessageAction.react:
      case ChatMessageAction.report:
        return;
    }
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.chat,
    required this.contrast,
    required this.currentUserId,
    required this.controller,
    required this.onAction,
    required this.onSwipeReply,
    required this.onMediaTap,
    required this.messageKeys,
  });

  final PrivateChatProvider chat;
  final ChatContrastTheme contrast;
  final String currentUserId;
  final ScrollController controller;
    final void Function(ChatMessage message, Rect rect) onAction;
  final ValueChanged<ChatMessage> onSwipeReply;
  final ValueChanged<ChatMessage> onMediaTap;
  final Map<String, GlobalKey> messageKeys;

  @override
  Widget build(BuildContext context) {
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
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: chat.messages.length + (chat.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0 && chat.hasMore) {
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
        final message = chat.messages[index - (chat.hasMore ? 1 : 0)];
        if (message.sendState == ChatSendState.failed) {
          return _FailedMessage(message: message);
        }
        return ChatMessageBubble(
          key: messageKeys.putIfAbsent(message.id, GlobalKey.new),
          message: message,
          isMine: message.senderId == currentUserId,
          contrast: contrast,
          showSenderRole: false,
           onLongPress: (rect) => onAction(message, rect),
          onSwipeReply: () => onSwipeReply(message),
          onMediaTap: message.isMedia ? () => onMediaTap(message) : null,
        );
      },
    );
  }
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
