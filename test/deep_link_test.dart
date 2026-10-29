import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/app_route.dart';
import 'package:pubget/app/app_router.dart';
import 'package:pubget/core/links/deep_link.dart';
import 'package:pubget/core/links/pubget_links.dart';
import 'package:pubget/features/search/search_history.dart';
import 'package:pubget/features/search/search_rank.dart';

void main() {
  group('canonical deep links (spec §2.3)', () {
    test('/reel/{id} resolves to the Reels feed highlight route', () {
      final target = DeepLinkTarget.parseString('/reel/r1')!;
      expect(target.kind, DeepLinkKind.reel);
      expect(target.id, 'r1');
      expect(target.legacy, isFalse);
      expect(target.appRoute, '/reels?highlight=r1');
    });

    test('/work/{id} resolves to the Fan Work reader', () {
      final target = DeepLinkTarget.parseString('/work/w1')!;
      expect(target.kind, DeepLinkKind.work);
      expect(target.appRoute, '/fan-work/w1');
    });

    test('/hashtag/{tag} normalises case and strips the hash', () {
      final target = DeepLinkTarget.parseString('/hashtag/%23OnePiece')!;
      expect(target.kind, DeepLinkKind.hashtag);
      expect(target.id, 'onepiece');
      expect(target.appRoute, '/hashtag?tag=onepiece');
    });

    test('/audio/{id} and /group/{id} keep their identity', () {
      expect(DeepLinkTarget.parseString('/audio/a1')!.appRoute, '/audio/a1');
      expect(DeepLinkTarget.parseString('/group/g1')!.appRoute, '/group/g1');
    });

    test('/profile/{handle} is flagged as needing username resolution', () {
      final target = DeepLinkTarget.parseString('/profile/kirito')!;
      expect(target.kind, DeepLinkKind.profile);
      expect(target.id, 'kirito');
      // The profile screen is addressed by uid; claiming otherwise would open a
      // blank profile.
      expect(target.needsUsernameResolution, isTrue);
      expect(target.appRoute, '/profile?uid=kirito');
    });

    test('a leading @ on a profile handle is stripped', () {
      expect(DeepLinkTarget.parseString('/profile/@asuna')!.id, 'asuna');
    });

    test('full https URLs parse the same as bare paths', () {
      final target = DeepLinkTarget.parseString(
        'https://pubget-aaf27.web.app/reel/abc?utm=x',
      )!;
      expect(target.kind, DeepLinkKind.reel);
      expect(target.id, 'abc');
    });

    test('anime character links are not mistaken for anime links', () {
      final character = DeepLinkTarget.parseString('/anime/character/c9')!;
      expect(character.kind, DeepLinkKind.character);
      expect(character.appRoute, '/anime/character/c9');

      final anime = DeepLinkTarget.parseString('/anime/16498')!;
      expect(anime.kind, DeepLinkKind.anime);
      expect(anime.appRoute, '/anime/16498');
    });

    test('reserved anime sub-trees are not entity links', () {
      for (final path in <String>[
        '/anime',
        '/anime/ratings/pubget',
        '/anime/characters/favorites',
        '/anime/lists/mine',
      ]) {
        expect(
          DeepLinkTarget.parseString(path)!.kind,
          DeepLinkKind.unknown,
          reason: path,
        );
      }
    });
  });

  group('legacy links keep resolving', () {
    test('/fan-work/{id} maps to the work kind and is flagged legacy', () {
      final target = DeepLinkTarget.parseString('/fan-work/w1')!;
      expect(target.kind, DeepLinkKind.work);
      expect(target.legacy, isTrue);
      expect(target.appRoute, '/fan-work/w1');
    });

    test('/hashtag?tag= keeps working', () {
      final target = DeepLinkTarget.parseString('/hashtag?tag=naruto')!;
      expect(target.kind, DeepLinkKind.hashtag);
      expect(target.id, 'naruto');
      expect(target.legacy, isTrue);
    });

    test('/profile?uid= keeps working', () {
      final target = DeepLinkTarget.parseString('/profile?uid=u1')!;
      expect(target.kind, DeepLinkKind.profile);
      expect(target.id, 'u1');
      expect(target.legacy, isTrue);
    });

    test('/reels?highlight= keeps working', () {
      final target = DeepLinkTarget.parseString('/reels?highlight=r9')!;
      expect(target.kind, DeepLinkKind.reel);
      expect(target.id, 'r9');
      expect(target.legacy, isTrue);
    });

    test('/g/{id} short invite form resolves to a group', () {
      final target = DeepLinkTarget.parseString('/g/abc123')!;
      expect(target.kind, DeepLinkKind.group);
      expect(target.id, 'abc123');
      expect(target.legacy, isTrue);
    });
  });

  group('malformed input never throws', () {
    test('blank input yields null rather than a fake target', () {
      for (final raw in <String>['', '   ']) {
        expect(DeepLinkTarget.parseString(raw), isNull, reason: raw);
      }
    });

    test('root, garbage paths and bare prefixes degrade to unknown', () {
      for (final raw in <String>['/', '/nonsense/deep/path', '/reel', '/hashtag']) {
        final target = DeepLinkTarget.parseString(raw);
        expect(target, isNotNull, reason: raw);
        expect(target!.kind, DeepLinkKind.unknown, reason: raw);
        expect(target.isResolvable, isFalse, reason: raw);
      }
    });

    test('an unparseable URI string returns null instead of crashing', () {
      expect(DeepLinkTarget.parseString('ht!tp://%%%'), isNull);
    });

    test('unknown targets route to /unknown, never to a real screen', () {
      expect(
        DeepLinkTarget.parseString('/reel')!.appRoute,
        '/unknown',
      );
    });
  });

  group('link builders emit the canonical shapes', () {
    test('work, hashtag, store and short group paths', () {
      expect(PubgetLinks.workPath('w1'), '/work/w1');
      expect(PubgetLinks.work('w1'), 'https://pubget-aaf27.web.app/work/w1');
      expect(PubgetLinks.hashtagTagPath('One Piece'), '/hashtag/one%20piece');
      expect(PubgetLinks.hashtagTagPath('#Anime'), '/hashtag/anime');
      expect(PubgetLinks.storeItemPath('frame-1'), '/store/frame-1');
      expect(PubgetLinks.groupShort('g1'), 'https://pubget-aaf27.web.app/g/g1');
    });

    test('empty ids do not produce broken links', () {
      expect(PubgetLinks.hashtagTagPath('   '), '/reels');
      expect(PubgetLinks.workPath('  '), '');
    });

    test('built paths round-trip back through the parser', () {
      for (final built in <String>[
        PubgetLinks.workPath('w1'),
        PubgetLinks.hashtagTagPath('naruto'),
        PubgetLinks.storeItemPath('frame-1'),
        PubgetLinks.groupPath('g1'),
      ]) {
        expect(
          DeepLinkTarget.parseString(built)!.isResolvable,
          isTrue,
          reason: built,
        );
      }
    });
  });

  group('share text', () {
    test('a caption leads the share, the URL follows', () {
      expect(
        PubgetLinks.editShareText(caption: '  My edit ', url: 'https://x/reel/1'),
        'My edit\nhttps://x/reel/1',
      );
    });

    test('a captionless Reel shares the bare URL rather than an empty line', () {
      expect(
        PubgetLinks.editShareText(caption: '   ', url: 'https://x/reel/1'),
        'https://x/reel/1',
      );
    });

    test('a store share names the Store so it does not read as a payment ask', () {
      expect(
        PubgetLinks.storeShareText(name: 'Gold Frame', url: 'https://x/store/1'),
        'Gold Frame — Pubget Store\nhttps://x/store/1',
      );
    });
  });

  group('the router accepts the canonical paths', () {
    test('every spec §2.3 path maps to a screen route with its id', () {
      final cases = <String, ({String path, String key, String id})>{
        '/work/w1': (path: '/fan-work', key: 'workId', id: 'w1'),
        '/reel/r1': (path: '/reel', key: 'reelId', id: 'r1'),
        '/hashtag/onepiece': (path: '/hashtag', key: 'tag', id: 'onepiece'),
        '/audio/a1': (path: '/audio', key: 'audioId', id: 'a1'),
        '/group/g1': (path: '/group', key: 'groupId', id: 'g1'),
        '/profile/kirito': (path: '/profile', key: 'uid', id: 'kirito'),
        '/store/frame-1': (path: '/store/item', key: 'itemId', id: 'frame-1'),
      };
      for (final entry in cases.entries) {
        final route = AppRouter.routeFromString(entry.key);
        expect(route, isA<ParameterizedRoute>(), reason: entry.key);
        final parameterized = route as ParameterizedRoute;
        expect(parameterized.path, entry.value.path, reason: entry.key);
        expect(
          parameterized.parameters[entry.value.key],
          entry.value.id,
          reason: entry.key,
        );
      }
    });

    test('/g/{id} resolves in the router, not only in the web shim', () {
      // The web shim covers browsers; this covers in-app navigation and any
      // platform that hands the raw URL straight to the engine.
      final route = AppRouter.routeFromString('/g/g1') as ParameterizedRoute;
      expect(route.path, '/group');
      expect(route.parameters['groupId'], 'g1');
    });

    test('the parser output is itself routable', () {
      for (final link in <String>[
        '/reel/r1',
        '/work/w1',
        '/hashtag/onepiece',
        '/audio/a1',
        '/group/g1',
        '/store/frame-1',
      ]) {
        final appRoute = DeepLinkTarget.parseString(link)!.appRoute;
        final route = AppRouter.routeFromString(appRoute);
        expect(
          (route as ParameterizedRoute).path,
          isNot('/unknown'),
          reason: '$link -> $appRoute',
        );
      }
    });
  });

  group('fuzzy matching', () {
    test('exact, prefix, word-prefix and substring all match, best first', () {
      expect(SearchRank.score('naruto', 'Naruto'), 1000);
      // A prefix loses points per unmatched character, so the tighter query
      // ranks higher — that is what makes typing more letters reorder results.
      expect(
        SearchRank.score('nar', 'Naruto Shippuden')! <
            SearchRank.score('naru', 'Naruto Shippuden')!,
        isTrue,
      );
      final prefix = SearchRank.score('nar', 'Naruto Shippuden')!;
      final wordPrefix = SearchRank.score('shippuden', 'Naruto Shippuden')!;
      expect(prefix, greaterThan(wordPrefix));
      expect(wordPrefix, greaterThan(400));
      expect(SearchRank.score('ruto', 'Naruto')! > 0, isTrue);
    });

    test('Arabic diacritics and alef variants do not block a match', () {
      expect(SearchRank.matches('انمى', 'أنمى'), isTrue);
      expect(SearchRank.matches('أنمي', 'انمي'), isTrue);
    });

    test('a typo of one missing letter still matches in order', () {
      expect(SearchRank.matches('narto', 'Naruto'), isTrue);
    });

    test('genuinely absent characters do not match', () {
      expect(SearchRank.score('zzz', 'Naruto'), isNull);
      expect(SearchRank.score('', 'Naruto'), isNull);
      expect(SearchRank.score('naruto', ''), isNull);
    });

    test('rank drops non-matches and keeps ties in their original order', () {
      final ranked = SearchRank.rank(
        <String>['Bleach', 'Naruto', 'One Piece', 'Naruto Shippuden'],
        'naruto',
        (item) => item,
      );
      expect(ranked.first, 'Naruto');
      expect(ranked, isNot(contains('Bleach')));
      expect(ranked.contains('One Piece'), isFalse);
      expect(ranked.length, 2);
    });
  });

  group('recent search history', () {
    test('records newest-first and de-duplicates case-insensitively', () async {
      final history = SearchHistory();
      await history.record('Naruto');
      await history.record('bleach');
      await history.record('naruto');

      expect(history.entries, <String>['naruto', 'bleach']);
    });

    test('re-searching moves a term to the front instead of duplicating', () async {
      final history = SearchHistory(store: MemorySearchHistoryStore(<String>['a', 'b']));
      await history.load();
      await history.record('b');
      expect(history.entries, <String>['b', 'a']);
    });

    test('caps at maxEntries, dropping the oldest', () async {
      final history = SearchHistory();
      for (var i = 0; i < SearchHistory.maxEntries + 3; i += 1) {
        await history.record('term $i');
      }
      expect(history.entries.length, SearchHistory.maxEntries);
      expect(history.entries.first, 'term 10');
      expect(history.entries, isNot(contains('term 0')));
    });

    test('a store holding duplicates or blanks is sanitised on load', () async {
      final history = SearchHistory(
        store: MemorySearchHistoryStore(<String>['  ', 'Dup', 'dup', 'x']),
      );
      await history.load();
      expect(history.entries, <String>['Dup', 'x']);
    });

    test('remove and clear both persist through the store', () async {
      final store = MemorySearchHistoryStore();
      final history = SearchHistory(store: store);
      await history.record('one');
      await history.record('two');

      await history.remove('one');
      expect(await store.read(), <String>['two']);

      await history.clear();
      expect(await store.read(), isEmpty);
      expect(history.isEmpty, isTrue);
    });

    test('blank input is ignored rather than stored', () async {
      final history = SearchHistory();
      await history.record('   ');
      expect(history.entries, isEmpty);
    });
  });
}
