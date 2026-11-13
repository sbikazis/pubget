/// Event-driven link-state detection for Axis Zero.
///
/// The old foundation asked a DNS server every 15 seconds whether the device
/// was online. That is the wrong question: DNS can be blocked while Firebase
/// still answers, and a captive portal resolves nothing while the radio is
/// perfectly up. It produced the false "no connection" banners that made the
/// app look broken to a user holding a working phone.
///
/// The platform now *tells* us when the link changes (`connectivity_plus`),
/// and a one-shot probe only verifies that the internet behind that link is
/// reachable. No timers, no polling loop.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// The platform reports a list: a device can hold Wi-Fi and a VPN at once.
/// Only an all-`none` list means the radio itself is down.
bool hasNetworkLink(List<ConnectivityResult> results) =>
    results.any((result) => result != ConnectivityResult.none);

/// Initial link state, used once at [start].
///
/// Never invent an offline verdict we cannot verify: a missing plugin (unit
/// tests, an unsupported desktop target, a denied permission) must behave like
/// "try the request", not "no connection".
Future<bool> currentLinkState() async {
  try {
    return hasNetworkLink(await Connectivity().checkConnectivity());
  } on Object {
    return true;
  }
}

/// Platform events only. `connectivity_plus` already de-duplicates the raw
/// EventChannel stream, so this emits on real transitions rather than on a
/// schedule. A plugin failure degrades to "no events" — never to "offline".
Stream<bool> linkStateChanges() {
  try {
    return Connectivity()
        .onConnectivityChanged
        .map(hasNetworkLink)
        .distinct()
        .handleError((Object _) {});
  } on Object {
    return const Stream<bool>.empty();
  }
}
