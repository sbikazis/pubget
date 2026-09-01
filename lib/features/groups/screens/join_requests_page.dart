import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../providers/group_members_provider.dart';

class JoinRequestsPage extends StatefulWidget {
  const JoinRequestsPage({required this.groupId, super.key});

  final String groupId;

  @override
  State<JoinRequestsPage> createState() => _JoinRequestsPageState();
}

class _JoinRequestsPageState extends State<JoinRequestsPage> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<GroupMembersProvider>();
    Future<void>.microtask(() => provider.loadRequests(widget.groupId));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GroupMembersProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Join requests')),
      body: PubgetLoadingStateView(
        state: provider.state,
        onRetry: () => provider.loadRequests(widget.groupId),
        empty: const PubgetEmptyState(title: 'No pending requests'),
        error: PubgetErrorState(
          message: provider.failure?.message ?? 'Requests could not load.',
          onRetry: () => provider.loadRequests(widget.groupId),
        ),
        offline: PubgetOfflineState(
          onRetry: () => provider.loadRequests(widget.groupId),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: provider.requests.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final request = provider.requests[index];
            return PubgetCard(
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(request.uid)),
                  PubgetIconButton(
                    icon: Icons.check,
                    tooltip: 'Accept request',
                    onPressed: () =>
                        provider.decideRequest(request.uid, accept: true),
                  ),
                  PubgetIconButton(
                    icon: Icons.close,
                    tooltip: 'Reject request',
                    onPressed: () =>
                        provider.decideRequest(request.uid, accept: false),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
