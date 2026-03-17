enum GameStatus {
  waiting,
  active,
  finished,
  cancelled;

  /// Display label for UI
  String get label {
    switch (this) {
      case GameStatus.waiting:
        return "في إنتظار الخصم";
      case GameStatus.active:
        return "اللعبة نشطة";
      case GameStatus.finished:
        return "منتهية";
      case GameStatus.cancelled:
        return "تم الإلغاء";
    }
  }

  /// Whether game is currently playable
  bool get isActive => this == GameStatus.active;

  /// Whether game is waiting for someone to join
  bool get canAcceptOpponent => this == GameStatus.waiting;

  /// Whether players can ask questions
  bool get canSendQuestions => this == GameStatus.active;

  /// Whether game reached final state
  bool get isTerminal =>
      this == GameStatus.finished || this == GameStatus.cancelled;

  /// Convert from Firestore string
  static GameStatus fromString(String value) {
    return GameStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GameStatus.waiting,
    );
  }
}