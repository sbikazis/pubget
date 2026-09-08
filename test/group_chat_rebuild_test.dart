import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/groups/widgets/chat_contrast_theme.dart';
import 'package:pubget/features/groups/widgets/event_center_sheet.dart';
import 'package:pubget/features/games/models/game_type_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chat contrast + default wallpaper', () {
    test('null background uses the official asset wallpaper', () {
      final theme = ChatContrastTheme.fromBackground(null);
      expect(theme.isImageBackground, isTrue);
      expect(theme.bubblesAreReadable, isTrue);
      final image = theme.background.image?.image;
      expect(image, isA<AssetImage>());
      expect(
        (image! as AssetImage).assetName,
        kPubgetDefaultChatWallpaperAsset,
      );
    });

    test('named presets stay readable on dark and light walls', () {
      for (final id in <String?>[
        null,
        'pubget://midnight',
        'pubget://dawn',
        'pubget://forest',
        'pubget://royal',
      ]) {
        final theme = ChatContrastTheme.fromBackground(id);
        expect(
          theme.bubblesAreReadable,
          isTrue,
          reason: 'failed for $id',
        );
      }
    });

    test('remote wallpaper falls back to a dark readable theme', () {
      final theme = ChatContrastTheme.fromBackground(
        'https://example.test/wall.jpg',
      );
      expect(theme.isImageBackground, isTrue);
      expect(theme.bubblesAreReadable, isTrue);
    });

    test('picker catalog starts with the official wallpaper', () {
      expect(pubgetChatBackgrounds.first.$1, isNull);
      expect(pubgetChatBackgrounds.first.$2, 'Pubget Classic');
    });
  });

  testWidgets('Event Center lists the four registered games', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EventCenterSheet(groupId: 'g1'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Event Center'), findsOneWidget);
    for (final spec in GameTypeRegistry.implemented) {
      expect(find.text(spec.name), findsWidgets);
    }
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('All group games'), findsOneWidget);
    expect(find.textContaining('isolated room'), findsWidgets);
  });
}
