sealed class AppRoute {
  const AppRoute();
}

final class FoundationRoute extends AppRoute {
  const FoundationRoute();
}

/// A typed route that can carry future deep-link parameters without
/// implementing deep-link business behavior in the foundation layer.
final class ParameterizedRoute extends AppRoute {
  const ParameterizedRoute({
    required this.path,
    this.parameters = const <String, String>{},
  });

  final String path;
  final Map<String, String> parameters;
}
