import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/roles.dart';

enum MessageType { text, media, gameEvent, gameInvite, systemEvent } // ✅ إضافة systemEvent

enum MessageStatus { sending, sent, failed }

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final bool senderIsPremium;
  final Roles? senderRole;
  final String? text;
  final String? mediaUrl;
  final String? mediaType;
  final MessageType type;
  final String? gameId;
  final String? gameSlot;
  final String? gameAction;
  final String? systemEventType; // ✅ جديد: join / leave / kick / roleAssign
  final String? replyToId;
  final String? replyText;
  final String? replyToSenderName;
  final String? replyToMediaUrl;
  final Map<String, String>? reactions;

  // ✅✅✅ تعديل جوهري: أصبح nullable
  // null يعني: السيرفر لم يكتب الوقت الحقيقي بعد (لحظة الإرسال نفسها قبل المزامنة).
  // هذا يحل مشكلة "اختلاف الساعة بين الأجهزة" (Clock Skew) نهائياً،
  // لأننا لا نعتمد إطلاقاً على ساعة أي جهاز محلي، بل فقط على وقت سيرفر فايرستور.
  final DateTime? createdAt;

  final bool isRead;
  final bool isDelivered;
  final int? audioDuration;
  final String? editThumbnail;
  final String? editAnimeTitle;
  final String? editId;
  final bool isEdited; // ✅ جديد: تم تعديل الرسالة أم لا
  final MessageStatus status;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    this.senderIsPremium = false,
    this.senderRole,
    this.text,
    this.mediaUrl,
    this.mediaType,
    this.type = MessageType.text,
    this.gameId,
    this.gameSlot,
    this.gameAction,
    this.systemEventType, // ✅ جديد
    this.replyToId,
    this.replyText,
    this.replyToSenderName,
    this.replyToMediaUrl,
    this.reactions,
    this.createdAt, // ✅ لم يعد required — يبدأ null دائماً عند الإنشاء المحلي
    this.isRead = false,
    this.isDelivered = false,
    this.audioDuration,
    this.editThumbnail,
    this.editAnimeTitle,
    this.editId,
    this.isEdited = false, // ✅ جديد
    this.status = MessageStatus.sent,
  });

  // ✅ مساعد: هل وقت هذه الرسالة مؤكَّد من السيرفر بالفعل؟
  // مفيد لأي واجهة تريد إظهار "⏳ جاري الإرسال" أو ساعة رمادية مؤقتة بدل وقت حقيقي.
  bool get isTimestampPending => createdAt == null;

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderAvatar: map['senderAvatar'] ?? '',
      senderIsPremium: map['senderIsPremium'] ?? false,
      senderRole: map['senderRole'] != null
          ? Roles.fromString(map['senderRole'])
          : null,
      text: map['text'],
      mediaUrl: map['mediaUrl'],
      mediaType: map['mediaType'],
      type: map['type'] != null
          ? MessageType.values.firstWhere(
              (e) => e.name == map['type'],
              orElse: () => MessageType.text)
          : MessageType.text,
      gameId: map['gameId'],
      gameSlot: map['gameSlot'],
      gameAction: map['gameAction'],
      systemEventType: map['systemEventType'], // ✅ جديد
      replyToId: map['replyToId'],
      replyText: map['replyText'],
      replyToSenderName: map['replyToSenderName'],
      replyToMediaUrl: map['replyToMediaUrl'],
      reactions: map['reactions'] != null
          ? Map<String, String>.from(map['reactions'] as Map)
          : null,
      // ✅✅✅ تعديل جوهري: إذا كان createdAt لا يزال null في فايرستور
      // (وثيقة كُتبت بـ serverTimestamp() ولم يصلنا التحديث المُحدَّث منه بعد)،
      // نُرجع null بصراحة بدل DateTime.now() — أي قيمة محلية بديلة كانت
      // هي بالضبط السبب الجذري لمشكلة اختلاط ترتيب الرسائل سابقاً.
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      isRead: map['isRead'] ?? false,
      isDelivered: map['isDelivered'] ?? false,
      audioDuration: map['audioDuration'],
      editThumbnail: map['editThumbnail'],
      editAnimeTitle: map['editAnimeTitle'],
      editId: map['editId'],
      isEdited: map['isEdited'] ?? false, // ✅ جديد
      status: MessageStatus.sent,
    );
  }

  // ✅✅✅ تعديل جوهري: useServerTimestamp (افتراضي true)
  // عند الإرسال الأولي للرسالة، نريد أن يكتب فايرستور نفسه الوقت الحقيقي.
  // عند استخدامات أخرى (نادرة، مثل ترحيل بيانات قديمة بوقت معروف مسبقاً)
  // يمكن تمرير useServerTimestamp: false لإرسال وقت محدد صريح.
  Map<String, dynamic> toMap({bool useServerTimestamp = true}) {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'senderIsPremium': senderIsPremium,
      'senderRole': senderRole?.name,
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'type': type.name,
      'gameId': gameId,
      'gameSlot': gameSlot,
      'gameAction': gameAction,
      'systemEventType': systemEventType, // ✅ جديد
      'replyToId': replyToId,
      'replyText': replyText,
      'replyToSenderName': replyToSenderName,
      'replyToMediaUrl': replyToMediaUrl,
      'reactions': reactions,
      // ✅✅✅ تعديل جوهري: بدل Timestamp.fromDate(createdAt) الذي يعتمد
      // على ساعة الجهاز المحلية وقت الإنشاء (سبب مشكلة Clock Skew بالكامل)،
      // نكتب الآن FieldValue.serverTimestamp() ليكتب فايرستور الوقت
      // الحقيقي الموحّد لحظة استلام الكتابة على السيرفر.
      // إذا useServerTimestamp == false (حالة استثنائية فقط) نستخدم
      // createdAt المُمرَّر يدوياً، أو الوقت الحالي إذا كان null.
      'createdAt': useServerTimestamp
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt ?? DateTime.now()),
      'isRead': isRead,
      'isDelivered': isDelivered,
      'audioDuration': audioDuration,
      'editThumbnail': editThumbnail,
      'editAnimeTitle': editAnimeTitle,
      'editId': editId,
      'isEdited': isEdited, // ✅ جديد
      // status لا يُحفظ في Firestore عمداً
    };
  }

  MessageModel copyWith({
    String? senderName,
    String? senderAvatar,
    bool? senderIsPremium,
    Roles? senderRole,
    String? text,
    MessageType? type,
    String? gameId,
    String? gameSlot,
    String? gameAction,
    String? systemEventType, // ✅ جديد
    Map<String, String>? reactions,
    DateTime? createdAt, // ✅ جديد: لإمكانية تثبيت الوقت بعد وصوله من السيرفر إن احتاج الأمر
    bool? isRead,
    bool? isDelivered,
    int? audioDuration,
    String? editThumbnail,
    String? editAnimeTitle,
    String? editId,
    bool? isEdited, // ✅ جديد
    MessageStatus? status,
  }) {
    return MessageModel(
      id: id,
      senderId: senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      senderIsPremium: senderIsPremium ?? this.senderIsPremium,
      senderRole: senderRole ?? this.senderRole,
      text: text ?? this.text,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      type: type ?? this.type,
      gameId: gameId ?? this.gameId,
      gameSlot: gameSlot ?? this.gameSlot,
      gameAction: gameAction ?? this.gameAction,
      systemEventType: systemEventType ?? this.systemEventType, // ✅ جديد
      replyToId: replyToId,
      replyText: replyText,
      replyToSenderName: replyToSenderName,
      replyToMediaUrl: replyToMediaUrl,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt ?? this.createdAt, // ✅ تعديل
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      audioDuration: audioDuration ?? this.audioDuration,
      editThumbnail: editThumbnail ?? this.editThumbnail,
      editAnimeTitle: editAnimeTitle ?? this.editAnimeTitle,
      editId: editId ?? this.editId,
      isEdited: isEdited ?? this.isEdited, // ✅ جديد
      status: status ?? this.status,
    );
  }
}
