import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../app/firebase_bootstrap.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/errors/result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({required this.firebaseState, super.key});

  final FirebaseInitializationState firebaseState;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !widget.firebaseState.isReady) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveRoute());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!widget.firebaseState.isReady) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: PubgetCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.auto_awesome,
                        size: 48,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Pubget', style: theme.textTheme.headlineMedium),
                      const SizedBox(height: AppSpacing.md),
                      PubgetErrorState(
                        title: 'Authentication is unavailable here',
                        message:
                            widget.firebaseState.message ??
                            'Firebase could not be initialized.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PubgetSecondaryButton(
                        onPressed: () => AppNavigation.go(context, '/login'),
                        semanticLabel: 'Open sign in',
                        child: const Text('Open sign in'),
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

    final auth = context.watch<AuthProvider>();
    if (auth.state == LoadingState.error ||
        auth.state == LoadingState.offline) {
      final offline = auth.state == LoadingState.offline;
      return Scaffold(
        body: offline
            ? PubgetOfflineState(
                message:
                    auth.failure?.message ??
                    'Check your connection and try again.',
                onRetry: _retry,
              )
            : PubgetErrorState(
                title: 'Could not start Pubget',
                message:
                    auth.failure?.message ?? 'Please try opening Pubget again.',
                onRetry: _retry,
              ),
      );
    }
    final onboarding = context.watch<OnboardingProvider>();
    if (onboarding.state == LoadingState.error ||
        onboarding.state == LoadingState.offline) {
      final offline = onboarding.state == LoadingState.offline;
      return Scaffold(
        body: offline
            ? PubgetOfflineState(
                message:
                    onboarding.failure?.message ??
                    'Check your connection and try again.',
                onRetry: _retry,
              )
            : PubgetErrorState(
                title: 'Could not load your profile',
                message:
                    onboarding.failure?.message ??
                    'Please try loading your profile again.',
                onRetry: _retry,
              ),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.auto_awesome,
              size: 56,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Pubget', style: theme.textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            const Text('Preparing your experience…'),
          ],
        ),
      ),
    );
  }

  Future<void> _resolveRoute() async {
    final auth = context.read<AuthProvider>();
    await auth.initialize();
    if (!mounted) return;
    if (auth.state == LoadingState.error ||
        auth.state == LoadingState.offline) {
      setState(() {});
      return;
    }
    final user = auth.currentUser;
    if (user == null) {
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
    await AppNavigation.go(
      context,
      onboarding.canEnterHome ? '/home' : '/onboarding',
    );
  }

  void _retry() {
    context.read<AuthProvider>().clearFailure();
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
