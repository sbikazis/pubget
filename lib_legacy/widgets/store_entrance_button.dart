// lib/features/store/widgets/store_entrance_button.dart

import 'package:flutter/material.dart';

class StoreEntranceButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool enabled;

  const StoreEntranceButton({super.key, this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
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
      ),
    );
  }
}