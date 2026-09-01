import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/social_models.dart';
import '../providers/social_provider.dart';

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({super.key});

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  bool _requestedLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedLoad) return;
    _requestedLoad = true;
    Future<void>.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Friend requests')),
      body: PubgetLoadingStateView(
        state: social.state == LoadingState.empty
            ? LoadingState.loaded
            : social.state,
        onRetry: _load,
        error: PubgetErrorState(
          message: social.failure?.message ?? 'Requests could not load.',
          onRetry: _load,
        ),
        offline: PubgetOfflineState(onRetry: _load),
        child: social.incomingRequests.isEmpty
            ? const PubgetEmptyState(
                title: 'No friend requests',
                message: 'New requests will appear here.',
                icon: Icons.person_add_disabled_outlined,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: social.incomingRequests.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) =>
                    _RequestCard(friendship: social.incomingRequests[index]),
              ),
      ),
    );
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) await context.read<SocialProvider>().load(userId);
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.friendship});

  final Friendship friendship;

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().currentUser?.id ?? '';
    final otherUserId = friendship.otherUserId(userId);
    return PubgetCard(
      child: Row(
        children: <Widget>[
          PubgetAvatar(name: otherUserId, size: PubgetAvatarSize.small),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Friend request'),
                Text(
                  otherUserId,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PubgetIconButton(
            icon: Icons.close,
            tooltip: 'Reject request',
            onPressed: () =>
                context.read<SocialProvider>().respondToFriendRequest(
                  otherUserId: otherUserId,
                  accept: false,
                ),
          ),
          PubgetIconButton(
            icon: Icons.check,
            tooltip: 'Accept request',
            onPressed: () => context
                .read<SocialProvider>()
                .respondToFriendRequest(otherUserId: otherUserId, accept: true),
          ),
        ],
      ),
    );
  }
}
