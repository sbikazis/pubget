// lib/core/theme/mafia_role_colors.dart
//
// موازٍ لـ role_colors.dart لكن لأدوار لعبة المافيا (mafia/doctor/...)
// بدلاً من رتب المجموعة (Roles). يستخدم نفس لوحة AppColors تماماً
// حتى تبقى الهوية البصرية موحّدة مع بقية التطبيق.

import 'package:flutter/material.dart';
import '../constants/mafia_constants.dart';
import 'app_colors.dart';

class MafiaRoleVisual {
  final Color color;
  final Color badgeBg;
  final IconData icon;
  final String label;

  const MafiaRoleVisual({
    required this.color,
    required this.badgeBg,
    required this.icon,
    required this.label,
  });
}

class MafiaRoleColors {
  MafiaRoleColors._();

  static const _mafia = MafiaRoleVisual(
    color: AppColors.error,
    badgeBg: Color(0x26EF4444),
    icon: Icons.gavel_rounded,
    label: 'مافيا',
  );

  static const _doctor = MafiaRoleVisual(
    color: Color(0xFF10B981),
    badgeBg: Color(0x2610B981),
    icon: Icons.medical_services_rounded,
    label: 'طبيب',
  );

  static const _detective = MafiaRoleVisual(
    color: Color.fromARGB(255, 125, 7, 204),
    badgeBg: Color(0x267D07CC),
    icon: Icons.search_rounded,
    label: 'محقق',
  );

  static const _sniper = MafiaRoleVisual(
    color: AppColors.goldAccent,
    badgeBg: Color(0x26FFC857),
    icon: Icons.gps_fixed_rounded,
    label: 'قناص',
  );

  static const _silencer = MafiaRoleVisual(
    color: Color(0xFF3B82F6),
    badgeBg: Color(0x263B82F6),
    icon: Icons.volume_off_rounded,
    label: 'مُسكِت',
  );

  static const _goodBoy = MafiaRoleVisual(
    color: Color(0xFF06B6D4),
    badgeBg: Color(0x2606B6D4),
    icon: Icons.pets_rounded,
    label: 'الفتى الصالح',
  );

  static const _citizen = MafiaRoleVisual(
    color: AppColors.primaryLight,
    badgeBg: Color(0x267A57FF),
    icon: Icons.person_rounded,
    label: 'مواطن',
  );

  static MafiaRoleVisual of(String role) {
    switch (role) {
      case MafiaRoles.mafia:
        return _mafia;
      case MafiaRoles.doctor:
        return _doctor;
      case MafiaRoles.detective:
        return _detective;
      case MafiaRoles.sniper:
        return _sniper;
      case MafiaRoles.silencer:
        return _silencer;
      case MafiaRoles.goodBoy:
        return _goodBoy;
      case MafiaRoles.citizen:
      default:
        return _citizen;
    }
  }

  static Color teamColor(String team) {
    return team == MafiaTeams.mafias ? AppColors.error : const Color(0xFF10B981);
  }
}