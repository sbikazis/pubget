// lib/models/mafia/mafia_player_private_model.dart
//
// ✅ جديد: البيانات الخاصة بكل لاعب — لا يقرأها أحد سوى صاحبها،
// عبر Firestore Rule صريحة (request.auth.uid == playerId).
// المسار: mafia_games/{gameId}/players/{playerId}/private/data
//
// role/team تُكتب عند الانضمام كـ 'citizen'/'citizens' افتراضياً من
// العميل (بما يطابق القيد الأمني القديم)، ثم تُحدَّث لاحقاً من
// roleAssigner.js فقط (على السيرفر) عند التوزيع الفعلي.

import 'package:cloud_firestore/cloud_firestore.dart';

class MafiaPlayerPrivateModel {
  final String role;
  final String team;
  final String? voteTarget;
  final String? nightTarget;
  final bool usedAbility;
  final bool usedBullet;

  /// نتيجة آخر فحص للمحقق: {targetId, targetTeam, nightNumber}.
  /// يُكتب من nightResolver.js فقط، ويُقرأ من صاحب المستند (المحقق نفسه).
  final Map<String, dynamic>? lastInvestigationResult;

  const MafiaPlayerPrivateModel({
    this.role = '',
    this.team = '',
    this.voteTarget,
    this.nightTarget,
    this.usedAbility = false,
    this.usedBullet = false,
    this.lastInvestigationResult,
  });

  factory MafiaPlayerPrivateModel.fromMap(Map<String, dynamic> map) {
    return MafiaPlayerPrivateModel(
      role: map['role'] ?? '',
      team: map['team'] ?? '',
      voteTarget: map['voteTarget'],
      nightTarget: map['nightTarget'],
      usedAbility: map['usedAbility'] ?? false,
      usedBullet: map['usedBullet'] ?? false,
      lastInvestigationResult: map['lastInvestigationResult'] != null
          ? Map<String, dynamic>.from(map['lastInvestigationResult'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'team': team,
      'voteTarget': voteTarget,
      'nightTarget': nightTarget,
      'usedAbility': usedAbility,
      'usedBullet': usedBullet,
      'lastInvestigationResult': lastInvestigationResult,
    };
  }
}