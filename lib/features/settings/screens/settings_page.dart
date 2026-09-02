import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../authentication/providers/onboarding_provider.dart';
import '../settings_provider.dart';
import '../settings_store.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({this.appVersion = '1.0.2+18', super.key});

  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<OnboardingProvider>().profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text('Account', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          PubgetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Signed in as'),
                  subtitle: Text(
                    profile?.email ?? auth.currentUser?.email ?? '—',
                  ),
                ),
                PubgetTextButton(
                  onPressed: () => AppNavigation.go(context, '/profile/edit'),
                  semanticLabel: 'Open privacy and profile settings',
                  child: const Text('Privacy and profile'),
                ),
                PubgetTextButton(
                  onPressed: auth.currentUser == null ||
                          auth.currentUser!.email.trim().isEmpty
                      ? null
                      : () async {
                          await auth.sendPasswordResetEmail(
                            email: auth.currentUser!.email,
                          );
                          if (!context.mounted) return;
                          PubgetSnackbars.showInfo(
                            context,
                            'Password reset email sent, if the account exists.',
                          );
                        },
                  semanticLabel: 'Send a password reset email',
                  child: const Text('Send password reset'),
                ),
                PubgetSecondaryButton(
                  onPressed: () => _signOut(context),
                  semanticLabel: 'Sign out',
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          PubgetCard(
            child: Column(
              children: <Widget>[
                for (final mode in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_themeLabel(mode)),
                    value: mode,
                    groupValue: settings.themeMode,
                    onChanged: (value) {
                      if (value != null) settings.setThemeMode(value);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Language', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          PubgetCard(
            child: Column(
              children: <Widget>[
                for (final option in AppLocaleOption.values)
                  RadioListTile<AppLocaleOption>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_localeLabel(option)),
                    value: option,
                    groupValue: settings.localeOption,
                    onChanged: (value) {
                      if (value != null) settings.setLocaleOption(value);
                    },
                  ),
              ],
            ),
          ),
          if (settings.failure != null) ...[
            const SizedBox(height: AppSpacing.md),
            PubgetErrorState(
              message: settings.failure!,
              onRetry: settings.load,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          PubgetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Version'),
                  subtitle: Text(appVersion),
                ),
                PubgetTextButton(
                  onPressed: () => AppNavigation.go(context, '/terms'),
                  semanticLabel: 'Open community terms',
                  child: const Text('Terms'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  static String _localeLabel(AppLocaleOption option) => switch (option) {
    AppLocaleOption.system => 'System',
    AppLocaleOption.english => 'English',
    AppLocaleOption.arabic => 'العربية',
  };

  static Future<void> _signOut(BuildContext context) async {
    await context.read<AuthProvider>().signOut();
    if (!context.mounted) return;
    await AppNavigation.go(context, '/login');
  }
}
