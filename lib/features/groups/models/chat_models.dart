import 'package:cloud_firestore/cloud_firestore.dart';

const int kChatAudioMaxBytes = 10 * 1024 * 1024;
const int kChatAudioMaxDurationSeconds = 60;

const reportReasons = <String>[
  'inappropriate',
  'spam',
  'copyright',
  'harassment',
  'other',
];

ChatMessageType chatMediaTypeFor({
  required String contentType,
  required String fileName,
}) {
  if (contentType.startsWith('video/')) return ChatMessageType.video;
  if (contentType.startsWith('audio/')) return ChatMessageType.audio;
  final name = fileName.toLowerCase();
  if (contentType == 'image/gif' || name.endsWith('.gif')) {
    return ChatMessageType.gif;
  }
  return ChatMessageType.image;
}

enum ChatMessageType {
  text,
  image,
  video,
  sticker,
  gif,
  audio,
  system,
  event,
  game,
}

enum ChatSendState { pending, sent, failed }

enum ChatDeliveryState { notDelivered, delivered, read }

final class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.senderRole,
    required this.type,
    required this.text,
    required this.mediaUrl,
    required this.thumbnailUrl,
    required this.mediaId,
    required this.replyToMessageId,
    this.replyPreview,
    this.stickerKey,
    this.forwardedFrom,
    required this.createdAt,
    required this.editedAt,
    required this.deletedAt,
    required this.pinnedAt,
    required this.reactions,
    required this.recipientCount,
    required this.deliveredCount,
    required this.readCount,
    required this.isOptimistic,
    required this.sendState,
    this.failureMessage,
    this.gameActivity,
    this.systemKind,
    this.senderTitle,
    this.disappearing = false,
    this.cardMeta,
  });

  factory ChatMessage.optimistic({
    required String id,
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String senderRole,
    required ChatMessageType type,
    required String? text,
    String? mediaUrl,
    String? thumbnailUrl,
    String? mediaId,
    String? replyToMessageId,
    String? replyPreview,
    String? stickerKey,
    Map<String, String>? forwardedFrom,
  }) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      senderRole: senderRole,
      type: type,
      text: text,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      mediaId: mediaId,
      replyToMessageId: replyToMessageId,
      replyPreview: replyPreview,
      stickerKey: stickerKey,
      forwardedFrom: forwardedFrom,
      createdAt: DateTime.now(),
      editedAt: null,
      deletedAt: null,
      pinnedAt: null,
      reactions: const <String, int>{},
      recipientCount: 0,
      deliveredCount: 0,
      readCount: 0,
      isOptimistic: true,
      sendState: ChatSendState.pending,
      gameActivity: null,
      systemKind: null,
      senderTitle: null,
      disappearing: false,
      cardMeta: null,
    );
  }

  factory ChatMessage.fromMap(
    Map<String, dynamic> map, {
    required String id,
    ChatSendState sendState = ChatSendState.sent,
  }) {
    final type = ChatMessageType.values.firstWhere(
      (value) => value.name == map['type'],
      orElse: () => ChatMessageType.text,
    );
    final reactions = <String, int>{};
    final rawReactions = map['reactions'];
    if (rawReactions is Map) {
      for (final entry in rawReactions.entries) {
        if (entry.key is String && entry.value is num) {
          reactions[entry.key as String] = (entry.value as num).toInt();
        }
      }
    }
    return ChatMessage(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Pubget user',
      senderAvatar: map['senderAvatar'] as String? ?? '',
      senderRole: map['senderRole'] as String? ?? 'member',
      type: type,
      text: map['text'] as String?,
      mediaUrl: map['mediaUrl'] as String?,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      mediaId: map['mediaId'] as String?,
      replyToMessageId:
          (map['replyToMessageId'] ?? map['replyToId']) as String?,
      replyPreview: map['replyPreview'] as String?,
      stickerKey: map['stickerKey'] as String?,
      forwardedFrom: _stringMap(map['forwardedFrom']),
      createdAt: _date(map['createdAt']),
      editedAt: _date(map['editedAt']),
      deletedAt: _date(map['deletedAt']),
      pinnedAt: _date(map['pinnedAt']),
      reactions: reactions,
      recipientCount: (map['recipientCount'] as num?)?.toInt() ?? 0,
      deliveredCount: (map['deliveredCount'] as num?)?.toInt() ?? 0,
      readCount: (map['readCount'] as num?)?.toInt() ?? 0,
      isOptimistic: false,
      sendState: sendState,
      gameActivity: ChatGameActivity.tryParse(map['gameActivity']),
      systemKind: map['systemKind'] as String?,
      senderTitle: map['senderTitle'] as String?,
      disappearing: map['disappearing'] == true || map['expiresAt'] != null,
      cardMeta: map['cardMeta'] is Map
          ? Map<String, dynamic>.from(map['cardMeta'] as Map)
          : null,
    );
  }

  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String senderRole;
  final ChatMessageType type;
  final String? text;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? mediaId;
  final String? replyToMessageId;
  final String? replyPreview;
  final String? stickerKey;
  final Map<String, String>? forwardedFrom;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime? pinnedAt;
  final Map<String, int> reactions;
  final int recipientCount;
  final int deliveredCount;
  final int readCount;
  final bool isOptimistic;
  final ChatSendState sendState;
  final String? failureMessage;
  final ChatGameActivity? gameActivity;
  /// system | member_joined | debate | encryption …
  final String? systemKind;
  final String? senderTitle;
  final bool disappearing;
  final Map<String, dynamic>? cardMeta;

  bool get isDeleted => deletedAt != null;
  bool get isMemberJoinedCard =>
      type == ChatMessageType.system &&
      (systemKind == 'member_joined' ||
          (text ?? '').toLowerCase().contains('joined'));
  bool get isDebateCard =>
      systemKind == 'debate' ||
      (cardMeta != null && cardMeta!['kind'] == 'debate');
  bool get isEncryptionNotice => systemKind == 'encryption';
  bool get isCatalogSticker =>
      type == ChatMessageType.sticker &&
      stickerKey != null &&
      stickerKey!.trim().isNotEmpty;

  bool get isMedia =>
      type == ChatMessageType.image ||
      type == ChatMessageType.video ||
      type == ChatMessageType.gif ||
      (type == ChatMessageType.sticker && !isCatalogSticker);

  ChatDeliveryState get deliveryState {
    if (readCount >= recipientCount && recipientCount > 0) {
      return ChatDeliveryState.read;
    }
    if (deliveredCount > 0) return ChatDeliveryState.delivered;
    return ChatDeliveryState.notDelivered;
  }

  ChatMessage copyWith({
    ChatSendState? sendState,
    bool? isOptimistic,
    String? failureMessage,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      senderRole: senderRole,
      type: type,
      text: text,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      mediaId: mediaId,
      replyToMessageId: replyToMessageId,
      replyPreview: replyPreview,
      stickerKey: stickerKey,
      forwardedFrom: forwardedFrom,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      pinnedAt: pinnedAt,
      reactions: reactions,
      recipientCount: recipientCount,
      deliveredCount: deliveredCount,
      readCount: readCount,
      isOptimistic: isOptimistic ?? this.isOptimistic,
      sendState: sendState ?? this.sendState,
      failureMessage: failureMessage ?? this.failureMessage,
      gameActivity: gameActivity,
      systemKind: systemKind,
      senderTitle: senderTitle,
      disappearing: disappearing,
      cardMeta: cardMeta,
    );
  }
}

final class ChatGameActivity {
  const ChatGameActivity({
    required this.kind,
    required this.gameType,
    this.title,
    this.winnerLabel,
    this.hostName,
    this.playerCount,
    this.maxPlayers,
    this.status,
    this.participantAvatars = const <String>[],
  });

  final String kind;
  final String gameType;
  final String? title;
  final String? winnerLabel;
  final String? hostName;
  final int? playerCount;
  final int? maxPlayers;
  final String? status;
  final List<String> participantAvatars;

  bool get isCreated => kind == 'created';
  bool get isMafia => gameType == 'mafia';
  bool get isFull =>
      playerCount != null &&
      maxPlayers != null &&
      playerCount! >= maxPlayers!;
  bool get isStarted => status == 'started' || status == 'live' || kind == 'started';
  String get actionLabel {
    if (isStarted) return 'View';
    if (isFull) return 'Full';
    return isCreated ? 'Join' : 'View result';
  }

  static ChatGameActivity? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final kind = raw['kind'] as String? ?? '';
    final gameType = raw['gameType'] as String? ?? '';
    if (kind.isEmpty && gameType.isEmpty) return null;
    final avatars = <String>[];
    final rawAvatars = raw['participantAvatars'] ?? raw['avatars'];
    if (rawAvatars is List) {
      for (final item in rawAvatars) {
        if (item is String && item.trim().isNotEmpty) avatars.add(item);
      }
    }
    return ChatGameActivity(
      kind: kind,
      gameType: gameType,
      title: raw['title'] as String?,
      winnerLabel: raw['winnerLabel'] as String?,
      hostName: raw['hostName'] as String?,
      playerCount: (raw['playerCount'] as num?)?.toInt(),
      maxPlayers: (raw['maxPlayers'] as num?)?.toInt(),
      status: raw['status'] as String?,
      participantAvatars: avatars,
    );
  }
}

final class ChatMediaUpload {
  const ChatMediaUpload({
    required this.mediaUrl,
    required this.thumbnailUrl,
    required this.mediaId,
    required this.type,
  });

  final String mediaUrl;
  final String? thumbnailUrl;
  final String mediaId;
  final ChatMessageType type;
}

Map<String, String>? _stringMap(dynamic value) {
  if (value is! Map) return null;
  final out = <String, String>{};
  for (final entry in value.entries) {
    if (entry.key is String && entry.value is String) {
      out[entry.key as String] = entry.value as String;
    }
  }
  return out.isEmpty ? null : out;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  try {
    return value?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
