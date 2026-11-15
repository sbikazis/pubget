import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../media/media_storage_provider.dart';

class IdentityWorkerException implements Exception {
  const IdentityWorkerException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'IdentityWorkerException($statusCode): $message';
}

/// Authenticated client for username reservation and profile mutations.
/// Firebase remains the user identity provider; the Worker owns privileged
/// Firestore transactions. No service-account credential is shipped to Flutter.
class IdentityWorkerClient {
  IdentityWorkerClient({
    FirebaseAuth? auth,
    http.Client? httpClient,
    String? workerUrl,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _http = httpClient ?? http.Client(),
       _workerUrl = (workerUrl ?? defaultR2WorkerUrl).replaceFirst(RegExp(r'/+$'), '');

  final FirebaseAuth _auth;
  final http.Client _http;
  final String _workerUrl;

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw const IdentityWorkerException(401, 'Authentication required.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const IdentityWorkerException(401, 'Authentication token unavailable.');
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
      throw IdentityWorkerException(
        response.statusCode,
        body['error'] as String? ?? 'Identity request failed.',
      );
    }
    return body;
  }

  void close() => _http.close();
}
