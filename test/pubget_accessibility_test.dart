import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/core/widgets/pubget_buttons.dart';

void main() {
  testWidgets('loading button preserves its accessible action name', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: PubgetPrimaryButton(
            onPressed: () {},
            semanticLabel: 'Send message',
            loading: true,
            child: const Text('Send'),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Send message'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('button content follows RTL directional ordering', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: PubgetPrimaryButton(
                onPressed: () {},
                semanticLabel: 'Create story',
                leadingIcon: Icons.auto_awesome,
                child: const Text('إنشاء قصة'),
              ),
            ),
          ),
        ),
      ),
    );

    final iconCenter = tester.getCenter(find.byIcon(Icons.auto_awesome));
    final textCenter = tester.getCenter(find.text('إنشاء قصة'));
    expect(iconCenter.dx, greaterThan(textCenter.dx));
  });

  testWidgets('icon button exposes its required tooltip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PubgetIconButton(
            icon: Icons.favorite_border,
            tooltip: 'Add to favorites',
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('Add to favorites'), findsOneWidget);
  });
}
