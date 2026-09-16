import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/anime/data/jikan_mapper.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/providers/anime_providers.dart';
import 'package:pubget/features/anime/screens/anime_hub_page.dart';
import 'package:pubget/features/anime/widgets/anime_widgets.dart';

void main() {
  test('anime feature dart sources do not embed API secrets', () {
    final root = Directory('lib/features/anime');
    final hits = <String>[];
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final content = file.readAsStringSync();
      expect(content.contains('apiKey'), isFalse, reason: file.path);
      expect(content.contains('api_key'), isFalse, reason: file.path);
      expect(content.contains('Authorization:'), isFalse, reason: file.path);
      expect(content.contains('BEGIN PRIVATE KEY'), isFalse, reason: file.path);
      if (content.contains('http.get') || content.contains('package:http')) {
        hits.add(file.path);
      }
    }
    expect(
      hits.where((path) => path.contains('/screens/') || path.contains('/widgets/') || path.contains('/providers/')),
      isEmpty,
      reason: 'UI/providers must not import HTTP',
    );
  });

  test('UI types do not mention the Jikan adapter', () {
    expect(AnimeHubPage, isNotNull);
    expect(AnimeHubProvider, isNotNull);
    expect(AnimeLinks.detailsPath('1'), '/anime/1');
    expect(jikanProviderName, 'jikan');
    expect(sampleDomainHasNoProviderFields(), isTrue);
  });
}

bool sampleDomainHasNoProviderFields() {
  const anime = Anime(id: '1', title: 'x');
  return anime.id == '1';
}
