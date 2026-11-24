/// Resolves media objects that still live only in the legacy Firebase Storage
/// bucket.
///
/// The app no longer depends on the Firebase Storage SDK. A signed-in callable
/// checks conversation/work ownership on the server and mints a short-lived
/// GCS URL, so the client never holds a permanent download token.
library;

import 'package:cloud_functions/cloud_functions.dart';

import 'media_url_cache.dart';

/// Injectable callable shape; tests supply a deterministic implementation.
typedef LegacyMediaCall =
    Future<Map<dynamic, dynamic>> Function(Map<String, dynamic> data);

final class LegacyMediaResolver {
  LegacyMediaResolver({
    FirebaseFunctions? functions,
    MediaUrlCache? cache,
    LegacyMediaCall? call,
  })  : _functions = functions,
        _cache = cache ?? mediaUrlCache,
        _call = call;

  final FirebaseFunctions? _functions;
  final MediaUrlCache _cache;
  final LegacyMediaCall? _call;

  /// Creates Firebase clients only on first use, so importing this library in
  /// a unit test never requires an initialized Firebase app.
  Future<Map<dynamic, dynamic>> _invoke(Map<String, dynamic> data) async {
    final injected = _call;
    if (injected != null) return await injected(data);
    final client =
        _functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');
    final result = await client
        .httpsCallable('resolveLegacyMedia')
        .call<Map<dynamic, dynamic>>(data);
    return result.data;
  }

  /// Returns a short-lived URL, or `null` when the object is absent,
  /// unauthorized or the bridge is unavailable. Failures never fall back to
  /// a long-lived bearer URL.
  Future<ResolvedMediaUrl?> resolve(String reference) async {
    final path = reference.trim();
    if (path.isEmpty || path.length > 1024 || path.contains('://')) return null;

    final cached = _cache.readEntry(path);
    if (cached != null) return cached;

    try {
      final result = await _invoke(<String, dynamic>{'path': path});
      final url = result['url'] as String?;
      final expires = result['expiresAt'];
      if (url == null || !url.startsWith('https://') || expires is! num) {
        return null;
      }
      final resolved = ResolvedMediaUrl(
        url: url,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(expires.toInt() * 1000),
      );
      _cache.write(path, resolved);
      return resolved;
    } on Object {
      return null;
    }
  }
}

/// Default resolver used by media and Kirari repositories. Tests inject their
/// own instance through the repository constructors.
final LegacyMediaResolver legacyMediaResolver = LegacyMediaResolver();
