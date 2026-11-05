import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persistent, bounded on-device cache for processed Kirari video renditions.
///
/// Files are written to a temporary sibling and atomically renamed only after
/// the complete response has been received. A process death can therefore
/// never make a partial download look like a playable cache hit.
class KirariVideoCache {
  KirariVideoCache({
    Directory? directory,
    HttpClient Function()? clientFactory,
    this.maxBytes = 400 * 1024 * 1024,
  })  : _directory = directory,
        _clientFactory = clientFactory ?? HttpClient.new;

  final Directory? _directory;
  final HttpClient Function() _clientFactory;
  final int maxBytes;

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
    if (!await file.exists() || await file.length() == 0) return null;
    await file.setLastModified(DateTime.now());
    return file;
  }

  Future<File> getOrDownload({
    required String reelId,
    required int quality,
    required Uri source,
  }) async {
    final root = await _root();
    final target = File('${root.path}/${_fileName(reelId, quality)}');
    if (await target.exists() && await target.length() > 0) {
      await target.setLastModified(DateTime.now());
      return target;
    }

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

        sink = temporary.openWrite();
        var received = 0;
        await for (final chunk in response.timeout(const Duration(seconds: 20))) {
          sink.add(chunk);
          received += chunk.length;
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
        await _prune(excluding: target.path);
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
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
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

  Future<void> _prune({required String excluding}) async {
    final root = await _root();
    final entries = <FileSystemEntity>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.mp4')) entries.add(entity);
    }

    final files = <({File file, int size, DateTime modified})>[];
    var total = 0;
    for (final entry in entries) {
      final stat = await entry.stat();
      final size = stat.size;
      total += size;
      files.add((file: File(entry.path), size: size, modified: stat.modified));
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
  }
}
