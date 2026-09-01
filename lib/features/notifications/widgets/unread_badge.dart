import 'package:flutter/material.dart';

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({required this.count, required this.child, super.key});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Badge(label: Text(count > 99 ? '99+' : '$count'), child: child);
  }
}
