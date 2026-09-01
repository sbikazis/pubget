import 'package:flutter/foundation.dart';

import 'analytics.dart';

final class LoggingAnalytics implements Analytics {
  const LoggingAnalytics();

  @override
  void logEvent(String name, {Map<String, Object?> parameters = const {}}) {
    debugPrint('analytics:$name $parameters');
  }
}
