/// Fallback for platforms with neither dart:io nor dart:html.
///
/// Never invent an offline verdict we cannot verify: an unknown platform must
/// behave like "try the request" rather than blocking the user with a false
/// "no connection" message. [NetworkService] still requires repeated evidence
/// before it publishes an offline state.
Future<bool> probeNetwork() async => true;
