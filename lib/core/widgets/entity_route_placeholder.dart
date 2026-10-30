import 'package:flutter/material.dart';

import '../../app/app_back_button.dart';

/// Minimal body for the Phase 2 entity route targets.
///
/// It only proves which entity the router resolved: no providers, no
/// repositories, no product behavior.
class EntityRoutePlaceholder extends StatelessWidget {
  const EntityRoutePlaceholder({
    required this.title,
    required this.entityId,
    required this.routePath,
    super.key,
  });

  /// Human label for the entity kind, e.g. `Reel`.
  final String title;

  /// Id parsed out of the route.
  final String entityId;

  /// Canonical route prefix, e.g. `/reel`.
  final String routePath;

  String get resolvedPath => entityId.isEmpty
      ? routePath
      : '$routePath/${Uri.encodeComponent(entityId)}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: AppBackButton.maybeOf(context),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  entityId.isEmpty ? '—' : entityId,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text('Route: $resolvedPath', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
