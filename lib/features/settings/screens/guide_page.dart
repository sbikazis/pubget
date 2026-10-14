import 'package:flutter/material.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../l10n/guide_copy.dart';

class GuidePage extends StatefulWidget {
  const GuidePage({super.key});

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = GuideCopy.of(context);
    final needle = _query.text.trim().toLowerCase();
    final topics = copy.topics.where((topic) {
      if (needle.isEmpty) return true;
      return copy.topicTitle(topic).toLowerCase().contains(needle) ||
          copy.topicBody(topic).toLowerCase().contains(needle);
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          PubgetSearchField(
            controller: _query,
            hint: copy.searchHint,
            onChanged: (_) => setState(() {}),
            onClear: () {
              _query.clear();
              setState(() {});
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          if (topics.isEmpty)
            PubgetEmptyState(
              title: copy.emptyTitle,
              message: copy.emptyMessage,
              action: PubgetTextButton(
                onPressed: () {
                  _query.clear();
                  setState(() {});
                },
                semanticLabel: copy.clearSearchSemantic,
                child: Text(copy.clearSearch),
              ),
            )
          else
            for (final topic in topics) ...[
              PubgetCard(
                onTap: topic.route == null
                    ? null
                    : () => AppNavigation.go(context, topic.route!),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      copy.topicTitle(topic),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(copy.topicBody(topic)),
                    if (topic.route != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: <Widget>[
                          Text(
                            copy.openLabel,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}
