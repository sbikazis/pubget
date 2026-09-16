import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../app/app_shell_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../notifications/providers/unread_engine.dart';
import '../../notifications/widgets/unread_badge.dart';
import '../models/private_chat_models.dart';
import '../providers/private_chat_list_provider.dart';

class PrivateChatsListScreen extends StatefulWidget {
  const PrivateChatsListScreen({super.key});

  @override
  State<PrivateChatsListScreen> createState() => _PrivateChatsListScreenState();
}

class _PrivateChatsListScreenState extends State<PrivateChatsListScreen> {
  final _scroll = ScrollController();
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid == null) return;
    _opened = true;
    final list = context.read<PrivateChatListProvider>();
    Future<void>.microtask(() => list.open(uid));
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >
        _scroll.position.maxScrollExtent - 240) {
      unawaitedLoadMore();
    }
  }

  void unawaitedLoadMore() {
    context.read<PrivateChatListProvider>().loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final list = context.watch<PrivateChatListProvider>();
    final uid = context.watch<AuthProvider>().currentUser?.id ?? '';
    return Scaffold(
      appBar: AppBar(
        leading: const AppShellMenuButton(),
        title: UnreadBadge(
          count: context.watch<UnreadEngine>().privateChats,
          child: const Text('Private'),
        ),
      ),
      body: PubgetLoadingStateView(
        state: list.state,
        onRetry: () {
          if (uid.isEmpty) return;
          context.read<PrivateChatListProvider>().open(uid);
        },
        empty: PubgetEmptyState(
          title: 'No private chats yet',
          message:
              'Start a conversation from a Friend or Fan profile.',
          icon: Icons.chat_bubble_outline,
          action: PubgetSecondaryButton(
            onPressed: () => AppNavigation.go(context, '/search'),
            semanticLabel: 'Find people',
            child: const Text('Find people'),
          ),
        ),
        error: PubgetErrorState(
          message: list.failure?.message ?? 'Private chats could not load.',
          onRetry: () {
            if (uid.isEmpty) return;
            context.read<PrivateChatListProvider>().open(uid);
          },
        ),
        offline: PubgetOfflineState(
          onRetry: () {
            if (uid.isEmpty) return;
            context.read<PrivateChatListProvider>().open(uid);
          },
        ),
        child: ListView.separated(
          controller: _scroll,
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: list.chats.length + (list.hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            if (index >= list.chats.length) {
              return TextButton(
                onPressed: list.loadMore,
                child: const Text('Load older chats'),
              );
            }
            return _ChatTile(chat: list.chats[index], currentUserId: uid);
          },
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.currentUserId});

  final PrivateChatSummary chat;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final unread = chat.isUnreadFor(currentUserId);
    return PubgetCard(
      key: ValueKey<String>('private-chat-${chat.id}'),
      onTap: () => AppNavigation.go(
        context,
        '/private-chat?chatId=${Uri.encodeComponent(chat.id)}',
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: UnreadBadge(
          count: unread ? 1 : 0,
          child: PubgetAvatar(
            imageUrl: chat.otherAvatarUrl(currentUserId),
            name: chat.otherDisplayName(currentUserId),
            size: PubgetAvatarSize.medium,
          ),
        ),
        title: Text(chat.otherDisplayName(currentUserId)),
        subtitle: Text(
          chat.lastMessageText.isEmpty ? 'No messages yet' : chat.lastMessageText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: unread
            ? const Icon(Icons.circle, size: 10, color: Color(0xFF6C3FC5))
            : null,
      ),
    );
  }
}
