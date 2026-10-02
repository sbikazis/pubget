import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/features/anime/l10n/anime_copy.dart';
import 'package:pubget/features/anime/widgets/anime_hub_widgets.dart';

void main() {
  const toggle = Key('anime-expandable-toggle');

  /// A paragraph long enough to be cut off at four lines in a narrow box, but
  /// short enough to fit four lines of a wide one.
  final paragraph = List<String>.filled(
    12,
    'The cartouche squadron was rebuilt from parts nobody was allowed to sell.',
  ).join(' ');

  Widget host(
    String text, {
    double width = 160,
    TextDirection direction = TextDirection.ltr,
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: width,
                child: AnimeExpandableText(text: text),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a paragraph that fits never offers a toggle', (tester) async {
    await tester.pumpWidget(host('Frieren: Beyond Journey\'s End.'));
    await tester.pumpAndSettle();

    expect(find.byKey(toggle), findsNothing);
  });

  testWidgets('an overflowing paragraph expands and collapses back', (
    tester,
  ) async {
    await tester.pumpWidget(host(paragraph));
    await tester.pumpAndSettle();

    final copy = AnimeCopy.forLocale(const Locale('en'));
    expect(find.byKey(toggle), findsOneWidget);
    expect(find.text(copy.showMore), findsOneWidget);

    await tester.tap(find.byKey(toggle));
    await tester.pumpAndSettle();
    // The way back has to stay reachable, or a long bio cannot be folded away.
    // Expanding pushes the toggle down with the text, so scroll it into view
    // the way a member would.
    await tester.ensureVisible(find.byKey(toggle));
    await tester.pumpAndSettle();
    expect(find.byKey(toggle), findsOneWidget);
    expect(find.text(copy.showLess), findsOneWidget);

    await tester.tap(find.byKey(toggle));
    await tester.pumpAndSettle();
    expect(find.text(copy.showMore), findsOneWidget);
  });

  testWidgets('overflow is measured in the reading direction', (tester) async {
    // A line made of bare numerals and a parenthesised year wraps differently
    // depending on the paragraph's base direction, so at this width it needs a
    // fourth line right-to-left and only three left-to-right. Measuring in one
    // fixed direction would offer "show more" to the half of the app that
    // never overflows, and hide it from the half that does.
    const width = 70.5;
    const numerals = '12 (2003) 2003';

    Widget narrow(TextDirection direction) => MaterialApp(
      theme: AppTheme.light,
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: width,
                child: const AnimeExpandableText(
                  text: numerals,
                  collapsedLines: 3,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(narrow(TextDirection.ltr));
    await tester.pumpAndSettle();
    expect(
      find.byKey(toggle),
      findsNothing,
      reason: 'three lines fit, so there is nothing to show',
    );

    await tester.pumpWidget(narrow(TextDirection.rtl));
    await tester.pumpAndSettle();
    expect(
      find.byKey(toggle),
      findsOneWidget,
      reason: 'the same text needs a fourth line right-to-left',
    );
  });

  testWidgets('overflow is measured at the reader\'s text scale', (tester) async {
    // A member who has turned the system font up sees a synopsis cut off four
    // lines earlier. Measuring at the default scale would report that the text
    // still fits and take the way to read it away.
    // Fits the four collapsed lines at the default scale, and needs more than
    // four at double. A measurement taken at the default scale would call this
    // text short and take the control away from the member who needs it.
    const synopsis = 'Engineers rebuild a crashed carrier in one quiet year.';

    await tester.pumpWidget(host(synopsis, width: 240));
    await tester.pumpAndSettle();
    expect(
      find.byKey(toggle),
      findsNothing,
      reason: 'at the default scale the whole synopsis fits',
    );

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: host(synopsis, width: 240),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(toggle), findsOneWidget);
  });

  testWidgets('an overflowing Arabic paragraph expands in Arabic', (
    tester,
  ) async {
    final arabic = List<String>.filled(
      20,
      'سرب الكارتوش أُعيد بناؤه من قطع Mechanics لا يسمح أحد ببيعها.',
    ).join(' ');
    await tester.pumpWidget(
      host(
        arabic,
        width: 200,
        direction: TextDirection.rtl,
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    final copy = AnimeCopy.forLocale(const Locale('ar'));
    expect(find.byKey(toggle), findsOneWidget);
    expect(find.text(copy.showMore), findsOneWidget);
    expect(find.text(copy.showMore), isNot(equals('Show more')));
  });
}
