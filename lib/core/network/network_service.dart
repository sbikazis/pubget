import 'dart:async';

import 'package:flutter/foundation.dart';

import 'network_probe.dart';

/// [unknown] is a first-class state: a single failed DNS lookup is not proof
/// that the device is offline. Publishing it stops the UI from claiming "no
/// connection" while Firebase is still answering requests.
enum NetworkStatus { online, offline, unknown }

class NetworkService extends ChangeNotifier {
  NetworkService({
    Future<bool> Function()? probe,
    Duration pollInterval = const Duration(seconds: 15),
    int failureThreshold = 2,
  }) : _probe = probe ?? probeNetwork,
       _pollInterval = pollInterval,
       _failureThreshold = failureThreshold < 1 ? 1 : failureThreshold;

  final Future<bool> Function() _probe;
  final Duration _pollInterval;
  final int _failureThreshold;
  Timer? _timer;
  NetworkStatus _status = NetworkStatus.unknown;
  int _refreshGeneration = 0;
  int _consecutiveFailures = 0;
  bool _disposed = false;
  bool _resolved = false;

  NetworkStatus get status => _status;
  bool get hasResolved => _resolved;

  bool get isOnline => _status == NetworkStatus.online;

  /// Only true after repeated, positive evidence of lost connectivity.
  bool get isOffline => _resolved && _status == NetworkStatus.offline;

  /// The gate callers should use before blocking an action. "Unknown" must
  /// never stop a user who is actually connected.
  bool get canAttemptRequest => !isOffline;

  /// How many probe failures in a row are currently recorded. Exposed for
  /// diagnostics so a support log can distinguish a blip from a real outage.
  int get consecutiveFailures => _consecutiveFailures;

  void start() {
    if (_timer != null) return;
    unawaited(refresh());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
  }

  /// A real request reached a backend. That is stronger evidence than any DNS
  /// probe, so it immediately clears a stale offline verdict.
  void noteSuccessfulRequest() {
    if (_disposed) return;
    _consecutiveFailures = 0;
    _publish(NetworkStatus.online);
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

    if (online) {
      _consecutiveFailures = 0;
      _publish(NetworkStatus.online);
      return;
    }

    _consecutiveFailures++;
    // One failed probe can be a flaky resolver, a captive portal, or one host
    // being blocked. Hold at `unknown` until the failure is confirmed.
    _publish(
      _consecutiveFailures >= _failureThreshold
          ? NetworkStatus.offline
          : NetworkStatus.unknown,
    );
  }

  void _publish(NetworkStatus next) {
    final changed = !_resolved || _status != next;
    _status = next;
    _resolved = true;
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshGeneration++;
    _timer?.cancel();
    super.dispose();
  }
}
