import 'dart:async';

import 'package:flutter/foundation.dart';

import 'network_probe.dart';

enum NetworkStatus { online, offline }

class NetworkService extends ChangeNotifier {
  NetworkService({
    Future<bool> Function()? probe,
    Duration pollInterval = const Duration(seconds: 15),
  }) : _probe = probe ?? probeNetwork,
       _pollInterval = pollInterval;

  final Future<bool> Function() _probe;
  final Duration _pollInterval;
  Timer? _timer;
  NetworkStatus _status = NetworkStatus.offline;
  int _refreshGeneration = 0;
  bool _disposed = false;

  NetworkStatus get status => _status;
  bool get isOnline => _status == NetworkStatus.online;

  void start() {
    if (_timer != null) return;
    unawaited(refresh());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
  }

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    var online = false;
    try {
      online = await _probe();
    } catch (_) {
      online = false;
    }
    if (_disposed || generation != _refreshGeneration) return;

    final nextStatus = online ? NetworkStatus.online : NetworkStatus.offline;
    if (_status == nextStatus) return;
    _status = nextStatus;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshGeneration++;
    _timer?.cancel();
    super.dispose();
  }
}
