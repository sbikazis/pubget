import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/network/network_service.dart';

void main() {
  test('network service publishes connectivity changes', () async {
    var online = true;
    final service = NetworkService(probe: () async => online);

    await service.refresh();
    expect(service.status, NetworkStatus.online);

    online = false;
    await service.refresh();
    expect(service.status, NetworkStatus.offline);

    service.dispose();
  });

  test('network service treats probe failures as offline', () async {
    final service = NetworkService(
      probe: () async => throw StateError('probe failed'),
    );

    await service.refresh();

    expect(service.status, NetworkStatus.offline);
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
}
