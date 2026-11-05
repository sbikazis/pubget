import 'dart:async';

import 'package:flutter/foundation.dart';

import 'network_probe.dart';

enum NetworkStatus { online, offline }

class NetworkService extends ChangeNotifier {
  NetworkService({
    Future<bool> Function()? probe,
    Duration pollInterval = const Duration(seconds: 15),
    Duration probeTimeout = const Duration(seconds: 7),
  }) : _probe = probe ?? probeNetwork,
       _pollInterval = pollInterval,
       _probeTimeout = probeTimeout;

  final Future<bool> Function() _probe;
  final Duration _pollInterval;
  final Duration _probeTimeout;
  Timer? _timer;
  Future<void>? _refreshInFlight;
  NetworkStatus _status = NetworkStatus.offline;
  bool _disposed = false;
  bool _resolved = false;

  NetworkStatus get status => _status;
  bool get hasResolved => _resolved;

  /// True until the first reachability probe has completed.
  ///
  /// An unresolved service is not evidence that the device is offline.
  bool get isChecking => !_resolved;

  bool get isOnline => _resolved && _status == NetworkStatus.online;
  bool get isOffline => _resolved && _status == NetworkStatus.offline;

  /// Whether a feature may attempt its request while the first probe is pending.
  ///
  /// The actual request remains authoritative: a failed Firebase/API request
  /// must still be handled by that feature's repository.
  bool get canAttemptNetworkRequest => !_resolved || isOnline;

  void start() {
    if (_disposed || _timer != null) return;
    unawaited(refresh());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
  }

  /// Refreshes reachability. Concurrent callers share one probe so a slow
  /// endpoint cannot create overlapping requests or stale status updates.
  Future<void> refresh() {
    if (_disposed) return Future<void>.value();

    final pending = _refreshInFlight;
    if (pending != null) return pending;

    late final Future<void> operation;
    operation = _performRefresh().whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
      }
    });
    _refreshInFlight = operation;
    return operation;
  }

  Future<void> _performRefresh() async {
    var online = false;
    try {
      online = await _probe().timeout(_probeTimeout);
    } catch (_) {
      online = false;
    }

    if (_disposed) return;

    final nextStatus = online ? NetworkStatus.online : NetworkStatus.offline;
    if (_resolved && _status == nextStatus) return;

    _status = nextStatus;
    _resolved = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
