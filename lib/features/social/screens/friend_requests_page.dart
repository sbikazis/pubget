import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../../core/l10n/app_strings.dart';
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
    final copy = AppStrings.of(context);
    final hasItems =
        social.incomingRequests.isNotEmpty || social.outgoingRequests.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.friendRequests),
      ),
      body: PubgetLoadingStateView(
        state: social.state == LoadingState.empty
            ? LoadingState.loaded
            : social.state,
        onRetry: _load,
        error: PubgetErrorState(
          message: social.failure?.message ?? copy.couldNotLoadFriendRequests,
          onRetry: _load,
        ),
        offline: PubgetOfflineState(onRetry: _load),
        child: !hasItems
            ? PubgetEmptyState(
                title: copy.noFriendRequests,
                message: copy.newRequestsAppearHere,
                icon: Icons.person_add_disabled_outlined,
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: <Widget>[
                  if (social.incomingRequests.isNotEmpty)
                    _SectionTitle(copy.incomingRequests),
                  ...social.incomingRequests.map(
                    (friendship) => _RequestCard(
                      key: Key('incoming-request-${friendship.userIdKey}'),
                      friendship: friendship,
                      outgoing: false,
                    ),
                  ),
                  if (social.incomingRequests.isNotEmpty &&
                      social.outgoingRequests.isNotEmpty)
                    const SizedBox(height: AppSpacing.lg),
                  if (social.outgoingRequests.isNotEmpty)
                    _SectionTitle(copy.outgoingRequests),
                  ...social.outgoingRequests.map(
                    (friendship) => _RequestCard(
                      key: Key('outgoing-request-${friendship.userIdKey}'),
                      friendship: friendship,
                      outgoing: true,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null) await context.read<SocialProvider>().load(userId);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    super.key,
    required this.friendship,
    required this.outgoing,
  });

  final Friendship friendship;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().currentUser?.id ?? '';
    final copy = AppStrings.of(context);
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
                Text(outgoing ? copy.requestSent : copy.friendRequest),
                Text(
                  otherUserId,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (outgoing)
            PubgetSecondaryButton(
              key: const Key('cancel-request'),
              onPressed: () => context
                  .read<SocialProvider>()
                  .cancelFriendRequest(otherUserId),
              semanticLabel: copy.cancelFriendRequest,
              child: Text(copy.cancelRequest),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PubgetIconButton(
                  icon: Icons.close,
                  tooltip: copy.rejectRequest,
                  onPressed: () =>
                      context.read<SocialProvider>().respondToFriendRequest(
                        otherUserId: otherUserId,
                        accept: false,
                      ),
                ),
                PubgetIconButton(
                  icon: Icons.check,
                  tooltip: copy.acceptRequest,
                  onPressed: () => context
                      .read<SocialProvider>()
                      .respondToFriendRequest(
                        otherUserId: otherUserId,
                        accept: true,
                      ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}