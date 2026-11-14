import 'package:web/web.dart' as web;

/// Browsers do not expose a portable cross-origin internet reachability probe:
/// navigator.onLine is therefore a link-state hint, not proof that Firebase or
/// a particular API is reachable. Feature requests still handle real failures.
Future<bool> probeNetwork() async => web.window.navigator.onLine;
