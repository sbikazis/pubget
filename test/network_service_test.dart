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
}
