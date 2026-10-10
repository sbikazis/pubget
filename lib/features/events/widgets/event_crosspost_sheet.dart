import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/failure.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../models/event_models.dart';
import '../repositories/event_repository.dart';

/// Spec 14.4 — "one event, no copies": offers to extend a live Event to more
/// joined groups or to global scope. The event itself is never duplicated.
///
/// Returns true when a cross-post was submitted successfully, false when the
/// creator declined or there was nothing new to share. Failure text is handed
/// to [onMessage] so the caller owns presentation.
Future<bool> offerEventCrosspost(
  BuildContext context,
  PubgetEvent event, {
  void Function(String message)? onMessage,
}) async {
  if (event.status != EventStatus.active) return false;
  final uid = context.read<AuthProvider>().currentUser?.id;
  final groupProvider = context.read<GroupProvider>();
  if (uid != null && groupProvider.joinedGroups.isEmpty) {
    await groupProvider.openJoined(uid);
    if (!context.mounted) return false;
  }
  final groups = groupProvider.joinedGroups;
  final hosting = <String>{
    if (event.groupId != null && event.groupId!.isNotEmpty) event.groupId!,
    ...event.groupIds,
  };
  final candidates = groups.where((g) => !hosting.contains(g.id)).toList();
  final canGlobal = event.scope != EventScope.global;
  if (candidates.isEmpty && !canGlobal) return false;

  final selected = <String>{};
  var toGlobal = false;
  final proceed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final copy = AppStrings.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  copy.eventCrosspostTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  copy.eventCrosspostHint,
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      if (canGlobal)
                        CheckboxListTile(
                          key: const Key('crosspost-global'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(copy.eventCrosspostToGlobal),
                          value: toGlobal,
                          onChanged: (value) =>
                              setSheetState(() => toGlobal = value ?? false),
                        ),
                      for (final group in candidates)
                        CheckboxListTile(
                          key: Key('crosspost-group-${group.id}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(group.name),
                          subtitle: Text(copy.membersCount(group.membersCount)),
                          value: selected.contains(group.id),
                          onChanged: (value) => setSheetState(() {
                            if (value == true) {
                              selected.add(group.id);
                            } else {
                              selected.remove(group.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                PubgetPrimaryButton(
                  key: const Key('crosspost-confirm'),
                  onPressed: toGlobal || selected.isNotEmpty
                      ? () => Navigator.pop(sheetContext, true)
                      : null,
                  semanticLabel: copy.eventShare,
                  child: Text(copy.eventShare),
                ),
                PubgetTextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  semanticLabel: copy.pick('Not now', 'ليس الآن'),
                  child: Text(copy.pick('Not now', 'ليس الآن')),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (proceed != true || !context.mounted) return false;

  final repository = context.read<EventRepository>();
  final result = await repository.crosspost(
    eventId: event.id,
    groupIds: selected.toList(growable: false),
    toGlobal: toGlobal,
  );
  if (!context.mounted) return result.isSuccess;
  final copy = AppStrings.of(context);
  if (result.isSuccess) {
    onMessage?.call(copy.eventCrosspostDone);
    return true;
  }
  final failure = result.failureOrNull;
  onMessage?.call(
    failure is ValidationError
        ? copy.eventValidationMessage(failure.message)
        : failure?.message ?? '',
  );
  return false;
}
