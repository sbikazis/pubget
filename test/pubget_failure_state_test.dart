import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pubget/core/errors/failure.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/core/network/network_service.dart';
import 'package:pubget/core/theme/app_theme.dart';
import 'package:pubget/core/widgets/pubget_buttons.dart';
import 'package:pubget/core/widgets/pubget_states.dart';

/// Axis 02 §2.1 / §2.2 — the state layer must tell the truth even when a
/// legacy screen never heard of the new resolver.
void main() {
  Future<NetworkService> service({required bool online}) async {
    final network = NetworkService(probe: () async => online);
    await network.refresh();
    return network;
  }

  Future<void> pumpSurface(
    WidgetTester tester,
    Widget child, {
    NetworkService? network,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: network == null
              ? child
              : ChangeNotifierProvider<NetworkService>.value(
                  value: network,
                  child: child,
                ),
        ),
      ),
    );
  }

  group('classifyPubgetFailure', () {
    test('backend pressure is never reported as a missing link', () {
      for (final failure in <Failure>[
        const UnavailableError(),
        const TimeoutError(),
        const RateLimitedError(),
      ]) {
        expect(
          classifyPubgetFailure(failure, linkStatus: NetworkStatus.online),
          PubgetFailureKind.serviceUnavailable,
          reason: '${failure.runtimeType} must not claim "no internet"',
        );
      }
    });

    test('a transport error is only offline when the platform agrees', () {
      expect(
        classifyPubgetFailure(
          const NetworkError(),
          linkStatus: NetworkStatus.offline,
        ),
        PubgetFailureKind.offline,
      );
      expect(
        classifyPubgetFailure(
          const NetworkError(),
          linkStatus: NetworkStatus.online,
        ),
        PubgetFailureKind.serviceUnavailable,
      );
    });

    test('permission, expired and generic failures keep their own verdicts', () {
      expect(
        classifyPubgetFailure(const PermissionError()),
        PubgetFailureKind.permissionDenied,
      );
      expect(
        classifyPubgetFailure(const NotFoundError()),
        PubgetFailureKind.expired,
      );
      expect(
        classifyPubgetFailure(const UnknownError()),
        PubgetFailureKind.generic,
      );
      expect(classifyPubgetFailure(null), PubgetFailureKind.generic);
    });

    test('a stale offline flag while online is a service failure', () {
      expect(
        classifyPubgetFailure(
          null,
          linkStatus: NetworkStatus.online,
          offlineHint: true,
        ),
        PubgetFailureKind.serviceUnavailable,
      );
      expect(
        classifyPubgetFailure(
          null,
          linkStatus: NetworkStatus.offline,
          offlineHint: true,
        ),
        PubgetFailureKind.offline,
      );
      // No provider (isolated widget / fixture): preserve the legacy verdict.
      expect(
        classifyPubgetFailure(null, offlineHint: true),
        PubgetFailureKind.offline,
      );
    });
  });

  group('state surfaces', () {
    testWidgets('legacy offline screen stops lying when the link is healthy', (
      tester,
    ) async {
      final network = await service(online: true);
      addTearDown(network.dispose);
      await pumpSurface(tester, const PubgetOfflineState(), network: network);

      expect(find.byType(PubgetServiceUnavailableState), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
    });

    testWidgets('offline stays offline when the platform agrees', (
      tester,
    ) async {
      final network = await service(online: false);
      addTearDown(network.dispose);
      await pumpSurface(tester, const PubgetOfflineState(), network: network);

      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.byType(PubgetServiceUnavailableState), findsNothing);
    });

    testWidgets('isolated fixtures keep their legacy state widgets', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        const PubgetLoadingStateView(
          state: LoadingState.offline,
          child: Text('content'),
        ),
      );
      expect(find.byType(PubgetOfflineState), findsOneWidget);

      await pumpSurface(
        tester,
        const PubgetLoadingStateView(
          state: LoadingState.error,
          child: Text('content'),
        ),
      );
      expect(find.byType(PubgetErrorState), findsOneWidget);
    });

    testWidgets('dispatcher upgrades a stale offline flag to a service fault', (
      tester,
    ) async {
      final network = await service(online: true);
      addTearDown(network.dispose);
      await pumpSurface(
        tester,
        const PubgetLoadingStateView(
          state: LoadingState.offline,
          child: Text('content'),
        ),
        network: network,
      );

      expect(find.byType(PubgetServiceUnavailableState), findsOneWidget);
      expect(find.byType(PubgetOfflineState), findsNothing);
    });

    testWidgets('typed failures resolve into their own screens', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        const PubgetErrorState(failure: UnavailableError()),
      );
      expect(find.byType(PubgetServiceUnavailableState), findsOneWidget);

      await pumpSurface(
        tester,
        const PubgetErrorState(failure: PermissionError()),
      );
      expect(find.byType(PubgetPermissionDeniedState), findsOneWidget);

      await pumpSurface(
        tester,
        const PubgetErrorState(failure: NotFoundError()),
      );
      expect(find.byType(PubgetExpiredState), findsOneWidget);
    });

    testWidgets('a typed verdict keeps the domain retry label', (
      tester,
    ) async {
      await pumpSurface(
        tester,
        PubgetErrorState(
          title: 'Unable to load anime right now.',
          message: 'Check your connection and try again.',
          failure: const UnavailableError(),
          onRetry: () {},
          retryLabel: 'Retry',
        ),
      );

      expect(find.byType(PubgetServiceUnavailableState), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Unable to load anime right now.'), findsOneWidget);
      // The whole point of the verdict: a backend outage must never inherit a
      // "check your connection" override from a legacy screen.
      expect(find.text('Check your connection and try again.'), findsNothing);
    });

    testWidgets('the resolver forwards a domain retry label', (tester) async {
      await pumpSurface(
        tester,
        PubgetFailureStateView(
          failure: const UnavailableError(),
          retryLabel: 'Retry',
          onRetry: () async {},
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry re-verifies the link then re-runs the action once', (
      tester,
    ) async {
      var probes = 0;
      var retries = 0;
      final network = NetworkService(
        probe: () async {
          probes++;
          return true;
        },
      );
      addTearDown(network.dispose);
      await network.refresh();
      expect(probes, 1);

      await pumpSurface(
        tester,
        PubgetFailureStateView(
          failure: const UnavailableError(),
          onRetry: () async {
            retries++;
          },
        ),
        network: network,
      );
      expect(find.byType(PubgetServiceUnavailableState), findsOneWidget);

      await tester.tap(find.byType(PubgetSecondaryButton));
      await tester.tap(find.byType(PubgetSecondaryButton));
      await tester.pumpAndSettle();

      expect(probes, 2, reason: 'the link must be re-verified before retrying');
      expect(retries, 1, reason: 'a double tap must never duplicate a write');
    });

    testWidgets('page skeleton is static so pumpAndSettle converges', (
      tester,
    ) async {
      await pumpSurface(tester, const PubgetPageLoading());
      await tester.pumpAndSettle();
      expect(find.byType(PubgetPageLoading), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
