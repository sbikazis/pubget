//SubscriptionService
import 'package:pubget/services/firebase/firestore_service.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/subscription_type.dart';

class SubscriptionService {
  final FirestoreService _firestore;

  SubscriptionService(this._firestore);

  // =========================================================
  //  ACTIVATE MONTHLY PREMIUM
  // =========================================================

  Future<void> purchasePremium({
    required String userId,
  }) async {
    final now = DateTime.now();

    final expiresAt = DateTime(
      now.year,
      now.month + 1,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );

    await _firestore.updateDocument(
      path: FirestorePaths.users,
      docId: userId,
      data: {
        'subscriptionType': SubscriptionType.premium.name,
        'premiumStartedAt': now,
        'premiumExpiresAt': expiresAt,
        'updatedAt': now,
      },
    );
  }

  // =========================================================
  //  CHECK CURRENT SUBSCRIPTION STATUS
  // =========================================================

  Future<SubscriptionType> getSubscriptionStatus({
    required String userId,
  }) async {
    final data = await _firestore.getDocument(
      path: FirestorePaths.users,
      docId: userId,
    );

    if (data == null) {
      return SubscriptionType.free;
    }

    final typeString = data['subscriptionType'] as String?;
    final expiresAt = data['premiumExpiresAt'];

    if (typeString == null ||
        typeString != SubscriptionType.premium.name ||
        expiresAt == null) {
      return SubscriptionType.free;
    }

    final expiryDate = (expiresAt as dynamic).toDate();

    if (DateTime.now().isAfter(expiryDate)) {
      await downgradeToFree(userId: userId);
      return SubscriptionType.free;
    }

    return SubscriptionType.premium;
  }

  // =========================================================
  //  RENEW PREMIUM (ADD ONE MONTH)
  // =========================================================

  Future<void> renewPremium({
    required String userId,
  }) async {
    final data = await _firestore.getDocument(
      path: FirestorePaths.users,
      docId: userId,
    );

    if (data == null) return;

    final currentExpiry = data['premiumExpiresAt']?.toDate();

    final baseDate = currentExpiry != null &&
            currentExpiry.isAfter(DateTime.now())
        ? currentExpiry
        : DateTime.now();

    final newExpiry = DateTime(
      baseDate.year,
      baseDate.month + 1,
      baseDate.day,
      baseDate.hour,
      baseDate.minute,
      baseDate.second,
    );

    await _firestore.updateDocument(
      path: FirestorePaths.users,
      docId: userId,
      data: {
        'subscriptionType': SubscriptionType.premium.name,
        'premiumExpiresAt': newExpiry,
        'updatedAt': DateTime.now(),
      },
    );
  }

  // =========================================================
  //  DOWNGRADE TO FREE
  // =========================================================

  Future<void> downgradeToFree({
    required String userId,
  }) async {
    await _firestore.updateDocument(
      path: FirestorePaths.users,
      docId: userId,
      data: {
        'subscriptionType': SubscriptionType.free.name,
        'premiumStartedAt': null,
        'premiumExpiresAt': null,
        'updatedAt': DateTime.now(),
      },
    );
  }

  // =========================================================
  //  RESTORE (FUTURE GOOGLE PLAY SUPPORT)
  // =========================================================

  Future<SubscriptionType> restorePurchase({
    required String userId,
  }) async {
    return await getSubscriptionStatus(userId: userId);
  }
}