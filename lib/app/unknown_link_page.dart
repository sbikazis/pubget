import 'package:flutter/material.dart';

import '../core/widgets/pubget_design_system.dart';

class UnknownLinkPage extends StatelessWidget {
  const UnknownLinkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: PubgetEmptyState(
            title: 'This link is not available',
            message: 'The address may be incomplete, outdated, or mistyped.',
            icon: Icons.link_off_outlined,
          ),
        ),
      ),
    );
  }
}
