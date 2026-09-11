import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/group_authority.dart';
import '../models/group_models.dart';
import '../providers/group_members_provider.dart';
import '../providers/group_provider.dart';

String _formatCouncilDate(DateTime? value) {
  if (value == null) return '';
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y/$m/$d';
}

/// Permission-aware member actions for the Council page.
Future<void> showMemberActionSheet(
  BuildContext context, {
  required GroupMember target,
  required GroupMember? actor,
  required String groupId,
  required String? founderId,
}) {
  final host = context;
  final canRank = GroupAuthority.canManageTargetRank(
    actor: actor,
    target: target,
  );
  final canWarn = GroupAuthority.canWarnTarget(actor: actor, target: target);
  final canKick = GroupAuthority.canKickOrBanTarget(
    actor: actor,
    target: target,
  );
  final canTransfer = GroupAuthority.canTransferOwnership(
        actor: actor,
        founderId: founderId,
      ) &&
      target.role != PubgetRank.mikado &&
      actor?.uid != target.uid;

  void afterClose(VoidCallback action) {
    Navigator.pop(host);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!host.mounted) return;
      action();
    });
  }

  final tiles = <Widget>[
    if (canRank)
      ListTile(
        key: const Key('member-action-role'),
        leading: const Icon(Icons.military_tech_outlined),
        title: const Text('تعديل الرتبة'),
        onTap: () => afterClose(() {
          showRankManagementSheet(
            host,
            target: target,
            actor: actor!,
            groupId: groupId,
          );
        }),
      ),
    ListTile(
      key: const Key('member-action-info'),
      leading: const Icon(Icons.info_outline),
      title: const Text('معلومات العضو'),
      onTap: () => afterClose(() {
        showMemberInfoSheet(host, target: target, groupId: groupId);
      }),
    ),
    ListTile(
      key: const Key('member-action-profile'),
      leading: const Icon(Icons.person_outline),
      title: const Text('الملف الشخصي'),
      onTap: () => afterClose(() {
        AppNavigation.go(host, '/profile?uid=${target.uid}');
      }),
    ),
    if (canWarn)
      ListTile(
        key: const Key('member-action-warn'),
        leading: const Icon(Icons.warning_amber_outlined),
        title: const Text('تحذير'),
        onTap: () => afterClose(() {
          showWarnMemberSheet(host, target: target);
        }),
      ),
    if (canKick)
      ListTile(
        key: const Key('member-action-kick'),
        leading: Icon(Icons.person_remove_outlined, color: AppColors.error),
        title: Text(
          'طرد',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
        ),
        onTap: () => afterClose(() {
          showKickBanSheet(host, target: target);
        }),
      ),
    if (canTransfer)
      ListTile(
        key: const Key('member-action-transfer'),
        leading: Icon(Icons.swap_horiz, color: AppColors.warningDark),
        title: Text(
          'نقل الملكية',
          style: TextStyle(
            color: AppColors.warningDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        onTap: () => afterClose(() async {
          final provider = host.read<GroupMembersProvider>();
          final first = await PubgetConfirmationDialog.show(
            host,
            title: 'نقل الملكية؟',
            message: 'سيتم نقل رتبة MIKADO إلى هذا العضو. يلزم تأكيد ثانٍ.',
            confirmLabel: 'متابعة',
            cancelLabel: 'إلغاء',
          );
          if (first != true || !host.mounted) return;
          final second = await PubgetConfirmationDialog.show(
            host,
            title: 'تأكيد نهائي',
            message: 'لن تبقى مالك المجموعة بعد هذا الإجراء.',
            confirmLabel: 'نقل',
            cancelLabel: 'إلغاء',
          );
          if (second == true) await provider.transferOwnership(target.uid);
        }),
      ),
  ];

  return PubgetBottomSheet.show<void>(
    host,
    title: target.primaryIdentity,
    isScrollControlled: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: tiles,
    ),
  );
}

Future<void> showRankManagementSheet(
  BuildContext context, {
  required GroupMember target,
  required GroupMember actor,
  required String groupId,
}) {
  return PubgetBottomSheet.present<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RankManagementSheet(
      target: target,
      actor: actor,
      groupId: groupId,
    ),
  );
}

class _RankManagementSheet extends StatefulWidget {
  const _RankManagementSheet({
    required this.target,
    required this.actor,
    required this.groupId,
  });

  final GroupMember target;
  final GroupMember actor;
  final String groupId;

  @override
  State<_RankManagementSheet> createState() => _RankManagementSheetState();
}

class _RankManagementSheetState extends State<_RankManagementSheet> {
  late bool _promote;

  @override
  void initState() {
    super.initState();
    final role = widget.target.role;
    if (role == PubgetRank.ronin) {
      _promote = true;
    } else if (role == PubgetRank.shogun) {
      _promote = false;
    } else {
      _promote = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupMembersProvider>();
    final occupancy = provider.rankOccupancy;
    final target = widget.target;
    final actor = widget.actor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = rankColorResolver(target.role, isDarkMode: isDark);
    final badge = pubgetRankBadgeAsset(target.role);
    final canPromote =
        target.role != PubgetRank.mikado &&
        target.role != PubgetRank.shogun &&
        GroupAuthority.authorizedDestinations(
          actor: actor,
          target: target,
          promote: true,
        ).isNotEmpty;
    final canDemote =
        target.role != PubgetRank.mikado &&
        target.role != PubgetRank.ronin &&
        GroupAuthority.authorizedDestinations(
          actor: actor,
          target: target,
          promote: false,
        ).isNotEmpty;
    final noControls = target.role == PubgetRank.mikado ||
        (!canPromote && !canDemote);

    final destinations = noControls
        ? const <PubgetRank>[]
        : GroupAuthority.authorizedDestinations(
            actor: actor,
            target: target,
            promote: _promote,
          );

    // Visible ladder (never MIKADO as destination).
    final visibleLadder = PubgetRank.values
        .where((r) => r != PubgetRank.mikado)
        .toList(growable: false);

    final height = MediaQuery.sizeOf(context).height * 0.82;
    return SizedBox(
      height: height,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'إدارة الرتبة',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const Key('sheet-close'),
                    tooltip: AppStrings.of(context).close,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              PubgetCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    PubgetAvatar(
                      name: target.primaryIdentity,
                      imageUrl: target.avatarUrl,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            target.primaryIdentity,
                            style: pubgetRankNameTextStyle(
                              target.role,
                              fontSize: 15,
                            ),
                          ),
                          if (target.secondaryIdentity != null)
                            Text(
                              target.secondaryIdentity!,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              if (badge != null)
                                Image.asset(
                                  badge,
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.military_tech,
                                    size: 16,
                                    color: color,
                                  ),
                                ),
                              if (badge != null) const SizedBox(width: 6),
                              Text(
                                groupRoleLabel(target.role),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: occupancy.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final seat = occupancy[index];
                    return _OccupancyChip(seat: seat);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (noControls)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    'لا يمكن تعديل رتبة هذا العضو من هنا.',
                    textAlign: TextAlign.center,
                  ),
                )
              else ...[
                Row(
                  children: <Widget>[
                    if (canPromote)
                      Expanded(
                        child: PubgetSecondaryButton(
                          key: const Key('rank-mode-promote'),
                          onPressed: () => setState(() => _promote = true),
                          semanticLabel: 'ترقية',
                          child: Text(
                            'ترقية',
                            style: TextStyle(
                              fontWeight:
                                  _promote ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    if (canPromote && canDemote)
                      const SizedBox(width: AppSpacing.sm),
                    if (canDemote)
                      Expanded(
                        child: PubgetSecondaryButton(
                          key: const Key('rank-mode-demote'),
                          onPressed: () => setState(() => _promote = false),
                          semanticLabel: 'تخفيض',
                          child: Text(
                            'تخفيض',
                            style: TextStyle(
                              fontWeight:
                                  !_promote ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: ListView(
                    children: <Widget>[
                      for (var index = 0;
                          index < visibleLadder.length;
                          index++) ...[
                        if (index > 0)
                          const SizedBox(height: AppSpacing.sm),
                        Builder(
                          builder: (context) {
                            final rank = visibleLadder[index];
                            if (rank == target.role) {
                              return _DestinationTile(
                                rank: rank,
                                enabled: false,
                                subtitle: 'الرتبة الحالية',
                                onTap: null,
                              );
                            }
                            final authorized = destinations.contains(rank);
                            final seat = occupancy.firstWhere(
                              (o) => o.rank == rank,
                              orElse: () => RankOccupancy(
                                rank: rank,
                                count: 0,
                                capacity: rankSeatConfig[rank]?.total,
                              ),
                            );
                            final full = seat.isFull;
                            final enabled = authorized && !full;
                            final subtitle = !authorized
                                ? pubgetRankSubtitle(rank, arabic: true)
                                : full
                                    ? 'ممتلئة'
                                    : '${seat.countLabel()} — ${seat.capacityLabel(arabic: true)}';
                            return _DestinationTile(
                              key: Key('pick-role-${rank.name}'),
                              rank: rank,
                              enabled: enabled,
                              muted: !enabled,
                              subtitle: subtitle,
                              onTap: enabled
                                  ? () =>
                                      _confirmAndAssign(context, rank, seat)
                                  : null,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndAssign(
    BuildContext context,
    PubgetRank desired,
    RankOccupancy seat,
  ) async {
    final confirmed = await showRankChangeConfirmationSheet(
      context,
      target: widget.target,
      desired: desired,
      seat: seat,
      promote: _promote,
    );
    if (confirmed != true || !context.mounted) return;
    final provider = context.read<GroupMembersProvider>();
    final result = await provider.changeRole(widget.target.uid, desired);
    if (!context.mounted) return;
    if (result.isSuccess) {
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _promote
                ? 'تمت ترقية العضو إلى ${groupRoleLabel(desired)}'
                : 'تم تخفيض الرتبة إلى ${groupRoleLabel(desired)}',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failureOrNull?.message ?? 'تعذّر تغيير الرتبة',
          ),
        ),
      );
    }
  }
}

class _OccupancyChip extends StatelessWidget {
  const _OccupancyChip({required this.seat});

  final RankOccupancy seat;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = rankColorResolver(seat.rank, isDarkMode: isDark);
    final badge = pubgetRankBadgeAsset(seat.rank);
    return Container(
      width: 108,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: color.withValues(alpha: seat.isFull ? 0.55 : 0.28),
        ),
        color: color.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (badge != null)
                Image.asset(
                  badge,
                  width: 14,
                  height: 14,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.military_tech, size: 12, color: color),
                ),
              if (badge != null) const SizedBox(width: 4),
              Expanded(
                child: Text(
                  groupRoleLabel(seat.rank),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            seat.countLabel(),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          Text(
            seat.capacityLabel(arabic: true),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.rank,
    required this.enabled,
    required this.subtitle,
    required this.onTap,
    this.muted = false,
    super.key,
  });

  final PubgetRank rank;
  final bool enabled;
  final bool muted;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = rankColorResolver(rank, isDarkMode: isDark);
    final badge = pubgetRankBadgeAsset(rank);
    final opacity = muted ? 0.45 : 1.0;
    return Opacity(
      opacity: opacity,
      child: PubgetCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            if (badge != null)
              Image.asset(
                badge,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.military_tech, color: color),
              )
            else
              Icon(Icons.military_tech, color: color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    groupRoleLabel(rank),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(subtitle),
                ],
              ),
            ),
            if (enabled)
              Icon(Icons.chevron_left, color: color)
            else if (subtitle == 'ممتلئة')
              Text(
                'ممتلئة',
                style: TextStyle(
                  color: AppColors.warningDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> showRankChangeConfirmationSheet(
  BuildContext context, {
  required GroupMember target,
  required PubgetRank desired,
  required RankOccupancy seat,
  required bool promote,
}) {
  final seatNote = seat.isUnlimited
      ? 'المقاعد غير محدودة لهذه الرتبة.'
      : seat.isFull
          ? 'هذه الرتبة ممتلئة حالياً.'
          : 'المقاعد: ${seat.countLabel()} — ${seat.capacityLabel(arabic: true)}';
  final permissionsNote = promote
      ? 'سيحصل العضو على صلاحيات ${groupRoleLabel(desired)}.'
      : 'ستُقيَّد صلاحيات العضو وفق رتبة ${groupRoleLabel(desired)}.';

  return PubgetBottomSheet.show<bool>(
    context,
    title: promote ? 'تأكيد الترقية' : 'تأكيد التخفيض',
    isScrollControlled: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '${groupRoleLabel(target.role)}  ←  ${groupRoleLabel(desired)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(seatNote),
        const SizedBox(height: AppSpacing.sm),
        Text(permissionsNote),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: PubgetTextButton(
                onPressed: () => Navigator.pop(context, false),
                semanticLabel: 'إلغاء',
                child: const Text('إلغاء'),
              ),
            ),
            Expanded(
              child: PubgetPrimaryButton(
                key: const Key('confirm-rank-change'),
                onPressed: () => Navigator.pop(context, true),
                semanticLabel: 'تأكيد',
                child: const Text('تأكيد'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> showMemberInfoSheet(
  BuildContext context, {
  required GroupMember target,
  required String groupId,
}) async {
  final provider = context.read<GroupMembersProvider>();
  await provider.loadMemberHistory(groupId: groupId, targetUid: target.uid);
  if (!context.mounted) return;

  return PubgetBottomSheet.present<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MemberInfoSheet(target: target),
  );
}

class _MemberInfoSheet extends StatelessWidget {
  const _MemberInfoSheet({required this.target});

  final GroupMember target;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupMembersProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = rankColorResolver(target.role, isDarkMode: isDark);
    final height = MediaQuery.sizeOf(context).height * 0.78;

    return SizedBox(
      height: height,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'معلومات العضو',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const Key('sheet-close'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              PubgetCard(
                child: Row(
                  children: <Widget>[
                    PubgetAvatar(
                      name: target.primaryIdentity,
                      imageUrl: target.avatarUrl,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            target.primaryIdentity,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (target.secondaryIdentity != null)
                            Text(target.secondaryIdentity!),
                          Text(
                            groupRoleLabel(target.role),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (target.joinedAt != null)
                _InfoRow(
                  label: 'تاريخ الانضمام',
                  value: _formatCouncilDate(target.joinedAt),
                ),
              if (target.rankChangedAt != null)
                _InfoRow(
                  label: 'آخر تغيير رتبة',
                  value: _formatCouncilDate(target.rankChangedAt),
                ),
              _InfoRow(
                label: 'التحذيرات',
                value: '${target.warningsCount}',
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'سجل الرتب',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    if (provider.audit.isEmpty)
                      const Text('لا يوجد سجل رتب متاح.')
                    else
                      ...provider.audit.map(
                        (event) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${event.from == null ? '—' : groupRoleLabel(event.from!)}'
                            ' → '
                            '${event.to == null ? '—' : groupRoleLabel(event.to!)}',
                          ),
                          subtitle: Text(
                            [
                              if (event.at != null)
                                _formatCouncilDate(event.at),
                              if (event.byUid.isNotEmpty) 'بواسطة ${event.byUid}',
                              if (event.reason != null &&
                                  event.reason!.trim().isNotEmpty)
                                event.reason!,
                            ].join(' · '),
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'التحذيرات',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (provider.warnings.isEmpty)
                      const Text('لا توجد تحذيرات مسجّلة.')
                    else
                      ...provider.warnings.map(
                        (w) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(w.type),
                          subtitle: Text(
                            [
                              if (w.createdAt != null)
                                _formatCouncilDate(w.createdAt),
                              if (w.details.trim().isNotEmpty) w.details,
                            ].join(' · '),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.65),
              ),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

Future<void> showWarnMemberSheet(
  BuildContext context, {
  required GroupMember target,
}) {
  return PubgetBottomSheet.present<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _WarnMemberSheet(target: target),
  );
}

class _WarnMemberSheet extends StatefulWidget {
  const _WarnMemberSheet({required this.target});

  final GroupMember target;

  @override
  State<_WarnMemberSheet> createState() => _WarnMemberSheetState();
}

class _WarnMemberSheetState extends State<_WarnMemberSheet> {
  MemberWarningType _type = MemberWarningType.groupRules;
  final _details = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = memberWarningTypeLabel(_type, arabic: true);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'تحذير ${widget.target.primaryIdentity}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const Key('sheet-close'),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: MemberWarningType.values
                  .map(
                    (type) => PubgetSelectionChip(
                      label: memberWarningTypeLabel(type, arabic: true),
                      selected: _type == type,
                      onSelected: (_) => setState(() => _type = type),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.md),
            PubgetTextField(
              controller: _details,
              label: 'التفاصيل',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            PubgetCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'معاينة',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('$preview — ${_details.text.trim()}'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PubgetPrimaryButton(
              key: const Key('submit-warning'),
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
              semanticLabel: 'إرسال التحذير',
              child: const Text('إرسال التحذير'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final provider = context.read<GroupMembersProvider>();
    final result = await provider.warnMember(
      uid: widget.target.uid,
      type: _type,
      details: _details.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result.isSuccess) {
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال التحذير')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.failureOrNull?.message ?? 'تعذّر إرسال التحذير',
          ),
        ),
      );
    }
  }
}

Future<void> showKickBanSheet(
  BuildContext context, {
  required GroupMember target,
}) {
  return PubgetBottomSheet.show<void>(
    context,
    title: 'طرد أو حظر',
    isScrollControlled: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'اختر إجراءً لـ ${target.primaryIdentity}. الطرد يزيل العضو؛ الحظر يمنعه من العودة.',
        ),
        const SizedBox(height: AppSpacing.lg),
        PubgetSecondaryButton(
          key: const Key('confirm-kick'),
          onPressed: () async {
            final provider = context.read<GroupMembersProvider>();
            final ok = await PubgetConfirmationDialog.show(
              context,
              title: 'طرد العضو؟',
              message:
                  'سيُزال ${target.primaryIdentity} من المجموعة ويمكنه الانضمام لاحقاً وفق سياسة الدخول.',
              confirmLabel: 'طرد',
              cancelLabel: 'إلغاء',
            );
            if (ok != true || !context.mounted) return;
            Navigator.pop(context);
            await provider.kick(target.uid);
          },
          semanticLabel: 'طرد',
          child: const Text('طرد من المجموعة'),
        ),
        const SizedBox(height: AppSpacing.sm),
        PubgetPrimaryButton(
          key: const Key('confirm-ban'),
          onPressed: () async {
            final provider = context.read<GroupMembersProvider>();
            final ok = await PubgetConfirmationDialog.show(
              context,
              title: 'حظر العضو؟',
              message:
                  'سيُحظر ${target.primaryIdentity} ولن يتمكن من الانضمام مجدداً حتى يُرفع الحظر.',
              confirmLabel: 'حظر',
              cancelLabel: 'إلغاء',
            );
            if (ok != true || !context.mounted) return;
            Navigator.pop(context);
            await provider.ban(target.uid);
          },
          semanticLabel: 'حظر',
          child: const Text('حظر العضو'),
        ),
      ],
    ),
  );
}

Future<void> showInviteMembersSheet(
  BuildContext context, {
  required String groupId,
}) {
  return PubgetBottomSheet.present<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _InviteMembersSheet(groupId: groupId),
  );
}

class _InviteMembersSheet extends StatefulWidget {
  const _InviteMembersSheet({required this.groupId});

  final String groupId;

  @override
  State<_InviteMembersSheet> createState() => _InviteMembersSheetState();
}

class _InviteMembersSheetState extends State<_InviteMembersSheet> {
  final _search = TextEditingController();
  final _selected = <String>{};
  List<GroupMember> _candidates = const <GroupMember>[];
  var _searching = false;
  var _sending = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupMembersProvider>();
    final memberIds = provider.members.map((m) => m.uid).toSet();
    final url = PubgetLinks.group(widget.groupId);
    final height = MediaQuery.sizeOf(context).height * 0.86;
    final strings = AppStrings.of(context);

    return SizedBox(
      height: height,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'دعوة أعضاء',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    key: const Key('sheet-close'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              PubgetSearchField(
                controller: _search,
                hint: 'ابحث باسم المستخدم أو المعرف',
                onChanged: (_) {},
                onSubmitted: (_) => _runSearch(provider),
                onClear: () {
                  _search.clear();
                  setState(() => _candidates = const <GroupMember>[]);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              PubgetSecondaryButton(
                onPressed: _searching ? null : () => _runSearch(provider),
                semanticLabel: 'بحث',
                loading: _searching,
                child: const Text('بحث'),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _candidates.isEmpty
                    ? const Center(
                        child: Text('ابحث عن مستخدمي Pubget لدعوتهم.'),
                      )
                    : ListView.separated(
                        itemCount: _candidates.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final candidate = _candidates[index];
                          final already = memberIds.contains(candidate.uid);
                          final selected = _selected.contains(candidate.uid);
                          return PubgetCard(
                            onTap: already
                                ? null
                                : () => setState(() {
                                      if (selected) {
                                        _selected.remove(candidate.uid);
                                      } else {
                                        _selected.add(candidate.uid);
                                      }
                                    }),
                            child: Row(
                              children: <Widget>[
                                PubgetAvatar(
                                  name: candidate.primaryIdentity,
                                  imageUrl: candidate.avatarUrl,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        candidate.primaryIdentity,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (candidate.secondaryIdentity != null)
                                        Text(candidate.secondaryIdentity!),
                                      if (already)
                                        const Text(
                                          'عضو بالفعل',
                                          style: TextStyle(
                                            color: AppColors.successDark,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (!already)
                                  Checkbox(
                                    value: selected,
                                    onChanged: (value) => setState(() {
                                      if (value == true) {
                                        _selected.add(candidate.uid);
                                      } else {
                                        _selected.remove(candidate.uid);
                                      }
                                    }),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (_selected.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                PubgetPrimaryButton(
                  key: const Key('send-invites'),
                  loading: _sending,
                  onPressed: _sending
                      ? null
                      : () => _sendInvites(provider, memberIds),
                  semanticLabel: 'إرسال الدعوات',
                  child: Text('إرسال ${_selected.length} دعوة'),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'دعوة خارجية',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              SelectableText(url),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: PubgetSecondaryButton(
                      onPressed: () => PubgetLinks.copy(
                        context,
                        url,
                        type: 'group',
                        message: strings.copyLink,
                      ),
                      semanticLabel: 'نسخ الرابط',
                      child: const Text('نسخ الرابط'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: PubgetSecondaryButton(
                      onPressed: () {
                        final name =
                            context.read<GroupProvider>().group?.name ??
                            'Pubget';
                        PubgetLinks.share(
                          context,
                          url: url,
                          title: name,
                          type: 'group',
                        );
                      },
                      semanticLabel: 'مشاركة الرابط',
                      child: const Text('مشاركة'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runSearch(GroupMembersProvider provider) async {
    final query = _search.text.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    final result = await provider.lookupInviteCandidates(query);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _candidates = result.valueOrNull ?? const <GroupMember>[];
    });
  }

  Future<void> _sendInvites(
    GroupMembersProvider provider,
    Set<String> memberIds,
  ) async {
    setState(() => _sending = true);
    var sent = 0;
    for (final uid in _selected.toList(growable: false)) {
      if (memberIds.contains(uid)) continue;
      final result = await provider.createInvite(uid);
      if (result.isSuccess) sent++;
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _selected.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم إرسال $sent دعوة')),
    );
  }
}
