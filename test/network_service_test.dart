import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/network/network_service.dart';

void main() {
  test('network service publishes connectivity changes and recovers', () async {
    var online = true;
    final service = NetworkService(probe: () async => online);

    await service.refresh();
    expect(service.status, NetworkStatus.online);
    expect(service.isOnline, isTrue);
    expect(service.isOffline, isFalse);

    online = false;
    await service.refresh();
    expect(service.status, NetworkStatus.offline);
    expect(service.isOffline, isTrue);

    online = true;
    await service.refresh();
    expect(service.status, NetworkStatus.online);
    expect(service.isOnline, isTrue);

    service.dispose();
  });

  test('network service treats probe failures as offline', () async {
    final service = NetworkService(
      probe: () async => throw StateError('probe failed'),
    );

    await service.refresh();

    expect(service.status, NetworkStatus.offline);
    expect(service.isOffline, isTrue);
    service.dispose();
  });

  test('network service times out a probe that never completes', () async {
    final service = NetworkService(
      probe: () => Completer<bool>().future,
      probeTimeout: const Duration(milliseconds: 1),
    );

    await service.refresh();

    expect(service.hasResolved, isTrue);
    expect(service.isOffline, isTrue);
    service.dispose();
  });

  test('concurrent refresh calls share one probe', () async {
    final completer = Completer<bool>();
    var calls = 0;
    final service = NetworkService(
      probe: () {
        calls += 1;
        return completer.future;
      },
    );

    final first = service.refresh();
    final second = service.refresh();
    expect(calls, 1);

    completer.complete(true);
    await Future.wait(<Future<void>>[first, second]);

    expect(service.isOnline, isTrue);
    expect(calls, 1);
    service.dispose();
  });

  test('network service ignores late completion after disposal', () async {
    final completer = Completer<bool>();
    final service = NetworkService(probe: () => completer.future);

    final refresh = service.refresh();
    service.dispose();
    completer.complete(true);

    await refresh;
    expect(service.hasResolved, isFalse);
  });

  test('network service stays unresolved and does not claim offline at startup', () {
    final service = NetworkService(probe: () async => true);

    expect(service.hasResolved, isFalse);
    expect(service.isChecking, isTrue);
    expect(service.isOffline, isFalse);
    expect(service.isOnline, isFalse);
    expect(service.canAttemptNetworkRequest, isTrue);

    service.dispose();
  });
}
