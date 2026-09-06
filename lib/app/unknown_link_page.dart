import 'package:flutter/material.dart';

import 'app_back_button.dart';
import '../core/widgets/pubget_design_system.dart';

class UnknownLinkPage extends StatelessWidget {
  const UnknownLinkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: AppBackButton.maybeOf(context)),
      body: const SafeArea(
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
