abstract interface class Analytics {
  void logEvent(String name, {Map<String, Object?> parameters = const {}});
}
