import 'dart:async';
import 'dart:io';

Future<bool> probeNetwork() async {
  try {
    final result = await InternetAddress.lookup(
      'example.com',
    ).timeout(const Duration(seconds: 3));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  }
}
