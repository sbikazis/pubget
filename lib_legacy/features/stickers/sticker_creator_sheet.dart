// lib/features/stickers/sticker_creator_sheet.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/sticker_model.dart';
import '../../providers/sticker_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/theme/app_colors.dart';

class StickerCreatorSheet extends StatefulWidget {
  final void Function(StickerModel sticker) onStickerCreated;

  const StickerCreatorSheet({super.key, required this.onStickerCreated});

  @override
  State<StickerCreatorSheet> createState() => _StickerCreatorSheetState();
}

class _StickerCreatorSheetState extends State<StickerCreatorSheet> {
  File? _croppedFile;
  bool _isUploading = false;

  // ─── اختيار وقص الصورة ──────────────────────────────────────
  Future<void> _pickAndCrop() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'قص الملصق',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.goldAccent,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'قص الملصق',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (cropped == null) return;
    setState(() => _croppedFile = File(cropped.path));
  }

  // ─── رفع الملصق ─────────────────────────────────────────────
  Future<void> _uploadSticker() async {
    if (_croppedFile == null) return;

    final userId =
        context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;

    setState(() => _isUploading = true);

    final sticker = await context.read<StickerProvider>().uploadSticker(
          userId: userId,
          imageFile: _croppedFile!,
        );

    if (!mounted) return;
    setState(() => _isUploading = false);

    if (sticker != null) {
      widget.onStickerCreated(sticker);
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل رفع الملصق، حاول مجدداً')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Handle ─────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Title ──────────────────────────────────────────
          const Text(
            'إنشاء ملصق جديد',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // ─── Preview ────────────────────────────────────────
          GestureDetector(
            onTap: _isUploading ? null : _pickAndCrop,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2A3E)
                    : const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _croppedFile != null
                      ? AppColors.goldAccent
                      : Colors.grey.shade400,
                  width: _croppedFile != null ? 2.5 : 1.5,
                ),
              ),
              child: _croppedFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_croppedFile!, fit: BoxFit.cover),
                          // ─── إطار ذهبي رفيع ──────────────
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.goldAccent.withOpacity(0.7),
                                width: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'اختر صورة',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12),

          // ─── hint ───────────────────────────────────────────
          Text(
            _croppedFile != null
                ? 'اضغط على الصورة لتغييرها'
                : 'ستُقص الصورة بشكل مربع تلقائياً',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),

          const SizedBox(height: 28),

          // ─── Buttons ────────────────────────────────────────
          Row(
            children: [
              // إلغاء
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _isUploading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  child: const Text('إلغاء'),
                ),
              ),
              const SizedBox(width: 12),
              // إرسال
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed:
                      (_croppedFile == null || _isUploading)
                          ? null
                          : _uploadSticker,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'إنشاء وإرسال',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}