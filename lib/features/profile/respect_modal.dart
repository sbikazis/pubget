// lib/features/profile/respect_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/profile_provider.dart';
import '../../core/constants/limits.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_widget.dart';

class RespectModal extends StatefulWidget {
  final UserModel targetUser;
  final String currentUserId;

  const RespectModal({
    Key? key,
    required this.targetUser,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<RespectModal> createState() => _RespectModalState();
}

class _RespectModalState extends State<RespectModal> {
  int _respectValue = Limits.respectMin;
  bool _isSaving = false;

  Future<void> _saveRespect() async {
    setState(() => _isSaving = true);

    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

    try {
      final success = await profileProvider.giveRespect(
        fromUserId: widget.currentUserId,
        toUserId: widget.targetUser.id,
        value: _respectValue,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _respectValue > Limits.fanThreshold
                  ? 'تم حفظ التقييم. هذا المستخدم أصبح من معجبيك!'
                  : 'تم حفظ التقييم بنجاح',
            ),
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لقد قمت بتقييم هذا المستخدم من قبل')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حفظ التقييم: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: _isSaving
          ? const LoadingWidget(message: 'جارٍ حفظ التقييم...')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: widget.targetUser.avatarUrl.isNotEmpty
                          ? NetworkImage(widget.targetUser.avatarUrl)
                          : null,
                      child: widget.targetUser.avatarUrl.isEmpty
                          ? Text(widget.targetUser.username[0].toUpperCase())
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.targetUser.nickname ?? widget.targetUser.username,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Respect Slider
                Text(
                  'اختر نقاط الاحترام (0–${Limits.respectMax})',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                Slider(
                  value: _respectValue.toDouble(),
                  min: Limits.respectMin.toDouble(),
                  max: Limits.respectMax.toDouble(),
                  divisions: Limits.respectMax,
                  activeColor: AppColors.respectBarFill,
                  inactiveColor: AppColors.respectBarBackground,
                  label: '$_respectValue',
                  onChanged: (val) {
                    setState(() => _respectValue = val.toInt());
                  },
                ),

                const SizedBox(height: 12),

                if (_respectValue > Limits.fanThreshold)
                  Text(
                    'عند هذا التقييم، سيصبح المستخدم من معجبيك!',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                const SizedBox(height: 20),

                // Save Button
                AppButton(
                  text: 'حفظ التقييم',
                  onPressed: _saveRespect,
                ),
              ],
            ),
    );
  }
}