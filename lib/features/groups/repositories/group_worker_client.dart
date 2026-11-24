import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/http_status_failure.dart';
import '../../../core/media/media_storage_provider.dart';

/// HTTP failure from a privileged Pubget Worker route. The status code is the
/// only trustworthy signal: a 503 is a backend failure, not a lost connection.
class GroupWorkerException implements Exception, HttpStatusFailure {
  const GroupWorkerException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'GroupWorkerException($statusCode): $message';
}

/// Injectable boundary so repository tests never need a live Firebase app.
abstract interface class GroupWorkerClient {
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> payload);
}

final class HttpGroupWorkerClient implements GroupWorkerClient {
  HttpGroupWorkerClient({
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

  factory HttpGroupWorkerClient.forFirebase({
    FirebaseAuth? auth,
    http.Client? httpClient,
    String? workerUrl,
  }) {
    final firebaseAuth = auth ?? FirebaseAuth.instance;
    return HttpGroupWorkerClient(
      tokenProvider: () async => firebaseAuth.currentUser == null
          ? null
          : await firebaseAuth.currentUser?.getIdToken(),
      httpClient: httpClient,
      workerUrl: workerUrl,
    );
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const GroupWorkerException(
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
      body: jsonEncode(payload),
    );
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      body = <String, dynamic>{};
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GroupWorkerException(
        response.statusCode,
        body['error'] as String? ?? 'Group request failed.',
      );
    }
    return body;
  }

  void close() => _http.close();
}
