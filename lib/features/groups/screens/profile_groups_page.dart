import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/errors/result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/group_models.dart';
import '../repositories/group_repository.dart';

/// Full list of one profile's joined groups, opened from the profile.
class ProfileGroupsPage extends StatefulWidget {
  const ProfileGroupsPage({this.userId, super.key});

  final String? userId;

  @override
  State<ProfileGroupsPage> createState() => _ProfileGroupsPageState();
}

class _ProfileGroupsPageState extends State<ProfileGroupsPage> {
  Future<Result<List<Group>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Result<List<Group>>> _load() {
    final uid = widget.userId ?? '';
    if (uid.isEmpty) {
      return Future<Result<List<Group>>>.value(
        const Success<List<Group>>(<Group>[]),
      );
    }
    try {
      return context.read<GroupRepository>().listJoinedGroups(uid);
    } on ProviderNotFoundException {
      return Future<Result<List<Group>>>.value(
        const Success<List<Group>>(<Group>[]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final isOwner = currentUserId != null && currentUserId == widget.userId;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: const Text('Groups'),
      ),
      body: SafeArea(
        child: FutureBuilder<Result<List<Group>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || snapshot.data is FailureResult) {
              return PubgetErrorState(
                message: 'Could not load groups.',
                onRetry: () => setState(() => _future = _load()),
              );
            }
            final groups = snapshot.data?.valueOrNull ?? const <Group>[];
            if (groups.isEmpty) {
              return PubgetEmptyState(
                icon: Icons.groups_outlined,
                title: isOwner ? 'No groups yet' : 'No groups to show',
                message: isOwner
                    ? 'Join a community or create your own.'
                    : 'Groups stay private or empty for now.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final group = groups[index];
                return PubgetCard(
                  key: Key('profile-group-${group.id}'),
                  onTap: () => AppNavigation.go(
                    context,
                    '/group?groupId=${Uri.encodeComponent(group.id)}',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: <Widget>[
                        PubgetAvatar(
                          imageUrl: group.imageUrl,
                          name: group.name,
                          size: PubgetAvatarSize.medium,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${group.membersCount} members',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}