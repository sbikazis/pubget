import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/limits.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/social_models.dart';
import '../providers/social_provider.dart';

/// Same 0–7 Respect grant used on Profile. Optimistic — closes immediately.
/// [silentFailure] suppresses error snackbars (Edits feed edge-case).
Future<bool> showGiveRespectSheet(
  BuildContext context, {
  required String toUserId,
  int initialValue = 5,
  bool silentFailure = false,
}) async {
  final result = await PubgetBottomSheet.present<bool>(
    context: context,
    backgroundColor: const Color(0xFF1A1228),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _GiveRespectSheet(
      toUserId: toUserId,
      initialValue: initialValue.clamp(0, 7),
      silentFailure: silentFailure,
    ),
  );
  return result == true;
}

class _GiveRespectSheet extends StatefulWidget {
  const _GiveRespectSheet({
    required this.toUserId,
    required this.initialValue,
    required this.silentFailure,
  });

  final String toUserId;
  final int initialValue;
  final bool silentFailure;

  @override
  State<_GiveRespectSheet> createState() => _GiveRespectSheetState();
}

class _GiveRespectSheetState extends State<_GiveRespectSheet> {
  late int _value = widget.initialValue;
  var _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'منح الاحترام',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'اختر مقدار الاحترام (0–${Limits.respectMax}). عند ${Limits.fanThreshold}+ تصبح من معجبيه.',
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: List<Widget>.generate(8, (value) {
              final selected = _value == value;
              final fanMark = value >= SocialSnapshot.fanThreshold;
              return ChoiceChip(
                label: Text(
                  '$value',
                  style: TextStyle(
                    color: selected ? AppColors.royalNight : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                selected: selected,
                selectedColor: fanMark
                    ? AppColors.gold
                    : AppColors.royalPurpleLight,
                backgroundColor: Colors.white12,
                side: BorderSide(
                  color: fanMark
                      ? AppColors.gold.withValues(alpha: 0.55)
                      : Colors.white24,
                ),
                onSelected: _submitting
                    ? null
                    : (_) => setState(() => _value = value),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          PubgetPrimaryButton(
            key: const Key('edit-give-respect'),
            onPressed: _submitting
                ? null
                : () {
                    final social = context.read<SocialProvider>();
                    final prior = social.snapshot.givenRespect
                        .where((item) => item.toUserId == widget.toUserId)
                        .map((item) => item.value)
                        .fold<int>(0, (max, item) => item > max ? item : max);
                    final becameFan =
                        prior < SocialSnapshot.fanThreshold &&
                        _value >= SocialSnapshot.fanThreshold;
                    setState(() => _submitting = true);
                    // Close immediately (optimistic); server sync continues.
                    Navigator.of(context).pop(becameFan);
                    unawaited(
                      social.giveRespect(
                        toUserId: widget.toUserId,
                        value: _value,
                        silentFailure: widget.silentFailure,
                      ),
                    );
                  },
            semanticLabel: 'Give selected Respect',
            loading: _submitting,
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }
}
