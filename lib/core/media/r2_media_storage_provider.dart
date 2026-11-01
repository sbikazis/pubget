import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../errors/failure.dart';
import 'media_kind.dart';
import 'media_storage_provider.dart';

/// Talks to the Cloudflare R2 worker (`worker/`) — see that service's README
/// for the endpoint contract.
///
/// Security posture:
/// * credentials never reach the app — the worker signs uploads server-side;
/// * the app only ever holds short-lived presigned URLs (15 min) or the
///   worker's own authenticated endpoints;
/// * object keys are minted by the worker for direct-to-R2 uploads and by
///   `buildMediaKey` for small proxied uploads; a user file name never
///   becomes a key.
final class R2MediaStorageProvider implements MediaStorageProvider {
  R2MediaStorageProvider({
    required String workerUrl,
    required Future<String?> Function() idTokenProvider,
    http.Client? client,
    this.directUploadMaxBytes = 2 * 1024 * 1024,
  })  : _baseUrl = workerUrl.replaceAll(RegExp(r'/+$'), ''),
        _idTokenProvider = idTokenProvider,
        _client = client ?? http.Client();

  final String _baseUrl;
  final Future<String?> Function() _idTokenProvider;
  final http.Client _client;

  /// Payloads at or below this size go through the worker's proxied
  /// `POST /upload` (one round trip, no presign quota spent); larger ones
  /// use a presigned PUT straight to R2.
  final int directUploadMaxBytes;

  @override
  MediaBackend get backend => MediaBackend.r2;

  @override
  Future<String> upload({
    required String ownerUid,
    required MediaKind kind,
    required Uint8List bytes,
    required String contentType,
    required String extension,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0);
    final key = bytes.length <= directUploadMaxBytes
        ? await _uploadProxied(
            kind: kind,
            bytes: bytes,
            contentType: contentType,
            extension: extension,
          )
        : await _uploadPresigned(
            kind: kind,
            bytes: bytes,
            contentType: contentType,
            extension: extension,
          );
    onProgress?.call(1);
    return key;
  }

  Future<String> _uploadProxied({
    required MediaKind kind,
    required Uint8List bytes,
    required String contentType,
    required String extension,
  }) async {
    final token = await _requireToken();
    final request = http.MultipartRequest('POST', _uri('/upload'))
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['kind'] = kind.name
      ..fields['contentType'] = contentType
      ..fields['ext'] = extension
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes,
            filename: 'upload.$extension', contentType: null),
      );

    final streamed =
        await _client.send(request).timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamed);
    return _unwrapKey(response);
  }

  Future<String> _uploadPresigned({
    required MediaKind kind,
    required Uint8List bytes,
    required String contentType,
    required String extension,
  }) async {
    final token = await _requireToken();
    final query = <String, String>{
      'kind': kind.name,
      'contentType': contentType,
      'sizeBytes': '${bytes.length}',
      'ext': extension,
    };
    final presignResponse = await _client
        .get(
          _uri('/presign', query),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));
    if (presignResponse.statusCode != 200) {
      throw _mapWorkerError(presignResponse);
    }
    final decoded =
        jsonDecode(utf8.decode(presignResponse.bodyBytes)) as Map<String, dynamic>;
    final uploadUrl = decoded['uploadUrl'] as String?;
    final key = decoded['key'] as String?;
    final headers = (decoded['headers'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, '$v'));
    if (uploadUrl == null || key == null) {
      throw const UnknownError('The upload service returned an invalid response.');
    }

    final putRequest = http.Request('PUT', Uri.parse(uploadUrl))
      ..bodyBytes = bytes
      ..headers['Content-Type'] = contentType;
    headers?.forEach((name, value) {
      // The signature covers these exact values, so the worker tells the app
      // which ones to send back. `content-length` and `host` are set by the
      // HTTP transport itself — setting them by hand duplicates the header and
      // would break the signature. The transport derives `content-length` from
      // the body, which is exactly the size that was signed.
      final lower = name.toLowerCase();
      if (lower == 'content-length' || lower == 'host') return;
      putRequest.headers[name] = value;
    });
    final putResponse =
        await _client.send(putRequest).timeout(const Duration(minutes: 10));
    if (putResponse.statusCode < 200 || putResponse.statusCode >= 300) {
      throw NetworkError(
        'R2 rejected the upload (HTTP ${putResponse.statusCode}).',
      );
    }
    return key;
  }

  @override
  Future<void> delete(String storageKey) async {
    final token = await _requireToken();
    final response = await _client
        .delete(
          _uri('/media/${Uri.encodeComponent(storageKey)}'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode == 204 || response.statusCode == 200) return;
    if (response.statusCode == 404) return;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const PermissionError(
        'Sign in again to manage this media.',
      );
    }
    throw NetworkError('Could not delete this file (HTTP ${response.statusCode}).');
  }

  @override
  Future<String> resolveUrl(String storageKey) async {
    // The worker serves objects publicly; no permanent R2 URL is stored.
    return '$_baseUrl/media/${Uri.encodeComponent(storageKey)}';
  }

  Future<String> _requireToken() async {
    final token = await _idTokenProvider();
    if (token == null || token.isEmpty) {
      throw const PermissionError('Sign in to upload media.');
    }
    return token;
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: query);

  String _unwrapKey(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final key = (decoded as Map<String, dynamic>)['key'] as String?;
      if (key != null) return key;
      throw const UnknownError('The upload service returned an invalid response.');
    }
    throw _mapWorkerError(response);
  }

  Failure _mapWorkerError(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      return const PermissionError('Sign in to upload media.');
    }
    if (response.statusCode == 413 ||
        response.statusCode == 400 ||
        response.statusCode == 415) {
      var message = 'This file was rejected by the media service.';
      try {
        final decoded =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final serverMessage = decoded['error'] as String?;
        if (serverMessage != null && serverMessage.isNotEmpty) {
          message = serverMessage;
        }
      } on Object {
        // Keep the generic message when the body is not JSON.
      }
      return ValidationError(message);
    }
    if (response.statusCode == 429) {
      return const RateLimitedError('Too many uploads. Please wait a moment.');
    }
    if (response.statusCode >= 500) {
      return const UnavailableError('The media service is unavailable.');
    }
    return NetworkError('Upload failed (HTTP ${response.statusCode}).');
  }
}
