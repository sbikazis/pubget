import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../app/app_shell_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../providers/group_provider.dart';
import '../widgets/group_list_card.dart';

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
      appBar: AppBar(
        leading: const AppShellMenuButton(),
        title: const Text('Groups'),
      ),
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
                      GroupListCard(group: provider.searchResults[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
