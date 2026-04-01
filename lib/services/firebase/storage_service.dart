import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class StorageService {
  final String cloudName = "djk89pmj3";
  final String uploadPreset = "pubgetanimecity";

  /// ==============================
  /// INTERNAL GENERIC UPLOAD METHOD
  /// ==============================

Future<String> _uploadFile({
  required File file,
  required String path,
}) async {
  try {
    final url = Uri.parse(
      "https://api.cloudinary.com/v1_1/djk89pmj3/image/upload",
    );

    final request = http.MultipartRequest("POST", url);

    request.fields["upload_preset"] = uploadPreset;
    request.fields["folder"] = path;

    request.files.add(
      await http.MultipartFile.fromPath("file", file.path),
    );

    final response = await request.send();

    final responseData = await response.stream.bytesToString();

    print("STATUS: ${response.statusCode}");
    print("RESPONSE: $responseData");

    if (response.statusCode != 200) {
      throw Exception("Upload failed: $responseData");
    }

    final jsonData = json.decode(responseData);

    return jsonData["secure_url"];
  } catch (e) {
    print("ERROR: $e");
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
    final path = "users/$userId/avatar";

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
    final path = "groups/$groupId/image";

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
    final path = "groups/$groupId/characters/$userId";

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
    final path = "groups/$groupId/chat/$messageId";

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
    final path = "private_chats/$chatId/$messageId";

    return _uploadFile(
      file: file,
      path: path,
    );
  }

  /// ==============================
  /// DELETE FILE (اختياري)
  /// ==============================

  Future<void> deleteFile(String url) async {
    // Cloudinary delete يحتاج API Secret (لا تضعه في التطبيق)
    // لذلك نتركه فارغ أو تنفذه عبر backend مستقبلاً
  }
}