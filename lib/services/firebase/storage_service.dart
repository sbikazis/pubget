import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../../core/constants/storage_paths.dart';

class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// ==============================
  /// INTERNAL GENERIC UPLOAD METHOD
  /// ==============================

  Future<String> _uploadFile({
    required File file,
    required String path,
  }) async {
    final ref = _storage.ref().child(path);

    final uploadTask = await ref.putFile(file);

    final downloadUrl = await uploadTask.ref.getDownloadURL();

    return downloadUrl;
  }

  /// ==============================
  /// USER AVATAR
  /// ==============================

  Future<String> uploadUserAvatar({
    required String userId,
    required File file,
  }) async {
    final path = StoragePaths.userAvatar(userId);

    return _uploadFile(
      file: file,
      path: path,
    );
  }

  /// ==============================
  /// GROUP IMAGE
  /// ==============================

  Future<String> uploadGroupImage({
    required String groupId,
    required File file,
  }) async {
    final path = StoragePaths.groupImage(groupId);

    return _uploadFile(
      file: file,
      path: path,
    );
  }

  /// ==============================
  /// ROLEPLAY CHARACTER IMAGE
  /// ==============================

  Future<String> uploadRoleplayCharacterImage({
    required String groupId,
    required String userId,
    required File file,
  }) async {
    final path = StoragePaths.roleplayCharacterImage(
      groupId,
      userId,
    );

    return _uploadFile(
      file: file,
      path: path,
    );
  }

  /// ==============================
  /// GROUP CHAT MEDIA
  /// ==============================

  Future<String> uploadGroupChatMedia({
    required String groupId,
    required String messageId,
    required File file,
  }) async {
    final path = StoragePaths.groupChatMedia(
      groupId,
      messageId,
    );

    return _uploadFile(
      file: file,
      path: path,
    );
  }

  /// ==============================
  /// PRIVATE CHAT MEDIA
  /// ==============================

  Future<String> uploadPrivateChatMedia({
    required String chatId,
    required String messageId,
    required File file,
  }) async {
    final path = StoragePaths.privateChatMedia(
      chatId,
      messageId,
    );

    return _uploadFile(
      file: file,
      path: path,
    );
  }

  /// ==============================
  /// DELETE FILE
  /// ==============================

  Future<void> deleteFile(String path) async {
    final ref = _storage.ref().child(path);
    await ref.delete();
  }
}