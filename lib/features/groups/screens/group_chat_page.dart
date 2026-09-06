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
import '../../events/widgets/event_widgets.dart';
import '../../private_chat/providers/private_chat_list_provider.dart';
import '../data/sticker_store.dart';
import '../models/chat_models.dart';
import '../models/group_models.dart';
import '../providers/chat_provider.dart';
import '../providers/group_provider.dart';
import '../services/chat_audio_player.dart';
import '../services/default_voice_capture.dart';
import '../services/voice_capture.dart';
import '../widgets/chat_contrast_theme.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/sticker_picker_sheet.dart';
import '../widgets/voice_recorder_sheet.dart';
import 'chat_background_picker_page.dart';
import 'media_viewer_page.dart';

class GroupChatPage extends StatefulWidget {
  const GroupChatPage({
    required this.groupId,
    this.voiceCapture,
    this.audioPlayer,
    this.stickerStore,
    super.key,
  });

  final String groupId;
  final VoiceCapture? voiceCapture;
  final ChatAudioPlayer? audioPlayer;
  final StickerStore? stickerStore;

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
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
    final chat = context.watch<ChatProvider>();
    final groupProvider = context.watch<GroupProvider>();
    final group = groupProvider.group;
    final contrast = ChatContrastTheme.fromBackground(group?.chatBackgroundUrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_wasNearBottom) _scrollToLatest();
      unawaited(chat.markAsRead(chat.messages));
    });
    return Scaffold(
      endDrawer: _GroupMenu(
        groupId: widget.groupId,
        group: group,
        isFounder: groupProvider.isFounder,
        canManageSettings: groupProvider.canManageSettings,
        canManageMembers: groupProvider.canManageMembers,
      ),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => AppNavigation.go(context, '/groups'),
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            PubgetAvatar(
              imageUrl: group?.imageUrl,
              name: group?.name ?? 'Group',
              size: PubgetAvatarSize.small,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _MarqueeTitle(group?.name ?? 'Group chat')),
          ],
        ),
        actions: <Widget>[
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Group menu',
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
            child: Column(
              children: <Widget>[
                if (chat.state == LoadingState.offline ||
                    chat.failure != null && chat.messages.isNotEmpty)
                  _OfflineBanner(message: chat.failure?.message),
                Expanded(
                  child: _MessageList(
                    chat: chat,
                    contrast: contrast,
                    currentUserId:
                        context.read<AuthProvider>().currentUser?.id ?? '',
                    controller: _scrollController,
                    onAction: _showActions,
                    onMediaTap: _openMedia,
                    onAudioTap: _playAudio,
                    onEventTap: (eventId) => EventLinks.open(context, eventId),
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
                  onGif: _pickGif,
                  onSticker: _pickSticker,
                  onVoice: _recordVoice,
                  onEvents: () => AppNavigation.go(
                    context,
                    '/events?groupId=${Uri.encodeComponent(widget.groupId)}',
                  ),
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
      unawaited(context.read<ChatProvider>().loadMore());
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
    final member = context.read<GroupProvider>().membership;
    if (user == null || member == null) return;
    _wasNearBottom = true;
    await context.read<ChatProvider>().sendText(
      groupId: widget.groupId,
      senderId: user.id,
      senderName: _senderName(user.displayName, user.email, member),
      senderAvatar: user.avatarUrl ?? '',
      senderRole: member.role.name,
      text: text,
      replyToMessageId: context.read<ChatProvider>().replyTarget?.id,
    );
  }

  Future<void> _pickMedia(ImageSource source, bool video) async {
    final picker = ImagePicker();
    final selected = video
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source);
    if (selected == null || !mounted) return;
    final user = context.read<AuthProvider>().currentUser;
    final member = context.read<GroupProvider>().membership;
    if (user == null || member == null) return;
    final bytes = await selected.readAsBytes();
    final extension = selected.name.split('.').last.toLowerCase();
    final contentType = video
        ? (extension == 'webm' ? 'video/webm' : 'video/mp4')
        : (extension == 'gif'
              ? 'image/gif'
              : extension == 'png'
              ? 'image/png'
              : 'image/jpeg');
    if (!mounted) return;
    await context.read<ChatProvider>().sendMedia(
      groupId: widget.groupId,
      senderId: user.id,
      senderName: _senderName(user.displayName, user.email, member),
      senderAvatar: user.avatarUrl ?? '',
      senderRole: member.role.name,
      bytes: bytes,
      fileName: selected.name,
      contentType: contentType,
    );
  }

  Future<void> _pickGif() async {
    final picker = ImagePicker();
    final selected = await picker.pickImage(source: ImageSource.gallery);
    if (selected == null || !mounted) return;
    final bytes = await selected.readAsBytes();
    final type = chatMediaTypeFor(
      contentType: selected.mimeType ?? 'image/gif',
      fileName: selected.name,
    );
    if (type != ChatMessageType.gif) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a .gif file to send a GIF.')),
      );
      return;
    }
    await _sendPickedBytes(
      bytes: bytes,
      fileName: selected.name,
      contentType: 'image/gif',
    );
  }

  Future<void> _pickSticker() async {
    final key = await StickerPickerSheet.show(
      context,
      store: widget.stickerStore,
    );
    if (key == null || !mounted) return;
    final user = context.read<AuthProvider>().currentUser;
    final member = context.read<GroupProvider>().membership;
    if (user == null || member == null) return;
    await context.read<ChatProvider>().sendSticker(
      groupId: widget.groupId,
      senderId: user.id,
      senderName: _senderName(user.displayName, user.email, member),
      senderAvatar: user.avatarUrl ?? '',
      senderRole: member.role.name,
      stickerKey: key,
    );
  }

  Future<void> _recordVoice() async {
    final capture = widget.voiceCapture ?? createDeviceVoiceCapture();
    final player = widget.audioPlayer ?? StorageChatAudioPlayer();
    final clip = await VoiceRecorderSheet.show(
      context,
      capture: capture,
      onPreview: (voice) => player.playBytes(voice.bytes),
    );
    if (clip == null || !mounted) return;
    if (clip.exceedsLimits) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice notes are limited to 60 seconds and 10 MB.'),
        ),
      );
      return;
    }
    await _sendPickedBytes(
      bytes: clip.bytes,
      fileName: clip.fileName,
      contentType: clip.contentType,
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
        const SnackBar(content: Text('Voice message could not be played.')),
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
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(context, 'reply'),
            ),
            ListTile(
              leading: const Icon(Icons.favorite_outline),
              title: const Text('React'),
              onTap: () => Navigator.pop(context, 'react'),
            ),
            ListTile(
              leading: Icon(
                message.pinnedAt == null
                    ? Icons.push_pin_outlined
                    : Icons.push_pin,
              ),
              title: Text(message.pinnedAt == null ? 'Pin' : 'Unpin'),
              onTap: () => Navigator.pop(context, 'pin'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.forward_outlined),
              title: const Text('Forward / share'),
              onTap: () => Navigator.pop(context, 'forward'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: () => Navigator.pop(context, 'report'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final chat = context.read<ChatProvider>();
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.text ?? ''));
    } else if (action == 'delete') {
      await chat.deleteMessage(message.id);
    } else if (action == 'pin') {
      await chat.pinMessage(message.id, message.pinnedAt == null);
    } else if (action == 'react') {
      await chat.addReaction(message.id, '❤️');
    } else if (action == 'reply') {
      chat.setReplyTarget(message);
    } else if (action == 'forward') {
      await _forwardMessage(message);
    } else if (action == 'report') {
      await _reportMessage(message);
    }
  }

  Future<void> _forwardMessage(ChatMessage message) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final groups = context.read<GroupProvider>();
    final chats = context.read<PrivateChatListProvider>();
    await Future.wait<void>([groups.loadJoined(user.id), chats.open(user.id)]);
    if (!mounted) return;
    final destination = await showModalBottomSheet<_ForwardTarget>(
      context: context,
      showDragHandle: true,
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
              ? 'Message forwarded'
              : result.failureOrNull?.message ?? 'Forward failed.',
        ),
      ),
    );
  }

  Future<void> _reportMessage(ChatMessage message) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && message.senderId == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot report your own message.')),
      );
      return;
    }
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Report message')),
            for (final item in reportReasons)
              ListTile(
                key: Key('report-reason-$item'),
                title: Text(item),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;
    final result = await context.read<ChatProvider>().reportMessage(
      messageId: message.id,
      reason: reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Report submitted'
              : result.failureOrNull?.message ?? 'Report failed.',
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
    required this.onAction,
    required this.onMediaTap,
    required this.onAudioTap,
    required this.onEventTap,
  });

  final ChatProvider chat;
  final ChatContrastTheme contrast;
  final String currentUserId;
  final ScrollController controller;
  final ValueChanged<ChatMessage> onAction;
  final ValueChanged<ChatMessage> onMediaTap;
  final ValueChanged<ChatMessage> onAudioTap;
  final ValueChanged<String> onEventTap;

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
        message: 'Messages from group members will appear here.',
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
          onLongPress: () => onAction(message),
          onMediaTap: message.isMedia ? () => onMediaTap(message) : null,
          onAudioTap: message.type == ChatMessageType.audio
              ? () => onAudioTap(message)
              : null,
          onEventTap:
              message.type == ChatMessageType.event &&
                  (message.mediaId ?? '').isNotEmpty
              ? () => onEventTap(message.mediaId!)
              : null,
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
    final chat = context.read<ChatProvider>();
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
    required this.onGif,
    required this.onSticker,
    required this.onVoice,
    required this.onEvents,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final void Function(ImageSource source, bool video) onMedia;
  final VoidCallback onGif;
  final VoidCallback onSticker;
  final VoidCallback onVoice;
  final VoidCallback onEvents;

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
              key: const Key('composer-attach'),
              tooltip: 'Attachments',
              icon: const Icon(Icons.add_circle_outline),
              onSelected: (value) {
                if (value == 'image') onMedia(ImageSource.gallery, false);
                if (value == 'video') onMedia(ImageSource.gallery, true);
                if (value == 'gif') onGif();
                if (value == 'sticker') onSticker();
                if (value == 'audio') onVoice();
              },
              itemBuilder: (_) => const <PopupMenuEntry<String>>[
                PopupMenuItem(value: 'image', child: Text('Image')),
                PopupMenuItem(value: 'video', child: Text('Video')),
                PopupMenuItem(
                  key: Key('composer-gif'),
                  value: 'gif',
                  child: Text('GIF'),
                ),
                PopupMenuItem(
                  key: Key('composer-sticker'),
                  value: 'sticker',
                  child: Text('Sticker'),
                ),
                PopupMenuItem(
                  key: Key('composer-audio'),
                  value: 'audio',
                  child: Text('Voice message'),
                ),
              ],
            ),
            IconButton(
              tooltip: 'Emoji',
              onPressed: () => controller.text += ' 😊',
              icon: const Icon(Icons.emoji_emotions_outlined),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Message the group',
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Group events',
              onPressed: onEvents,
              icon: const Icon(Icons.celebration_outlined),
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
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: <Widget>[
            DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  PubgetAvatar(
                    imageUrl: group?.imageUrl,
                    name: group?.name ?? 'Group',
                    size: PubgetAvatarSize.large,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    group?.name ?? 'Group',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            _MenuTile(
              icon: Icons.person_add_alt,
              label: 'Add members',
              onTap: () =>
                  AppNavigation.go(context, '/group-members?groupId=$groupId'),
            ),
            _MenuTile(
              icon: Icons.link,
              label: 'Copy group link',
              onTap: () => Clipboard.setData(
                ClipboardData(text: '/group?groupId=$groupId'),
              ),
            ),
            _MenuTile(
              icon: Icons.info_outline,
              label: 'Group information',
              onTap: () => AppNavigation.go(context, '/group?groupId=$groupId'),
            ),
            _MenuTile(
              icon: Icons.celebration_outlined,
              label: 'Group events',
              onTap: () => AppNavigation.go(
                context,
                '/events?groupId=${Uri.encodeComponent(groupId)}',
              ),
            ),
            _MenuTile(
              icon: Icons.sports_esports_outlined,
              label: 'Group games',
              onTap: () => AppNavigation.go(
                context,
                '/games?groupId=${Uri.encodeComponent(groupId)}',
              ),
            ),
            _MenuTile(
              icon: Icons.perm_media_outlined,
              label: 'Group media',
              onTap: () =>
                  AppNavigation.go(context, '/group-media?groupId=$groupId'),
            ),
            _MenuTile(
              icon: Icons.groups_outlined,
              label: 'Members',
              onTap: () =>
                  AppNavigation.go(context, '/group-members?groupId=$groupId'),
            ),
            if (canManageSettings)
              _MenuTile(
                icon: Icons.settings_outlined,
                label: 'Group settings',
                onTap: () => AppNavigation.go(
                  context,
                  '/group-settings?groupId=$groupId',
                ),
              ),
            if (canManageMembers)
              _MenuTile(
                icon: Icons.block_outlined,
                label: 'Banned users',
                onTap: () =>
                    AppNavigation.go(context, '/group-bans?groupId=$groupId'),
              ),
            if (isFounder)
              _MenuTile(
                icon: Icons.edit_outlined,
                label: 'Edit group',
                onTap: () =>
                    AppNavigation.go(context, '/group?groupId=$groupId'),
              ),
            _MenuTile(
              icon: Icons.wallpaper_outlined,
              label: 'Chat background',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatBackgroundPickerPage(
                    current: group?.chatBackgroundUrl,
                  ),
                ),
              ),
            ),
            if (!isFounder)
              _MenuTile(
                icon: Icons.exit_to_app,
                label: 'Leave group',
                onTap: () {
                  groupProvider.leaveOptimistically(groupId);
                  AppNavigation.go(context, '/groups');
                },
              ),
            if (isFounder)
              _MenuTile(
                icon: Icons.delete_forever_outlined,
                label: 'Disband group',
                onTap: () async {
                  final confirmed = await PubgetConfirmationDialog.show(
                    context,
                    title: 'Disband ${group?.name ?? 'group'}?',
                    message: 'This permanently removes the group.',
                    confirmLabel: 'Disband',
                    cancelLabel: 'Cancel',
                  );
                  if (confirmed == true && context.mounted) {
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

class _MarqueeTitleState extends State<_MarqueeTitle> {
  final _scroll = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _animate());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _animate() {
    if (!_scroll.hasClients || _scroll.position.maxScrollExtent <= 0) return;
    final target = _scroll.offset == 0 ? _scroll.position.maxScrollExtent : 0.0;
    _scroll.animateTo(
      target,
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, maxLines: 1),
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
        title: const Text('Offline · showing cached messages'),
        subtitle: message == null ? null : Text(message!),
      ),
    );
  }
}
