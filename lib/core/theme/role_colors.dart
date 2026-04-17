// lib/core/theme/role_colors.dart
import 'package:flutter/material.dart';
import '../constants/roles.dart';
import 'app_colors.dart';

class RoleColors {
  RoleColors._();


  // FOUNDER – Royal Gold Authority


  static const Color founder = Color(0xFFFFC857);
  static const Color founderDark = Color(0xFFE0A800);

  // 15% opacity pre-defined (0x26 ≈ 15%)
  static const Color founderBadgeBg = Color(0x26FFC857);


  // SENSEI – Deep Royal Purple


  static const Color sensei = Color.fromARGB(255, 125, 7, 204);
  static const Color senseiDark = Color.fromARGB(255, 101, 4, 165);

  static const Color senseiBadgeBg = Color(0x265B2EFF);


  // HAKUSHO – War Red (Updated)


  static const Color hakusho = Color(0xFFEF4444);
  static const Color hakushoDark = Color(0xFFDC2626);

  static const Color hakushoBadgeBg = Color(0x26EF4444);


  // SENPAI – Nature Green (Updated)


  static const Color senpai = Color(0xFF10B981);
  static const Color senpaiDark = Color(0xFF059669);

  static const Color senpaiBadgeBg = Color(0x2610B981);


  // MEMBER – Neutral Authority


  static const Color memberLight = Color(0xFF9CA3AF);
  static const Color memberDark = Color(0xFFB3B3C2);


  // ROLE COLOR RESOLVER


  static Color getColor(Roles role, {required bool isDark}) {
    switch (role) {
      case Roles.founder:
        return founder;

      case Roles.sensei:
        return sensei;

      case Roles.hakusho:
        return hakusho;

      case Roles.senpai:
        return senpai;

      case Roles.member:
        return isDark ? memberDark : memberLight;
    }
  }
  


  // BADGE BACKGROUND


  static Color getBadgeBackground(Roles role, {required bool isDark}) {
    switch (role) {
      case Roles.founder:
        return founderBadgeBg;

      case Roles.sensei:
        return senseiBadgeBg;

      case Roles.hakusho:
        return hakushoBadgeBg;

      case Roles.senpai:
        return senpaiBadgeBg;

      case Roles.member:
        return isDark
            ? AppColors.darkCard
            : AppColors.lightCard;
    }
  }
}