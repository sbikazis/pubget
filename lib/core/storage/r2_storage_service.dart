import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'r2_config.dart';
import 'r2_presign_client.dart';

class R2StorageService {
  R2StorageService({http.Client? client, R2PresignClient? presignClient})
      : _client = client ?? http.Client(),
        _presignClient = presignClient ?? R2PresignClient();

  final http.Client _client;
  final R2PresignClient _presignClient;

  /// Upload bytes directly to R2 using presigned URL
  Future<R2UploadResult> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String folder,
  }) async {
    final presign = await _presignClient.getPresignedUpload(
      fileName: fileName,
      contentType: contentType,
      fileSize: bytes.length,
      folder: folder,
    );

    final uploadResponse = await _client.put(
      Uri.parse(presign.uploadUrl),
      headers: {
        'Content-Type': contentType,
        'Content-Length': bytes.length.toString(),
      },
      body: bytes,
    );

    if (uploadResponse.statusCode != 200 && uploadResponse.statusCode != 204) {
      throw Exception('R2 upload failed: ${uploadResponse.statusCode} ${uploadResponse.body}');
    }

    await _presignClient.confirmUpload(
      key: presign.key,
      fileName: fileName,
      fileSize: bytes.length,
      contentType: contentType,
    );

    return R2UploadResult(
      key: presign.key,
      publicUrl: presign.publicUrl,
      downloadUrl: presign.publicUrl,
    );
  }

  /// Upload file from disk (mobile/desktop)
  Future<R2UploadResult> uploadFile({
    required File file,
    required String fileName,
    required String contentType,
    required String folder,
  }) async {
    final bytes = await file.readAsBytes();
    return uploadBytes(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      folder: folder,
    );
  }

  Future<void> delete(String key) async {
    if (key.isEmpty) return;
    await _presignClient.deleteFile(key);
  }

  String getPublicUrl(String key) {
    return R2Config.publicUrl(key);
  }
}

class R2UploadResult {
  R2UploadResult({
    required this.key,
    required this.publicUrl,
    required this.downloadUrl,
  });

  final String key;
  final String publicUrl;
  final String downloadUrl;
}
