// lib/core/constants/firestore_paths.dart
//
// ✅ الإضافة الوحيدة: مسار الوثيقة الخاصة لكل لاعب (private/data)،
// بقية الملف كما هو دون أي تغيير.

class FirestorePaths {

  // ROOT COLLECTIONS
  static const String users = 'users';
  static const String publicProfiles = 'public_profiles';
  static const String groups = 'groups';
  static const String privateChats = 'privateChats';
  static const String respects = 'respects';
  static const String fans = 'fans';
  static const String promotions = 'promotions';
  static const String edits = 'edits';

  // GROUP SUBCOLLECTIONS
  static String groupMembers(String groupId) =>
      '$groups/$groupId/members';

  static String groupJoinRequests(String groupId) =>
      '$groups/$groupId/requests';

  static String groupJoinRequestDoc(String groupId, String userId) =>
      '$groups/$groupId/requests/$userId';

  static String groupInvites(String groupId) =>
      '$groups/$groupId/invites';

  static String groupMessages(String groupId) =>
      '$groups/$groupId/messages';

  static String groupMessagesDoc(String groupId, String messageId) =>
      '$groups/$groupId/messages/$messageId';

  static String groupGames(String groupId) =>
      '$groups/$groupId/games';

  static String mafiaGames() => 'mafia_games';

  static String mafiaGameDoc(String gameId) =>
      '${mafiaGames()}/$gameId';

  static String mafiaGamePlayers(String gameId) =>
      '${mafiaGameDoc(gameId)}/players';

  static String mafiaGamePlayerDoc(String gameId, String playerId) =>
      '${mafiaGamePlayers(gameId)}/$playerId';

  /// ✅ جديد: مسار الوثيقة الخاصة (private) لكل لاعب — دور/فريق/نتائج
  /// قدرات — لا يُسمح بقراءتها إلا لصاحب المستند نفسه (Stage 4.5).
  static String mafiaGamePlayerPrivateDoc(String gameId, String playerId) =>
      '${mafiaGamePlayerDoc(gameId, playerId)}/private/data';

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

  static String groupGameDoc(String groupId, String gameId) =>
      '$groups/$groupId/games/$gameId';

  static String groupCharacters(String groupId) =>
      '$groups/$groupId/characters';

  static String groupCharacterDoc(String groupId, String charId) =>
      '$groups/$groupId/characters/$charId';

  // USER SUBCOLLECTIONS
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

  static String publicProfileDoc(String userId) =>
      '$publicProfiles/$userId';

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