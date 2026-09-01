import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/core/widgets/pubget_skeleton.dart';
import 'package:pubget/core/widgets/pubget_states.dart';

void main() {
  Future<void> pumpState(WidgetTester tester, LoadingState state) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PubgetLoadingStateView(
            state: state,
            child: const Text('Loaded content'),
          ),
        ),
      ),
    );
  }

  testWidgets('loading maps to skeleton and loaded maps to content', (
    tester,
  ) async {
    await pumpState(tester, LoadingState.initial);
    expect(find.byType(PubgetSkeleton), findsOneWidget);

    await pumpState(tester, LoadingState.loading);
    expect(find.byType(PubgetSkeleton), findsOneWidget);
    expect(find.text('Loaded content'), findsNothing);

    await pumpState(tester, LoadingState.loaded);
    expect(find.text('Loaded content'), findsOneWidget);
  });

  testWidgets('empty, error, and offline map to friendly states', (
    tester,
  ) async {
    await pumpState(tester, LoadingState.empty);
    expect(find.byType(PubgetEmptyState), findsOneWidget);

    await pumpState(tester, LoadingState.error);
    expect(find.byType(PubgetErrorState), findsOneWidget);

    await pumpState(tester, LoadingState.offline);
    expect(find.byType(PubgetOfflineState), findsOneWidget);
  });

  testWidgets('refresh and pagination use distinct progress positions', (
    tester,
  ) async {
    await pumpState(tester, LoadingState.refreshing);
    expect(find.text('Loaded content'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await pumpState(tester, LoadingState.loadingMore);
    expect(find.text('Loaded content'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
