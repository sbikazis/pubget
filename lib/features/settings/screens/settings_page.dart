import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../authentication/providers/onboarding_provider.dart';
import '../../authentication/repositories/user_repository.dart';
import '../../notifications/repositories/notification_repository.dart';
import '../settings_provider.dart';
import '../settings_store.dart';
import '../widgets/language_picker.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({this.appVersion = '1.0.2+18', super.key});

  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<OnboardingProvider>().profile;
    final copy = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.settings)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text(copy.account, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          PubgetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(copy.signedInAs),
                  subtitle: Text(
                    profile?.email ?? auth.currentUser?.email ?? '—',
                  ),
                ),
                PubgetTextButton(
                  onPressed: () => AppNavigation.go(context, '/profile/edit'),
                  semanticLabel: copy.openPrivacyAndProfile,
                  child: Text(copy.privacyAndProfile),
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
                            AppStrings.of(context).passwordResetSent,
                          );
                        },
                  semanticLabel: copy.sendPasswordResetEmail,
                  child: Text(copy.sendPasswordReset),
                ),
                PubgetSecondaryButton(
                  onPressed: () => _signOut(context),
                  semanticLabel: copy.signOut,
                  child: Text(copy.signOut),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(copy.language, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          PubgetCard(
            child: SettingsLanguageRadios(
              onChanged: (option) => _mirrorLanguage(context, option),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(copy.appearance, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          PubgetCard(
            child: Column(
              children: <Widget>[
                for (final mode in ThemeMode.values)
                  RadioListTile<ThemeMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_themeLabel(copy, mode)),
                    value: mode,
                    groupValue: settings.themeMode,
                    onChanged: (value) {
                      if (value != null) settings.setThemeMode(value);
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
          Text(copy.help, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          PubgetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                PubgetTextButton(
                  onPressed: () => AppNavigation.go(context, '/guide'),
                  semanticLabel: copy.openGuide,
                  child: Text(copy.guide),
                ),
                PubgetTextButton(
                  onPressed: () => AppNavigation.go(context, '/terms'),
                  semanticLabel: copy.openTerms,
                  child: Text(copy.terms),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(copy.about, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          PubgetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(copy.version),
                  subtitle: Text(appVersion),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _themeLabel(AppStrings copy, ThemeMode mode) => switch (mode) {
    ThemeMode.system => copy.themeSystem,
    ThemeMode.light => copy.themeLight,
    ThemeMode.dark => copy.themeDark,
  };

  static void _mirrorLanguage(BuildContext context, AppLocaleOption option) {
    if (option == AppLocaleOption.system) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final code = option == AppLocaleOption.english ? 'en' : 'ar';
    // Mirror the explicit device choice to Firestore (spec §1.4). The event
    // is unawaited by design; the device settings remain the source of truth.
    unawaited(context.read<UserRepository>().updateLanguage(code));
  }

  static Future<void> _signOut(BuildContext context) async {
    // Release the push token before dropping the session (mirrors the sign-out
    // in the place holder home chrome).
    await context.read<NotificationRepository>().unregisterDeviceToken();
    if (!context.mounted) return;
    await context.read<AuthProvider>().signOut();
    if (!context.mounted) return;
    await AppNavigation.go(context, '/login');
  }
}
