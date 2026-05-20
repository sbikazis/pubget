import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  /// ==============================
  /// INTERNAL GENERIC UPLOAD - نسخة آمنة
  /// ==============================
  Future<String> _uploadFile({
    required File file,
    required String path,
  }) async {
    try {
      // 1. تأكد المستخدم مسجل
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('AUTH_NULL: المستخدم غير مسجل دخول');
      }

      // 2. تأكد الملف موجود
      if (!await file.exists()) {
        throw Exception('FILE_NOT_FOUND: ${file.path}');
      }

      final fileSize = await file.length();
      print('STORAGE UPLOAD: $path | ${(fileSize/1024).toStringAsFixed(1)}KB | uid=$uid');

      final ref = _storage.ref().child(path);
      
      // 3. حدد نوع الصورة تلقائياً
      final ext = p.extension(file.path).toLowerCase();
      final contentType = ext == '.png' ? 'image/png' 
                         : ext == '.webp' ? 'image/webp'
                         : ext == '.gif' ? 'image/gif'
                         : 'image/jpeg';

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {'uploadedBy': uid},
      );

      await ref.putFile(file, metadata);
      final url = await ref.getDownloadURL();
      
      print('STORAGE SUCCESS: $url');
      return url;
      
    } catch (e, stack) {
      print("FIREBASE UPLOAD ERROR: $e");
      print("STACK: $stack");
      rethrow;
    }
  }

  /// ==============================
  /// USER AVATAR
  /// ==============================
  Future<String> uploadUserAvatar({
    required String userId,
    required File file,
  }) async {
    final path = "avatars/$userId.jpg";
    return _uploadFile(file: file, path: path);
  }

  /// ==============================
  /// GROUP IMAGE
  /// ==============================
  Future<String> uploadGroupImage({
    required String groupId,
    required File file,
  }) async {
    final path = "groups/$groupId.jpg";
    return _uploadFile(file: file, path: path);
  }

  /// ==============================
  /// ROLEPLAY CHARACTER IMAGE
  /// ==============================
  Future<String> uploadRoleplayCharacterImage({
    required String groupId,
    required String userId,
    required File file,
  }) async {
    final path = "groups/$groupId/characters/$userId.jpg";
    return _uploadFile(file: file, path: path);
  }

  /// ==============================
  /// GROUP CHAT MEDIA
  /// ==============================
  Future<String> uploadGroupChatMedia({
    required String groupId,
    required String messageId,
    required File file,
  }) async {
    final path = "groups/$groupId/chat/$messageId.jpg";
    return _uploadFile(file: file, path: path);
  }

  /// ==============================
  /// PRIVATE CHAT MEDIA
  /// ==============================
  Future<String> uploadPrivateChatMedia({
    required String chatId,
    required String messageId,
    required File file,
  }) async {
    final path = "private_chats/$chatId/$messageId.jpg";
    return _uploadFile(file: file, path: path);
  }

  /// ==============================
  /// DELETE FILE
  /// ==============================
  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      print("DELETE ERROR: $e");
    }
  }
}