// lib/core/logic/respect_logic.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/respect_model.dart';
import '../../models/fan_model.dart';
import '../../services/firebase/firestore_service.dart';
import '../../providers/notifications_provider.dart';
import '../constants/firestore_paths.dart';
import '../constants/limits.dart';

/// ✅ نتيجة عملية منح/تعديل نقاط الاحترام
/// previousValue == null  → كانت هذه أول مرة (لا يوجد تقييم سابق)
/// previousValue != null  → كان هناك تقييم سابق وتم استبداله بالقيمة الجديدة
class RateUserResult {
  final int newValue;
  final int? previousValue;
  final bool becameFan; // ✅ true فقط لو تجاوز العتبة لأول مرة في هذه العملية

  const RateUserResult({
    required this.newValue,
    required this.previousValue,
    required this.becameFan,
  });

  bool get isFirstTime => previousValue == null;
  bool get isNoOp => previousValue != null && previousValue == newValue;
}

class RespectLogic {
  final FirestoreService _firestore;
  final NotificationsProvider? notificationsProvider;

  RespectLogic(this._firestore, {this.notificationsProvider});

  /// ✅✅✅ تعديل جوهري: rateUser أصبح يدعم "استبدال" القيمة بدل الرفض.
  /// - لو لا يوجد تقييم سابق: يُنشئ وثيقة جديدة ويزيد totalRespect بالقيمة كاملة.
  /// - لو يوجد تقييم سابق: يُحدّث الوثيقة بالقيمة الجديدة فقط (set كامل/overwrite،
  ///   لا merge على value)، ويُحدّث totalRespect بالـ delta (الفرق بين الجديدة
  ///   والقديمة) عبر FieldValue.increment(delta) — هذا يضمن أن "5 تستبدل 4"
  ///   تصبح +1 فقط على totalRespect، لا +5.
  /// - fansCount/الانضمام كمعجب: يُحتسب فقط إذا كانت القيمة الجديدة عابرة
  ///   لـ fanThreshold والقيمة القديمة (أو غيابها) لم تكن عابرة لها من قبل،
  ///   حتى لا يتكرر احتساب "معجب" مع كل تعديل لاحق على تقييم عابر بالفعل.
  /// - لو القيمة الجديدة == القديمة بالضبط: لا تتم أي كتابة على الإطلاق.
  Future<RateUserResult> rateUser({
    required String fromUserId,
    required String toUserId,
    required int respectValue,
    String? fromUsername,
  }) async {
    if (fromUserId == toUserId) {
      throw Exception('لا يمكن أن تمنح نفسك نقاط إحترام.');
    }

    if (respectValue < Limits.respectMin.toInt() ||
        respectValue > Limits.respectMax.toInt()) {
      throw Exception(
          'نقاط الإحترام يجب أن تكون بين ${Limits.respectMin} و ${Limits.respectMax}.');
    }

    final respectId = _respectDocId(fromUserId, toUserId);

    final existingDoc = await _firestore.getDocument(
      path: FirestorePaths.respects,
      docId: respectId,
    );

    final int? previousValue = existingDoc != null
        ? RespectModel.fromMap(existingDoc, respectId).value
        : null;

    // ✅ نفس القيمة بالضبط — لا حاجة لأي كتابة
    if (previousValue != null && previousValue == respectValue) {
      return RateUserResult(
        newValue: respectValue,
        previousValue: previousValue,
        becameFan: false,
      );
    }

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    final respect = RespectModel(
      id: respectId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      value: respectValue,
      createdAt: DateTime.now(),
    );

    final respectRef =
        firestore.collection(FirestorePaths.respects).doc(respectId);
    // ✅ set كامل (overwrite) — القيمة الجديدة تستبدل القديمة بالكامل،
    // تمامًا كما طُلب (4 ثم 5 تصبح 5 فقط، وليست 9)
    batch.set(respectRef, respect.toMap());

    final userRef = firestore.collection(FirestorePaths.users).doc(toUserId);

    // ✅ الـ delta فقط يُضاف لـ totalRespect:
    // - أول مرة (previousValue == null): الـ delta = القيمة كاملة
    // - تعديل: الـ delta = الجديدة - القديمة (قد تكون سالبة لو قلّت القيمة)
    final int delta = respectValue - (previousValue ?? 0);
    batch.update(userRef, {
      'totalRespect': FieldValue.increment(delta),
    });

    // ✅ تحديد ما إذا كانت هذه أول مرة "يعبر" فيها التقييم لعتبة المعجبين
    final bool wasFanBefore =
        previousValue != null && previousValue > Limits.fanThreshold.toInt();
    final bool isFanNow = respectValue > Limits.fanThreshold.toInt();
    final bool becameFanNow = isFanNow && !wasFanBefore;

    if (becameFanNow) {
      final fanDocId = '${fromUserId}_$toUserId';
      final fanDoc = await _firestore.getDocument(
          path: FirestorePaths.fans, docId: fanDocId);

      // ✅ نتأكد كذلك أن وثيقة fans غير موجودة فعليًا (حماية إضافية من
      // عدم تزامن نادر بين totalRespect وقيمة respect نفسها)
      if (fanDoc == null) {
        final fan = FanModel(
          id: fanDocId,
          fanUserId: fromUserId,
          targetUserId: toUserId,
          createdAt: DateTime.now(),
        );

        final fanRef =
            firestore.collection(FirestorePaths.fans).doc(fanDocId);
        batch.set(fanRef, fan.toMap());

        batch.update(userRef, {
          'fansCount': FieldValue.increment(1),
        });

        final String chatId = fromUserId.hashCode <= toUserId.hashCode
            ? '${fromUserId}_$toUserId'
            : '${toUserId}_$fromUserId';

        final chatRef =
            firestore.collection(FirestorePaths.privateChats).doc(chatId);

        batch.set(chatRef, {
          'userA': fromUserId,
          'userB': toUserId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage':
              'لقد أصبحتما معجبين ببعضكما، يمكنكما البدء بالدردشة الآن!',
          'lastMessageTime': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await batch.commit();

    // ✅ إشعار الاحترام بعد commit ناجح (لكل عملية منح/تعديل، أول مرة أو لاحقًا)
    if (notificationsProvider != null) {
      notificationsProvider!.createRespectNotification(
        toUserId: toUserId,
        fromUserId: fromUserId,
        fromUsername: fromUsername ?? 'مستخدم',
        respectValue: respectValue,
      );
    }

    return RateUserResult(
      newValue: respectValue,
      previousValue: previousValue,
      becameFan: becameFanNow,
    );
  }

  /// ✅ جديد: جلب القيمة السابقة فقط (بدون أي كتابة) — تُستخدم قبل فتح
  /// RespectModal لمعرفة هل سبق منح هذا العضو نقاط احترام أم لا.
  Future<int?> getPreviousRespectValue({
    required String fromUserId,
    required String toUserId,
  }) async {
    final respectId = _respectDocId(fromUserId, toUserId);
    final existingDoc = await _firestore.getDocument(
      path: FirestorePaths.respects,
      docId: respectId,
    );

    if (existingDoc == null) return null;

    return RespectModel.fromMap(existingDoc, respectId).value;
  }

  String _respectDocId(String from, String to) => '${from}_$to';
}