/// On platforms without a supported probe, stay optimistic rather than
/// incorrectly disabling every network-backed feature. The request itself
/// remains responsible for reporting whether its destination is reachable.
Future<bool> probeNetwork() async => true;
