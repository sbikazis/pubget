import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/roles.dart';

/// ✅ إضافة Enum لتحديد نوع الرسالة (عادية أو حدث لعبة)
enum MessageType { text, media, gameEvent }

class MessageModel {
  final String id;

  final String senderId;
  final String senderName;
  final String senderAvatar; // 🔥 هذا الحقل سيحمل الآن (صورة التقمص أو صورة البروفايل) بفضل تعديل الـ Provider
  
  // ✅ الحقل الجديد لتمييز مستخدمي البريميوم بصرياً في الدردشة
  final bool senderIsPremium;

  // ✅ جعل الرتبة اختيارية لدعم الدردشة الخاصة
  final Roles? senderRole;

  final String? text;

  final String? mediaUrl;
  final String? mediaType; // image | video | audio

  // --- حقول نظام اللعبة المضافة ---
  final MessageType type; // نوع الرسالة (نص، ميديا، أو حدث لعبة)
  final String? gameId; // معرف اللعبة المرتبط
  final String? gameSlot; // لتمييز اللون بصرياً (game_1 أو game_2)
  final String? gameAction; // نوع الحدث (challenge, win, draw, quit, move)

  // الحقول الجديدة للرد والتفاعلات
  final String? replyToId; // معرف الرسالة التي يتم الرد عليها
  final String? replyText; // نص الرسالة المردود عليها (للعرض السريع)
  final Map<String, String>? reactions; // خريطة: {userId: emoji}

  final DateTime createdAt;
  
  // ✅ الحقل الجديد لضمان دقة العداد بنسبة 100%
  final bool isRead;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    this.senderIsPremium = false, // القيمة الافتراضية عادي
    this.senderRole, 
    this.text,
    this.mediaUrl,
    this.mediaType,
    this.type = MessageType.text, // القيمة الافتراضية نصية
    this.gameId,
    this.gameSlot,
    this.gameAction,
    this.replyToId,
    this.replyText,
    this.reactions,
    required this.createdAt,
    this.isRead = false, // القيمة الافتراضية غير مقروءة
  });

  /// Firestore → Model
  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    return MessageModel(
      id: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderAvatar: map['senderAvatar'] ?? '',
      // جلب حالة البريميوم من Firestore
      senderIsPremium: map['senderIsPremium'] ?? false,
      // ✅ التعامل مع الرتبة بحذر: إذا كانت موجودة نأخذها، وإلا نتركها null للخاص
      senderRole: map['senderRole'] != null 
          ? Roles.fromString(map['senderRole']) 
          : null,
      text: map['text'],
      mediaUrl: map['mediaUrl'],
      mediaType: map['mediaType'],
      // جلب نوع الرسالة مع قيمة افتراضية
      type: map['type'] != null 
          ? MessageType.values.firstWhere((e) => e.name == map['type'], orElse: () => MessageType.text)
          : MessageType.text,
      gameId: map['gameId'],
      gameSlot: map['gameSlot'],
      gameAction: map['gameAction'],
      replyToId: map['replyToId'],
      replyText: map['replyText'],
      // تحويل خريطة التفاعلات من Firestore بأمان
      reactions: map['reactions'] != null 
          ? Map<String, String>.from(map['reactions'] as Map) 
          : null,
      // تأمين تحويل التاريخ لتجنب الأخطاء البرمجية
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      // جلب حالة القراءة من Firestore
      isRead: map['isRead'] ?? false,
    );
  }

  /// Model → Firestore
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'senderIsPremium': senderIsPremium, // إرسال حالة البريميوم
      // ✅ إرسال اسم الرتبة فقط في حال وجودها لضمان عدم وجود قيم فارغة تؤثر على الواجهة
      'senderRole': senderRole?.name, 
      'text': text,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'type': type.name, // حفظ اسم النوع في Firestore
      'gameId': gameId,
      'gameSlot': gameSlot,
      'gameAction': gameAction,
      'replyToId': replyToId,
      'replyText': replyText,
      'reactions': reactions,
      'createdAt': Timestamp.fromDate(createdAt), // التأكد من إرسالها كـ Timestamp
      'isRead': isRead,
    };
  }

  // ✅ إضافة copyWith للحفاظ على مرونة التعديل في المستقبل دون فقدان البيانات
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
    Map<String, String>? reactions,
    bool? isRead,
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
      replyToId: replyToId,
      replyText: replyText,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}