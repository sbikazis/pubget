enum GroupType {
  public,
  roleplay;

  /// Display label inside UI
  String get label {
    switch (this) {
      case GroupType.public:
        return "Public Group";
      case GroupType.roleplay:
        return "Roleplay Group";
    }
  }

  /// Short description used in create/join screens
  String get description {
    switch (this) {
      case GroupType.public:
        return "مجموعة نقاط مفتوحة حول الأنمي مع شروط دخول بسيطة .";
      case GroupType.roleplay:
        return "مجموعة لعب أدوار قائمة على شخصيات من عالم الأنمي .";
    }
  }

  /// Whether joining requires selecting a character
  bool get requiresCharacter {
    switch (this) {
      case GroupType.public:
        return false;
      case GroupType.roleplay:
        return true;
    }
  }

  /// Whether Anime API validation is required
  bool get requiresAnimeValidation {
    switch (this) {
      case GroupType.public:
        return false;
      case GroupType.roleplay:
        return true;
    }
  }

  /// Quick helper
  bool get isRoleplay => this == GroupType.roleplay;

  /// Convert from Firestore string
  static GroupType fromString(String value) {
    return GroupType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GroupType.public,
    );
  }
}