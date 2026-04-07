// lib/features/profile/respect_modal.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/profile_provider.dart';
import '../../core/constants/limits.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_widget.dart';

// ✅ ملاحظة: تم حذف كلاس RespectModel من هنا لأنه موجود بالفعل في مسار Models لعدم التكرار

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
      // ✅ الاعتماد الكلي على ProfileProvider كما تم الاتفاق عليه
      final success = await profileProvider.giveRespect(
        fromUserId: widget.currentUserId,
        toUserId: widget.targetUser.id,
        value: _respectValue,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary, // لمسة أرجوانية ملكية
            content: Text(
              _respectValue > Limits.fanThreshold
                  ? 'تم حفظ التقييم. لقد أصبحت الآن من المعجبين بـ ${widget.targetUser.username}! 🌟'
                  : 'تم منح ${_respectValue} نقاط احترام بنجاح',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لقد قمت بتقييم هذا العضو مسبقاً')),
        );
        Navigator.of(context).pop();
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // استخدام ألوان الواجهة المحددة مع خلفية فخمة
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.2), // حدود ذهبية خفيفة جداً للفخامة
          width: 0.5,
        ),
      ),
      child: _isSaving
          ? const SizedBox(
              height: 250,
              child: LoadingWidget(message: 'جارٍ تسجيل الاحترام في السجل الملكي...'),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // مقبض السحب (Drag Handle)
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Header (User Info)
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD700), width: 2), // إطار ذهبي
                      ),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundImage: widget.targetUser.avatarUrl.isNotEmpty
                            ? NetworkImage(widget.targetUser.avatarUrl)
                            : null,
                        child: widget.targetUser.avatarUrl.isEmpty
                            ? Text(
                                widget.targetUser.username[0].toUpperCase(),
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.targetUser.nickname ?? widget.targetUser.username,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            "منح نقاط التقدير",
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // عرض القيمة الحالية بشكل بارز
                    Text(
                      '$_respectValue',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD700), // اللون الذهبي
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Respect Slider
                Text(
                  'اختر مستوى الاحترام',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.primary.withOpacity(0.2),
                    thumbColor: const Color(0xFFFFD700),
                    overlayColor: const Color(0xFFFFD700).withOpacity(0.1),
                    valueIndicatorColor: AppColors.primary,
                    valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                  ),
                  child: Slider(
                    value: _respectValue.toDouble(),
                    min: Limits.respectMin.toDouble(),
                    max: Limits.respectMax.toDouble(),
                    divisions: Limits.respectMax,
                    label: '$_respectValue',
                    onChanged: (val) {
                      setState(() => _respectValue = val.toInt());
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // التحذير المنطقي (المعجبين)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _respectValue > Limits.fanThreshold ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'سيتم إضافتك لقائمة المعجبين تلقائياً!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB8860B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Save Button (AppButton الموحد)
                AppButton(
                  text: 'تأكيد التقييم الملكي',
                  onPressed: _saveRespect,
                ),
                const SizedBox(height: 10),
              ],
            ),
    );
  }
}