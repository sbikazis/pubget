import 'package:web/web.dart' as web;

Future<bool> probeNetwork() async => web.window.navigator.onLine;
