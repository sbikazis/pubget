import 'package:flutter/material.dart';

import '../../../core/links/pubget_links.dart';

/// Kirari phase 2 — canonical entity target for `/reel/{reelId}`.
///
/// Routing placeholder only. It renders the reel identity and the resolved
/// route so a deep link lands on a real page while the product surface for a
/// single Reel is built in a later phase. No providers, no repository calls.
class ReelDetailsPage extends StatelessWidget {
  const ReelDetailsPage({required this.reelId, super.key});

  final String reelId;

  @override
  Widget build(BuildContext context) {
    final route = PubgetLinks.reelPath(reelId);
    return Scaffold(
      appBar: AppBar(title: const Text('Reel')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(reelId, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(route, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
