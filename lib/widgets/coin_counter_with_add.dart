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
    return Container(
      padding: const EdgeInsets.only(right: 4, left: 10, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00FF87).withOpacity(0.3),
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
            style: const TextStyle(
              color: Colors.white,
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