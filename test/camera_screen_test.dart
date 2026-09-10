import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/features/groups/widgets/wa_composer/wa_in_app_camera.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CameraScreen builds premium chrome without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CameraScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CameraScreen), findsOneWidget);
    expect(find.text('اسحب للأعلى للخيارات'), findsOneWidget);
  });

  test('WaCapturedMedia keeps high-quality payload fields', () {
    final media = WaCapturedMedia(
      bytes: Uint8List.fromList(const <int>[1, 2, 3]),
      fileName: 'capture.jpg',
      contentType: 'image/jpeg',
      isVideo: false,
    );
    expect(media.contentType, 'image/jpeg');
    expect(media.isVideo, isFalse);
    expect(media.bytes, hasLength(3));
  });
}
