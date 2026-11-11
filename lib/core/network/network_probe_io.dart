import 'dart:async';
import 'dart:io';

/// Hosts operated by different providers. A single blocked domain, a flaky
/// resolver, or one unreachable CDN must never be reported as "no internet".
const List<String> _probeHosts = <String>[
  'one.one.one.one',
  'dns.google',
  'www.gstatic.com',
];

/// Returns true when *any* host resolves. Connectivity is only considered lost
/// when all of them fail, and [NetworkService] additionally requires repeated
/// failures before publishing an offline state.
Future<bool> probeNetwork() async {
  final results = await Future.wait<bool>(_probeHosts.map(_canResolve));
  return results.any((bool ok) => ok);
}

Future<bool> _canResolve(String host) async {
  try {
    final addresses = await InternetAddress.lookup(
      host,
    ).timeout(const Duration(seconds: 3));
    return addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty;
  } on Object {
    return false;
  }
}
