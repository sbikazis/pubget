import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/group_models.dart';
import '../providers/group_provider.dart';

class GroupsHomePage extends StatefulWidget {
  const GroupsHomePage({super.key});

  @override
  State<GroupsHomePage> createState() => _GroupsHomePageState();
}

class _GroupsHomePageState extends State<GroupsHomePage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<GroupProvider>();
    Future<void>.microtask(() => provider.search(''));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AppNavigation.go(context, '/groups/create'),
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            PubgetSearchField(
              controller: _search,
              hint: 'Search groups',
              onChanged: provider.search,
              onClear: () {
                _search.clear();
                provider.search('');
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: PubgetLoadingStateView(
                state: provider.state,
                onRetry: () => provider.search(_search.text),
                empty: PubgetEmptyState(
                  title: 'No groups found',
                  message:
                      'Discover a community or create the first group on Pubget.',
                  icon: Icons.groups_outlined,
                  action: PubgetPrimaryButton(
                    onPressed: () =>
                        AppNavigation.go(context, '/groups/create'),
                    semanticLabel: 'Create a group',
                    child: const Text('Create a group'),
                  ),
                ),
                error: PubgetErrorState(
                  message:
                      provider.failure?.message ?? 'Groups could not load.',
                  onRetry: () => provider.search(_search.text),
                ),
                offline: PubgetOfflineState(
                  onRetry: () => provider.search(_search.text),
                ),
                child: ListView.separated(
                  itemCount: provider.searchResults.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _GroupCard(group: provider.searchResults[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return PubgetCard(
      onTap: () => AppNavigation.go(context, '/group?groupId=${group.id}'),
      child: Row(
        children: <Widget>[
          const Icon(Icons.groups_outlined, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text('${group.membersCount}/${group.maxMembers} members'),
              ],
            ),
          ),
          Text(group.type.name),
        ],
      ),
    );
  }
}
