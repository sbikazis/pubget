import 'package:flutter/material.dart';

import '../../../core/widgets/entity_route_placeholder.dart';

/// Routing target for the canonical `/reel/:reelId` entity route.
///
/// Phase 2 scaffold: shows the resolved entity id only.
class ReelDetailsPage extends StatelessWidget {
  const ReelDetailsPage({required this.reelId, super.key});

  static const routePath = '/reel';

  final String reelId;

  @override
  Widget build(BuildContext context) {
    return EntityRoutePlaceholder(
      title: 'Reel',
      entityId: reelId,
      routePath: routePath,
    );
  }
}
