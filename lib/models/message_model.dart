// lib/models/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/roles.dart';

class MessageModel {
  final String id;

  final String senderId;
  final String senderName;
  final String senderAvatar;
  
  // ✅ الحقل الجديد لتمييز مستخدمي البريميوم بصرياً في الدردشة
  final bool senderIsPremium;

  // ✅ جعل الرتبة اختيارية لدعم الدردشة الخاصة
  final Roles? senderRole;

  final String? text;

  final String? mediaUrl;
  final String? mediaType; // image | video | audio

  final String? gameId;

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
    this.gameId,
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
      gameId: map['gameId'],
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
      'gameId': gameId,
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
      gameId: gameId,
      replyToId: replyToId,
      replyText: replyText,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}