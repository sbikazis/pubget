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

  // ✅ التعديل المطلوب: حقل تحديد الرتبة اليدوية لمنع التغيير التلقائي
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
    this.isManualRole = false, // القيمة الافتراضية false
    this.isPremium = false, // القيمة الافتراضية false
  });

  // =========================================================
  // ✅ التعديل الذهبي المحسن: الـ Getters الذكية (الجوكر)
  // تم التحسين لمعالجة الـ null والـ empty string "" معاً
  // =========================================================

  // يختار الصورة الصحيحة: التقمص أولاً، ثم الحقيقية
  String? get displayImageUrl {
    if (characterImageUrl != null && characterImageUrl!.trim().isNotEmpty) {
      return characterImageUrl;
    }
    if (realUserImageUrl != null && realUserImageUrl!.trim().isNotEmpty) {
      return realUserImageUrl;
    }
    return null;
  }

  // يختار الاسم الصحيح: اسم الشخصية أولاً، ثم الحقيقي
  String get effectiveName {
    if (characterName != null && characterName!.trim().isNotEmpty) {
      return characterName!;
    }
    if (realUserName != null && realUserName!.trim().isNotEmpty) {
      return realUserName!;
    }
    // العودة للاسم المستعار أو كلمة "عضو" كحل أخير
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!;
    }
    return 'عضو';
  }

  // -------------------------
  // Firestore → Model
  // -------------------------

  factory MemberModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return MemberModel(
      userId: map['userId'] as String,
      groupId: map['groupId'] as String,
      role: Roles.fromString(map['role'] as String),
      displayName: map['displayName'] as String?,
      characterName: map['characterName'] as String?,
      characterImageUrl: map['characterImageUrl'] as String?,
      characterReason: map['characterReason'] as String?,
      realUserName: map['realUserName'] as String?, 
      realUserImageUrl: map['realUserImageUrl'] as String?, 
      invitedByUserId: map['invitedByUserId'] as String?,
      inviterDisplayName: map['inviterDisplayName'] as String?, 
      joinedAt: map['joinedAt'] is Timestamp 
          ? (map['joinedAt'] as Timestamp).toDate() 
          : DateTime.now(),
      lastReadAt: map['lastReadAt'] != null 
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
      characterImageUrl:
          characterImageUrl ?? this.characterImageUrl,
      characterReason:
          characterReason ?? this.characterReason,
      realUserName: realUserName ?? this.realUserName, 
      realUserImageUrl: realUserImageUrl ?? this.realUserImageUrl, 
      invitedByUserId:
          invitedByUserId ?? this.invitedByUserId,
      inviterDisplayName:
          inviterDisplayName ?? this.inviterDisplayName, 
      joinedAt: joinedAt ?? this.joinedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      isManualRole: isManualRole ?? this.isManualRole,
      isPremium: isPremium ?? this.isPremium,
    );
  }
}