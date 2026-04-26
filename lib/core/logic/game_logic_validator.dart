import '../constants/game_constants.dart';
import '../../models/game_model.dart';
import '../../core/constants/game_status.dart';

class GameLogicValidator {
  
  /// 1. التحقق من توفر مكان للعبة (Slot Availability)
  /// يمنع إنشاء لعبة ثالثة في المجموعة
  static bool canCreateNewGame(List<GameModel> activeGames) {
    return activeGames.length < GameConstants.maxConcurrentGames;
  }

  /// 2. حماية "السبق في الانضمام"
  /// يتأكد أن اللعبة لا تزال تنتظر خصماً ولم يخطفها أحد أثناء قراءة المستخدم للقواعد
  static bool isSlotStillAvailable(GameModel game) {
    return game.status == GameStatus.waitingForOpponent && game.playerTwoId == null;
  }

  /// 3. التحقق من صحة الإجابة (نعم/لا فقط) - ✅ تم التعديل لتوسيع القبول
  /// نظام صارم لمنع اللاعب من كتابة أي نص خارج القوانين في دور الجواب
  static bool isValidGameAnswer(String input) {
    if (input.isEmpty) return false;
    
    final cleanInput = input.trim().toLowerCase();
    
    // قائمة موسعة لضمان تجربة مستخدم مرنة مع الحفاظ على جوهر اللعبة
    final allowed = [
      'نعم', 'لا', 
      'yes', 'no', 
      'يب', 'لاا', 
      'اجل', 'كلا'
    ]; 
    
    return allowed.contains(cleanInput) || GameConstants.validAnswers.contains(input.trim());
  }

  /// 4. التحقق من تطابق التخمين (Win Condition)
  /// يقارن بين تخمين اللاعب والشخصية التي اختارها الخصم فعلياً
  static bool isGuessCorrect(String guessedName, String actualName) {
    if (guessedName.isEmpty || actualName.isEmpty) return false;
    
    // تنظيف النصوص للمقارنة العادلة (حذف المسافات وتحويل لحروف صغيرة)
    final cleanGuess = guessedName.trim().toLowerCase();
    final cleanActual = actualName.trim().toLowerCase();
    
    return cleanGuess == cleanActual;
  }

  /// 5. التحقق من صلاحية الحركة (Turn Validation)
  /// يتأكد أن الشخص الذي يحاول الإرسال هو فعلاً من عليه الدور
  static bool isUserTurn(String userId, String? currentTurnUserId) {
    return userId == currentTurnUserId;
  }

  /// 6. التحقق من ملكية اللعبة
  /// يمنع أي شخص غريب في المجموعة من التدخل في أزرار اللعبة (انسحاب/إرسال)
  static bool isPlayerInGame(String userId, GameModel game) {
    return userId == game.playerOneId || userId == game.playerTwoId;
  }
}