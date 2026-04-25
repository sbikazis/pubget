import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/roles.dart';

class MemberModel {
  final String userId;
  final String groupId;
  final Roles role;

  // Display inside group
  final String? displayName;
  final String? characterName;
  final String? characterImageUrl;
  final String? characterReason;

  // الهوية الحقيقية للمستخدم لربط الطلب بملفه الشخصي
  final String? realUserName; 
  final String? realUserImageUrl; 

  final String? invitedByUserId;
  final String? inviterDisplayName; 

  final DateTime joinedAt;

  // حقل تتبع آخر وقت لقرأة الرسائل
  final DateTime? lastReadAt;

  // ✅ حقل تحديد الرتبة اليدوية لمنع التغيير التلقائي
  final bool isManualRole;

  // ✅ إضافة حقل البريميوم لضمان ظهوره في طلبات الانضمام والدردشة
  final bool isPremium;

  const MemberModel({
    required this.userId,
    required this.groupId,
    required this.role,
    required this.joinedAt,
    this.displayName,
    this.characterName,
    this.characterImageUrl,
    this.characterReason,
    this.realUserName, 
    this.realUserImageUrl, 
    this.invitedByUserId,
    this.inviterDisplayName, 
    this.lastReadAt,
    this.isManualRole = false,
    this.isPremium = false,
  });

  // =========================================================
  // ✅ التعديل الذهبي: السماح بمرور أي رابط غير فارغ
  // =========================================================
  String? get displayImageUrl {
    final charImg = (characterImageUrl ?? '').trim();
    if (charImg.isNotEmpty) {
      return charImg;
    }

    final realImg = (realUserImageUrl ?? '').trim();
    if (realImg.isNotEmpty) {
      return realImg;
    }

    return null;
  }

  // يختار الاسم الصحيح: اسم الشخصية أولاً، ثم الحقيقي
  String get effectiveName {
    if (characterName != null && characterName!.trim().isNotEmpty) {
      return characterName!.trim();
    }
    if (realUserName != null && realUserName!.trim().isNotEmpty) {
      return realUserName!.trim();
    }
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    return 'عضو';
  }

  // -------------------------
  // Firestore → Model
  // -------------------------
  factory MemberModel.fromMap(Map<String, dynamic> map) {
    String? clean(dynamic value) {
      if (value == null) return null;
      final String s = value.toString().trim();
      return s.isEmpty ? null : s;
    }

    return MemberModel(
      userId: map['userId']?.toString() ?? '',
      groupId: map['groupId']?.toString() ?? '',
      role: Roles.fromString(map['role']?.toString() ?? 'member'),
      displayName: clean(map['displayName']),
      characterName: clean(map['characterName']),
      characterImageUrl: clean(map['characterImageUrl']),
      characterReason: clean(map['characterReason']),
      realUserName: clean(map['realUserName']), 
      realUserImageUrl: clean(map['realUserImageUrl']), 
      invitedByUserId: clean(map['invitedByUserId']),
      inviterDisplayName: clean(map['inviterDisplayName']), 
      joinedAt: map['joinedAt'] is Timestamp 
          ? (map['joinedAt'] as Timestamp).toDate() 
          : DateTime.now(),
      lastReadAt: map['lastReadAt'] != null && map['lastReadAt'] is Timestamp
          ? (map['lastReadAt'] as Timestamp).toDate() 
          : null,
      isManualRole: map['isManualRole'] ?? false, 
      isPremium: map['isPremium'] ?? false, 
    );
  }

  // -------------------------
  // Model → Firestore
  // -------------------------
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'groupId': groupId,
      'role': role.name,
      'displayName': displayName,
      'characterName': characterName,
      'characterImageUrl': characterImageUrl,
      'characterReason': characterReason,
      'realUserName': realUserName, 
      'realUserImageUrl': realUserImageUrl, 
      'invitedByUserId': invitedByUserId,
      'inviterDisplayName': inviterDisplayName, 
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastReadAt': lastReadAt != null ? Timestamp.fromDate(lastReadAt!) : null,
      'isManualRole': isManualRole, 
      'isPremium': isPremium, 
    };
  }

  // -------------------------
  // Copy With
  // -------------------------
  MemberModel copyWith({
    Roles? role,
    String? displayName,
    String? characterName,
    String? characterImageUrl,
    String? characterReason,
    String? realUserName, 
    String? realUserImageUrl, 
    String? invitedByUserId,
    String? inviterDisplayName, 
    DateTime? joinedAt,
    DateTime? lastReadAt,
    bool? isManualRole,
    bool? isPremium,
  }) {
    return MemberModel(
      userId: userId,
      groupId: groupId,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      characterName: characterName ?? this.characterName,
      characterImageUrl: characterImageUrl ?? this.characterImageUrl,
      characterReason: characterReason ?? this.characterReason,
      realUserName: realUserName ?? this.realUserName, 
      realUserImageUrl: realUserImageUrl ?? this.realUserImageUrl, 
      invitedByUserId: invitedByUserId ?? this.invitedByUserId,
      inviterDisplayName: inviterDisplayName ?? this.inviterDisplayName, 
      joinedAt: joinedAt ?? this.joinedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      isManualRole: isManualRole ?? this.isManualRole,
      isPremium: isPremium ?? this.isPremium,
    );
  }
}