import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const String _workerBaseUrl = 'https://pubget-media.pubget.workers.dev';

Future<String> resolveEditMediaUrl(String key) async {
  if (key.isEmpty || key.startsWith('http://') || key.startsWith('https://')) {
    return key;
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Authentication required to play this Reel.');
  final token = await user.getIdToken();
  if (token == null || token.isEmpty) throw StateError('Authentication token unavailable.');
  final uri = Uri.parse('$_workerBaseUrl/edits/resolve').replace(
    queryParameters: {'key': key},
  );
  final response = await http.get(uri, headers: {'authorization': 'Bearer $token'});
  if (response.statusCode != 200) {
    throw StateError('Could not resolve Reel media (${response.statusCode}).');
  }
  final payload = jsonDecode(response.body);
  if (payload is! Map || payload['url'] is! String) {
    throw StateError('The media resolver returned an invalid response.');
  }
  return payload['url'] as String;
}
