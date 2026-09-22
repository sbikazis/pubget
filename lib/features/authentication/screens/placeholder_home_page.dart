import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/errors/result.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../../notifications/providers/unread_engine.dart';
import '../../notifications/repositories/notification_repository.dart';
import '../../notifications/widgets/unread_badge.dart';

class PlaceholderHomePage extends StatelessWidget {
  const PlaceholderHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<OnboardingProvider>().profile;
    final name =
        profile?.displayName ?? profile?.username ?? auth.currentUser?.email;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: const Text('Pubget'),
        actions: <Widget>[
          UnreadBadge(
            count: context.watch<UnreadEngine>().notifications,
            child: PubgetIconButton(
              icon: Icons.notifications_outlined,
              tooltip: copy.notifications,
              onPressed: () => AppNavigation.go(context, '/notifications'),
            ),
          ),
          PubgetIconButton(
            icon: Icons.logout,
            tooltip: copy.signOut,
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: PubgetCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PubgetAvatar(
                    imageUrl: profile?.avatarUrl ?? auth.currentUser?.avatarUrl,
                    name: name,
                    size: PubgetAvatarSize.large,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    name == null
                        ? copy.homeWelcomeToPubget
                        : copy.userNameWelcome(name),
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    copy.homeAccountReady,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PubgetSecondaryButton(
                    onPressed: () => AppNavigation.go(context, '/profile'),
                    semanticLabel: copy.homeMyProfileSemantic,
                    child: Text(copy.homeMyProfile),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PubgetSecondaryButton(
                    onPressed: () => AppNavigation.go(context, '/groups'),
                    semanticLabel: copy.homeGroupsSemantic,
                    child: Text(copy.homeGroups),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PubgetTextButton(
                    onPressed: () => AppNavigation.go(context, '/onboarding'),
                    semanticLabel: copy.homeEditOnboardingSemantic,
                    child: Text(copy.homeEditOnboarding),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await context.read<NotificationRepository>().unregisterDeviceToken();
    if (!context.mounted) return;
    final result = await context.read<AuthProvider>().signOut();
    if (!context.mounted) return;
    if (result is Success) await AppNavigation.go(context, '/login');
  }
}
