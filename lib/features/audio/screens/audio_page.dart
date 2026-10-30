import 'package:flutter/material.dart';

import '../../../core/widgets/entity_route_placeholder.dart';

/// Routing target for the canonical `/audio/:audioId` entity route.
///
/// Phase 2 scaffold: shows the resolved entity id only.
class AudioPage extends StatelessWidget {
  const AudioPage({required this.audioId, super.key});

  static const routePath = '/audio';

  final String audioId;

  @override
  Widget build(BuildContext context) {
    return EntityRoutePlaceholder(
      title: 'Audio',
      entityId: audioId,
      routePath: routePath,
    );
  }
}
