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
  /// - true  => rating successful
  /// - false => already rated
  Future<bool> rateUser({
    required String fromUserId,
    required String toUserId,
    required int respectValue,
  }) async {
    //  Prevent self rating
    if (fromUserId == toUserId) {
      throw Exception('لا يمكن أن تمنح نفسك نقاط إحترام .');
    }

    //  Validate range
    if (respectValue < Limits.respectMin ||
        respectValue > Limits.respectMax) {
      throw Exception('نقاط الإحترام يجب أن تكون بين 0 و 7 .');
    }

    //  Check if already rated
    final existing = await _firestore.getDocument(
      path: FirestorePaths.respects,
      docId: _respectDocId(fromUserId, toUserId),
    );

    if (existing != null) {
      return false; // Already rated
    }

    //  Create RespectModel
    final respect = RespectModel(
      id: _respectDocId(fromUserId, toUserId),
      fromUserId: fromUserId,
      toUserId: toUserId,
      value: respectValue,
      createdAt: DateTime.now(),
    );

    await _firestore.createDocument(
      path: FirestorePaths.respects,
      docId: respect.id,
      data: respect.toMap(),
    );

    //  Create Fan if threshold passed
    if (respectValue > Limits.fanThreshold) {
      await _createFanIfNeeded(
        fanUserId: fromUserId,
        targetUserId: toUserId,
      );
    }

    return true;
  }

  /// Generate deterministic respect doc id
  String _respectDocId(String from, String to) {
    return '${from}_$to';
  }

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