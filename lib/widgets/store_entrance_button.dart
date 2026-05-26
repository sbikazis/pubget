// lib/features/store/widgets/store_entrance_button.dart

import 'package:flutter/material.dart';

class StoreEntranceButton extends StatelessWidget {
  final VoidCallback onTap;

  const StoreEntranceButton({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFB800FF).withOpacity(0.5),
            width: 1,
          ),
        ),
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFB800FF), Color(0xFF00FF87)],
          ).createShader(bounds),
          child: const Icon(
            Icons.storefront_rounded, // أيقونة متجر واضحة ومميزة
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}