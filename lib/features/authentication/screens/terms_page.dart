import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../widgets/terms_copy.dart';
import 'auth_page_shell.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return AuthPageShell(
      title: copy.termsOfUse,
      subtitle: copy.termsSubtitle,
      compactBrand: true,
      leading: AuthBackButton(
        onPressed: () => AppNavigation.back(context),
        tooltip: copy.backToRegistration,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[const TermsCopy()],
      ),
    );
  }
}
