import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../errors/http_status_failure.dart';
import '../media/media_storage_provider.dart';

/// Typed failure from a read-only Pubget Worker route.
///
/// The HTTP status is authoritative: a 503 is a backend outage, never a lost
/// internet connection. The shared mapper uses this to show honest UI states.
class CoreReadWorkerException implements Exception, HttpStatusFailure {
  const CoreReadWorkerException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'CoreReadWorkerException($statusCode): $message';
}

/// Injectable boundary so repository tests never need a live Firebase app.
abstract interface class CoreReadWorkerClient {
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? payload,
  ]);
}

final class HttpCoreReadWorkerClient implements CoreReadWorkerClient {
  HttpCoreReadWorkerClient({
    required Future<String?> Function() tokenProvider,
    http.Client? httpClient,
    String? workerUrl,
  }) : _tokenProvider = tokenProvider,
       _http = httpClient ?? http.Client(),
       _workerUrl = (workerUrl ?? defaultR2WorkerUrl).replaceFirst(
         RegExp(r'/+$'),
         '',
       );

  final Future<String?> Function() _tokenProvider;
  final http.Client _http;
  final String _workerUrl;

  factory HttpCoreReadWorkerClient.forFirebase({
    FirebaseAuth? auth,
    http.Client? httpClient,
    String? workerUrl,
  }) {
    final firebaseAuth = auth ?? FirebaseAuth.instance;
    return HttpCoreReadWorkerClient(
      tokenProvider: () async {
        final user = firebaseAuth.currentUser;
        return user == null ? null : await user.getIdToken();
      },
      httpClient: httpClient,
      workerUrl: workerUrl,
    );
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const CoreReadWorkerException(
        401,
        'Please sign in again to continue.',
      );
    }

    final response = await _http.post(
      Uri.parse('$_workerUrl$path'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload ?? <String, dynamic>{}),
    );

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      body = <String, dynamic>{};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CoreReadWorkerException(
        response.statusCode,
        body['error'] as String? ?? 'Core read request failed.',
      );
    }
    return body;
  }

  void close() => _http.close();
}
