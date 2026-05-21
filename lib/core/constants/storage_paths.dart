// lib/core/constants/storage_paths.dart
class StoragePaths {

  // USER STORAGE

  /// users/{userId}/avatar.jpg
  static String userAvatar(String userId) =>
      'users/$userId/avatar.jpg';

  // GROUP STORAGE

  /// groups/{groupId}/group_image.jpg
  static String groupImage(String groupId) =>
      'groups/$groupId/group_image.jpg';

  // ✅ جديد: خلفية دردشة المجموعة (يرفعها المؤسس)
  /// groups/{groupId}/chat_background.jpg
  static String groupChatBackground(String groupId) =>
      'groups/$groupId/chat_background.jpg';

  // ✅ جديد: خلفية الدردشة الخاصة (تُحفظ محلياً فقط، لكن المسار احتياطي)
  /// privateChats/{chatId}/backgrounds/{userId}.jpg
  static String privateChatBackground(String chatId, String userId) =>
      'privateChats/$chatId/backgrounds/$userId.jpg';

  // ROLEPLAY CHARACTER STORAGE

  /// groups/{groupId}/characters/{userId}.jpg
  static String roleplayCharacterImage(
    String groupId,
    String userId,
  ) =>
      'groups/$groupId/characters/$userId.jpg';

  // GROUP CHAT MEDIA

  /// groups/{groupId}/media/{messageId}
  static String groupChatMedia(
    String groupId,
    String messageId,
  ) =>
      'groups/$groupId/media/$messageId';

  // PRIVATE CHAT MEDIA

  /// privateChats/{chatId}/media/{messageId}
  static String privateChatMedia(
    String chatId,
    String messageId,
  ) =>
      'privateChats/$chatId/media/$messageId';

  // VOICE MESSAGES

  /// groups/{groupId}/voices/{messageId}.m4a
  static String groupVoice(
    String groupId,
    String messageId,
  ) =>
      'groups/$groupId/voices/$messageId.m4a';

  /// privateChats/{chatId}/voices/{messageId}.m4a
  static String privateVoice(
    String chatId,
    String messageId,
  ) =>
      'privateChats/$chatId/voices/$messageId.m4a';
}