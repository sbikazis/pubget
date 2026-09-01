import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/core/widgets/pubget_buttons.dart';

void main() {
  testWidgets('enabled buttons preserve their native semantic tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              PubgetPrimaryButton(
                onPressed: () {},
                semanticLabel: 'Primary action',
                child: const Text('Primary'),
              ),
              PubgetSecondaryButton(
                onPressed: () {},
                semanticLabel: 'Secondary action',
                child: const Text('Secondary'),
              ),
              PubgetTextButton(
                onPressed: () {},
                semanticLabel: 'Text action',
                child: const Text('Text'),
              ),
            ],
          ),
        ),
      ),
    );

    for (final label in <String>[
      'Primary action',
      'Secondary action',
      'Text action',
    ]) {
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    }
    semantics.dispose();
  });

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
    final node = tester.getSemantics(find.bySemanticsLabel('Send message'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets('disabled button does not expose a semantic tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PubgetPrimaryButton(
            onPressed: null,
            semanticLabel: 'Unavailable action',
            child: Text('Unavailable'),
          ),
        ),
      ),
    );

    final node = tester.getSemantics(
      find.bySemanticsLabel('Unavailable action'),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
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
