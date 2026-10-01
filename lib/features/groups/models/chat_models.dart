import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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

/// In-bubble media send stages (progress UI must not rebuild the whole page).
enum MediaUploadPhase { uploading, processing }

final class MediaUploadUiState {
  const MediaUploadUiState({
    required this.phase,
    this.progress = 0,
  });

  final MediaUploadPhase phase;

  /// 0‥1 while [phase] is [MediaUploadPhase.uploading]; ignored while processing.
  final double progress;

  static const uploadingStart = MediaUploadUiState(
    phase: MediaUploadPhase.uploading,
  );
}

/// Per-message upload surface a bubble needs, independent of which conversation
/// owns it. Injected into the bubble rather than resolved from a global
/// provider, so the group and the 1:1 chat share one bubble widget without
/// either side reading the other's state.
abstract interface class ChatMediaUploadHost {
  /// Local camera/gallery bytes for a message whose upload has not produced a
  /// remote URL yet, so the sender sees their own media immediately.
  Uint8List? localPreviewBytes(String messageId);

  /// Per-message upload listenable, or null when this message is not uploading.
  /// Bubbles listen to it directly so progress ticks never rebuild the list.
  ValueListenable<MediaUploadUiState>? uploadUiListenable(String messageId);
}

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
    this.mediaWidth,
    this.mediaHeight,
    required this.replyToMessageId,
    this.replyPreview,
    this.stickerKey,
    this.stickerCreatorId,
    this.stickerCreatorName,
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
    this.reactionUsers = const <String, Set<String>>{},
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
    int? mediaWidth,
    int? mediaHeight,
    String? replyToMessageId,
    String? replyPreview,
    String? stickerKey,
    String? stickerCreatorId,
    String? stickerCreatorName,
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
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      replyToMessageId: replyToMessageId,
      replyPreview: replyPreview,
      stickerKey: stickerKey,
      stickerCreatorId: stickerCreatorId,
      stickerCreatorName: stickerCreatorName,
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
      mediaWidth: _positiveInt(map['mediaWidth']),
      mediaHeight: _positiveInt(map['mediaHeight']),
      replyToMessageId:
          (map['replyToMessageId'] ?? map['replyToId']) as String?,
      replyPreview: map['replyPreview'] as String?,
      stickerKey: map['stickerKey'] as String?,
      stickerCreatorId: map['stickerCreatorId'] as String?,
      stickerCreatorName: map['stickerCreatorName'] as String?,
      forwardedFrom: _stringMap(map['forwardedFrom']),
      createdAt: _date(map['createdAt']),
      editedAt: _date(map['editedAt']),
      deletedAt: _date(map['deletedAt']),
      pinnedAt: _date(map['pinnedAt']),
      reactions: reactions,
      reactionUsers: _reactionUsers(map['reactionUsers']),
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
  /// Display-oriented pixel size of [mediaUrl], recorded by the media pipeline.
  /// Null for legacy media, in which case the bubble falls back to a neutral
  /// ratio instead of probing (which would mean a full decode per bubble).
  final int? mediaWidth;
  final int? mediaHeight;
  final String? replyToMessageId;
  final String? replyPreview;
  final String? stickerKey;
  /// Original sticker author (not necessarily the message sender).
  final String? stickerCreatorId;
  final String? stickerCreatorName;
  final Map<String, String>? forwardedFrom;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime? pinnedAt;
  final Map<String, int> reactions;

  /// Who reacted, per emoji. The server is the source of truth for this and
  /// reconciles it on the watch stream; the client only reads it to know which
  /// way a toggle goes before the round trip lands.
  final Map<String, Set<String>> reactionUsers;
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

  /// Whether [uid] already reacted with [emoji], as the last server answer said.
  bool hasReacted(String emoji, String uid) =>
      reactionUsers[emoji]?.contains(uid) ?? false;

  /// This message with [uid]'s [emoji] reaction toggled, the way the server's
  /// read-modify-write would leave it.
  ///
  /// The server toggles, so the direction has to be known before the call goes
  /// out — applying the wrong one would visibly flip the pill twice. Documents
  /// written before `reactionUsers` existed carry counts with no owners; those
  /// are read as "not mine yet", which is right for a first reaction and heals
  /// from the stream either way.
  ChatMessage withReactionToggled(String emoji, String uid) {
    final users = reactionUsers[emoji];
    final removing = users?.contains(uid) ?? false;
    final nextCounts = Map<String, int>.from(reactions);
    final nextUsers = <String, Set<String>>{...reactionUsers};
    if (removing) {
      final remaining = Set<String>.from(users!)..remove(uid);
      final count = (nextCounts[emoji] ?? 1) - 1;
      if (remaining.isEmpty || count <= 0) {
        nextUsers.remove(emoji);
        nextCounts.remove(emoji);
      } else {
        nextUsers[emoji] = remaining;
        nextCounts[emoji] = count;
      }
    } else {
      nextUsers[emoji] = <String>{...?users, uid};
      nextCounts[emoji] = (nextCounts[emoji] ?? 0) + 1;
    }
    return copyWith(reactions: nextCounts, reactionUsers: nextUsers);
  }
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

  /// True when the media pipeline recorded a usable pixel size.
  bool get hasMediaSize => mediaWidth != null && mediaHeight != null;

  /// True when the bubble renders a raster/stream frame and therefore can be
  /// given a concrete box up front instead of an intrinsic layout pass.
  bool get hasDisplayMedia =>
      type == ChatMessageType.image ||
      type == ChatMessageType.video ||
      type == ChatMessageType.gif;

  /// Aspect ratio the bubble should render at.
  ///
  /// Clamped so a very tall screenshot or a panorama cannot dominate the
  /// viewport; the bubble always crops with `BoxFit.cover` inside these bounds.
  double get mediaAspectRatio {
    final w = mediaWidth;
    final h = mediaHeight;
    if (w == null || h == null || w <= 0 || h <= 0) return kChatMediaFallbackAspect;
    final ratio = w / h;
    return ratio.clamp(kChatMediaMinAspect, kChatMediaMaxAspect);
  }

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
    bool clearFailureMessage = false,
    DateTime? createdAt,
    DateTime? deletedAt,
    DateTime? pinnedAt,
    bool clearPinnedAt = false,
    Map<String, int>? reactions,
    Map<String, Set<String>>? reactionUsers,
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
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      replyToMessageId: replyToMessageId,
      replyPreview: replyPreview,
      stickerKey: stickerKey,
      stickerCreatorId: stickerCreatorId,
      stickerCreatorName: stickerCreatorName,
      forwardedFrom: forwardedFrom,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      pinnedAt: clearPinnedAt ? null : (pinnedAt ?? this.pinnedAt),
      reactions: reactions ?? this.reactions,
      reactionUsers: reactionUsers ?? this.reactionUsers,
      recipientCount: recipientCount,
      deliveredCount: deliveredCount,
      readCount: readCount,
      isOptimistic: isOptimistic ?? this.isOptimistic,
      sendState: sendState ?? this.sendState,
      failureMessage: clearFailureMessage
          ? null
          : (failureMessage ?? this.failureMessage),
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
    this.requiredPlayers,
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
  final int? requiredPlayers;
  final int? maxPlayers;
  final String? status;
  final List<String> participantAvatars;

  bool get isCreated => kind == 'created';
  bool get isMafia => gameType == 'mafia';
  bool get isFull =>
      playerCount != null &&
      maxPlayers != null &&
      playerCount! >= maxPlayers!;
  bool get isStarted =>
      status == 'started' || status == 'live' || kind == 'started';
  bool get isCancelled => kind == 'cancelled' || status == 'cancelled';
  String get actionLabel {
    if (isCancelled) return 'Closed';
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
      requiredPlayers: (raw['requiredPlayers'] as num?)?.toInt(),
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
    this.width,
    this.height,
  });

  final String mediaUrl;
  final String? thumbnailUrl;
  final String mediaId;
  final ChatMessageType type;
  final int? width;
  final int? height;
}

/// Fallback ratio for media the pipeline never measured. Landscape-leaning so a
/// portrait screenshot does not become a letterboxed sliver before its real size
/// is known, and so the box does not jump when the dimensions arrive.
const double kChatMediaFallbackAspect = 4 / 3;

/// A bubble is never wider than roughly three quarters of the viewport and never
/// taller than this, so extreme ratios stay readable.
const double kChatMediaMinAspect = 0.5;
const double kChatMediaMaxAspect = 2.4;

int? _positiveInt(dynamic value) {
  if (value is! num) return null;
  final rounded = value.toInt();
  return rounded > 0 ? rounded : null;
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

/// `reactionUsers` as the server writes it: emoji -> { uid: true }. Read so the
/// client knows whether *this* account already reacted, which is what makes the
/// server's toggle predictable enough to apply on the device first.
Map<String, Set<String>> _reactionUsers(dynamic value) {
  if (value is! Map) return const <String, Set<String>>{};
  final out = <String, Set<String>>{};
  for (final entry in value.entries) {
    if (entry.key is! String || entry.value is! Map) continue;
    final uids = <String>{
      for (final uid in (entry.value as Map).keys)
        if (uid is String) uid,
    };
    if (uids.isNotEmpty) out[entry.key as String] = uids;
  }
  return out.isEmpty ? const <String, Set<String>>{} : out;
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

/// Newest live pinned message in [messages].
///
/// Tombstones are skipped so a pinned banner never jumps to a deleted message,
/// and a missing `pinnedAt` (older documents) is treated as "not pinned".
ChatMessage? newestPinnedMessage(List<ChatMessage> messages) {
  ChatMessage? newest;
  for (final message in messages) {
    final pinnedAt = message.pinnedAt;
    if (pinnedAt == null || message.isDeleted) continue;
    if (newest == null || pinnedAt.isAfter(newest.pinnedAt!)) {
      newest = message;
    }
  }
  return newest;
}
