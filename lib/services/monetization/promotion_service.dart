import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:pubget/services/firebase/firestore_service.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../models/group_model.dart';

class PromotionService {
  final FirestoreService _firestore;

  PromotionService(this._firestore);

  // =========================================================
  //  PROMOTE GROUP
  // =========================================================

  Future<void> promoteGroup({
    required String groupId,
    required String promoterUserId,
    int durationInDays = 3,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(Duration(days: durationInDays));

    final promotionId = '${groupId}_$now';

    await _firestore.runBatch((batch) async {
      final firestoreInstance = FirebaseFirestore.instance;

      //  Create promotion record
      final promotionRef = firestoreInstance
          .collection(FirestorePaths.promotions)
          .doc(promotionId);

      batch.set(promotionRef, {
        'groupId': groupId,
        'promoterUserId': promoterUserId,
        'startedAt': now,
        'expiresAt': expiresAt,
        'createdAt': now,
      });

      //  Update group promotion status
      final groupRef = firestoreInstance
          .collection(FirestorePaths.groups)
          .doc(groupId);

      batch.update(groupRef, {
        'isPromoted': true,
        'promotionExpiresAt': expiresAt,
      });
    });
  }

  // =========================================================
  //  GET ACTIVE PROMOTED GROUPS
  // =========================================================

  Stream<List<GroupModel>> getPromotedGroups() {
    final now = DateTime.now();

    final query = _firestore.buildQuery(
      path: FirestorePaths.groups,
      conditions: [
        QueryCondition(
          field: 'isPromoted',
          isEqualTo: true,
        ),
      ],
      orderBy: 'promotionExpiresAt',
      descending: true,
    );

    return _firestore.streamCollection(
      path: FirestorePaths.groups,
      query: query,
    ).map((snapshot) {
      return snapshot.docs
          .map((doc) => GroupModel.fromMap(doc.id, doc.data()))
          .where((group) =>
              group.promotionExpiresAt != null &&
              group.promotionExpiresAt!.isAfter(now))
          .toList();
    });
  }

  // =========================================================
  //  CLEAN EXPIRED PROMOTIONS
  // =========================================================

  Future<void> cleanExpiredPromotions() async {
    final now = DateTime.now();

    final query = _firestore.buildQuery(
      path: FirestorePaths.groups,
      conditions: [
        QueryCondition(
          field: 'isPromoted',
          isEqualTo: true,
        ),
      ],
    );

    final snapshot = await _firestore.getCollection(
      path: FirestorePaths.groups,
      query: query,
    );

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final expiresAt = data['promotionExpiresAt'];

      if (expiresAt != null &&
          (expiresAt as Timestamp).toDate().isBefore(now)) {
        await _firestore.updateDocument(
          path: FirestorePaths.groups,
          docId: doc.id,
          data: {
            'isPromoted': false,
            'promotionExpiresAt': null,
          },
        );
      }
    }
  }
}