// lib/core/constants/group_type.dart

enum GroupType {
  public,
  roleplay,
  openRoleplay; // ✅ الإضافة الجديدة: تقمص أدوار مفتوح

  /// Display label inside UI
  String get label {
    switch (this) {
      case GroupType.public:
        return "Public Group";
      case GroupType.roleplay:
        return "Roleplay Group";
      case GroupType.openRoleplay:
        return "Open Roleplay"; // ✅ التسمية للنوع الجديد
    }
  }

  /// Short description used in create/join screens
  String get description {
    switch (this) {
      case GroupType.public:
        return "مجموعة نقاط مفتوحة حول الأنمي مع شروط دخول بسيطة .";
      case GroupType.roleplay:
        return "مجموعة لعب أدوار قائمة على شخصيات من عالم أنمي محدد .";
      case GroupType.openRoleplay:
        return "مجموعة لعب أدوار حرة، يمكنك اختيار أي شخصية من أي أنمي ."; // ✅ وصف النوع الجديد
    }
  }

  /// Whether joining requires selecting a character
  bool get requiresCharacter {
    switch (this) {
      case GroupType.public:
        return false;
      case GroupType.roleplay:
      case GroupType.openRoleplay:
        return true; // ✅ كلاهما يتطلب شخصية
    }
  }

  /// Whether Anime API validation is required (Against a specific Anime ID)
  bool get requiresAnimeValidation {
    switch (this) {
      case GroupType.public:
      case GroupType.openRoleplay:
        return false; // ✅ المفتوح لا يحتاج للتحقق من أنمي محدد (فقط وجود الشخصية عالمياً)
      case GroupType.roleplay:
        return true; // ✅ النوع القديم يبقى يتطلب التحقق من الأنمي والسلسلة
    }
  }

  /// Quick helper
  bool get isRoleplay => this == GroupType.roleplay || this == GroupType.openRoleplay;

  /// Convert from Firestore string
  static GroupType fromString(String value) {
    return GroupType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GroupType.public,
    );
  }
}