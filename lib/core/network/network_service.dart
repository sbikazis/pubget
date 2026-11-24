import 'dart:async';

import 'package:flutter/foundation.dart';

import 'network_probe.dart';

/// Axis Zero — three verdicts, not two.
///
/// `unknown` is the honest answer when the platform says the link is up but a
/// one-shot reachability probe fails. It must never be presented as a confirmed
/// outage: the user may have perfectly working internet and a broken DNS
/// resolver, a captive portal, or a transiently blocked 204 endpoint.
enum NetworkStatus { online, offline, unknown }

/// A lightweight reachability *hint*, never an authority on Firebase health.
///
/// Two modes, chosen by the caller:
///
/// * **Event-driven (production).** Pass [linkChanges] from `connectivity_plus`.
///   The platform tells us when the radio changes; a single HTTPS-204 probe
///   only verifies that the internet behind that link is actually reachable.
///   No timers, no polling loop, no false "no connection" banner.
/// * **Polling (legacy / injected tests).** Without [linkChanges] the original
///   periodic behaviour is preserved exactly, so existing consumers and
///   fixtures keep their contract.
class NetworkService extends ChangeNotifier {
  NetworkService({
    Future<bool> Function()? probe,
    Duration pollInterval = const Duration(seconds: 15),
    Duration probeTimeout = const Duration(seconds: 7),
    Stream<bool>? linkChanges,
    Future<bool> Function()? initialLinkState,
  })  : _probe = probe ?? probeNetwork,
        _pollInterval = pollInterval,
        _probeTimeout = probeTimeout,
        _linkChanges = linkChanges,
        _initialLinkState = initialLinkState;

  final Future<bool> Function() _probe;
  final Duration _pollInterval;
  final Duration _probeTimeout;
  final Stream<bool>? _linkChanges;
  final Future<bool> Function()? _initialLinkState;

  Timer? _timer;
  StreamSubscription<bool>? _linkSubscription;
  Future<void>? _refreshInFlight;
  NetworkStatus _status = NetworkStatus.offline;
  bool _disposed = false;
  bool _resolved = false;
  bool _started = false;
  bool _linkIsUp = true;

  NetworkStatus get status => _status;
  bool get hasResolved => _resolved;

  /// True until the first reachability probe has completed.
  bool get isChecking => !_resolved;

  bool get isOnline => _resolved && _status == NetworkStatus.online;
  bool get isOffline => _resolved && _status == NetworkStatus.offline;

  /// A failed reachability probe while the radio is up is `unknown`, not an
  /// outage. Features that only need permission to try the real request must
  /// use this instead of [isOnline], otherwise a blocked probe endpoint makes
  /// a connected device look offline.
  bool get isLikelyOnline => !isOffline;

  /// Whether a feature may attempt its request.
  ///
  /// An unresolved or unverifiable link is *never* a reason to block the user:
  /// the real request stays authoritative and repositories still map their own
  /// destination-specific failures.
  bool get canAttemptNetworkRequest =>
      !_resolved || isOnline || _status == NetworkStatus.unknown;

  /// Alias used by the Axis Zero foundation widgets.
  bool get canAttemptRequest => canAttemptNetworkRequest;

  void start() {
    if (_disposed || _started) return;
    _started = true;

    final events = _linkChanges;
    if (events == null) {
      // Legacy contract: periodic polling, unchanged behaviour for fixtures.
      unawaited(refresh());
      _timer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
      return;
    }

    // Production contract: react to the OS, verify once per transition.
    _linkSubscription = events.listen(
      _onLinkEvent,
      onError: (Object _) {},
    );
    unawaited(_checkInitialLink());
  }

  Future<void> _checkInitialLink() async {
    bool hasLink = true;
    try {
      hasLink = await (_initialLinkState?.call() ?? Future<bool>.value(true));
    } on Object {
      // A missing/denied plugin is not evidence of an outage.
      hasLink = true;
    }
    if (_disposed) return;
    _linkIsUp = hasLink;
    if (!hasLink) {
      _publish(NetworkStatus.offline);
      return;
    }
    await refresh();
  }

  void _onLinkEvent(bool hasLink) {
    if (_disposed) return;
    _linkIsUp = hasLink;
    if (!hasLink) {
      _publish(NetworkStatus.offline);
      return;
    }
    unawaited(refresh());
  }

  /// A real request that succeeded is stronger evidence than any probe.
  /// Repositories call this so a stale offline/unknown verdict cannot linger
  /// after Firebase has in fact answered.
  void noteSuccessfulRequest() {
    if (_disposed) return;
    _linkIsUp = true;
    _publish(NetworkStatus.online);
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

    if (online) {
      _publish(NetworkStatus.online);
      return;
    }

    // Event-driven mode: a failed probe while the OS reports a live link is
    // inconclusive, never a confirmed outage. Polling mode keeps its old
    // contract (probe failure == offline) so existing fixtures stay valid.
    final next = _linkChanges != null && _linkIsUp
        ? NetworkStatus.unknown
        : NetworkStatus.offline;
    _publish(next);
  }

  void _publish(NetworkStatus next) {
    if (_resolved && _status == next) return;
    _status = next;
    _resolved = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_linkSubscription?.cancel());
    super.dispose();
  }
}
