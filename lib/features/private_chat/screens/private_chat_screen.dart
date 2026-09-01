import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/models/chat_models.dart';
import '../../groups/screens/media_viewer_page.dart';
import '../../groups/widgets/chat_contrast_theme.dart';
import '../../groups/widgets/chat_message_bubble.dart';
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
  bool _initialized = false;
  bool _wasNearBottom = true;

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
    final title = summary.isNotEmpty
        ? summary.first.otherDisplayName(uid)
        : (widget.otherUserId?.trim().isNotEmpty == true
            ? widget.otherUserId!
            : 'Private chat');
    final avatarUrl = summary.isNotEmpty
        ? summary.first.otherAvatarUrl(uid)
        : null;
    final contrast = ChatContrastTheme.fromBackground(null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_wasNearBottom) _scrollToLatest();
      unawaited(chat.markAsRead(chat.messages));
    });
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => AppNavigation.go(context, '/private'),
          icon: const Icon(Icons.arrow_back),
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
            Expanded(
              child: Text(title, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Hide conversation',
            onPressed: () async {
              final result = await context.read<PrivateChatProvider>().hideChat();
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
                  child: _MessageList(
                    chat: chat,
                    contrast: contrast,
                    currentUserId: uid,
                    controller: _scrollController,
                    onAction: _showActions,
                    onMediaTap: _openMedia,
                  ),
                ),
                if (chat.uploadProgress.isNotEmpty)
                  LinearProgressIndicator(
                    value: chat.uploadProgress.values.first,
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
    if (_scrollController.position.pixels < 180) {
      unawaited(context.read<PrivateChatProvider>().loadMore());
    }
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendText() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    _wasNearBottom = true;
    await context.read<PrivateChatProvider>().sendText(
      chatId: widget.chatId,
      senderId: user.id,
      senderName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!
          : user.email,
      senderAvatar: user.avatarUrl ?? '',
      text: text,
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

  Future<void> _showActions(ChatMessage message) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            if (message.text?.isNotEmpty == true)
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy'),
                onTap: () => Navigator.pop(context, 'copy'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final chat = context.read<PrivateChatProvider>();
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.text ?? ''));
    } else if (action == 'delete') {
      await chat.deleteMessage(message.id);
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
    required this.onMediaTap,
  });

  final PrivateChatProvider chat;
  final ChatContrastTheme contrast;
  final String currentUserId;
  final ScrollController controller;
  final ValueChanged<ChatMessage> onAction;
  final ValueChanged<ChatMessage> onMediaTap;

  @override
  Widget build(BuildContext context) {
    if (chat.messages.isEmpty) {
      if (chat.state == LoadingState.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (chat.state == LoadingState.offline) {
        return PubgetOfflineState(
          message: chat.failure?.message ?? 'Cached messages are unavailable.',
        );
      }
      if (chat.state == LoadingState.error) {
        return PubgetErrorState(
          message: chat.failure?.message ?? 'Messages could not load.',
        );
      }
      return const PubgetEmptyState(
        title: 'Start the conversation',
        message: 'Messages in this private chat will appear here.',
        icon: Icons.forum_outlined,
      );
    }
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: chat.messages.length + (chat.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0 && chat.hasMore) {
          return TextButton.icon(
            onPressed: chat.loadMore,
            icon: const Icon(Icons.history),
            label: const Text('Load older messages'),
          );
        }
        final message = chat.messages[index - (chat.hasMore ? 1 : 0)];
        if (message.sendState == ChatSendState.failed) {
          return _FailedMessage(message: message);
        }
        return ChatMessageBubble(
          key: ValueKey<String>(message.id),
          message: message,
          isMine: message.senderId == currentUserId,
          contrast: contrast,
          showSenderRole: false,
          onLongPress: () => onAction(message),
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
    return Card(
      key: ValueKey<String>('failed-${message.id}'),
      color: Theme.of(context).colorScheme.errorContainer,
      margin: const EdgeInsets.all(AppSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(message.text ?? 'Media message'),
        subtitle: Text(message.failureMessage ?? 'Message was not sent.'),
        trailing: Wrap(
          children: <Widget>[
            IconButton(
              tooltip: 'Retry',
              onPressed: () => chat.retry(message),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Delete failed message',
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
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: <Widget>[
            PopupMenuButton<String>(
              tooltip: 'Attachments',
              icon: const Icon(Icons.add_circle_outline),
              onSelected: (value) {
                if (value == 'image') onMedia(ImageSource.gallery, false);
                if (value == 'video') onMedia(ImageSource.gallery, true);
              },
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem(value: 'image', child: Text('Image')),
                PopupMenuItem(value: 'video', child: Text('Video')),
              ],
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Message privately',
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Send message',
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
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
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(message ?? 'You are offline. Failed sends can be retried.'),
      ),
    );
  }
}
