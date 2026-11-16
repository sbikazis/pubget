import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_route.dart';
import 'package:pubget/app/app_router.dart';
import 'package:pubget/core/links/pubget_links.dart';

/// A shared link is a promise: the router accepts it, and the app has a page
/// to keep that promise. This guard fails when either side drifts.
void main() {
  /// Read the registration maps from source so the guard cannot silently
  /// approve a path just because a test copied the same typo.
  Set<String> registeredPaths() {
    final paths = <String>{};
    const files = <String>[
      'lib/app/pubget_app.dart',
      'lib/app/entity_routes.dart',
    ];
    final literal = RegExp(r"'/(?:[A-Za-z0-9_]+/)*[A-Za-z0-9_]+'");
    for (final file in files) {
      final source = File(file).readAsStringSync();
      for (final match in literal.allMatches(source)) {
        paths.add(match.group(0)!.replaceAll("'", ''));
      }
    }
    return paths;
  }

  const requiredKeys = <String, String>{
    '/reel': 'reelId',
    '/audio': 'audioId',
    '/hashtag': 'tag',
    '/event': 'eventId',
    '/game': 'gameId',
    '/mafia': 'gameId',
    '/fan-work': 'workId',
    '/group': 'groupId',
    '/profile': 'uid',
    '/anime/details': 'animeId',
    '/anime/character': 'characterId',
    '/anime/studio': 'studioId',
    '/store/item': 'itemId',
  };

  test('every production share link resolves to a registered page', () {
    final registered = registeredPaths();
    final links = <String>[
      PubgetLinks.event('e1'),
      PubgetLinks.fanWork('w1'),
      PubgetLinks.work('w2'),
      PubgetLinks.reel('r1'),
      PubgetLinks.audio('a1'),
      PubgetLinks.hashtag('One Piece'),
      PubgetLinks.anime('42'),
      PubgetLinks.character('c1'),
      PubgetLinks.group('g1'),
      PubgetLinks.groupShort('g2'),
      PubgetLinks.profile('u1'),
      PubgetLinks.storeItem('s1'),
      PubgetLinks.animeReels('42'),
      PubgetLinks.characterReels('c1'),
      PubgetLinks.creatorReels('u1'),
      PubgetLinks.editHighlight('r2'),
      PubgetLinks.reelHighlight('r3'),
    ];

    for (final link in links) {
      final route = AppRouter.routeFromString(link) as ParameterizedRoute;
      expect(route.path, isNot('/unknown'), reason: link);
      expect(registered, contains(route.path), reason: link);
      final key = requiredKeys[route.path];
      if (key != null) {
        expect(route.parameters[key]?.trim(), isNotEmpty, reason: link);
      }
    }
  });

  test('legacy links already in the wild still land on a registered page', () {
    final registered = registeredPaths();
    final legacy = <String>[
      '/fan-work/w1',
      '/hashtag?tag=anime',
      '/profile?uid=u1',
      '/edits?highlight=r1',
      '/reels?highlight=r1',
      '/reels/anime/42',
      '/reels/character/c1',
      '/reels/creator/u1',
      '/anime/character/c1',
      '/anime/characters/favorites',
      '/anime/ratings/pubget',
      '/anime/studio?studioId=1',
      '/anime/updated',
      '/g/g3',
      '/game/gm1',
      '/mafia/m1',
    ];

    for (final link in legacy) {
      final route = AppRouter.routeFromString(link) as ParameterizedRoute;
      expect(route.path, isNot('/unknown'), reason: link);
      expect(registered, contains(route.path), reason: link);
      final key = requiredKeys[route.path];
      if (key != null) {
        expect(route.parameters[key]?.trim(), isNotEmpty, reason: link);
      }
    }
  });

  test('new scoped reel helpers emit canonical entity paths', () {
    expect(PubgetLinks.animeReelsPath('42'), PubgetLinks.animePath('42'));
    expect(
      PubgetLinks.characterReelsPath('c1'),
      PubgetLinks.characterPath('c1'),
    );
    expect(PubgetLinks.creatorReelsPath('u1'), PubgetLinks.profilePath('u1'));
  });

  test('legacy scoped reels links redirect to the entity that owns them', () {
    ParameterizedRoute parse(String raw) =>
        AppRouter.routeFromString(raw) as ParameterizedRoute;

    final anime = parse('/reels/anime/42?ref=share');
    expect(anime.path, '/anime/details');
    expect(anime.parameters['animeId'], '42');
    expect(anime.parameters['ref'], 'share');

    final character = parse('/reels/character/c1');
    expect(character.path, '/anime/character');
    expect(character.parameters['characterId'], 'c1');

    final creator = parse('/reels/creator/u1');
    expect(creator.path, '/profile');
    expect(creator.parameters['uid'], 'u1');
  });
}
