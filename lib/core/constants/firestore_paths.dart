class FirestorePaths {

  //  ROOT COLLECTIONS


  static const String users = 'users';
  static const String groups = 'groups';
  static const String privateChats = 'privateChats';
  static const String respects = 'respects';
  static const String fans = 'fans';
  static const String promotions = 'promotions';


  //  GROUP SUBCOLLECTIONS


  static String groupMembers(String groupId) =>
      '$groups/$groupId/members';

  static String groupInvites(String groupId) =>
      '$groups/$groupId/invites';

  static String groupMessages(String groupId) =>
      '$groups/$groupId/messages';

  static String groupGames(String groupId) =>
      '$groups/$groupId/games';

  static String groupCharacters(String groupId) =>
      '$groups/$groupId/characters';


  //  USER SUBCOLLECTIONS


  static String userNotifications(String userId) =>
      '$users/$userId/notifications';


  //  PRIVATE CHAT SUBCOLLECTIONS


  static String privateMessages(String chatId) =>
      '$privateChats/$chatId/messages';


  //  DOCUMENT PATH HELPERS


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