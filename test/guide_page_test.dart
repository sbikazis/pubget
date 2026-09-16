import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/features/settings/screens/guide_page.dart';

void main() {
  testWidgets('guide is searchable and lists core Pubget domains', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const GuidePage(),
      ),
    );

    expect(find.text('Guide'), findsOneWidget);
    expect(find.text('Groups'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'respect');
    await tester.pump();
    expect(find.text('Respect and Fans'), findsOneWidget);
    expect(find.text('Edits'), findsNothing);

    await tester.enterText(find.byType(TextField), 'mafia');
    await tester.pump();
    expect(find.text('Mafia'), findsOneWidget);
    expect(find.text('Edits'), findsNothing);
  });
}
