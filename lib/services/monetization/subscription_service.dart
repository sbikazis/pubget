// lib/services/monetization/subscription_service.dart
import 'package:pubget/services/firebase/firestore_service.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/constants/subscription_type.dart';
import '../../../core/constants/store_constants.dart';

class SubscriptionService {
  final FirestoreService _firestore;

  SubscriptionService(this._firestore);

  Future<void> purchasePremium({required String userId}) async {
    final now = DateTime.now();
    final expiresAt = now.add(Duration(days: StoreConstants.premiumDurationDays));

    await _firestore.updateDocument(
      path: FirestorePaths.users,
      docId: userId,
      data: {
        'subscriptionType': SubscriptionType.premium.name,
        'premiumSince': now,
        'premiumExpiresAt': expiresAt,
        'autoRenewPremium': true,
        'updatedAt': now,
      },
    );
  }

  Future<SubscriptionType> getSubscriptionStatus({required String userId}) async {
    final data = await _firestore.getDocument(path: FirestorePaths.users, docId: userId);
    if (data == null) return SubscriptionType.free;

    final typeString = data['subscriptionType'] as String?;
    final expiresAt = data['premiumExpiresAt'];

    if (typeString != SubscriptionType.premium.name || expiresAt == null) {
      return SubscriptionType.free;
    }

    final expiryDate = (expiresAt as dynamic).toDate();
    if (DateTime.now().isAfter(expiryDate)) {
      await downgradeToFree(userId: userId);
      return SubscriptionType.free;
    }
    return SubscriptionType.premium;
  }

  Future<void> renewPremium({required String userId}) async {
    final data = await _firestore.getDocument(path: FirestorePaths.users, docId: userId);
    if (data == null) return;

    final currentExpiry = data['premiumExpiresAt']?.toDate();
    final baseDate = (currentExpiry != null && currentExpiry.isAfter(DateTime.now())) ? currentExpiry : DateTime.now();
    final newExpiry = baseDate.add(Duration(days: StoreConstants.premiumDurationDays));

    await _firestore.updateDocument(
      path: FirestorePaths.users,
      docId: userId,
      data: {
        'premiumExpiresAt': newExpiry,
        'updatedAt': DateTime.now(),
      },
    );
  }

  Future<void> downgradeToFree({required String userId}) async {
    await _firestore.updateDocument(
      path: FirestorePaths.users,
      docId: userId,
      data: {
        'subscriptionType': SubscriptionType.free.name,
        'premiumSince': null,
        'premiumExpiresAt': null,
        'autoRenewPremium': false,
        'updatedAt': DateTime.now(),
      },
    );
  }

  // ✅ دالة التجديد التلقائي الجديدة
  Future<void> autoRenewIfNeeded(String userId) async {
    final data = await _firestore.getDocument(path: FirestorePaths.users, docId: userId);
    if (data == null) return;

    final autoRenew = data['autoRenewPremium'] ?? false;
    final expiresAt = data['premiumExpiresAt'];
    final type = data['subscriptionType'];

    if (type != SubscriptionType.premium.name || !autoRenew || expiresAt == null) return;

    final expiryDate = (expiresAt as dynamic).toDate();
    if (DateTime.now().isBefore(expiryDate)) return; // لم ينته بعد

    final coins = data['coinsBalance'] ?? 0;
    if (coins >= StoreConstants.premiumSubscriptionPrice) {
      // خصم 900 وتجديد
      final newExpiry = DateTime.now().add(Duration(days: StoreConstants.premiumDurationDays));
      await _firestore.updateDocument(
        path: FirestorePaths.users,
        docId: userId,
        data: {
          'coinsBalance': coins - StoreConstants.premiumSubscriptionPrice,
          'premiumExpiresAt': newExpiry,
          'updatedAt': DateTime.now(),
        },
      );
    } else {
      // رصيد غير كافي - إلغاء تلقائي
      await downgradeToFree(userId: userId);
    }
  }

  Future<SubscriptionType> restorePurchase({required String userId}) async {
    return await getSubscriptionStatus(userId: userId);
  }
}