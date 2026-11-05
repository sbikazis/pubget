import 'dart:async';
import 'dart:io';

/// Independent public 204 endpoints avoid treating one DNS hostname as the
/// whole internet. A successful 204 confirms outbound HTTPS reachability;
/// failure of one provider falls through to the other.
const List<String> _connectivityEndpoints = <String>[
  'https://connectivitycheck.gstatic.com/generate_204',
  'https://cp.cloudflare.com/generate_204',
];

const Duration _endpointTimeout = Duration(seconds: 3);

Future<bool> probeNetwork() async {
  for (final endpoint in _connectivityEndpoints) {
    if (await _probeEndpoint(Uri.parse(endpoint))) return true;
  }
  return false;
}

Future<bool> _probeEndpoint(Uri endpoint) async {
  final client = HttpClient()..connectionTimeout = _endpointTimeout;
  try {
    final response = await (() async {
      final request = await client.getUrl(endpoint);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      final response = await request.close();
      await response.drain<void>();
      return response;
    })().timeout(_endpointTimeout);

    // A captive portal commonly redirects or returns an HTML 200 page. Only
    // the endpoint's documented no-content response counts as reachable.
    return response.statusCode == HttpStatus.noContent;
  } on Object {
    return false;
  } finally {
    client.close(force: true);
  }
}
