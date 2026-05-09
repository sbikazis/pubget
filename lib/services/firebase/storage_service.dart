import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  /// ==============================
  /// INTERNAL GENERIC UPLOAD
  /// ==============================
  Future<String> _uploadFile({
    required File file,
    required String path,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploadedBy': _uid},
      );

      await ref.putFile(file, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      print("FIREBASE UPLOAD ERROR: $e");
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