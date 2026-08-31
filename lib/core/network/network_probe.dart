import 'network_probe_stub.dart'
    if (dart.library.io) 'network_probe_io.dart'
    if (dart.library.html) 'network_probe_web.dart'
    as platform;

Future<bool> probeNetwork() => platform.probeNetwork();
