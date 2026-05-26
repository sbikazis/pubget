// lib/services/firebase/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/constants/subscription_type.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirestoreService _firestore;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthService({
    FirebaseAuth? auth,
    required FirestoreService firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore;

  // =========================================================
  // GOOGLE SIGN IN
  // =========================================================
  Future<UserModel> signInWithGoogle({String? referrerId}) async {
    try {
      final googleProvider = GoogleAuthProvider();
      final userCredential = await _auth.signInWithProvider(googleProvider);
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('فشل تسجيل الدخول عن طريق حساب جوجل / Google sign-in failed');
      }

      final existingDoc = await _firestore.getDocument(
        path: FirestorePaths.users,
        docId: firebaseUser.uid,
      );

      if (existingDoc != null) {
        final user = UserModel.fromMap(existingDoc, firebaseUser.uid);
        if (user.isBanned) {
          await logout();
          throw Exception('المستخدم محظور / User is banned');
        }
        return user;
      }

      // إذا كان مستخدم جديد، نقوم بإنشاء مستنده والتحقق من كود الداعي عبر الـ Transaction
      return await _createInitialUserData(firebaseUser, referrerId: referrerId);
    } catch (e) {
      rethrow;
    }
  }

  // =========================================================
  // REGISTER (Email & Password)
  // =========================================================
  Future<UserModel> register({
    required String email,
    required String password,
    String? referrerId,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final firebaseUser = credential.user;
    if (firebaseUser == null) throw Exception('فشل إنشاء الحساب / Register failed');

    return await _createInitialUserData(firebaseUser, referrerId: referrerId);
  }

  // =========================================================
  // LOGIN (Email & Password)
  // =========================================================
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final firebaseUser = credential.user;
    if (firebaseUser == null) throw Exception('فشل تسجيل الدخول / Login failed');

    final doc = await _firestore.getDocument(
      path: FirestorePaths.users,
      docId: firebaseUser.uid,
    );
    if (doc == null) throw Exception('تعذر إيجاد بيانات المستخدم / User data not found');

    final user = UserModel.fromMap(doc, firebaseUser.uid);
    if (user.isBanned) {
      await logout();
      throw Exception('المستخدم محظور / User is banned');
    }

    return user;
  }

  // =========================================================
  // LOGOUT
  // =========================================================
  Future<void> logout() async {
    await _auth.signOut();
  }

  // =========================================================
  // CREATE INITIAL USER DOCUMENT (مع معالجة الإحالة الصارمة)
  // =========================================================
  Future<UserModel> _createInitialUserData(User firebaseUser, {String? referrerId}) async {
    final now = DateTime.now();

    final user = UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      username: '',
      nickname: null,
      avatarUrl: firebaseUser.photoURL ?? '',
      bio: '',
      favoriteAnimes: [],
      age: null,
      country: null,
      subscriptionType: SubscriptionType.free,
      totalRespect: 0,
      fansCount: 0,
      isProfileCompleted: false,
      isBanned: false,
      createdAt: now,
      updatedAt: now,
    );

    // التحقق الفني لمنع المستخدم من إحالة نفسه أو إذا كان كود الداعي فارغاً
    if (referrerId == null || referrerId.isEmpty || referrerId == firebaseUser.uid) {
      await _firestore.createDocument(
        path: FirestorePaths.users,
        docId: firebaseUser.uid,
        data: user.toMap(),
      );
      return user;
    }

    // 🛡️ تفعيل المعاملة الذرية (Firestore Transaction) لحقن المكافآت بالتزامن
    await _db.runTransaction((transaction) async {
      final referrerDocRef = _db.collection(FirestorePaths.users).doc(referrerId);
      final newUserDocRef = _db.collection(FirestorePaths.users).doc(firebaseUser.uid);

      final referrerSnapshot = await transaction.get(referrerDocRef);

      if (referrerSnapshot.exists) {
        final userData = user.toMap();
        userData['coins'] = (userData['coins'] ?? 0) + 30; // منح المدعو 30 عملة
        userData['referredBy'] = referrerId;
        
        transaction.set(newUserDocRef, userData);

        final currentReferrerCoins = referrerSnapshot.data()?['coins'] ?? 0;
        transaction.update(referrerDocRef, {
          'coins': currentReferrerCoins + 70, // منح الداعي 70 عملة بالتزامن
        });

        // توثيق العملية مالياً في مستندات الـ Transactions لمنع التلاعب
        final transactionDocRef = _db.collection('wallet_transactions').doc();
        transaction.set(transactionDocRef, {
          'id': transactionDocRef.id,
          'type': 'referral_reward',
          'amount': 70,
          'userId': referrerId,
          'receiverId': firebaseUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'description': '🎯 مكافأة دعوة مستخدم جديد للتطبيق بنجاح',
        });
      } else {
        // في حال عدم وجود مستند حقيقي للداعي يتم إنشاء مستند المدعو العادي
        transaction.set(newUserDocRef, user.toMap());
      }
    });

    return user;
  }

  // =========================================================
  // GET CURRENT USER (AUTO LOGIN)
  // =========================================================
  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    final doc = await _firestore.getDocument(
      path: FirestorePaths.users,
      docId: firebaseUser.uid,
    );
    if (doc == null) return null;

    final user = UserModel.fromMap(doc, firebaseUser.uid);
    if (user.isBanned) {
      await logout();
      return null;
    }

    return user;
  }
}
