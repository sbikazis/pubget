import 'dart:convert';

import 'package:http/http.dart' as http;

import 'r2_auth_helper.dart';
import 'r2_config.dart';

class R2PresignClient {
  R2PresignClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PresignUploadResult> getPresignedUpload({
    required String fileName,
    required String contentType,
    required int fileSize,
    required String folder,
  }) async {
    final token = await R2AuthHelper.getIdToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await _client.post(
      Uri.parse(R2Config.presignUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'fileName': fileName,
        'contentType': contentType,
        'fileSize': fileSize,
        'folder': folder,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to get presigned URL: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return PresignUploadResult.fromJson(data);
  }

  Future<void> confirmUpload({
    required String key,
    required String fileName,
    required int fileSize,
    required String contentType,
  }) async {
    final token = await R2AuthHelper.getIdToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await _client.post(
      Uri.parse(R2Config.completeUploadUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'key': key,
        'fileName': fileName,
        'fileSize': fileSize,
        'contentType': contentType,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to confirm upload: ${response.body}');
    }
  }

  Future<void> deleteFile(String key) async {
    final token = await R2AuthHelper.getIdToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await _client.delete(
      Uri.parse(R2Config.deleteUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'key': key}),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete file: ${response.body}');
    }
  }
}

class PresignUploadResult {
  PresignUploadResult({
    required this.uploadUrl,
    required this.key,
    required this.publicUrl,
    required this.expiresIn,
  });

  factory PresignUploadResult.fromJson(Map<String, dynamic> json) {
    return PresignUploadResult(
      uploadUrl: json['uploadUrl'] as String,
      key: json['key'] as String,
      publicUrl: json['publicUrl'] as String,
      expiresIn: json['expiresIn'] as int? ?? 900,
    );
  }

  final String uploadUrl;
  final String key;
  final String publicUrl;
  final int expiresIn;
}
