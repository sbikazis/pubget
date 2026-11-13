import 'dart:async';

import 'package:flutter/foundation.dart';

import 'connectivity_events.dart';
import 'network_probe.dart';

/// Three honest states, and the distinction is the whole point of Axis Zero:
///
/// * [online] — the platform reports a link and the one-shot verification
///   succeeded, or a real backend request came back.
/// * [offline] — the platform itself reports no network interface. This is
///   positive evidence, not a guess, and it is the only path to a "no
///   connection" message.
/// * [unknown] — the link is up but verification failed (captive portal,
///   blocked resolver, flaky DNS), or the platform cannot report link state.
///   A backend hiccup is *not* evidence of a missing connection; it surfaces
///   as `UnavailableError` ("service temporarily unavailable") instead.
///
/// [unknown] must never block an action. Callers gate on [canAttemptRequest].
enum NetworkStatus { online, offline, unknown }

class NetworkService extends ChangeNotifier {
  NetworkService({
    /// One-shot verification of real internet reachability. Injectable so
    /// tests never touch a socket.
    Future<bool> Function()? probe,

    /// Injectable event stream; production uses [linkStateChanges].
    Stream<bool>? linkChanges,

    /// Injectable initial link state; production uses [currentLinkState].
    Future<bool> Function()? initialLinkState,

    /// Fallback only, for targets where the platform cannot report link state
    /// (unit tests, some desktop/web builds). Repeated *verification* failures
    /// are then the only signal available.
    int failureThreshold = 2,
  }) : _probe = probe ?? probeNetwork,
       _linkChanges = linkChanges,
       _initialLinkState = initialLinkState,
       _failureThreshold = failureThreshold < 1 ? 1 : failureThreshold;

  final Future<bool> Function() _probe;
  final Stream<bool>? _linkChanges;
  final Future<bool> Function()? _initialLinkState;
  final int _failureThreshold;

  StreamSubscription<bool>? _subscription;
  bool _started = false;
  bool _disposed = false;

  /// `null` = the platform has not reported (tests / unsupported target).
  /// `false` = the OS says the radio is down. `true` = link is up.
  bool? _linkUp;

  NetworkStatus _status = NetworkStatus.unknown;
  int _refreshGeneration = 0;
  int _consecutiveFailures = 0;
  bool _resolved = false;

  NetworkStatus get status => _status;
  bool get hasResolved => _resolved;
  bool get isOnline => _status == NetworkStatus.online;

  /// Only true with positive, platform-level evidence of a missing link.
  bool get isOffline => _resolved && _status == NetworkStatus.offline;

  /// "Unknown" must never stop a user who is actually connected. The real
  /// request — and its own error handling — is the final authority.
  bool get canAttemptRequest => !isOffline;

  /// How many verification failures in a row are currently recorded. Exposed
  /// so a support log can distinguish a blip from a real outage.
  int get consecutiveFailures => _consecutiveFailures;

  /// Subscribe to platform link events. There is deliberately no
  /// [Timer.periodic]: the OS pushes transitions, we verify once per event.
  void start() {
    if (_started || _disposed) return;
    _started = true;

    final stream = _linkChanges ?? linkStateChanges();
    _subscription = stream.listen(_onLinkChanged, onError: (Object _) {});
    unawaited(_checkInitialLinkState());
  }

  Future<void> _checkInitialLinkState() async {
    final check = _initialLinkState ?? currentLinkState;
    bool linkUp;
    try {
      linkUp = await check();
    } on Object {
      return;
    }
    if (_disposed) return;
    _onLinkChanged(linkUp);
  }

  void _onLinkChanged(bool linkUp) {
    if (_disposed) return;
    _linkUp = linkUp;
    if (!linkUp) {
      _consecutiveFailures = 0;
      _publish(NetworkStatus.offline);
      return;
    }
    // Link came back: verify the internet behind it before claiming online.
    unawaited(refresh());
  }

  /// A real request reached a backend. That is stronger evidence than any
  /// probe and overrides even a stale platform "no link" verdict (VPNs and
  /// enterprise profiles commonly misreport those).
  void noteSuccessfulRequest() {
    if (_disposed) return;
    _consecutiveFailures = 0;
    _linkUp = true;
    _publish(NetworkStatus.online);
  }

  /// Re-verify now. Called on every link event and by a real retry button.
  Future<void> refresh() async {
    final generation = ++_refreshGeneration;

    // The OS already knows there is no radio. Do not burn a DNS timeout to
    // "confirm" it, and never let a late probe overwrite that verdict.
    if (_linkUp == false) {
      _publish(NetworkStatus.offline);
      return;
    }

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

    // A live link with a failed DNS lookup is *not* proof of no internet. A
    // captive portal, a filtered resolver or one blocked CDN all look like
    // this. Hold at `unknown`: the request is allowed through, and a genuine
    // backend problem surfaces as UnavailableError with honest copy.
    if (_linkUp == true) {
      _publish(NetworkStatus.unknown);
      return;
    }

    // No platform signal at all (tests / unsupported targets): fall back to
    // repeated failures as the only available evidence.
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
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
