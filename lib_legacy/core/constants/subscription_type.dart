enum SubscriptionType {
  free,
  premium;

  /// Display name used in UI
  String get label {
    switch (this) {
      case SubscriptionType.free:
        return "Free";
      case SubscriptionType.premium:
        return "Premium";
    }
  }

  /// Whether user should see ads
  bool get hasAds {
    switch (this) {
      case SubscriptionType.free:
        return true;
      case SubscriptionType.premium:
        return false;
    }
  }

  /// Whether user has extended limits
  bool get hasExtendedLimits {
    switch (this) {
      case SubscriptionType.free:
        return false;
      case SubscriptionType.premium:
        return true;
    }
  }

  /// Quick helper
  bool get isPremium => this == SubscriptionType.premium;

  /// Convert from Firestore string
  static SubscriptionType fromString(String value) {
    return SubscriptionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SubscriptionType.free,
    );
  }
}