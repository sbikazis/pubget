import 'package:firebase_auth/firebase_auth.dart';

class R2AuthHelper {
  R2AuthHelper._();

  static Future<String?> getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getIdTokenForceRefresh() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken(true);
    } catch (_) {
      return null;
    }
  }
}
