import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../app/app_shell_scope.dart';
import '../../../core/l10n/app_strings.dart';
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
    final copy = AppStrings.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const AppShellMenuButton(),
        title: Text(copy.groupsTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AppNavigation.go(context, '/groups/create'),
        icon: const Icon(Icons.add),
        label: Text(copy.createGroup),
      ),
      body: PubgetAtmosphere(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: <Widget>[
              PubgetSearchField(
                controller: _search,
                hint: copy.searchGroups,
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
                    title: copy.noGroupsFound,
                    message: copy.noGroupsMessage,
                    icon: Icons.groups_outlined,
                    action: PubgetPrimaryButton(
                      onPressed: () =>
                          AppNavigation.go(context, '/groups/create'),
                      semanticLabel: copy.createAGroup,
                      child: Text(copy.createAGroup),
                    ),
                  ),
                  error: PubgetErrorState(
                    message: provider.failure?.message ?? copy.groupsFailed,
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
      ),
    );
  }
}
