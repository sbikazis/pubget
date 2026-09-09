import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/groups/widgets/wa_composer/wa_attachment_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('premium attachment sheet shows luxury actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open-attach'),
                  onPressed: () {
                    showPremiumAttachmentSheet(
                      context,
                      groupId: 'g1',
                      onCamera: () {},
                      onGallery: () {},
                      onGames: () {},
                      onCreateEvent: () {},
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-attach')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 850));

    expect(find.text('المعرض'), findsOneWidget);
    expect(find.text('كاميرا'), findsOneWidget);
    expect(find.text('إنشاء فعالية'), findsOneWidget);
    expect(find.text('الألعاب'), findsOneWidget);
  });
}
