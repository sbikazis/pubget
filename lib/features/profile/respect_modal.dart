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
  // ✅ جديد: القيمة السابقة لو سبق ومنح currentUserId نقاط احترام لـ targetUser.
  // null تعني "أول مرة" — أي قيمة أخرى تعني "تعديل" وتفتح الـ Modal مقفولة
  // ومحددة على هذه القيمة.
  final int? previousValue;

  const RespectModal({
    Key? key,
    required this.targetUser,
    required this.currentUserId,
    this.previousValue,
  }) : super(key: key);

  @override
  State<RespectModal> createState() => _RespectModalState();
}

class _RespectModalState extends State<RespectModal> {
  late int _respectValue;
  bool _isSaving = false;
  // ✅ جديد: true يعني السلايدر مقفول (وضع العرض فقط) — يبدأ مقفولاً
  // فقط لو كان هناك تقييم سابق؛ في حالة "أول مرة" يكون مفتوحاً من البداية.
  late bool _isLocked;

  @override
  void initState() {
    super.initState();
    _respectValue = widget.previousValue ?? Limits.respectMin;
    _isLocked = widget.previousValue != null;
  }

  // ✅ جديد: الضغط على "تعديل" يفتح السلايدر فقط، بدون أي حفظ أو اتصال بالسيرفر
  void _unlockForEditing() {
    setState(() => _isLocked = false);
  }

  Future<void> _saveRespect() async {
    setState(() => _isSaving = true);

    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

    try {
      // ✅✅✅ تعديل جوهري: giveRespect يرجع الآن RateUserResult بدل bool.
      // لا يوجد سيناريو "فشل بسبب تقييم مسبق" بعد الآن — الاستبدال دائماً
      // ينجح، فالـ catch أصبح مخصصاً فقط للأخطاء الحقيقية (مثل تقييم النفس).
      final result = await profileProvider.giveRespect(
        fromUserId: widget.currentUserId,
        toUserId: widget.targetUser.id,
        value: _respectValue,
      );

      if (!mounted) return;

      final String message;
      if (result.becameFan) {
        message =
            'تم حفظ التقييم. لقد أصبحت الآن من المعجبين بـ ${widget.targetUser.username}! 🌟';
      } else if (result.isFirstTime) {
        message = 'تم منح $_respectValue نقاط احترام بنجاح';
      } else {
        message = 'تم تعديل تقييمك إلى $_respectValue نقاط احترام';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary, // لمسة أرجوانية ملكية
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
      Navigator.of(context).pop();
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
          color: const Color(0xFFFFD700).withValues(alpha: 0.2), // حدود ذهبية خفيفة جداً للفخامة
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
                    color: Colors.grey.withValues(alpha: 0.3),
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
                            // ✅ نص توضيحي يختلف حسب الحالة (أول مرة / تعديل)
                            _isLocked ? "تقييمك السابق لهذا العضو" : "منح نقاط التقدير",
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
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        // ✅ اللون يصبح رمادياً في وضع القفل لتأكيد أنها قيمة
                        // "معروضة" لا "قابلة للتعديل الفوري"
                        color: _isLocked
                            ? (isDark ? Colors.white38 : Colors.black26)
                            : const Color(0xFFFFD700),
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
                    // ✅ ألوان رمادية في وضع القفل لتوضيح أن السلايدر معطّل
                    activeTrackColor:
                        _isLocked ? Colors.grey.withValues(alpha: 0.4) : AppColors.primary,
                    inactiveTrackColor: _isLocked
                        ? Colors.grey.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.2),
                    thumbColor:
                        _isLocked ? Colors.grey.withValues(alpha: 0.6) : const Color(0xFFFFD700),
                    overlayColor: const Color(0xFFFFD700).withValues(alpha: 0.1),
                    valueIndicatorColor: AppColors.primary,
                    valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                  ),
                  child: Slider(
                    value: _respectValue.toDouble(),
                    min: Limits.respectMin.toDouble(),
                    max: Limits.respectMax.toDouble(),
                    divisions: Limits.respectMax,
                    label: '$_respectValue',
                    // ✅✅✅ تعديل جوهري: onChanged يصبح null (يعطّل السلايدر
                    // فعلياً ويُظهره باللون الرمادي) في وضع القفل، ويعمل
                    // بشكل طبيعي فقط بعد الضغط على "تعديل"
                    onChanged: _isLocked
                        ? null
                        : (val) {
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
                      color: Colors.amber.withValues(alpha: 0.1),
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
                // ✅✅✅ تعديل جوهري: في وضع القفل، الزر يفتح السلايدر فقط
                // (بدون أي اتصال بالسيرفر)؛ خارج وضع القفل، الزر يحفظ فعلياً
                AppButton(
                  text: _isLocked ? 'تعديل' : 'تأكيد التقييم الملكي',
                  onPressed: _isLocked ? _unlockForEditing : _saveRespect,
                ),
                const SizedBox(height: 10),
              ],
            ),
    );
  }
}