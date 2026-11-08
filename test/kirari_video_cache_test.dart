import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/kirari/data/kirari_video_cache.dart';

void main() {
  late Directory directory;
  late HttpServer server;
  var requests = 0;
  final bytes = List<int>.generate(256 * 1024, (index) => index % 251);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kirari-cache-test-');
    requests = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentLength = bytes.length;
      request.response.add(bytes);
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  Uri testUri() => Uri.parse('http://${server.address.address}:${server.port}/video.mp4');

  test('stores a complete rendition and reuses it after cache recreation', () async {
    final firstCache = KirariVideoCache(directory: directory);
    final first = await firstCache.getOrDownload(
      reelId: 'reel-1', quality: 540, source: testUri(),
    );
    expect(await first.length(), bytes.length);
    expect(await first.readAsBytes(), bytes);
    expect(requests, 1);

    final secondCache = KirariVideoCache(directory: directory);
    final second = await secondCache.getOrDownload(
      reelId: 'reel-1', quality: 540, source: testUri(),
    );
    expect(second.path, first.path);
    expect(requests, 1);
  });

  test('deduplicates simultaneous downloads for the same rendition', () async {
    final cache = KirariVideoCache(directory: directory);
    final results = await Future.wait([
      cache.getOrDownload(reelId: 'reel-2', quality: 360, source: testUri()),
      cache.getOrDownload(reelId: 'reel-2', quality: 360, source: testUri()),
    ]);
    expect(results[0].path, results[1].path);
    expect(requests, 1);
  });

  test('rejects a rendition larger than the configured cache file limit', () async {
    final cache = KirariVideoCache(
      directory: directory,
      maxBytes: 128 * 1024,
      maxFileBytes: 128 * 1024,
    );
    await expectLater(
      cache.getOrDownload(reelId: 'reel-3', quality: 360, source: testUri()),
      throwsA(isA<StateError>()),
    );
    expect(await Directory(directory.path).list().toList(), isEmpty);
  });

  test('does not expose a failed partial download as a cache hit', () async {
    await server.close(force: true);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests++;
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('temporary failure');
      await request.response.close();
    });

    final cache = KirariVideoCache(directory: directory);
    await expectLater(
      cache.getOrDownload(reelId: 'reel-4', quality: 360, source: testUri()),
      throwsA(isA<StateError>()),
    );
    expect(await Directory(directory.path).list().toList(), isEmpty);
  });

  test('evicts the least-recently-used rendition without exceeding the cache budget', () async {
    final cache = KirariVideoCache(
      directory: directory,
      maxBytes: 300 * 1024,
      maxFileBytes: 300 * 1024,
    );
    final first = await cache.getOrDownload(
      reelId: 'old-reel', quality: 360, source: testUri(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final second = await cache.getOrDownload(
      reelId: 'new-reel', quality: 360, source: testUri(),
    );

    expect(await first.exists(), isFalse);
    expect(await second.exists(), isTrue);
    final cachedFiles = await Directory(directory.path)
        .list()
        .where((entity) => entity.path.endsWith('.mp4'))
        .cast<File>()
        .toList();
    final totalBytes = cachedFiles.fold<int>(0, (sum, file) => sum + file.lengthSync());
    expect(totalBytes, lessThanOrEqualTo(300 * 1024));
  });

}
