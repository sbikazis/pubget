import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';

/// Lightweight durable outbox for pending chat sends (text/sticker/metadata).
///
/// Raw media bytes stay in-memory only; once mediaUrl/mediaId exist the
/// metadata can be persisted for retry after rebuild.
final class PendingChatOutbox {
  PendingChatOutbox({SharedPreferences? prefs}) : _prefsOverride = prefs;

  final SharedPreferences? _prefsOverride;

  String _key(String scope) => 'pubget.chat.outbox.$scope';

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? SharedPreferences.getInstance();

  Future<List<ChatMessage>> load(String scope) async {
    final raw = (await _prefs()).getString(_key(scope));
    if (raw == null || raw.isEmpty) return const <ChatMessage>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((item) {
            final map = Map<String, dynamic>.from(item);
            final id = map['id'] as String? ?? '';
            if (id.isEmpty) return null;
            return ChatMessage.fromMap(
              map,
              id: id,
              sendState: ChatSendState.pending,
            ).copyWith(isOptimistic: true, clearFailureMessage: true);
          })
          .whereType<ChatMessage>()
          .toList(growable: false);
    } catch (_) {
      return const <ChatMessage>[];
    }
  }

  Future<void> upsert(String scope, ChatMessage message) async {
    if (message.id.isEmpty) return;
    if (!_isPersistable(message)) return;
    final prefs = await _prefs();
    final maps = _decodeMaps(prefs.getString(_key(scope)));
    maps.removeWhere((item) => item['id'] == message.id);
    maps.add(_toMap(message));
    await prefs.setString(_key(scope), jsonEncode(maps));
  }

  Future<void> remove(String scope, String messageId) async {
    final prefs = await _prefs();
    final maps = _decodeMaps(prefs.getString(_key(scope)));
    maps.removeWhere((item) => item['id'] == messageId);
    if (maps.isEmpty) {
      await prefs.remove(_key(scope));
      return;
    }
    await prefs.setString(_key(scope), jsonEncode(maps));
  }

  bool _isPersistable(ChatMessage message) {
    if (message.type == ChatMessageType.image ||
        message.type == ChatMessageType.video ||
        message.type == ChatMessageType.gif ||
        message.type == ChatMessageType.audio) {
      final hasMedia =
          (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) ||
          (message.mediaId != null && message.mediaId!.isNotEmpty);
      return hasMedia;
    }
    return true;
  }

  List<Map<String, dynamic>> _decodeMaps(String? raw) {
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Map<String, dynamic> _toMap(ChatMessage message) {
    return <String, dynamic>{
      'id': message.id,
      'senderId': message.senderId,
      'senderName': message.senderName,
      'senderAvatar': message.senderAvatar,
      'senderRole': message.senderRole,
      'type': message.type.name,
      'text': message.text,
      'mediaUrl': message.mediaUrl,
      'thumbnailUrl': message.thumbnailUrl,
      'mediaId': message.mediaId,
      'replyToMessageId': message.replyToMessageId,
      'replyPreview': message.replyPreview,
      'stickerKey': message.stickerKey,
      'stickerCreatorId': message.stickerCreatorId,
      'stickerCreatorName': message.stickerCreatorName,
      'createdAt': message.createdAt?.toIso8601String(),
      'editedAt': null,
      'deletedAt': null,
      'pinnedAt': null,
      'reactions': const <String, int>{},
      'recipientCount': 0,
      'deliveredCount': 0,
      'readCount': 0,
    };
  }
}
