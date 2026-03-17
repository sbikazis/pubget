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

  /// Maximum allowed count per group
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