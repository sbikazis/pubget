// lib/features/store/widgets/coin_counter_with_add.dart

import 'package:flutter/material.dart';
import 'shiny_coin_widget.dart';

class CoinCounterWithAddWidget extends StatelessWidget {
  final int coinsBalance;
  final VoidCallback onAddTap; // ينقله لصفحة المهام وكسب العملات

  const CoinCounterWithAddWidget({
    Key? key,
    required this.coinsBalance,
    required this.onAddTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.only(right: 4, left: 10, top: 4, bottom: 4),
      decoration: BoxDecoration(
        // 🛠️ التعديل: خلفية ديناميكية شبه شفافة تتكيف مع طبيعة الوضع الحالي لضمان التباين الرائع
        color: isDarkMode 
            ? Colors.black.withOpacity(0.4) 
            : theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00FF87).withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // زر الزائد الصغير المخصص للذهاب لصفحة كسب العملات والمهام
          GestureDetector(
            onTap: onAddTap,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Color(0xFF00FF87),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                size: 12,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$coinsBalance',
            style: TextStyle(
              // 🛠️ التعديل: النص يقرأ الآن من لون المحتوى المتوفر على السطح ليتغير بين الأبيض والأسود تلقائياً
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          const ShinyCoinWidget(size: 16),
        ],
      ),
    );
  }
}