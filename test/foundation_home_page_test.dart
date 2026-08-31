import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/app/firebase_bootstrap.dart';
import 'package:pubget/app/foundation_home_page.dart';
import 'package:pubget/core/examples/dummy_provider.dart';
import 'package:pubget/core/examples/dummy_repository.dart';
import 'package:pubget/core/network/network_service.dart';

void main() {
  testWidgets('foundation UI exercises Provider and Repository flow', (
    tester,
  ) async {
    final network = NetworkService(probe: () async => true);
    final repository = DummyRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<NetworkService>.value(value: network),
          Provider<DummyRepository>.value(value: repository),
          ChangeNotifierProvider<DummyProvider>(
            create: (context) =>
                DummyProvider(repository: context.read<DummyRepository>()),
          ),
        ],
        child: const MaterialApp(
          home: FoundationHomePage(
            firebaseState: FirebaseInitializationState.unavailable(
              'Not configured in this test.',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Run foundation data flow'));
    await tester.pump();

    expect(find.text('Repository result'), findsOneWidget);
  });
}
