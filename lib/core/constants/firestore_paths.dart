// lib/core/constants/firestore_paths.dart

class FirestorePaths {

  // ROOT COLLECTIONS
  static const String users = 'users';
  static const String groups = 'groups';
  static const String privateChats = 'privateChats';
  static const String respects = 'respects';
  static const String fans = 'fans';
  static const String promotions = 'promotions';
  static const String edits = 'edits';

  // GROUP SUBCOLLECTIONS
  static String groupMembers(String groupId) =>
      '$groups/$groupId/members';

  // مسار طلبات الانضمام للمجموعة (يراه الشوغو)
  static String groupJoinRequests(String groupId) =>
      '$groups/$groupId/requests';

  // مسار طلب محدد لمستخدم معين داخل مجموعة (للتحقق السريع)
  static String groupJoinRequestDoc(String groupId, String userId) =>
      '$groups/$groupId/requests/$userId';

  static String groupInvites(String groupId) =>
      '$groups/$groupId/invites';

  static String groupMessages(String groupId) =>
      '$groups/$groupId/messages';

  static String groupMessagesDoc(String groupId, String messageId) =>
      '$groups/$groupId/messages/$messageId';

  // مسار الألعاب داخل المجموعة
  static String groupGames(String groupId) =>
      '$groups/$groupId/games';

  // مسار الألعاب المخصصة لخاصية المافيا
  static String mafiaGames() => 'mafia_games';

  static String mafiaGameDoc(String gameId) =>
      '${mafiaGames()}/$gameId';

  static String mafiaGamePlayers(String gameId) =>
      '${mafiaGameDoc(gameId)}/players';

  static String mafiaGamePlayerDoc(String gameId, String playerId) =>
      '${mafiaGamePlayers(gameId)}/$playerId';

  static String mafiaGameNightActions(String gameId) =>
      '${mafiaGameDoc(gameId)}/night_actions';

  static String mafiaGameVotes(String gameId) =>
      '${mafiaGameDoc(gameId)}/votes';

  static String mafiaGameEvents(String gameId) =>
      '${mafiaGameDoc(gameId)}/events';

  static String mafiaGameChat(String gameId) =>
      '${mafiaGameDoc(gameId)}/chat';

  static String mafiaHistory() => 'mafia_history';

  static String userMafiaHistory(String userId) =>
      '$users/$userId/user_mafia_history';

  // مسار للوصول إلى مستند لعبة محددة (للتحقق السريع أو التحديث)
  static String groupGameDoc(String groupId, String gameId) =>
      '$groups/$groupId/games/$gameId';

  // مسار حجز الشخصيات (يستخدم للحجز وللتنظيف عند الخروج أو التفكيك)
  static String groupCharacters(String groupId) =>
      '$groups/$groupId/characters';

  static String groupCharacterDoc(String groupId, String charId) =>
      '$groups/$groupId/characters/$charId';


  // USER SUBCOLLECTIONS
  
  // مسار الإشعارات لإرسال التنبيهات (مثل القبول، الرفض، أو تفكيك المجموعة)
  static String userNotifications(String userId) =>
      '$users/$userId/notifications';

  static String userNotificationDoc(String userId, String notifId) =>
      '$users/$userId/notifications/$notifId';
  
  static String userStickers(String userId) =>
      '$users/$userId/stickers';

  static String userStickerDoc(String userId, String stickerId) =>
      '$users/$userId/stickers/$stickerId';


  // PRIVATE CHAT SUBCOLLECTIONS
  static String privateMessages(String chatId) =>
      '$privateChats/$chatId/messages';


  // DOCUMENT PATH HELPERS
  static String userDoc(String userId) =>
      '$users/$userId';

  static String groupDoc(String groupId) =>
      '$groups/$groupId';

  static String privateChatDoc(String chatId) =>
      '$privateChats/$chatId';

  static String respectDoc(String respectId) =>
      '$respects/$respectId';

  static String fanDoc(String fanId) =>
      '$fans/$fanId';

  static String promotionDoc(String promotionId) =>
      '$promotions/$promotionId';
}