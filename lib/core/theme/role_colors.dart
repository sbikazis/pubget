import 'package:flutter/material.dart';
import '../constants/roles.dart';
import 'app_colors.dart';

class RoleColors {
  RoleColors._();


  //  FOUNDER – Royal Gold Authority


  static const Color founder = Color(0xFFFFC857);
  static const Color founderDark = Color(0xFFE0A800);

  // 15% opacity pre-defined (0x26 ≈ 15%)
  static const Color founderBadgeBg = Color(0x26FFC857);


  //  SENSEI – Deep Royal Purple


  static const Color sensei = Color(0xFF5B2EFF);
  static const Color senseiDark = Color(0xFF4A25CC);

  static const Color senseiBadgeBg = Color(0x265B2EFF);


  //  HAKUSHO – Controlled Violet


  static const Color hakusho = Color(0xFF6D4CFF);
  static const Color hakushoDark = Color(0xFF5936D6);

  static const Color hakushoBadgeBg = Color(0x266D4CFF);


  //  SENPAI – Soft Tech Purple


  static const Color senpai = Color(0xFF8C75FF);
  static const Color senpaiDark = Color(0xFF715BE0);

  static const Color senpaiBadgeBg = Color(0x268C75FF);


  //  MEMBER – Neutral Authority


  static const Color memberLight = Color(0xFF9CA3AF);
  static const Color memberDark = Color(0xFFB3B3C2);


  //  ROLE COLOR RESOLVER


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
  


  //  BADGE BACKGROUND


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