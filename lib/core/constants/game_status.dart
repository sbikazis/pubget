enum GameStatus {
  /// في انتظار انضمام خصم (بعد ضغط زر مقبض اللعب والتأكيد)
  waitingForOpponent,

  /// مرحلة الـ 60 ثانية: اللاعبان يقومان باختيار الشخصيات والتحقق منها
  setup,

  /// اللعبة بدأت فعلياً وكلاهما ضغط "بدأ" - دور السؤال
  guessing,

  /// انتهت اللعبة بفوز أحدهم أو التعادل (10 دقائق)
  finished,

  /// تم إلغاء اللعبة (انسحاب أحد الطرفين قبل البدء أو أثنائه)
  cancelled;

  /// ملصق العرض للواجهة (UI)
  String get label {
    switch (this) {
      case GameStatus.waitingForOpponent:
        return "في إنتظار تحدي جديد...";
      case GameStatus.setup:
        return "جاري تجهيز الشخصيات (60ث)";
      case GameStatus.guessing:
        return "اللعبة جارية الآن";
      case GameStatus.finished:
        return "الجولة انتهت";
      case GameStatus.cancelled:
        return "تم الانسحاب/الإلغاء";
    }
  }

  // --- منطق الحماية المنطقية ---

  /// هل اللعبة في مرحلة تسمح لخصم بالدخول؟
  /// تُستخدم لمنع "السبق في الانضمام" إذا اكتمل العدد أثناء القراءة
  bool get canAcceptOpponent => this == GameStatus.waitingForOpponent;

  /// هل اللعبة في مرحلة التجهيز؟ (عداد الـ 60 ثانية)
  bool get isInSetup => this == GameStatus.setup;

  /// هل اللعبة في مرحلة التخمين وتبادل الأدوار؟ (عداد الـ 40 ثانية)
  bool get isLive => this == GameStatus.guessing;

  /// هل اللعبة انتهت بأي شكل؟ (لإعادة الشريط السفلي لطبيعته)
  bool get isOver => this == GameStatus.finished || this == GameStatus.cancelled;

  /// تحويل من نص Firestore إلى Enum
  static GameStatus fromString(String value) {
    return GameStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GameStatus.waitingForOpponent,
    );
  }
}

/// إضافة منطق إضافي للتحقق من السعة (Slot Check)
/// هذا الجزء سيساعدنا في الـ Provider للتحقق من شرط "لا أكثر من لعبتين"
extension GameCapacityChecker on List<GameStatus> {
  /// يتحقق إذا كانت المجموعة قد وصلت للحد الأقصى (لعبتين نشطتين)
  bool get isGroupFull {
    // اللعبة تعتبر "تشغل مكاناً" إذا لم تكن منتهية أو ملغاة
    int activeGames = where((status) => !status.isOver).length;
    return activeGames >= 2; 
  }
}