import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_shell_scope.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/group_models.dart';
import '../providers/group_provider.dart';
import '../widgets/group_list_card.dart';
import 'group_type_sheet.dart';

class GroupsHomePage extends StatefulWidget {
  const GroupsHomePage({this.initialTab = 0, super.key});

  final int initialTab;

  @override
  State<GroupsHomePage> createState() => _GroupsHomePageState();
}

class _GroupsHomePageState extends State<GroupsHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid != null) {
      final provider = context.read<GroupProvider>();
      Future<void>.microtask(() => provider.loadJoined(uid));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupProvider>();
    final uid = context.watch<AuthProvider>().currentUser?.id;
    final copy = AppStrings.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const AppShellMenuButton(),
        title: Text(copy.groupsTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: <Widget>[
            Tab(
              key: const Key('groups-tab-joined'),
              text: copy.joinedGroupsTab,
            ),
            Tab(
              key: const Key('groups-tab-created'),
              text: copy.createdGroupsTab,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => GroupTypeSheet.show(context),
        icon: const Icon(Icons.add),
        label: Text(copy.createGroup),
      ),
      body: PubgetAtmosphere(
        child: TabBarView(
          controller: _tabs,
          children: <Widget>[
            _GroupsList(
              key: const Key('groups-pane-joined'),
              groups: uid == null
                  ? provider.joinedGroups
                  : provider.memberGroups(uid),
              state: provider.joinedState,
              failure: provider.joinedFailure?.message ?? copy.joinedFailed,
              emptyTitle: copy.noJoinedGroups,
              emptyMessage: copy.noJoinedMessage,
              onRetry: uid == null ? null : () => provider.loadJoined(uid),
            ),
            _GroupsList(
              key: const Key('groups-pane-created'),
              groups: uid == null
                  ? const []
                  : provider.foundedGroups(uid),
              state: provider.joinedState,
              failure: provider.joinedFailure?.message ?? copy.groupsFailed,
              emptyTitle: copy.noCreatedGroups,
              emptyMessage: copy.noCreatedMessage,
              onRetry: uid == null ? null : () => provider.loadJoined(uid),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupsList extends StatelessWidget {
  const _GroupsList({
    super.key,
    required this.groups,
    required this.state,
    required this.failure,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRetry,
  });

  final List<Group> groups;
  final LoadingState state;
  final String failure;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final viewState = state == LoadingState.loaded && groups.isEmpty
        ? LoadingState.empty
        : state;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: PubgetLoadingStateView(
        state: viewState,
        onRetry: onRetry,
        empty: PubgetEmptyState(
          title: emptyTitle,
          message: emptyMessage,
          icon: Icons.groups_outlined,
          action: PubgetPrimaryButton(
            onPressed: () => GroupTypeSheet.show(context),
            semanticLabel: copy.createAGroup,
            child: Text(copy.createAGroup),
          ),
        ),
        error: PubgetErrorState(message: failure, onRetry: onRetry),
        offline: PubgetOfflineState(onRetry: onRetry),
        child: ListView.separated(
          itemCount: groups.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => GroupListCard(group: groups[index]),
        ),
      ),
    );
  }
}
