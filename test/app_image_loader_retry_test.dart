import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/widgets/app_image_loader.dart';

void main() {
  testWidgets('an empty resolution is retried a bounded number of times', (
    tester,
  ) async {
    var calls = 0;
    Future<String?> resolver(String reference) async {
      calls++;
      return null; // simulate a transient failure with no signature
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppImageLoader(
            imageUrl: 'images/alice/a.jpg',
            urlResolver: resolver,
          ),
        ),
      ),
    );
    // Initial resolve + at most two scheduled retries; each post-frame
    // callback triggers one more build/resolve.
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }

    expect(calls, greaterThanOrEqualTo(1));
    expect(
      calls,
      lessThanOrEqualTo(4),
      reason: 'retry must be bounded, never an unbounded rebuild loop',
    );
  });

  testWidgets('changing the reference resets the retry path', (tester) async {
    final resolved = <String>[];
    Future<String?> resolver(String reference) async {
      resolved.add(reference);
      return null;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppImageLoader(imageUrl: 'first', urlResolver: resolver),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppImageLoader(imageUrl: 'second', urlResolver: resolver),
        ),
      ),
    );
    await tester.pump();

    expect(resolved, contains('first'));
    expect(resolved, contains('second'));
    expect(resolved.length, lessThanOrEqualTo(8));
  });
}
