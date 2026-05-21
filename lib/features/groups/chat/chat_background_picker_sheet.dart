// lib/features/groups/chat/chat_background_picker_sheet.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/chat_background_provider.dart';

class ChatBackgroundPickerSheet extends StatefulWidget {
  final String chatId;

  /// true → دردشة مجموعة (الخلفية تُرفع على Firebase)
  /// false → دردشة خاصة (الخلفية تُحفظ محلياً)
  final bool isGroup;

  const ChatBackgroundPickerSheet({
    super.key,
    required this.chatId,
    required this.isGroup,
  });

  @override
  State<ChatBackgroundPickerSheet> createState() =>
      _ChatBackgroundPickerSheetState();
}

class _ChatBackgroundPickerSheetState
    extends State<ChatBackgroundPickerSheet> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  // ══════════════════════════════════════════════
  // ── اختيار صورة من الهاتف
  // ══════════════════════════════════════════════

  Future<void> _pickAndApply() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null) return;
    if (!mounted) return;

    setState(() => _isUploading = true);

    try {
      final provider = context.read<ChatBackgroundProvider>();

      if (widget.isGroup) {
        // ✅ دردشة مجموعة → رفع على Firebase
        await provider.uploadGroupBackground(
          groupId: widget.chatId,
          file: File(picked.path),
        );
      } else {
        // ✅ دردشة خاصة → حفظ محلياً فقط
        await provider.setPrivateBackground(
          chatId: widget.chatId,
          filePath: picked.path,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        _showSuccess('تم تعيين الخلفية بنجاح');
      }
    } catch (e) {
      if (mounted) {
        _showError('حدث خطأ أثناء تعيين الخلفية');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ══════════════════════════════════════════════
  // ── حذف الخلفية الحالية
  // ══════════════════════════════════════════════

  Future<void> _removeBackground() async {
    setState(() => _isUploading = true);

    try {
      final provider = context.read<ChatBackgroundProvider>();

      if (widget.isGroup) {
        await provider.deleteGroupBackground(groupId: widget.chatId);
      } else {
        await provider.deletePrivateBackground(chatId: widget.chatId);
      }

      if (mounted) {
        Navigator.pop(context);
        _showSuccess('تمت إزالة الخلفية');
      }
    } catch (e) {
      if (mounted) {
        _showError('حدث خطأ أثناء إزالة الخلفية');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // ── UI
  // ══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatBackgroundProvider>();

    final bool hasCurrentBackground = widget.isGroup
        ? provider.groupBackground.hasBackground
        : provider.privateBackground.hasBackground;

    final String? currentPath = widget.isGroup
        ? provider.groupBackground.path
        : provider.privateBackground.path;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.darkBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ── العنوان
          Row(
            children: [
              const Icon(Icons.wallpaper, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'خلفية الدردشة',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (widget.isGroup) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'تظهر للجميع',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // ── معاينة الخلفية الحالية
          if (hasCurrentBackground && currentPath != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // صورة الخلفية الحالية
                  SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: currentPath.startsWith('http')
                        ? Image.network(
                            currentPath,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.darkCard,
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Image.file(
                            File(currentPath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.darkCard,
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                  ),
                  // Overlay
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(
                        widget.isGroup
                            ? provider.groupBackground.overlayOpacity
                            : provider.privateBackground.overlayOpacity,
                      ),
                    ),
                  ),
                  // نص "الخلفية الحالية"
                  const Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'الخلفية الحالية',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── خيار: تغيير الخلفية
          _buildOption(
            icon: Icons.add_photo_alternate_outlined,
            label: hasCurrentBackground ? 'تغيير الخلفية' : 'اختيار خلفية',
            subtitle: 'اختر صورة من معرض هاتفك',
            color: AppColors.primary,
            onTap: _isUploading ? null : _pickAndApply,
          ),
          const SizedBox(height: 12),

          // ── خيار: إزالة الخلفية (يظهر فقط إذا كانت هناك خلفية)
          if (hasCurrentBackground) ...[
            _buildOption(
              icon: Icons.delete_outline,
              label: 'إزالة الخلفية',
              subtitle: 'العودة للمظهر الافتراضي',
              color: Colors.red,
              onTap: _isUploading ? null : _removeBackground,
            ),
            const SizedBox(height: 12),
          ],

          // ── مؤشر التحميل
          if (_isUploading) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.isGroup ? 'جاري الرفع...' : 'جاري الحفظ...',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],

          // ── ملاحظة للدردشة الخاصة
          if (!widget.isGroup) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.15),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الخلفية تظهر لك فقط ولا يراها الطرف الآخر',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // ── Widget مساعد لبناء خيار
  // ══════════════════════════════════════════════

  Widget _buildOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: color.withOpacity(0.5),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}