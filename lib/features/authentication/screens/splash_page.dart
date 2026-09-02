import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../app/firebase_bootstrap.dart';
import '../../../core/errors/result.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/auth_atmosphere.dart';
import '../widgets/pubget_torii_mark.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({required this.firebaseState, super.key});

  final FirebaseInitializationState firebaseState;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _started = false;
  final _startedAt = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !widget.firebaseState.isReady) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveRoute());
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.firebaseState.isReady) {
      return _MessageScaffold(
        offline: false,
        title: 'Pubget could not start',
        message:
            widget.firebaseState.message ??
            FirebaseBootstrap.unexpectedInitializationMessage,
      );
    }

    final auth = context.watch<AuthProvider>();
    if (auth.state == LoadingState.error ||
        auth.state == LoadingState.offline) {
      return _MessageScaffold(
        offline: auth.state == LoadingState.offline,
        title: 'Could not start Pubget',
        message: auth.failure?.message ?? 'Please try opening Pubget again.',
        onRetry: _retry,
      );
    }
    final onboarding = context.watch<OnboardingProvider>();
    if (onboarding.state == LoadingState.error ||
        onboarding.state == LoadingState.offline) {
      return _MessageScaffold(
        offline: onboarding.state == LoadingState.offline,
        title: 'Could not load your profile',
        message:
            onboarding.failure?.message ??
            'Please try loading your profile again.',
        onRetry: _retry,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.royalNight,
      body: AuthAtmosphere(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const PubgetToriiMark(size: 104),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'PUBGET',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  letterSpacing: 7,
                  fontWeight: FontWeight.w700,
                  color: AppColors.goldPale,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Premium Anime Community',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.4,
                  color: AppColors.goldSheen,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 96,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(99),
                  color: AppColors.goldSheen,
                  backgroundColor: AppColors.royalPurpleLight.withValues(
                    alpha: 0.22,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Preparing your experience…',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.goldPale.withValues(alpha: 0.86),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _resolveRoute() async {
    final auth = context.read<AuthProvider>();
    final alreadyReady = auth.isInitialized;
    await auth.initialize();
    if (!mounted) return;
    if (auth.state == LoadingState.error ||
        auth.state == LoadingState.offline) {
      setState(() {});
      return;
    }
    final user = auth.currentUser;
    if (user == null) {
      if (!alreadyReady) await _holdBrandMoment();
      if (!mounted) return;
      await AppNavigation.go(context, '/login');
      return;
    }
    final onboarding = context.read<OnboardingProvider>();
    final result = await onboarding.loadProfile(user.id);
    if (!mounted) return;
    if (result is FailureResult) {
      setState(() {});
      return;
    }
    if (!alreadyReady) await _holdBrandMoment();
    if (!mounted) return;
    await AppNavigation.go(
      context,
      onboarding.canEnterHome ? '/home' : '/onboarding',
    );
  }

  Future<void> _holdBrandMoment() async {
    final elapsed = DateTime.now().difference(_startedAt);
    const minimum = Duration(milliseconds: 900);
    if (elapsed < minimum) {
      await Future<void>.delayed(minimum - elapsed);
    }
  }

  void _retry() {
    context.read<AuthProvider>().clearFailure();
    context.read<OnboardingProvider>().clearFailure();
    _started = false;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _started = true;
        _resolveRoute();
      }
    });
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({
    required this.offline,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final bool offline;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.royalNight,
      body: AuthAtmosphere(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const PubgetToriiMark(size: 88),
                    const SizedBox(height: AppSpacing.xl),
                    if (offline)
                      PubgetInlineBanner(
                        title: 'You are offline',
                        message: message,
                        icon: Icons.cloud_off_outlined,
                        onRetry: onRetry,
                      )
                    else
                      PubgetInlineBanner.error(
                        title: title,
                        message: message,
                        onRetry: onRetry,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
