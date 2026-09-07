import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';

/// Lets any signed-in member pick a joined group, then opens the real builder.
class CreateEventEntryPage extends StatefulWidget {
  const CreateEventEntryPage({this.templateId, super.key});

  final String? templateId;

  @override
  State<CreateEventEntryPage> createState() => _CreateEventEntryPageState();
}

class _CreateEventEntryPageState extends State<CreateEventEntryPage> {
  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>().currentUser?.id;
    final groups = context.read<GroupProvider>();
    if (uid != null) {
      Future<void>.microtask(() => groups.openJoined(uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final groups = context.watch<GroupProvider>();
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.createEvent),
      ),
      body: PubgetLoadingStateView(
        state: groups.joinedState == LoadingState.initial
            ? LoadingState.loading
            : groups.joinedState,
        onRetry: () {
          final uid = context.read<AuthProvider>().currentUser?.id;
          if (uid != null) groups.openJoined(uid);
        },
        empty: PubgetEmptyState(
          title: copy.createEvent,
          message: copy.joinGroupToCreateEvent,
          action: PubgetPrimaryButton(
            onPressed: () => AppNavigation.go(context, '/groups'),
            semanticLabel: copy.findGroups,
            child: Text(copy.findGroups),
          ),
        ),
        error: PubgetErrorState(
          title: copy.couldNotLoad,
          message: groups.joinedFailure?.message ?? copy.tryAgainShort,
          onRetry: () {
            final uid = context.read<AuthProvider>().currentUser?.id;
            if (uid != null) groups.openJoined(uid);
          },
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            Text(copy.pickHostGroup, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            for (final group in groups.joinedGroups)
              ListTile(
                key: Key('create-event-group-${group.id}'),
                leading: const Icon(Icons.groups_outlined),
                title: Text(group.name),
                subtitle: Text(copy.membersCount(group.membersCount)),
                onTap: () {
                  final template = widget.templateId;
                  final path = template == null || template.isEmpty
                      ? '/events/create?groupId=${Uri.encodeComponent(group.id)}'
                      : '/events/create?groupId=${Uri.encodeComponent(group.id)}'
                            '&templateId=${Uri.encodeComponent(template)}';
                  AppNavigation.go(context, path);
                },
              ),
          ],
        ),
      ),
    );
  }
}
