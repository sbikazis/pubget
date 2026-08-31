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
      
      final contentType = await _detectContentType(file);

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

  /// Detect the actual media format where its signature is available.  This
  /// avoids declaring every upload as JPEG (which is rejected by the strict
  /// media rules for audio/video).
  Future<String> _detectContentType(File file) async {
    final header = await file.openRead(0, 32).fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes.length >= 32
          ? bytes
          : <int>[...bytes, ...chunk].take(32).toList(),
    );
    final ext = p.extension(file.path).toLowerCase();
    bool startsWith(List<int> signature) =>
        header.length >= signature.length &&
        signature.asMap().entries.every((entry) => header[entry.key] == entry.value);
    String? ftypBrand() => header.length >= 12 &&
            header[4] == 0x66 &&
            header[5] == 0x74 &&
            header[6] == 0x79 &&
            header[7] == 0x70
        ? String.fromCharCodes(header.sublist(8, 12))
        : null;

    if (startsWith([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (startsWith([0x89, 0x50, 0x4E, 0x47])) return 'image/png';
    if (startsWith([0x47, 0x49, 0x46, 0x38])) return 'image/gif';
    if (startsWith([0x52, 0x49, 0x46, 0x46]) &&
        header.length >= 12 &&
        String.fromCharCodes(header.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    if (startsWith([0x4F, 0x67, 0x67, 0x53])) return 'audio/ogg';
    if (startsWith([0x52, 0x49, 0x46, 0x46]) &&
        header.length >= 12 &&
        String.fromCharCodes(header.sublist(8, 12)) == 'WAVE') {
      return 'audio/wav';
    }
    if (startsWith([0x1A, 0x45, 0xDF, 0xA3])) return 'video/webm';
    final brand = ftypBrand();
    if (brand == 'qt  ') return 'video/quicktime';
    if (brand != null) {
      if (brand == 'M4A ' || brand == 'M4B ' || brand == 'M4P ') {
        return 'audio/mp4';
      }
      return 'video/mp4';
    }
    if (header.length >= 2 && header[0] == 0xFF && (header[1] & 0xF6) == 0xF0) {
      return 'audio/aac';
    }
    if (startsWith([0x49, 0x44, 0x33]) ||
        (header.length >= 2 && header[0] == 0xFF && (header[1] & 0xE0) == 0xE0)) {
      return 'audio/mpeg';
    }

    // Some platform pickers expose a transcoded file without its signature.
    // Only use an extension when it maps to a type accepted by storage rules.
    const types = {
      '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
      '.webp': 'image/webp', '.gif': 'image/gif', '.aac': 'audio/aac',
      '.mp3': 'audio/mpeg', '.m4a': 'audio/x-m4a', '.ogg': 'audio/ogg',
      '.wav': 'audio/wav', '.mp4': 'video/mp4', '.webm': 'video/webm',
      '.mov': 'video/quicktime',
    };
    final type = types[ext];
    if (type == null) throw Exception('UNSUPPORTED_MEDIA_TYPE: ${file.path}');
    return type;
  }

  void _requireCurrentUser(String userId) {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      throw Exception('AUTH_NULL: المستخدم غير مسجل دخول');
    }
    if (userId != currentUid) {
      throw Exception('AUTH_UID_MISMATCH: لا يمكن الرفع نيابة عن مستخدم آخر');
    }
  }

  /// ==============================
  /// USER AVATAR
  /// ==============================
  Future<String> uploadUserAvatar({
    required String userId,
    required File file,
  }) async {
    _requireCurrentUser(userId);
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
    final path = "groups/$groupId/group_image.jpg";
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
    _requireCurrentUser(userId);
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
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('AUTH_NULL: المستخدم غير مسجل دخول');
    }
    final path = "groups/$groupId/chat/$uid/$messageId";
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
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('AUTH_NULL: المستخدم غير مسجل دخول');
    }
    final path = "private_chats/$chatId/$uid/$messageId";
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