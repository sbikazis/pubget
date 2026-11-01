import 'package:flutter/material.dart';

import 'app_back_button.dart';
import '../core/l10n/app_strings.dart';
import '../core/widgets/pubget_design_system.dart';

class UnknownLinkPage extends StatelessWidget {
  const UnknownLinkPage({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(leading: AppBackButton.maybeOf(context)),
      body: SafeArea(
        child: Center(
          child: PubgetEmptyState(
            title: copy.linkNotAvailable,
            message: copy.linkNotAvailableMessage,
            icon: Icons.link_off_outlined,
          ),
        ),
      ),
    );
  }
}
