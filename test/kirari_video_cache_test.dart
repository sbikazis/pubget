import 'dart:convert';
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

  test('stores a complete rendition and reuses it after cache recreation', () async {
    final uri = Uri.parse('http://${server.address.address}:${server.port}/video.mp4');
    final firstCache = KirariVideoCache(directory: directory);
    final first = await firstCache.getOrDownload(
      reelId: 'reel-1',
      quality: 540,
      source: uri,
    );

    expect(await first.length(), bytes.length);
    expect(await first.readAsBytes(), bytes);
    expect(requests, 1);

    final secondCache = KirariVideoCache(directory: directory);
    final second = await secondCache.getOrDownload(
      reelId: 'reel-1',
      quality: 540,
      source: uri,
    );

    expect(second.path, first.path);
    expect(requests, 1);
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
    final uri = Uri.parse('http://${server.address.address}:${server.port}/video.mp4');
    await expectLater(
      cache.getOrDownload(reelId: 'reel-2', quality: 360, source: uri),
      throwsA(isA<StateError>()),
    );

    expect(await Directory(directory.path).list().toList(), isEmpty);
  });
}
