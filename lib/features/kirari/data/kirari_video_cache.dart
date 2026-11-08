import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persistent, bounded on-device cache for processed Kirari video renditions.
///
/// Downloads are deduplicated, size-limited and written to a temporary sibling.
/// A cache hit is exposed only after the complete response has been atomically
/// renamed into place.
class KirariVideoCache {
  KirariVideoCache({
    Directory? directory,
    HttpClient Function()? clientFactory,
    this.maxBytes = 400 * 1024 * 1024,
    this.maxFileBytes = 180 * 1024 * 1024,
  })  : _directory = directory,
        _clientFactory = clientFactory ?? HttpClient.new;

  final Directory? _directory;
  final HttpClient Function() _clientFactory;
  final int maxBytes;
  final int maxFileBytes;

  static final Map<String, Future<File>> _inFlight = <String, Future<File>>{};
  static Future<void> _pruneQueue = Future<void>.value();

  Future<Directory> _root() async {
    final directory = _directory ??
        Directory('${(await getApplicationSupportDirectory()).path}/kirari_video_cache');
    await directory.create(recursive: true);
    return directory;
  }

  String _fileName(String reelId, int quality) {
    final key = base64Url.encode(utf8.encode('$reelId-$quality')).replaceAll('=', '');
    return '$key.mp4';
  }

  Future<File?> getCached({
    required String reelId,
    required int quality,
  }) async {
    final root = await _root();
    final file = File('${root.path}/${_fileName(reelId, quality)}');
    if (!await file.exists()) return null;
    final size = await file.length();
    if (size <= 0 || size > maxFileBytes) {
      await file.delete().catchError((_) => file);
      return null;
    }
    await file.setLastModified(DateTime.now());
    return file;
  }

  Future<File> getOrDownload({
    required String reelId,
    required int quality,
    required Uri source,
  }) async {
    if (maxBytes <= 0 || maxFileBytes <= 0) {
      throw ArgumentError('Kirari cache limits must be positive.');
    }
    if (source.scheme != 'https' && source.scheme != 'http') {
      throw ArgumentError.value(source, 'source', 'A valid HTTP(S) URL is required.');
    }
    final root = await _root();
    final target = File('${root.path}/${_fileName(reelId, quality)}');
    if (await target.exists()) {
      final size = await target.length();
      if (size > 0 && size <= maxFileBytes) {
        await target.setLastModified(DateTime.now());
        return target;
      }
      await target.delete().catchError((_) => target);
    }

    final key = target.absolute.path;
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final pending = _download(root: root, target: target, source: source);
    _inFlight[key] = pending;
    try {
      return await pending;
    } finally {
      if (identical(_inFlight[key], pending)) _inFlight.remove(key);
    }
  }

  Future<File> _download({
    required Directory root,
    required File target,
    required Uri source,
  }) async {
    await _removeStalePartials(root);
    final temporary = File('${target.path}.part');
    Object? lastError;

    for (var attempt = 0; attempt < 3; attempt++) {
      final client = _clientFactory()..connectionTimeout = const Duration(seconds: 12);
      IOSink? sink;
      try {
        if (await temporary.exists()) await temporary.delete();
        final request = await client.getUrl(source).timeout(const Duration(seconds: 15));
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        final response = await request.close().timeout(const Duration(seconds: 20));
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          throw HttpException('Video cache download returned HTTP ${response.statusCode}.');
        }
        if (response.contentLength > maxFileBytes ||
            response.contentLength > maxBytes) {
          await response.drain<void>();
          throw HttpException('Video rendition exceeds the configured cache file limit.');
        }

        sink = temporary.openWrite();
        var received = 0;
        await for (final chunk in response.timeout(const Duration(seconds: 20))) {
          received += chunk.length;
          if (received > maxFileBytes || received > maxBytes) {
            throw HttpException('Video rendition exceeded the configured cache file limit.');
          }
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();
        sink = null;

        if (received == 0 ||
            (response.contentLength >= 0 && received != response.contentLength)) {
          throw const HttpException('Video cache download was incomplete.');
        }
        if (await target.exists()) await target.delete();
        await temporary.rename(target.path);
        final total = await _prune(excluding: target.path);
        if (total > maxBytes) {
          await target.delete().catchError((_) => target);
          throw HttpException('Insufficient cache space for this video rendition.');
        }
        return target;
      } catch (error) {
        lastError = error;
        try {
          await sink?.close();
        } catch (_) {}
        try {
          if (await temporary.exists()) await temporary.delete();
        } catch (_) {}
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
      } finally {
        client.close(force: true);
      }
    }
    throw StateError('Unable to cache Kirari video: $lastError');
  }

  Future<void> _removeStalePartials(Directory root) async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 6));
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.part')) continue;
      try {
        if ((await entity.stat()).modified.isBefore(cutoff)) {
          await entity.delete();
        }
      } catch (_) {
        // A concurrent writer may still own this temporary file.
      }
    }
  }

  Future<int> _prune({required String excluding}) async {
    final previous = _pruneQueue;
    final release = Completer<void>();
    _pruneQueue = release.future;
    await previous;
    try {
      final root = await _root();
      final files = <({File file, int size, DateTime modified})>[];
      var total = 0;
      await for (final entity in root.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.mp4')) continue;
        final stat = await entity.stat();
        total += stat.size;
        files.add((file: entity, size: stat.size, modified: stat.modified));
      }
      files.sort((a, b) => a.modified.compareTo(b.modified));

      for (final item in files) {
        if (total <= maxBytes) break;
        if (item.file.path == excluding) continue;
        try {
          await item.file.delete();
          total -= item.size;
        } catch (_) {
          // A file currently held by a player is left in place.
        }
      }
      return total;
    } finally {
      release.complete();
    }
  }
}
