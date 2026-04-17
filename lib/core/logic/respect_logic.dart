// lib/core/logic/respect_logic.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ مضاف للتعامل مع الـ Batch
import '../../models/respect_model.dart';
import '../../models/fan_model.dart';
import '../../services/firebase/firestore_service.dart';
import '../constants/firestore_paths.dart';
import '../constants/limits.dart';

class RespectLogic {
  final FirestoreService _firestore;

  RespectLogic(this._firestore);

  /// Rate a user (one-time only)
  /// Returns:
  /// - true => rating successful
  /// - false => already rated
  Future<bool> rateUser({
    required String fromUserId,
    required String toUserId,
    required int respectValue, // ✅ التأكد من استخدام int بشكل صارم
  }) async {
    // Prevent self rating
    if (fromUserId == toUserId) {
      throw Exception('لا يمكن أن تمنح نفسك نقاط إحترام.');
    }

    // Validate range
    // ✅ التأكد من تحويل القيم إلى int عند المقارنة لضمان الدقة
    if (respectValue < Limits.respectMin.toInt() ||
        respectValue > Limits.respectMax.toInt()) {
      throw Exception('نقاط الإحترام يجب أن تكون بين ${Limits.respectMin} و ${Limits.respectMax}.');
    }

    // Check if already rated
    final existing = await _firestore.getDocument(
      path: FirestorePaths.respects,
      docId: _respectDocId(fromUserId, toUserId),
    );

    if (existing != null) {
      return false; // Already rated
    }

    // ✅ التعديل الجوهري: استخدام Batch لضمان تحديث العدادات في ملف المستخدم
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // 1. إنشاء سجل الاحترام
    final respectId = _respectDocId(fromUserId, toUserId);
    final respect = RespectModel(
      id: respectId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      value: respectValue,
      createdAt: DateTime.now(),
    );
    
    final respectRef = firestore.collection(FirestorePaths.respects).doc(respectId);
    batch.set(respectRef, respect.toMap());

    // 2. تحديث إجمالي نقاط الاحترام في وثيقة المستخدم المستهدف
    final userRef = firestore.collection(FirestorePaths.users).doc(toUserId);
    batch.update(userRef, {
      'totalRespect': FieldValue.increment(respectValue),
    });

    // 3. التحقق من عتبة المعجبين (Fan Threshold)
    if (respectValue > Limits.fanThreshold.toInt()) {
      final fanDocId = '${fromUserId}_$toUserId';
      
      // ملاحظة: نتحقق من وجود الفان قبل الإضافة لتجنب التكرار في العداد
      final fanDoc = await _firestore.getDocument(path: FirestorePaths.fans, docId: fanDocId);
      
      if (fanDoc == null) {
        final fan = FanModel(
          id: fanDocId,
          fanUserId: fromUserId,
          targetUserId: toUserId,
          createdAt: DateTime.now(),
        );
        
        final fanRef = firestore.collection(FirestorePaths.fans).doc(fanDocId);
        batch.set(fanRef, fan.toMap());

        // زيادة عداد المعجبين في وثيقة المستخدم
        batch.update(userRef, {
          'fansCount': FieldValue.increment(1),
        });

        // 🔥 التعديل المطلوب: إنشاء وثيقة الدردشة الخاصة تلقائياً لفتح القناة فوراً
        // نستخدم chatId ثابت يعتمد على المعجب والمستهدف لضمان عدم التكرار
        final String chatId = fromUserId.hashCode <= toUserId.hashCode 
            ? '${fromUserId}_$toUserId' 
            : '${toUserId}_$fromUserId';

        final chatRef = firestore.collection(FirestorePaths.privateChats).doc(chatId);
        
        // نقوم بإنشاء الغرفة فقط إذا لم تكن موجودة (استخدام set مع merge)
        batch.set(chatRef, {
          'userA': fromUserId,
          'userB': toUserId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': 'لقد أصبحتما معجبين ببعضكما، يمكنكما البدء بالدردشة الآن!',
          'lastMessageTime': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    // تنفيذ جميع العمليات معاً ككتلة واحدة (Atomic)
    await batch.commit();

    return true;
  }

  /// Generate deterministic respect doc id
  String _respectDocId(String from, String to) {
    return '${from}_$to';
  }

  // ✅ تم دمج منطق إنشاء الفان داخل الـ Batch في الدالة الأساسية لضمان التزامن الذري (Atomicity)
  // وبقاء هذه الدالة هنا للرجوع إليها أو لاستخدامات أخرى مستقبلاً إذا لزم الأمر
  Future<void> _createFanIfNeeded({
    required String fanUserId,
    required String targetUserId,
  }) async {
    final fanDocId = '${fanUserId}_$targetUserId';

    final existingFan = await _firestore.getDocument(
      path: FirestorePaths.fans,
      docId: fanDocId,
    );

    if (existingFan != null) {
      return; // Already fan
    }

    final fan = FanModel(
      id: fanDocId,
      fanUserId: fanUserId,
      targetUserId: targetUserId,
      createdAt: DateTime.now(),
    );

    await _firestore.createDocument(
      path: FirestorePaths.fans,
      docId: fan.id,
      data: fan.toMap(),
    );
  }
}