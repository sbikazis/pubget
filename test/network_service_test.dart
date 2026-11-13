import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/network/network_service.dart';

void main() {
  test('network service publishes a confirmed online state', () async {
    final service = NetworkService(probe: () async => true);

    await service.refresh();

    expect(service.status, NetworkStatus.online);
    expect(service.isOnline, isTrue);
    expect(service.isOffline, isFalse);
    expect(service.canAttemptRequest, isTrue);
    service.dispose();
  });

  test('one failed probe is unknown, never a false offline verdict', () async {
    final service = NetworkService(probe: () async => false);

    await service.refresh();

    expect(service.status, NetworkStatus.unknown);
    expect(service.isOffline, isFalse);
    expect(service.consecutiveFailures, 1);
    // The user must still be allowed to try the real request.
    expect(service.canAttemptRequest, isTrue);
    service.dispose();
  });

  test('offline is published only after repeated failures', () async {
    var online = true;
    final service = NetworkService(probe: () async => online);

    await service.refresh();
    expect(service.status, NetworkStatus.online);

    online = false;
    await service.refresh();
    expect(service.status, NetworkStatus.unknown);
    expect(service.isOffline, isFalse);

    await service.refresh();
    expect(service.status, NetworkStatus.offline);
    expect(service.isOffline, isTrue);
    expect(service.canAttemptRequest, isFalse);

    online = true;
    await service.refresh();
    expect(service.status, NetworkStatus.online);
    expect(service.consecutiveFailures, 0);
    service.dispose();
  });

  test('probe exceptions count as unconfirmed, not offline', () async {
    final service = NetworkService(
      probe: () async => throw StateError('probe failed'),
    );

    await service.refresh();
    expect(service.status, NetworkStatus.unknown);

    await service.refresh();
    expect(service.status, NetworkStatus.offline);
    service.dispose();
  });

  test('a real backend response clears a stale offline verdict', () async {
    final service = NetworkService(probe: () async => false);

    await service.refresh();
    await service.refresh();
    expect(service.isOffline, isTrue);

    service.noteSuccessfulRequest();

    expect(service.status, NetworkStatus.online);
    expect(service.isOffline, isFalse);
    expect(service.consecutiveFailures, 0);
    service.dispose();
  });

  test('network service ignores late completion after disposal', () async {
    final completer = Completer<bool>();
    final service = NetworkService(probe: () => completer.future);

    final refresh = service.refresh();
    service.dispose();
    completer.complete(true);

    await refresh;
  });

  test('network service stays unresolved until the first probe finishes', () {
    final service = NetworkService(probe: () async => true);
    expect(service.hasResolved, isFalse);
    expect(service.status, NetworkStatus.unknown);
    expect(service.isOffline, isFalse);
    expect(service.isOnline, isFalse);
    expect(service.canAttemptRequest, isTrue);
    service.dispose();
  });

  group('event-driven link state (connectivity_plus)', () {
    // The initial link check and the verification probe are both async. Drain
    // a few microtask turns instead of sleeping on a wall-clock timer.
    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('a platform "no link" event is positive offline evidence', () async {
      final controller = StreamController<bool>.broadcast();
      addTearDown(controller.close);
      final service = NetworkService(
        probe: () async => false,
        linkChanges: controller.stream,
        initialLinkState: () async => true,
      );
      addTearDown(service.dispose);

      service.start();
      await settle();
      expect(service.isOffline, isFalse);

      controller.add(false);
      await settle();

      expect(service.status, NetworkStatus.offline);
      expect(service.isOffline, isTrue);
      expect(service.canAttemptRequest, isFalse);
    });

    test('link up with a failed probe stays unknown, never false offline',
        () async {
      final controller = StreamController<bool>.broadcast();
      addTearDown(controller.close);
      final service = NetworkService(
        probe: () async => false,
        linkChanges: controller.stream,
        initialLinkState: () async => true,
      );
      addTearDown(service.dispose);

      service.start();
      await settle();
      // Even repeated DNS failures on a live link must not block the user.
      await service.refresh();
      await service.refresh();

      expect(service.status, NetworkStatus.unknown);
      expect(service.isOffline, isFalse);
      expect(service.canAttemptRequest, isTrue);
    });

    test('the link event itself triggers re-verification (no polling)',
        () async {
      final controller = StreamController<bool>.broadcast();
      addTearDown(controller.close);
      var probeCalls = 0;
      final service = NetworkService(
        probe: () async {
          probeCalls++;
          return true;
        },
        linkChanges: controller.stream,
        initialLinkState: () async => true,
      );
      addTearDown(service.dispose);

      service.start();
      await settle();
      final afterStart = probeCalls;
      expect(afterStart, greaterThan(0));

      controller.add(true);
      await settle();
      expect(probeCalls, greaterThan(afterStart));
      expect(service.status, NetworkStatus.online);
    });

    test('a real request overrides a stale platform offline verdict', () async {
      final controller = StreamController<bool>.broadcast();
      addTearDown(controller.close);
      final service = NetworkService(
        probe: () async => false,
        linkChanges: controller.stream,
        initialLinkState: () async => false,
      );
      addTearDown(service.dispose);

      service.start();
      await settle();
      expect(service.isOffline, isTrue);

      service.noteSuccessfulRequest();
      expect(service.status, NetworkStatus.online);
      expect(service.canAttemptRequest, isTrue);

      // A later offline event is still honoured.
      controller.add(false);
      await settle();
      expect(service.isOffline, isTrue);
    });
  });
}
