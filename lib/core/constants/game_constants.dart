class GameConstants {
  // --- قيود إعداد اللعبة ---
  
  /// الحد الأقصى للألعاب النشطة في نفس المجموعة
  static const int maxConcurrentGames = 2;

  /// الوقت المتاح للاعب للانضمام بعد رؤية الإعلان (بالثواني)
  /// هذا يساعد في تنظيف الطلبات القديمة التي لم يستجب لها أحد
  static const int joinTimeout = 300; // 5 دقائق

  // --- عدادات الوقت (Timers) ---

  /// الوقت المتاح لكل لاعب لاختيار شخصيته وتأكيدها (بالثواني)
  /// إذا انتهى الوقت ولم يضغط "بدء"، يخسر تلقائياً
  static const int characterSelectionDuration = 60;

  /// الوقت المتاح لكل دور (سؤال أو جواب) (بالثواني)
  static const int turnDuration = 40;

  /// العمر الإجمالي الأقصى للعبة الواحدة (بالدقائق)
  /// إذا انتهت، تنتهي اللعبة بالتعادل
  static const int maxGameDurationMinutes = 10;

  // --- تسميات الغرف (Slots) ---
  
  /// معرف اللعبة الأولى
  static const String slot1 = 'game_1';
  
  /// معرف اللعبة الثانية
  static const String slot2 = 'game_2';

  // --- قوانين الإدخال ---
  
  /// الكلمات المقبولة في دور الجواب (نظام صارم لمنع الانهيار)
  static const List<String> validAnswers = ['نعم', 'لا'];
  
  /// تنبيه المستخدم بخصوص مصدر الأسماء
  static const String malWarning = 'يرجى كتابة اسم الشخصية تماماً كما في MyAnimeList (MAL)';
}