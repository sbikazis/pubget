// lib/features/stickers/sticker_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sticker_model.dart';
import '../../providers/sticker_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import 'sticker_creator_sheet.dart';

class StickerPickerSheet extends StatefulWidget {
  final void Function(StickerModel sticker) onStickerSelected;

  const StickerPickerSheet({super.key, required this.onStickerSelected});

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId =
          context.read<UserProvider>().currentUser?.id;
      if (userId != null) {
        context.read<StickerProvider>().loadStickers(userId);
      }
    });
  }

  void _openCreator() {
    Navigator.pop(context); // أغلق الـ picker أولاً
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StickerCreatorSheet(
        onStickerCreated: (sticker) {
          widget.onStickerSelected(sticker);
        },
      ),
    );
  }

  void _onStickerTap(StickerModel sticker) {
    Navigator.pop(context);
    widget.onStickerSelected(sticker);
  }

  void _onStickerLongPress(StickerModel sticker) {
    final userId =
        context.read<UserProvider>().currentUser?.id;
    if (userId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الملصق'),
        content: const Text('هل تريد حذف هذا الملصق نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<StickerProvider>().deleteSticker(
                    userId: userId,
                    stickerId: sticker.id,
                  );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<StickerProvider>();

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ─── Handle ───────────────────────────────────────────
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),

          // ─── Header ───────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Text(
                  'ملصقاتي',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // زر إنشاء ملصق جديد — مثل واتساب
                GestureDetector(
                  onTap: _openCreator,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text(
                          'إنشاء',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ─── Grid ─────────────────────────────────────────────
          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : provider.stickers.isEmpty
                    ? _buildEmptyState(isDark)
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: provider.stickers.length,
                        itemBuilder: (context, index) {
                          final sticker = provider.stickers[index];
                          return GestureDetector(
                            onTap: () => _onStickerTap(sticker),
                            onLongPress: () =>
                                _onStickerLongPress(sticker),
                            child: AnimatedScale(
                              scale: 1.0,
                              duration: const Duration(milliseconds: 100),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white12
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        sticker.imageUrl,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child,
                                            loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Container(
                                            color: isDark
                                                ? const Color(0xFF2A2A3E)
                                                : Colors.grey.shade100,
                                            child: const Center(
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      // إطار ذهبي رفيع
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(11),
                                          border: Border.all(
                                            color: AppColors.goldAccent
                                                .withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_emotions_outlined,
            size: 56,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد ملصقات بعد',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط "إنشاء" لإضافة أول ملصق',
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openCreator,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إنشاء ملصق'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}