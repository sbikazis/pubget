import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/links/pubget_links.dart';
import 'package:pubget/features/events/widgets/event_widgets.dart';

void main() {
  test('copy path stays relative and native share uses the canonical host', () {
    expect(EventLinks.path('abc 1'), '/event/abc%201');
    expect(
      EventLinks.canonical('abc 1'),
      'https://pubget-aaf27.web.app/event/abc%201',
    );
  });

  testWidgets('native share sends the canonical event deep link', (
    tester,
  ) async {
    String? shared;
    PubgetLinks.debugNativeShare = (text, subject) async {
      shared = text;
    };
    addTearDown(() => PubgetLinks.debugNativeShare = null);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => EventLinks.share(context, 'e1', title: 'Quiz'),
            child: const Text('Share'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(shared, 'https://pubget-aaf27.web.app/event/e1');
  });
}

