import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import 'r2_storage_service.dart';

class MediaUploadService {
  MediaUploadService({R2StorageService? r2StorageService})
      : _r2StorageService = r2StorageService ?? R2StorageService();

  final R2StorageService _r2StorageService;
  final _uuid = const Uuid();

  String _getContentType(String fileName) {
    final mimeType = lookupMimeType(fileName);
    if (mimeType != null) return mimeType;
    
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'ogg' => 'audio/ogg',
      'aac' => 'audio/aac',
      _ => 'application/octet-stream',
    };
  }

  Future<R2UploadResult> uploadImage({
    required String userId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();
    final ext = image.name.split('.').last.toLowerCase();
    final fileName = '${_uuid.v4()}.$ext';
    final contentType = _getContentType(fileName);

    return _r2StorageService.uploadBytes(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      folder: 'images/$userId',
    );
  }

  Future<R2UploadResult> uploadImageBytes({
    required String userId,
    required Uint8List bytes,
    String extension = 'jpg',
  }) async {
    final fileName = '${_uuid.v4()}.$extension';
    final contentType = _getContentType(fileName);

    return _r2StorageService.uploadBytes(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      folder: 'images/$userId',
    );
  }

  Future<R2UploadResult> uploadImageFile({
    required String userId,
    required File file,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final fileName = '${_uuid.v4()}.$ext';
    final contentType = _getContentType(fileName);

    return _r2StorageService.uploadFile(
      file: file,
      fileName: fileName,
      contentType: contentType,
      folder: 'images/$userId',
    );
  }

  Future<R2UploadResult> uploadReel({
    required String userId,
    required File video,
  }) async {
    final ext = video.path.split('.').last.toLowerCase();
    final fileName = '${_uuid.v4()}.$ext';
    final contentType = _getContentType(fileName);

    return _r2StorageService.uploadFile(
      file: video,
      fileName: fileName,
      contentType: contentType,
      folder: 'reels/$userId',
    );
  }

  Future<R2UploadResult> uploadAudio({
    required String userId,
    required File audio,
  }) async {
    final ext = audio.path.split('.').last.toLowerCase();
    final fileName = '${_uuid.v4()}.$ext';
    final contentType = _getContentType(fileName);

    return _r2StorageService.uploadFile(
      file: audio,
      fileName: fileName,
      contentType: contentType,
      folder: 'audio/$userId',
    );
  }

  Future<void> delete(String key) async {
    await _r2StorageService.delete(key);
  }
}
