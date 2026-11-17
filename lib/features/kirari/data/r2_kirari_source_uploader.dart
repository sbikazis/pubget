import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Uploads a Kirari source directly to Cloudflare R2 through the authenticated
/// Worker's multipart endpoints. The object key is never chosen by the client:
/// the Worker derives it from the signed-in owner and the reel document.
///
/// A session (uploadId + confirmed parts) is persisted so an app restart can
/// continue from the next part instead of resending bytes already committed.
class R2KirariSourceUploader {
  R2KirariSourceUploader({
    required this.workerUrl,
    required this.uidProvider,
    required this.getIdToken,
    http.Client? client,
    SharedPreferences? preferences,
    this.chunkSize = 8 * 1024 * 1024,
  }) : _client = client ?? http.Client(),
       _preferences = preferences;

  static const int maxSourceBytes = 500 * 1024 * 1024;
  static const int maxPartBytes = 16 * 1024 * 1024;
  static const int maxCoverBytes = 5 * 1024 * 1024;

  final String workerUrl;
  final String Function() uidProvider;
  final Future<String> Function() getIdToken;
  final http.Client _client;
  SharedPreferences? _preferences;
  final int chunkSize;

  Future<SharedPreferences> _prefs() async =>
      _preferences ??= await SharedPreferences.getInstance();

  String _sessionKey(String path) => 'kirari_r2_multipart_session:$path';
  String _fingerprintKey(String path) =>
      'kirari_r2_multipart_fingerprint:$path';

  static final RegExp _sourceKeyPattern = RegExp(
    r'^kirari/([A-Za-z0-9_-]{1,128})/([A-Za-z0-9_-]{1,128})/source\.mp4$',
  );

  static String reelIdFromPath(String storagePath) {
    final match = _sourceKeyPattern.firstMatch(storagePath);
    if (match == null) {
      throw FormatException('Invalid Kirari source object key: $storagePath');
    }
    return match.group(2)!;
  }

  Future<void> clearSession(String storagePath) async {
    final prefs = await _prefs();
    await prefs.remove(_sessionKey(storagePath));
    await prefs.remove(_fingerprintKey(storagePath));
  }

  Future<Map<String, dynamic>?> _loadSession(
    String storagePath,
    String fingerprint,
    int total,
  ) async {
    final prefs = await _prefs();
    if (prefs.getString(_fingerprintKey(storagePath)) != fingerprint)
      return null;
    final raw = prefs.getString(_sessionKey(storagePath));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final uploadId = decoded['uploadId'] as String?;
      final partsRaw = decoded['parts'] as List<dynamic>?;
      final uploaded = decoded['uploadedBytes'];
      if (uploadId == null ||
          uploadId.isEmpty ||
          partsRaw == null ||
          uploaded is! int ||
          uploaded < 0 ||
          uploaded > total) {
        return null;
      }
      final parts = partsRaw.map((entry) {
        final part = entry as Map<String, dynamic>;
        final number = part['partNumber'];
        final etag = part['etag'] as String?;
        if (number is! int || number < 1 || etag == null || etag.isEmpty) {
          throw const FormatException('Invalid stored Kirari multipart part.');
        }
        return <String, dynamic>{'partNumber': number, 'etag': etag};
      }).toList();
      for (var index = 0; index < parts.length; index++) {
        if (parts[index]['partNumber'] != index + 1) return null;
      }
      return <String, dynamic>{
        'uploadId': uploadId,
        'parts': parts,
        'uploadedBytes': uploaded,
      };
    } on Object {
      return null;
    }
  }

  Future<void> _saveSession(
    String storagePath,
    String fingerprint,
    Map<String, dynamic> session,
  ) async {
    final prefs = await _prefs();
    await prefs.setString(_sessionKey(storagePath), jsonEncode(session));
    await prefs.setString(_fingerprintKey(storagePath), fingerprint);
  }

  Future<Map<String, String>> _authHeaders(
    Map<String, String> extra, {
    bool withContentType = true,
  }) async {
    final token = await getIdToken();
    if (token.isEmpty) {
      throw StateError('Sign in before uploading a Kirari reel.');
    }
    return <String, String>{
      'Authorization': 'Bearer $token',
      if (withContentType) 'Content-Type': 'application/json',
      ...extra,
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
    workerUrl.replaceAll(RegExp(r'/+$'), '') + path,
  ).replace(queryParameters: query);

  /// Returns true when a completed source already exists in R2. Used to avoid
  /// re-uploading a durable local file after the app was killed before
  /// finalization.
  Future<bool> sourceExists(String storagePath) async {
    final reelId = reelIdFromPath(storagePath);
    final response = await _client.send(
      http.Request('HEAD', _uri('/kirari/multipart/$reelId'))
        ..headers.addAll(
          await _authHeaders(const <String, String>{}, withContentType: false),
        ),
    );
    final result = await http.Response.fromStream(response);
    if (result.statusCode == 200) return true;
    if (result.statusCode == 404) return false;
    throw HttpException(
      'Unable to check the Kirari upload (${result.statusCode}): ${result.body}',
    );
  }

  /// Uploads a custom cover before finalization. The pipeline reads this key.
  Future<void> uploadCover({
    required String storagePath,
    required File file,
  }) async {
    final reelId = reelIdFromPath(storagePath);
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxCoverBytes) {
      throw StateError('The cover image must be smaller than 5 MB.');
    }
    final request = http.Request('PUT', _uri('/kirari/multipart/$reelId/cover'))
      ..headers.addAll(
        await _authHeaders(<String, String>{
          'Content-Type': 'image/jpeg',
          'Content-Length': bytes.length.toString(),
        }),
      )
      ..bodyBytes = bytes;
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode != 201) {
      throw HttpException(
        'Kirari cover upload failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<void> abort(String storagePath) async {
    final reelId = reelIdFromPath(storagePath);
    final prefs = await _prefs();
    final raw = prefs.getString(_sessionKey(storagePath));
    if (raw == null || raw.isEmpty) return;
    try {
      final uploadId =
          (jsonDecode(raw) as Map<String, dynamic>)['uploadId'] as String?;
      if (uploadId != null && uploadId.isNotEmpty) {
        final request =
            http.Request(
                'DELETE',
                _uri('/kirari/multipart/$reelId/$uploadId/abort'),
              )
              ..headers.addAll(
                await _authHeaders(
                  const <String, String>{},
                  withContentType: false,
                ),
              );
        await _client.send(request);
      }
    } on Object {
      // Abort is best-effort: the reel is already being deleted locally.
    }
    await clearSession(storagePath);
  }

  Future<void> upload({
    required File file,
    required String storagePath,
    required String contentType,
    required void Function(double progress) onProgress,
  }) async {
    final owner = uidProvider();
    final reelId = reelIdFromPath(storagePath);
    if (storagePath != 'kirari/$owner/$reelId/source.mp4') {
      throw StateError(
        'This Kirari upload does not belong to the signed-in user.',
      );
    }
    if (contentType != 'video/mp4') {
      throw StateError('Kirari sources must be MP4 videos.');
    }
    final total = await file.length();
    if (total <= 0 || total > maxSourceBytes) {
      throw StateError('Choose a video no larger than 500 MB.');
    }
    if (chunkSize <= 0 || chunkSize > maxPartBytes) {
      throw StateError('Kirari multipart chunk size is out of range.');
    }
    final modified = await file.lastModified();
    final fingerprint =
        '${file.absolute.path}|$total|${modified.millisecondsSinceEpoch}';

    // A 404/410 from any Worker multipart call invalidates the whole session;
    // at most one fresh session per upload attempt keeps recovery bounded.
    for (var attempt = 0; attempt < 2; attempt++) {
      var session = await _loadSession(storagePath, fingerprint, total);
      if (session == null) {
        session = await _startSession(storagePath, reelId, total);
        await _saveSession(storagePath, fingerprint, session);
      }
      try {
        final parts = session['parts'] as List<Map<String, dynamic>>;
        var uploaded = session['uploadedBytes'] as int;
        onProgress((uploaded / total).clamp(0, 1).toDouble());

        while (uploaded < total) {
          final end = math.min(uploaded + chunkSize, total).toInt();
          final previous = uploaded;
          var retries = 0;
          late http.Response response;
          while (true) {
            response = await _sendPart(
              reelId: reelId,
              uploadId: session['uploadId'] as String,
              partNumber: parts.length + 1,
              file: file,
              start: uploaded,
              endExclusive: end,
            );
            if (response.statusCode == 201) break;
            if (response.statusCode == 404 || response.statusCode == 410) {
              throw _MultipartSessionExpired();
            }
            if (response.statusCode >= 500 && retries < 5) {
              retries++;
              continue;
            }
            throw HttpException(
              'Kirari multipart upload failed (${response.statusCode}): ${response.body}',
            );
          }
          final payload = jsonDecode(response.body) as Map<String, dynamic>;
          final etag = payload['etag'] as String?;
          if (etag == null || etag.isEmpty) {
            throw const HttpException(
              'Kirari Worker returned an invalid part ETag.',
            );
          }
          parts.add(<String, dynamic>{
            'partNumber': parts.length + 1,
            'etag': etag,
          });
          uploaded = end;
          session['uploadedBytes'] = uploaded;
          await _saveSession(storagePath, fingerprint, session);
          onProgress((uploaded / total).clamp(0, 1).toDouble());
          if (uploaded <= previous) {
            throw const HttpException(
              'Kirari multipart upload did not advance.',
            );
          }
        }

        final complete = await _complete(
          reelId,
          session['uploadId'] as String,
          parts,
        );
        if (complete.statusCode != 201) {
          if (complete.statusCode == 404 || complete.statusCode == 410) {
            throw _MultipartSessionExpired();
          }
          throw HttpException(
            'Kirari multipart completion failed (${complete.statusCode}): ${complete.body}',
          );
        }
        await clearSession(storagePath);
        onProgress(1);
        return;
      } on _MultipartSessionExpired {
        await clearSession(storagePath);
        if (attempt == 1) {
          throw const HttpException('Kirari upload session expired twice.');
        }
      }
    }
  }

  Future<Map<String, dynamic>> _startSession(
    String storagePath,
    String reelId,
    int total,
  ) async {
    final request = http.Request('POST', _uri('/kirari/multipart/$reelId'))
      ..headers.addAll(
        await _authHeaders(<String, String>{'X-Kirari-Size': total.toString()}),
      )
      ..body = '{}';
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode != 201) {
      throw HttpException(
        'Unable to start the Kirari R2 upload (${response.statusCode}): ${response.body}',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final uploadId = payload['uploadId'] as String?;
    if (payload['key'] != storagePath || uploadId == null || uploadId.isEmpty) {
      throw const HttpException(
        'Kirari Worker returned an invalid upload session.',
      );
    }
    return <String, dynamic>{
      'uploadId': uploadId,
      'parts': <Map<String, dynamic>>[],
      'uploadedBytes': 0,
    };
  }

  Future<http.Response> _sendPart({
    required String reelId,
    required String uploadId,
    required int partNumber,
    required File file,
    required int start,
    required int endExclusive,
  }) async {
    final request =
        http.StreamedRequest(
            'PUT',
            _uri('/kirari/multipart/$reelId/$uploadId/$partNumber'),
          )
          ..contentLength = endExclusive - start
          ..headers.addAll(
            await _authHeaders(<String, String>{
              'Content-Type': 'video/mp4',
              'Content-Length': (endExclusive - start).toString(),
            }, withContentType: false),
          );
    final pending = _client.send(request);
    await request.sink.addStream(file.openRead(start, endExclusive));
    await request.sink.close();
    return http.Response.fromStream(await pending);
  }

  Future<http.Response> _complete(
    String reelId,
    String uploadId,
    List<Map<String, dynamic>> parts,
  ) async {
    final request =
        http.Request(
            'POST',
            _uri('/kirari/multipart/$reelId/$uploadId/complete'),
          )
          ..headers.addAll(await _authHeaders(const <String, String>{}))
          ..body = jsonEncode(<String, dynamic>{'parts': parts});
    return http.Response.fromStream(await _client.send(request));
  }
}

class _MultipartSessionExpired implements Exception {}
