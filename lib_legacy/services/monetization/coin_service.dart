import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/store_constants.dart';
import 'package:pubget/models/wallet_tarnsaction_model.dart';

class CoinService {
  final _db = FirebaseFirestore.instance;
  final _uuid = Uuid();

  // ✅ الفوز في الفعالية - 3 مرات يومياً كحد أقصى
  Future<bool> rewardEventWin({required String userId, required String gameId}) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final userRef = _db.collection('users').doc(userId);
    final dailyRef = userRef.collection('daily_rewards').doc('event_$today');
    final txRef = userRef.collection('transactions').doc(gameId);

    return await _db.runTransaction((tx) async {
      final existing = await tx.get(txRef);
      if (existing.exists) return false; // نفس اللعبة

      final dailySnap = await tx.get(dailyRef);
      final count = dailySnap.exists? (dailySnap.data()?['count']?? 0) : 0;
      if (count >= StoreConstants.maxEventWinsPerDay) return false; // وصل للحد

      tx.update(userRef, {'coinsBalance': FieldValue.increment(StoreConstants.rewardEventWin)});
      tx.set(dailyRef, {
        'count': count + 1,
        'date': today,
        'lastUpdate': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));

      final model = WalletTransactionModel(
        id: gameId,
        amount: StoreConstants.rewardEventWin,
        type: 'event_win',
        timestamp: DateTime.now(),
        description: 'الفوز في فعالية ($count+1/3 اليوم)',
      );
      tx.set(txRef, model.toMap());

      return true;
    });
  }

  // ✅ مكافأة الدعوة - 70 للداعي و 30 للمدعو
  Future<void> rewardReferral({required String inviterId, required String newUserId}) async {
    if (inviterId == newUserId) return;

    final inviterRef = _db.collection('users').doc(inviterId);
    final newUserRef = _db.collection('users').doc(newUserId);

    await _db.runTransaction((tx) async {
      final newUserSnap = await tx.get(newUserRef);

      if (!newUserSnap.exists) return;
      final hasClaimed = newUserSnap.data()?['hasClaimedReferral']?? false;
      if (hasClaimed == true) return;

      tx.update(inviterRef, {'coinsBalance': FieldValue.increment(StoreConstants.rewardInviter)});

      tx.update(newUserRef, {
        'coinsBalance': FieldValue.increment(StoreConstants.rewardInvited),
        'hasClaimedReferral': true,
        'invitedBy': inviterId,
      });

      final tx1 = WalletTransactionModel(
        id: _uuid.v4(),
        amount: StoreConstants.rewardInviter,
        type: 'referral_inviter',
        timestamp: DateTime.now(),
        description: 'دعوة صديق جديد'
      );
      final tx2 = WalletTransactionModel(
        id: _uuid.v4(),
        amount: StoreConstants.rewardInvited,
        type: 'referral_invited',
        timestamp: DateTime.now(),
        description: 'مكافأة التسجيل عبر دعوة'
      );

      tx.set(inviterRef.collection('transactions').doc(tx1.id), tx1.toMap());
      tx.set(newUserRef.collection('transactions').doc(tx2.id), tx2.toMap());
    });
  }

  // ✅ نشر إديت - مرة واحدة يومياً
  Future<bool> rewardForPublishingEdit({required String userId}) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final userRef = _db.collection('users').doc(userId);
    final dailyRef = userRef.collection('daily_rewards').doc('edit_$today');

    return await _db.runTransaction((tx) async {
      final dailySnap = await tx.get(dailyRef);
      if (dailySnap.exists) return false; // نشر اليوم بالفعل

      tx.update(userRef, {'coinsBalance': FieldValue.increment(StoreConstants.rewardPublishEdit)});
      tx.set(dailyRef, {
        'count': 1,
        'date': today,
        'timestamp': FieldValue.serverTimestamp()
      });

      final model = WalletTransactionModel(
        id: _uuid.v4(),
        amount: StoreConstants.rewardPublishEdit,
        type: 'publish_edit',
        timestamp: DateTime.now(),
        description: 'نشر مقطع إديت جديد',
      );
      tx.set(userRef.collection('transactions').doc(model.id), model.toMap());

      return true;
    });
  }
}
