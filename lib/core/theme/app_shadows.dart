import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppShadows {
  static const lightCard = <BoxShadow>[
    BoxShadow(
      color: AppColors.lightShadow,
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static const darkCard = <BoxShadow>[
    BoxShadow(
      color: AppColors.darkShadow,
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static List<BoxShadow> focus(Color color) => <BoxShadow>[
    BoxShadow(
      color: color.withValues(alpha: 0.22),
      blurRadius: 0,
      spreadRadius: 3,
    ),
  ];
}
