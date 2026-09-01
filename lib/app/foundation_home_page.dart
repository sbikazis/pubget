import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/examples/dummy_provider.dart';
import '../core/loading/loading_state.dart';
import '../core/network/network_service.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/pubget_buttons.dart';
import 'design_system_showcase_page.dart';
import 'firebase_bootstrap.dart';

class FoundationHomePage extends StatelessWidget {
  const FoundationHomePage({super.key, this.firebaseState});

  final FirebaseInitializationState? firebaseState;

  @override
  Widget build(BuildContext context) {
    final network = context.watch<NetworkService>();
    final dummy = context.watch<DummyProvider>();
    final firebase = firebaseState;

    return Scaffold(
      appBar: AppBar(title: const Text('Pubget')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Pubget foundation',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  'The new application foundation is ready. Feature domains '
                  'will be added in later stages.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                _StatusRow(
                  label: 'Firebase',
                  value: firebase?.isReady == true
                      ? 'Initialized'
                      : 'Unavailable in this environment',
                ),
                _StatusRow(
                  label: 'Network',
                  value: network.isOnline ? 'Online' : 'Offline',
                ),
                const SizedBox(height: AppSpacing.lg),
                PubgetSecondaryButton(
                  onPressed: dummy.state == LoadingState.loading
                      ? null
                      : dummy.load,
                  semanticLabel: 'Run foundation data flow',
                  child: Text(
                    dummy.state == LoadingState.loading
                        ? 'Loading example…'
                        : 'Run foundation data flow',
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: AppSpacing.md),
                  PubgetPrimaryButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const DesignSystemShowcasePage(),
                      ),
                    ),
                    semanticLabel: 'Open design system showcase',
                    leadingIcon: Icons.palette_outlined,
                    child: const Text('Open design system showcase'),
                  ),
                ],
                if (dummy.greeting case final greeting?)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(greeting, textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
