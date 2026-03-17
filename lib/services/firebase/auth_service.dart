import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_model.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/constants/subscription_type.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth;
  final FirestoreService _firestore;

  AuthService({
    FirebaseAuth? auth,
    required FirestoreService firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore;

  // =========================================================
  // REGISTER
  // =========================================================

  Future<UserModel> register({
    required String email,
    required String password,
  }) async {
    final credential =
        await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw Exception('فشل التسجيل/Registraction failed');
    }

    return await _createInitialUserData(firebaseUser);
  }

  // =========================================================
  // LOGIN
  // =========================================================

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final credential =
        await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw Exception('فشل تسجيل الدخول / Login failed');
    }

    final doc = await _firestore.getDocument(
      path: FirestorePaths.users,
      docId: firebaseUser.uid,
    );

    if (doc == null) {
      throw Exception('تعذر  إيجاد بيانات المستخدم / User data not found');
    }

    final user =
        UserModel.fromMap(doc, firebaseUser.uid);

    if (user.isBanned) {
      await logout();
      throw Exception('المستخدم محظور / User is banned');
    }

    return user;
  }

  // =========================================================
  // GOOGLE SIGN IN
  // =========================================================

  Future<UserModel> signInWithGoogle() async {
    final googleProvider = GoogleAuthProvider();

    final credential =
        await _auth.signInWithProvider(googleProvider);

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw Exception('فشل تسجيل الدخول عن طريق حساب جوجل / Google sign-in failed');
    }

    final existingDoc =
        await _firestore.getDocument(
      path: FirestorePaths.users,
      docId: firebaseUser.uid,
    );

    if (existingDoc != null) {
      return UserModel.fromMap(
          existingDoc, firebaseUser.uid);
    }

    return await _createInitialUserData(firebaseUser);
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> logout() async {
    await _auth.signOut();
  }

  // =========================================================
  // CREATE INITIAL USER DOCUMENT
  // =========================================================

  Future<UserModel> _createInitialUserData(
    User firebaseUser,
  ) async {
    final now = DateTime.now();

    final user = UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',

      username: '',
      nickname: null,

      avatarUrl: '',
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

    await _firestore.createDocument(
      path: FirestorePaths.users,
      docId: firebaseUser.uid,
      data: user.toMap(),
    );

    return user;
  }
}