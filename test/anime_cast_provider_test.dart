import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/anime/models/anime_models.dart';
import 'package:pubget/features/anime/providers/anime_cast_provider.dart';

import 'anime_test_support.dart';

void main() {
  test('loads the cast and filters by name or role', () async {
    final provider = AnimeCastProvider(
      repository: FakeAnimeRepository(
        characters: const <AnimeCharacter>[
          AnimeCharacter(id: '10', name: 'Frieren', role: 'Main'),
          AnimeCharacter(id: '11', name: 'Fern', role: 'Main'),
          AnimeCharacter(id: '12', name: 'Aura', role: 'Supporting'),
        ],
      ),
    );
    addTearDown(provider.dispose);

    await provider.load('52991');
    expect(provider.state, LoadingState.loaded);
    expect(provider.visible, hasLength(3));

    provider.search('fe');
    expect(provider.visible.single.name, 'Fern');

    provider.search('frier');
    expect(provider.visible.single.name, 'Frieren');

    provider.search('supporting');
    expect(provider.visible.single.name, 'Aura');

    provider.search('');
    expect(provider.visible, hasLength(3));
  });

  test('an empty cast is an empty state and a blank id short-circuits', () async {
    final empty = AnimeCastProvider(repository: FakeAnimeRepository());
    addTearDown(empty.dispose);
    await empty.load('52991');
    expect(empty.state, LoadingState.empty);

    final missing = AnimeCastProvider(repository: FakeAnimeRepository());
    addTearDown(missing.dispose);
    await missing.load('   ');
    expect(missing.state, LoadingState.empty);
  });

  test('a failure surfaces the error state with the reason', () async {
    final provider = AnimeCastProvider(
      repository: FakeAnimeRepository(charactersFailure: const NetworkError()),
    );
    addTearDown(provider.dispose);
    await provider.load('52991');
    expect(provider.state, LoadingState.offline);
    expect(provider.failure, isA<NetworkError>());
  });
}