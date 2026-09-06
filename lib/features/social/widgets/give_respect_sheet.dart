import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../providers/social_provider.dart';

/// Same 0–7 Respect grant used on Profile. Calls [SocialProvider.giveRespect].
Future<void> showGiveRespectSheet(
  BuildContext context, {
  required String toUserId,
  int initialValue = 5,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => _GiveRespectSheet(
      toUserId: toUserId,
      initialValue: initialValue.clamp(0, 7),
    ),
  );
}

class _GiveRespectSheet extends StatefulWidget {
  const _GiveRespectSheet({
    required this.toUserId,
    required this.initialValue,
  });

  final String toUserId;
  final int initialValue;

  @override
  State<_GiveRespectSheet> createState() => _GiveRespectSheetState();
}

class _GiveRespectSheetState extends State<_GiveRespectSheet> {
  late int _value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialProvider>();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Give Respect', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const Text('This uses the same Respect total as a profile.'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: List<Widget>.generate(
              8,
              (value) => PubgetSelectionChip(
                label: '$value',
                selected: _value == value,
                onSelected: social.state == LoadingState.loading
                    ? null
                    : (_) => setState(() => _value = value),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetPrimaryButton(
            key: const Key('edit-give-respect'),
            onPressed: social.state == LoadingState.loading
                ? null
                : () async {
                    final result = await social.giveRespect(
                      toUserId: widget.toUserId,
                      value: _value,
                    );
                    if (!context.mounted) return;
                    if (result.isSuccess) {
                      Navigator.of(context).pop();
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result.failureOrNull?.message ??
                              'Respect could not be saved.',
                        ),
                      ),
                    );
                  },
            semanticLabel: 'Give selected Respect',
            loading: social.state == LoadingState.loading,
            child: const Text('Save Respect'),
          ),
        ],
      ),
    );
  }
}
