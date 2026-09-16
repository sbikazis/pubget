import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pubget/features/edits/providers/edit_upload_manager.dart';
import 'package:pubget/features/edits/widgets/global_edit_upload_bar.dart';

import 'edits_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('global bar stays visible while uploading', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = FakeEditsRepository();
    final manager = EditUploadManager(repository: repo);
    await manager.restore();
    await manager.enqueue(
      caption: 'hi',
      animeTag: '',
      contentType: 'video/mp4',
      fileName: 'reel.mp4',
      localPath: '/tmp/reel.mp4',
      sizeBytes: 100,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<EditUploadManager>.value(
        value: manager,
        child: const MaterialApp(
          home: Scaffold(
            body: EditUploadOverlayHost(
              child: ColoredBox(
                color: Colors.white,
                child: Center(child: Text('Screen A')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('global-edit-upload-bar')), findsOneWidget);

    // Navigate-like rebuild with different body — bar must persist.
    await tester.pumpWidget(
      ChangeNotifierProvider<EditUploadManager>.value(
        value: manager,
        child: const MaterialApp(
          home: Scaffold(
            body: EditUploadOverlayHost(
              child: ColoredBox(
                color: Colors.white,
                child: Center(child: Text('Screen B')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Screen B'), findsOneWidget);
    expect(find.byKey(const Key('global-edit-upload-bar')), findsOneWidget);

    manager.dispose();
    await repo.close();
  });
}
