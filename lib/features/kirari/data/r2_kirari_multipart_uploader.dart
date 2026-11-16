import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Resumable client for the private R2 multipart endpoints exposed by the
/// Pubget media Worker. Only Firebase ID tokens leave the device; R2
/// credentials and object keys remain server-controlled.
class R2KirariMultipartUploader {
  R2KirariMultipartUploader({
    required String workerUrl,
    required this.uidProvider,
    required this.getIdToken,
    http.Client? client,
    SharedPreferences? preferences,
    this.chunkSize = 8 * 1024 * 1024,
  }) : _baseUrl = workerUrl.replaceAll(RegExp(r'/+$'), ''),
       _client = client ?? http.Client(),
       _preferences = preferences;

  final String _baseUrl;
  final String Function() uidProvider;
  final Future<String> Function() getIdToken;
  final http.Client _client;
  SharedPreferences? _preferences;
  final int chunkSize;

  Future<SharedPreferences> _prefs() async =>
      _preferences ??= await SharedPreferences.getInstance();

  String _sessionKey(String reelId) => 'r2_kirari_upload:$reelId';

  Future<void> clearSession(String reelId) async {
    final prefs = await _prefs();
    await prefs.remove(_sessionKey(reelId));
  }

  Future<void> abort(String reelId) async {
    final prefs = await _prefs();
    final saved = _decodeSession(prefs.getString(_sessionKey(reelId)));
    if (saved != null) {
      await _abort(reelId, saved['uploadId'] as String);
    }
    await clearSession(reelId);
  }

  Future<void> uploadCover({
    required File file,
    required String reelId,
  }) async {
    final uid = uidProvider();
    if (uid.isEmpty) throw StateError('Sign in before uploading a Kirari cover.');
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}    required File file,
    required String reelId,
    required void Function(double progress) onProgress,
  }) async {
    final uid = uidProvider();
    if (uid.isEmpty) throw StateError('Sign in before uploading a Kirari reel.');
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(reelId)) {
      throw ArgumentError.value(reelId, 'reelId', 'Invalid reel id.');
    }
    final total = await file.length();
    if (total <= 0 || total > 500 * 1024 * 1024) {
      throw StateError('The video must be between 1 byte and 500 MB.');
    }
    final modified = await file.lastModified();
    final fingerprint = '${file.absolute.path}|$total|${modified.millisecondsSinceEpoch}';
    final prefs = await _prefs();
    final key = _sessionKey(reelId);
    final existing = await _request('HEAD', '/kirari/multipart/$reelId');
    if (existing.statusCode == 200 &&
        int.tryParse(existing.headers['content-length'] ?? '') == total &&
        existing.headers['x-kirari-fingerprint'] == fingerprint) {
      await clearSession(reelId);
      onProgress(1);
      return;
    }
    if (existing.statusCode != 404 && existing.statusCode != 200) {
      throw HttpException('Could not verify the existing R2 upload (' + existing.statusCode.toString() + ').');
    }
    var saved = _decodeSession(prefs.getString(key));
    if (saved == null || saved['fingerprint'] != fingerprint) {
      if (saved != null) await _abort(reelId, saved['uploadId'] as String);
      saved = await _start(reelId, total, fingerprint);
      await prefs.setString(key, jsonEncode(saved));
    }

    final uploadId = saved['uploadId'] as String;
    final parts = Map<String, String>.from(saved['parts'] as Map);
    final count = (total / chunkSize).ceil();
    for (var number = 1; number <= count; number++) {
      if (parts.containsKey('$number')) {
        final end = math.min(number * chunkSize, total);
        onProgress(end / total);
        continue;
      }
      final start = (number - 1) * chunkSize;
      final end = math.min(start + chunkSize, total);
      final etag = await _sendPart(
        reelId: reelId,
        uploadId: uploadId,
        number: number,
        file: file,
        start: start,
        end: end,
      );
      parts['$number'] = etag;
      saved['parts'] = parts;
      await prefs.setString(key, jsonEncode(saved));
      onProgress(end / total);
    }

    final ordered = List.generate(count, (index) => <String, dynamic>{
      'partNumber': index + 1,
      'etag': parts['${index + 1}'],
    });
    final response = await _request(
      'POST',
      '/kirari/multipart/$reelId/$uploadId/complete',
      body: jsonEncode({'parts': ordered}),
      headers: {'content-type': 'application/json'},
    );
    if (response.statusCode == 404 || response.statusCode == 410) {
      await clearSession(reelId);
      throw const HttpException('The upload session expired. Please retry the upload.');
    }
    if (response.statusCode != 201) {
      throw HttpException('R2 could not finalize the video upload (${response.statusCode}).');
    }
    await clearSession(reelId);
    onProgress(1);
  }

  Map<String, dynamic>? _decodeSession(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['uploadId'] is! String ||
          decoded['fingerprint'] is! String ||
          decoded['parts'] is! Map) return null;
      final parts = decoded['parts'] as Map;
      if (parts.entries.any((entry) =>
          entry.key is! String || entry.value is! String)) return null;
      return decoded;
    } on Object {
      return null;
    }
  }

  Future<Map<String, dynamic>> _start(
    String reelId,
    int total,
    String fingerprint,
  ) async {
    final response = await _request(
      'POST',
      '/kirari/multipart/$reelId',
      headers: {
        'content-type': 'application/json',
        'x-kirari-size': '$total',
        'x-kirari-fingerprint': fingerprint,
      },
      body: '{}',
    );
    if (response.statusCode != 201) {
      throw HttpException('R2 could not start the video upload (${response.statusCode}).');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final uploadId = payload['uploadId'];
    if (uploadId is! String || uploadId.isEmpty) {
      throw const FormatException('R2 returned an invalid upload session.');
    }
    return {'uploadId': uploadId, 'fingerprint': fingerprint, 'parts': <String, String>{}};
  }

  Future<String> _sendPart({
    required String reelId,
    required String uploadId,
    required int number,
    required File file,
    required int start,
    required int end,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final request = http.StreamedRequest(
          'PUT',
          Uri.parse('$_baseUrl/kirari/multipart/$reelId/$uploadId/$number'),
        )
          ..contentLength = end - start
          ..headers.addAll({
            'authorization': 'Bearer ${await getIdToken()}',
            'content-type': 'application/octet-stream',
          });
        final pending = _client.send(request);
        await request.sink.addStream(file.openRead(start, end));
        await request.sink.close();
        final response = await http.Response.fromStream(await pending);
        if (response.statusCode == 201) {
          final payload = jsonDecode(response.body) as Map<String, dynamic>;
          final etag = payload['etag'];
          if (etag is String && etag.isNotEmpty) return etag;
          throw const FormatException('R2 returned a multipart part without an ETag.');
        }
        if (response.statusCode == 404 || response.statusCode == 410) {
          await _abort(reelId, uploadId);
          await clearSession(reelId);
          throw HttpException('The R2 upload session expired. Start the upload again.');
        }
        if (response.statusCode < 500 && response.statusCode != 429) {
          await _abort(reelId, uploadId);
          await clearSession(reelId);
          throw HttpException('R2 rejected upload part $number (${response.statusCode}).');
        }
        lastError = HttpException('R2 temporarily rejected upload part $number.');
      } on HttpException {
        rethrow;
      } on Object catch (error) {
        lastError = error;
      }
      if (attempt < 4) {
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    throw HttpException('Video upload paused; retry safely to resume. $lastError');
  }

  Future<String> resolveUrl(String storageKey) async {
    final uri = Uri.parse('$_baseUrl/kirari/resolve')
        .replace(queryParameters: {'key': storageKey});
    final response = await _request('GET', uri.toString().replaceFirst(_baseUrl, ''));
    if (response.statusCode != 200) {
      throw HttpException('Kirari media is unavailable (' + response.statusCode.toString() + ').');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final url = payload['url'];
    if (url is! String || !url.startsWith('https://')) {
      throw const FormatException('Kirari returned an invalid playback URL.');
    }
    return url;
  }

  Future<void> _abort(String reelId, String uploadId) async {
    try {
      await _request('DELETE', '/kirari/multipart/$reelId/$uploadId/abort');
    } on Object {
      // A stale multipart session must never prevent starting a fresh upload.
    }
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final token = await getIdToken();
    if (token.isEmpty) throw StateError('Firebase sign-in token is unavailable.');
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers.addAll({'authorization': 'Bearer $token', ...headers});
    if (body != null) request.body = body;
    return http.Response.fromStream(await _client.send(request));
  }

  void close() => _client.close();
}
).hasMatch(reelId)) {
      throw ArgumentError.value(reelId, 'reelId', 'Invalid reel id.');
    }
    final total = await file.length();
    if (total <= 0 || total > 5 * 1024 * 1024) {
      throw StateError('The cover image must be no larger than 5 MB.');
    }
    final prefix = await file.openRead(0, 8).fold<List<int>>(
      <int>[],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    final isPng = prefix.length >= 8 &&
        prefix[0] == 0x89 && prefix[1] == 0x50 &&
        prefix[2] == 0x4e && prefix[3] == 0x47 &&
        prefix[4] == 0x0d && prefix[5] == 0x0a &&
        prefix[6] == 0x1a && prefix[7] == 0x0a;
    final contentType = isPng ? 'image/png' : 'image/jpeg';
    final request = http.StreamedRequest(
      'PUT',
      Uri.parse('$_baseUrl/kirari/cover/$reelId'),
    )
      ..contentLength = total
      ..headers.addAll({
        'authorization': 'Bearer ${await getIdToken()}',
        'content-type': contentType,
      });
    final pending = _client.send(request);
    await request.sink.addStream(file.openRead());
    await request.sink.close();
    final response = await http.Response.fromStream(await pending);
    if (response.statusCode != 201) {
      throw HttpException('R2 could not upload the Kirari cover (${response.statusCode}).');
    }
  }

  Future<void> upload({
    required File file,
    required String reelId,
    required void Function(double progress) onProgress,
  }) async {
    final uid = uidProvider();
    if (uid.isEmpty) throw StateError('Sign in before uploading a Kirari reel.');
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(reelId)) {
      throw ArgumentError.value(reelId, 'reelId', 'Invalid reel id.');
    }
    final total = await file.length();
    if (total <= 0 || total > 500 * 1024 * 1024) {
      throw StateError('The video must be between 1 byte and 500 MB.');
    }
    final modified = await file.lastModified();
    final fingerprint = '${file.absolute.path}|$total|${modified.millisecondsSinceEpoch}';
    final prefs = await _prefs();
    final key = _sessionKey(reelId);
    final existing = await _request('HEAD', '/kirari/multipart/$reelId');
    if (existing.statusCode == 200 &&
        int.tryParse(existing.headers['content-length'] ?? '') == total &&
        existing.headers['x-kirari-fingerprint'] == fingerprint) {
      await clearSession(reelId);
      onProgress(1);
      return;
    }
    if (existing.statusCode != 404 && existing.statusCode != 200) {
      throw HttpException('Could not verify the existing R2 upload (' + existing.statusCode.toString() + ').');
    }
    var saved = _decodeSession(prefs.getString(key));
    if (saved == null || saved['fingerprint'] != fingerprint) {
      if (saved != null) await _abort(reelId, saved['uploadId'] as String);
      saved = await _start(reelId, total, fingerprint);
      await prefs.setString(key, jsonEncode(saved));
    }

    final uploadId = saved['uploadId'] as String;
    final parts = Map<String, String>.from(saved['parts'] as Map);
    final count = (total / chunkSize).ceil();
    for (var number = 1; number <= count; number++) {
      if (parts.containsKey('$number')) {
        final end = math.min(number * chunkSize, total);
        onProgress(end / total);
        continue;
      }
      final start = (number - 1) * chunkSize;
      final end = math.min(start + chunkSize, total);
      final etag = await _sendPart(
        reelId: reelId,
        uploadId: uploadId,
        number: number,
        file: file,
        start: start,
        end: end,
      );
      parts['$number'] = etag;
      saved['parts'] = parts;
      await prefs.setString(key, jsonEncode(saved));
      onProgress(end / total);
    }

    final ordered = List.generate(count, (index) => <String, dynamic>{
      'partNumber': index + 1,
      'etag': parts['${index + 1}'],
    });
    final response = await _request(
      'POST',
      '/kirari/multipart/$reelId/$uploadId/complete',
      body: jsonEncode({'parts': ordered}),
      headers: {'content-type': 'application/json'},
    );
    if (response.statusCode == 404 || response.statusCode == 410) {
      await clearSession(reelId);
      throw const HttpException('The upload session expired. Please retry the upload.');
    }
    if (response.statusCode != 201) {
      throw HttpException('R2 could not finalize the video upload (${response.statusCode}).');
    }
    await clearSession(reelId);
    onProgress(1);
  }

  Map<String, dynamic>? _decodeSession(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['uploadId'] is! String ||
          decoded['fingerprint'] is! String ||
          decoded['parts'] is! Map) return null;
      final parts = decoded['parts'] as Map;
      if (parts.entries.any((entry) =>
          entry.key is! String || entry.value is! String)) return null;
      return decoded;
    } on Object {
      return null;
    }
  }

  Future<Map<String, dynamic>> _start(
    String reelId,
    int total,
    String fingerprint,
  ) async {
    final response = await _request(
      'POST',
      '/kirari/multipart/$reelId',
      headers: {
        'content-type': 'application/json',
        'x-kirari-size': '$total',
        'x-kirari-fingerprint': fingerprint,
      },
      body: '{}',
    );
    if (response.statusCode != 201) {
      throw HttpException('R2 could not start the video upload (${response.statusCode}).');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final uploadId = payload['uploadId'];
    if (uploadId is! String || uploadId.isEmpty) {
      throw const FormatException('R2 returned an invalid upload session.');
    }
    return {'uploadId': uploadId, 'fingerprint': fingerprint, 'parts': <String, String>{}};
  }

  Future<String> _sendPart({
    required String reelId,
    required String uploadId,
    required int number,
    required File file,
    required int start,
    required int end,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final request = http.StreamedRequest(
          'PUT',
          Uri.parse('$_baseUrl/kirari/multipart/$reelId/$uploadId/$number'),
        )
          ..contentLength = end - start
          ..headers.addAll({
            'authorization': 'Bearer ${await getIdToken()}',
            'content-type': 'application/octet-stream',
          });
        final pending = _client.send(request);
        await request.sink.addStream(file.openRead(start, end));
        await request.sink.close();
        final response = await http.Response.fromStream(await pending);
        if (response.statusCode == 201) {
          final payload = jsonDecode(response.body) as Map<String, dynamic>;
          final etag = payload['etag'];
          if (etag is String && etag.isNotEmpty) return etag;
          throw const FormatException('R2 returned a multipart part without an ETag.');
        }
        if (response.statusCode == 404 || response.statusCode == 410) {
          await _abort(reelId, uploadId);
          await clearSession(reelId);
          throw HttpException('The R2 upload session expired. Start the upload again.');
        }
        if (response.statusCode < 500 && response.statusCode != 429) {
          await _abort(reelId, uploadId);
          await clearSession(reelId);
          throw HttpException('R2 rejected upload part $number (${response.statusCode}).');
        }
        lastError = HttpException('R2 temporarily rejected upload part $number.');
      } on HttpException {
        rethrow;
      } on Object catch (error) {
        lastError = error;
      }
      if (attempt < 4) {
        await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    throw HttpException('Video upload paused; retry safely to resume. $lastError');
  }

  Future<String> resolveUrl(String storageKey) async {
    final uri = Uri.parse('$_baseUrl/kirari/resolve')
        .replace(queryParameters: {'key': storageKey});
    final response = await _request('GET', uri.toString().replaceFirst(_baseUrl, ''));
    if (response.statusCode != 200) {
      throw HttpException('Kirari media is unavailable (' + response.statusCode.toString() + ').');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final url = payload['url'];
    if (url is! String || !url.startsWith('https://')) {
      throw const FormatException('Kirari returned an invalid playback URL.');
    }
    return url;
  }

  Future<void> _abort(String reelId, String uploadId) async {
    try {
      await _request('DELETE', '/kirari/multipart/$reelId/$uploadId/abort');
    } on Object {
      // A stale multipart session must never prevent starting a fresh upload.
    }
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    final token = await getIdToken();
    if (token.isEmpty) throw StateError('Firebase sign-in token is unavailable.');
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers.addAll({'authorization': 'Bearer $token', ...headers});
    if (body != null) request.body = body;
    return http.Response.fromStream(await _client.send(request));
  }

  void close() => _client.close();
}
