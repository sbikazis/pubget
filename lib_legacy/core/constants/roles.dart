enum Roles {
  founder,
  sensei,
  hakusho,
  senpai,
  member;

  /// Display label inside UI
  String get label {
    switch (this) {
      case Roles.founder:
        return "Shogun";
      case Roles.sensei:
        return "Sensei";
      case Roles.hakusho:
        return "Hakusho";
      case Roles.senpai:
        return "Senpai";
      case Roles.member:
        return "Member";
    }
  }

  /// Hierarchy level (higher = more power)
  int get rankLevel {
    switch (this) {
      case Roles.founder:
        return 5;
      case Roles.sensei:
        return 4;
      case Roles.hakusho:
        return 3;
      case Roles.senpai:
        return 2;
      case Roles.member:
        return 1;
    }
  }

  /// Maximum allowed count per group (إجمالي المقاعد يدوي + تلقائي)
  int? get maxCount {
    switch (this) {
      case Roles.founder:
        return 1;
      case Roles.sensei:
        return 2;
      case Roles.hakusho:
        return 3;
      case Roles.senpai:
        return 4;
      case Roles.member:
        return null; // unlimited
    }
  }

  /// ✅ [إضافة] الحد الأقصى الذي يملك الشوغو تعيينه يدوياً
  /// sensei: 1 يدوي (المقعد الثاني للدعوات)
  /// hakusho: 2 يدوي (المقعد الثالث للدعوات)
  /// senpai: 2 يدوي (المقعدان الثالث والرابع للدعوات)
  int? get manualMaxCount {
    switch (this) {
      case Roles.founder:
        return 0; // لا يمكن تعيين شوغو يدوياً
      case Roles.sensei:
        return 1; // الشوغو يعين 1 فقط يدوياً
      case Roles.hakusho:
        return 2; // الشوغو يعين 2 فقط يدوياً
      case Roles.senpai:
        return 2; // الشوغو يعين 2 فقط يدوياً
      case Roles.member:
        return null; // unlimited
    }
  }

  /// ✅ [إضافة] المقاعد المتاحة للدعوات التلقائية
  /// = maxCount - manualMaxCount
  int? get autoMaxCount {
    final total = maxCount;
    final manual = manualMaxCount;
    if (total == null || manual == null) return null;
    return total - manual;
  }

  /// Whether role has limited slots
  bool get isLimited => maxCount != null;

  /// Compare hierarchy
  bool isHigherThan(Roles other) {
    return rankLevel > other.rankLevel;
  }

  /// Convert from Firestore string
  static Roles fromString(String value) {
    return Roles.values.firstWhere(
      (e) => e.name == value,
      orElse: () => Roles.member,
    );
  }
}