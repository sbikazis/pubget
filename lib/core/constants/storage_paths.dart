class StoragePaths {

  //  USER STORAGE


  /// users/{userId}/avatar.jpg
  static String userAvatar(String userId) =>
      'users/$userId/avatar.jpg';


  //  GROUP STORAGE


  /// groups/{groupId}/group_image.jpg
  static String groupImage(String groupId) =>
      'groups/$groupId/group_image.jpg';


  //  ROLEPLAY CHARACTER STORAGE


  /// groups/{groupId}/characters/{userId}.jpg
  static String roleplayCharacterImage(
    String groupId,
    String userId,
  ) =>
      'groups/$groupId/characters/$userId.jpg';


  //  GROUP CHAT MEDIA


  /// groups/{groupId}/media/{messageId}
  static String groupChatMedia(
    String groupId,
    String messageId,
  ) =>
      'groups/$groupId/media/$messageId';


  //  PRIVATE CHAT MEDIA


  /// privateChats/{chatId}/media/{messageId}
  static String privateChatMedia(
    String chatId,
    String messageId,
  ) =>
      'privateChats/$chatId/media/$messageId';
}