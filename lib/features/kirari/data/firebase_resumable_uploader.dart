import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Storage JSON API resumable uploader used on iOS.
///
/// The session URL is persisted independently of the Flutter page. On restart
/// the server's committed Range is queried before sending any further bytes.
class FirebaseResumableUploader {
  FirebaseResumableUploader({
    required this.bucket,
    required this.uidProvider,
    required this.getIdToken,
    required this.getAppCheckToken,
    http.Client? client,
    SharedPreferences? preferences,
    this.chunkSize = 8 * 1024 * 1024,
  }) : _client = client ?? http.Client(),
       _preferences = preferences;

  final String bucket;
  final String Function() uidProvider;
  final Future<String> Function() getIdToken;
  final Future<String?> Function() getAppCheckToken;
  final http.Client _client;
  SharedPreferences? _preferences;
  final int chunkSize;

  Future<SharedPreferences> _prefs() async =>
      _preferences ??= await SharedPreferences.getInstance();

  String _sessionKey(String storagePath) =>
      'kirari_resumable_session:$storagePath';

  String _fingerprintKey(String storagePath) =>
      'kirari_resumable_fingerprint:$storagePath';

  Future<void> clearSession(String storagePath) async {
    final prefs = await _prefs();
    await prefs.remove(_sessionKey(storagePath));
    await prefs.remove(_fingerprintKey(storagePath));
  }

  static int nextOffsetFromRange(String? range) {
    if (range == null || range.isEmpty) return 0;
    final match = RegExp(r'^bytes=0-(\\d+)$').firstMatch(range.trim());
    if (match == null) {
      throw FormatException('Invalid resumable upload Range header: $range');
    }
    return int.parse(match.group(1)!) + 1;
  }

  Future<void> upload({
    required File file,
    required String storagePath,
    required String contentType,
    required void Function(double progress) onProgress,
  }) async {
    final total = await file.length();
    if (total <= 0) throw StateError('Cannot upload an empty file.');
    final modified = await file.lastModified();
    final fingerprint = '${file.absolute.path}|$total|${modified.millisecondsSinceEpoch}';
    final prefs = await _prefs();
    final sessionKey = _sessionKey(storagePath);
    final fingerprintKey = _fingerprintKey(storagePath);
    var sessionUrl = prefs.getString(sessionKey);

    if (prefs.getString(fingerprintKey) != fingerprint) {
      await prefs.remove(sessionKey);
      sessionUrl = null;
    }
    if (sessionUrl == null || sessionUrl.isEmpty) {
      sessionUrl = await _startSession(
        storagePath: storagePath,
        total: total,
        contentType: contentType,
      );
      await prefs.setString(sessionKey, sessionUrl);
      await prefs.setString(fingerprintKey, fingerprint);
    }

    int offset;
    try {
      offset = await _queryOffset(sessionUrl, total);
    } on _UploadSessionExpired {
      await clearSession(storagePath);
      sessionUrl = await _startSession(storagePath: storagePath, total: total, contentType: contentType);
      await prefs.setString(sessionKey, sessionUrl);
      await prefs.setString(fingerprintKey, fingerprint);
      offset = 0;
    }
    if (offset == total) {
      await clearSession(storagePath);
      onProgress(1);
      return;
    }

    var retries = 0;
    while (offset < total) {
      final endExclusive = math.min(offset + chunkSize, total).toInt();
      try {
        final response = await _sendChunk(
          sessionUrl: sessionUrl,
          file: file,
          start: offset,
          endExclusive: endExclusive,
          total: total,
          contentType: contentType,
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          offset = total;
        } else if (response.statusCode == 308) {
          final committed = nextOffsetFromRange(response.headers['range']);
          if (committed <= offset || committed > total) {
            throw HttpException('Storage did not advance the resumable upload offset.');
          }
          offset = committed;
        } else if (response.statusCode == 404 || response.statusCode == 410) {
          await clearSession(storagePath);
          sessionUrl = await _startSession(
            storagePath: storagePath,
            total: total,
            contentType: contentType,
          );
          await prefs.setString(sessionKey, sessionUrl);
          await prefs.setString(fingerprintKey, fingerprint);
          offset = 0;
        } else if (response.statusCode >= 500) {
          retries++;
          if (retries > 5) throw HttpException('Firebase Storage temporarily rejected the upload chunk.');
          offset = await _queryOffset(sessionUrl, total);
        } else {
          throw HttpException(
            'Firebase Storage resumable upload failed (${response.statusCode}): ${response.body}',
          );
        }
        retries = 0;
      } catch (error) {
        if (error is _UploadSessionExpired) {
          await clearSession(storagePath);
          sessionUrl = await _startSession(storagePath: storagePath, total: total, contentType: contentType);
          await prefs.setString(sessionKey, sessionUrl);
          await prefs.setString(fingerprintKey, fingerprint);
          offset = 0;
          retries = 0;
        } else {
          retries++;
          if (retries > 5) rethrow;
          // The connection may have failed after Storage committed part or all
          // of the chunk. Always ask Storage before sending bytes again.
          offset = await _queryOffset(sessionUrl, total);
        }
      }
      onProgress((offset / total).clamp(0, 1).toDouble());
      if (offset == total) break;
      if (retries > 5) {
        throw const SocketException('Resumable upload retry limit reached.');
      }
    }

    await clearSession(storagePath);
    onProgress(1);
  }

  Future<String> _startSession({
    required String storagePath,
    required int total,
    required String contentType,
  }) async {
    final token = await getIdToken();
    final appCheck = await getAppCheckToken();
    final ownerUid = uidProvider();
    if (ownerUid.isEmpty) throw StateError('Sign in before uploading a Kirari reel.');
    final uri = Uri.https(
      'firebasestorage.googleapis.com',
      '/v0/b/$bucket/o',
      <String, String>{
        'uploadType': 'resumable',
        'name': storagePath,
      },
    );
    final request = http.Request('POST', uri)
      ..headers.addAll(<String, String>{
        'Authorization': 'Firebase $token',
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': contentType,
        'X-Upload-Content-Length': '$total',
        if (appCheck != null && appCheck.isNotEmpty)
          'X-Firebase-AppCheck': appCheck,
      })
      ..body = jsonEncode(<String, dynamic>{
        'name': storagePath,
        'contentType': contentType,
        'metadata': <String, String>{'uploadedBy': ownerUid},
      });
    final response = await _client.send(request);
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw HttpException(
        'Unable to start Firebase Storage upload (${response.statusCode}): $body',
      );
    }
    final location = response.headers['location'];
    if (location == null || location.isEmpty) {
      throw const HttpException('Firebase Storage did not return an upload session URL.');
    }
    return location;
  }

  Future<int> _queryOffset(String sessionUrl, int total) async {
    final request = http.Request('PUT', Uri.parse(sessionUrl))
      ..headers.addAll(<String, String>{
        'Content-Length': '0',
        'Content-Range': 'bytes */$total',
      });
    final response = await _client.send(request);
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200 || response.statusCode == 201) {
      return total;
    }
    if (response.statusCode == 308) {
      return nextOffsetFromRange(response.headers['range']);
    }
    if (response.statusCode == 404 || response.statusCode == 410) {
      throw _UploadSessionExpired();
    }
    throw HttpException(
      'Unable to query Firebase Storage upload offset (${response.statusCode}): $body',
    );
  }

  Future<http.StreamedResponse> _sendChunk({
    required String sessionUrl,
    required File file,
    required int start,
    required int endExclusive,
    required int total,
    required String contentType,
  }) async {
    final length = endExclusive - start;
    final request = http.StreamedRequest('PUT', Uri.parse(sessionUrl))
      ..contentLength = length
      ..headers.addAll(<String, String>{
        'Content-Type': contentType,
        'Content-Range': 'bytes $start-${endExclusive - 1}/$total',
      });
    final response = _client.send(request);
    await request.sink.addStream(file.openRead(start, endExclusive));
    await request.sink.close();
    return response;
  }
}

class _UploadSessionExpired implements Exception {}
