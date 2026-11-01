import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_radius.dart';
import '../../../../../core/constants/rank_colors.dart';
import '../../../l10n/group_copy.dart';
import '../../../models/group_models.dart';

class Step5Permissions extends StatelessWidget {
  const Step5Permissions({
    required this.groupType,
    super.key,
  });

  final GroupType groupType;

  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    final isRoleplay = groupType != GroupType.public;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            copy.permissionsTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            copy.permissionsHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isRoleplay) ...[
            _RoleplayNote(text: copy.roleplayRanksNote),
            const SizedBox(height: AppSpacing.md),
          ],
          _PermissionsTable(),
          const SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: copy.rolesNotesTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NoteItem(copy.founderNote),
                _NoteItem(copy.shogunNote),
                _NoteItem(copy.daimyoNote),
                _NoteItem(copy.roleChangeNote),
                _NoteItem(copy.serverSideOnlyNote),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleplayNote extends StatelessWidget {
  const _RoleplayNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: AppColors.royalPurple.withValues(alpha: 0.2),
        border: Border.all(color: AppColors.royalPurple.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.theater_comedy_outlined, color: AppColors.gold, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
class _PermissionsTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final copy = GroupCopy.of(context);
    final ranks = <PubgetRank>[
      PubgetRank.ronin,
      PubgetRank.gokenin,
      PubgetRank.samurai,
      PubgetRank.hatamoto,
      PubgetRank.daimyo,
      PubgetRank.shogun,
      PubgetRank.mikado,
    ];

    final permissions = GroupPermission.values;

    return _SectionCard(
      title: copy.permissionsMatrix,
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    copy.permissionColumn,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                for (final rank in ranks)
                  Expanded(
                    child: Center(
                      child: Text(
                        pubgetRankDisplayName(rank),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: RankColors.colorForKey(rank.name),
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Data rows
          for (final permission in permissions)
            _PermissionRow(label: copy.permissionLabel(permission), permission: permission, ranks: ranks),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.label,
    required this.permission,
    required this.ranks,
  });

  final String label;
  final GroupPermission permission;
  final List<PubgetRank> ranks;

  @override
  Widget build(BuildContext context) {
    final defaultRankPermissions = {
      PubgetRank.ronin: <GroupPermission>{},
      PubgetRank.gokenin: <GroupPermission>{GroupPermission.invite},
      PubgetRank.samurai: <GroupPermission>{
        GroupPermission.invite,
        GroupPermission.pinOwnMessages,
        GroupPermission.promoteContent,
      },
      PubgetRank.hatamoto: <GroupPermission>{
        GroupPermission.invite,
        GroupPermission.pinOwnMessages,
        GroupPermission.promoteContent,
        GroupPermission.manageRequests,
        GroupPermission.manageEvents,
        GroupPermission.moderateChat,
        GroupPermission.deleteMessages,
      },
      PubgetRank.daimyo: <GroupPermission>{
        GroupPermission.invite,
        GroupPermission.pinOwnMessages,
        GroupPermission.promoteContent,
        GroupPermission.manageRequests,
        GroupPermission.manageEvents,
        GroupPermission.moderateChat,
        GroupPermission.deleteMessages,
        GroupPermission.manageGames,
        GroupPermission.kickBan,
        GroupPermission.manageBackground,
      },
      PubgetRank.shogun: <GroupPermission>{
        GroupPermission.invite,
        GroupPermission.pinOwnMessages,
        GroupPermission.promoteContent,
        GroupPermission.manageRequests,
        GroupPermission.manageEvents,
        GroupPermission.moderateChat,
        GroupPermission.deleteMessages,
        GroupPermission.manageGames,
        GroupPermission.kickBan,
        GroupPermission.unban,
        GroupPermission.manageBackground,
        GroupPermission.manageSettings,
        GroupPermission.manageRoles,
      },
      PubgetRank.mikado: GroupPermission.values.toSet(),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
            ),
          ),
          for (final rank in ranks)
            Expanded(
              child: Center(
                child: Icon(
                  defaultRankPermissions[rank]!.contains(permission)
                      ? Icons.check_circle_rounded
                      : Icons.cancel_outlined,
                  color: defaultRankPermissions[rank]!.contains(permission)
                      ? RankColors.colorForKey(rank.name)
                      : Colors.white24,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.royalPurple.withValues(alpha: 0.35),
            const Color(0xFF160B24),
          ],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _NoteItem extends StatelessWidget {
  const _NoteItem(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('• ', style: TextStyle(color: AppColors.gold)),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}