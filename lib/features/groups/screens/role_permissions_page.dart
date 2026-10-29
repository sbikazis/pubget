import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/group_copy.dart';
import '../models/group_models.dart';
import '../providers/group_members_provider.dart';

class RolePermissionsPage extends StatefulWidget {
  const RolePermissionsPage({required this.groupId, super.key});

  final String groupId;

  @override
  State<RolePermissionsPage> createState() => _RolePermissionsPageState();
}

class _RolePermissionsPageState extends State<RolePermissionsPage> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<GroupMembersProvider>();
    Future<void>.microtask(() => provider.loadRoles(widget.groupId));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupMembersProvider>();
    final copy = GroupCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.rolePermissionsTitle)),
      body: PubgetLoadingStateView(
        state: provider.state,
        onRetry: () => provider.loadRoles(widget.groupId),
        empty: PubgetEmptyState(title: copy.noRoles),
        error: PubgetErrorState(
          message: provider.failure?.message ?? copy.rolesLoadFailed,
          onRetry: () => provider.loadRoles(widget.groupId),
        ),
        offline: PubgetOfflineState(
          onRetry: () => provider.loadRoles(widget.groupId),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: provider.roles.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final role = provider.roles[index];
            return PubgetCard(
              child: ListTile(
                title: Text(groupRoleLabel(role.name)),
                subtitle: Text(copy.permissionsCount(role.permissions.length)),
                trailing: role.name == PubgetRank.mikado
                    ? PubgetBadge(label: copy.immutable)
                    : const Icon(Icons.edit_outlined),
                onTap: role.name == PubgetRank.mikado
                    ? null
                    : () => _edit(context, provider, role),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    GroupMembersProvider provider,
    GroupRoleDefinition role,
  ) async {
    final copy = GroupCopy.of(context);
    final selected = Set<GroupPermission>.from(role.permissions);
    final result = await showDialog<Set<GroupPermission>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(copy.permissionsFor(groupRoleLabel(role.name))),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                for (final permission in GroupPermission.values)
                  CheckboxListTile(
                    value: selected.contains(permission),
                    onChanged: (value) => setDialogState(() {
                      if (value ?? false) {
                        selected.add(permission);
                      } else {
                        selected.remove(permission);
                      }
                    }),
                    title: Text(copy.permissionLabel(permission)),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            PubgetTextButton(
              onPressed: () => Navigator.pop(dialogContext),
              semanticLabel: copy.cancelRoleChangesSemantic,
              child: Text(copy.cancel),
            ),
            PubgetPrimaryButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              semanticLabel: copy.saveRolePermissionsSemantic,
              child: Text(copy.save),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await provider.updateRolePermissions(role.name, result);
    }
  }
}
