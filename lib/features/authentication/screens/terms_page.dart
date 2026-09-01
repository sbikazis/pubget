import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../widgets/terms_copy.dart';
import 'auth_page_shell.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      title: 'Terms of use',
      subtitle: 'A clear summary before you create your account.',
      compactBrand: true,
      leading: AuthBackButton(
        onPressed: () => AppNavigation.go(context, '/register'),
        tooltip: 'Back to registration',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[const TermsCopy()],
      ),
    );
  }
}
