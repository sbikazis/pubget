import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/app/design_system_showcase_page.dart';

void main() {
  testWidgets('showcase toggles theme and text direction live', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: DesignSystemShowcasePage()),
    );
    await tester.pump();

    BuildContext contentContext() =>
        tester.element(find.byKey(const Key('showcase-content')));

    expect(Theme.of(contentContext()).brightness, Brightness.light);
    expect(Directionality.of(contentContext()), TextDirection.ltr);

    await tester.tap(find.byKey(const Key('showcase-theme-switch')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(Theme.of(contentContext()).brightness, Brightness.dark);

    await tester.tap(find.byKey(const Key('showcase-direction-switch')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(Directionality.of(contentContext()), TextDirection.rtl);
  });

  testWidgets('showcase exposes the requested component groups', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: DesignSystemShowcasePage()),
    );

    expect(find.text('Buttons'), findsOneWidget);
    expect(find.text('Inputs'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Cards, avatars & badges'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cards, avatars & badges'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('LoadingState mapping'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('LoadingState mapping'), findsOneWidget);
  });
}
