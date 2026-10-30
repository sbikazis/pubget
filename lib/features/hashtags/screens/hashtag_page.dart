import 'package:flutter/material.dart';

import '../../../core/widgets/entity_route_placeholder.dart';

/// Routing target for the canonical `/hashtag/:tag` entity route.
///
/// Phase 2 scaffold: shows the resolved tag only.
class HashtagPage extends StatelessWidget {
  const HashtagPage({required this.tag, super.key});

  static const routePath = '/hashtag';

  final String tag;

  @override
  Widget build(BuildContext context) {
    return EntityRoutePlaceholder(
      title: 'Hashtag',
      entityId: tag,
      routePath: routePath,
    );
  }
}
