import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/l10n/app_strings.dart';
import 'package:pubget/features/home/widgets/home_luxury_tiles.dart';
import 'package:pubget/features/social/models/public_profile.dart';

void main() {
  test('username-only profiles do not duplicate as a handle line', () {
    const person = PublicProfile(uid: 'u1', username: 'noon', displayName: 'noon');
    expect(person.primaryName(), 'noon');
    expect(person.distinctHandle, isNull);

    const fallback = PublicProfile(uid: 'u2', username: 'noon');
    expect(fallback.primaryName(), 'noon');
    expect(fallback.distinctHandle, isNull);
  });

  test('distinct display names keep name plus @handle', () {
    const person = PublicProfile(
      uid: 'u3',
      username: 'teemwa',
      displayName: 'تيموا',
    );
    expect(person.primaryName(), 'تيموا');
    expect(person.distinctHandle, '@teemwa');
  });

  testWidgets('people card hides duplicate handle and keeps distinct pairs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        home: Scaffold(
          body: Row(
            children: <Widget>[
              HomePersonCard(
                person: PublicProfile(
                  uid: 'noon',
                  username: 'noon',
                  displayName: 'noon',
                  fansCount: 2,
                ),
              ),
              HomePersonCard(
                person: PublicProfile(
                  uid: 'teem',
                  username: 'teemwa',
                  displayName: 'تيموا',
                  fansCount: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('noon'), findsOneWidget);
    expect(find.text('@noon'), findsNothing);
    expect(find.text('تيموا'), findsOneWidget);
    expect(find.text('@teemwa'), findsOneWidget);
    expect(find.text(AppStrings.english.fansCount(2)), findsOneWidget);
  });
}
