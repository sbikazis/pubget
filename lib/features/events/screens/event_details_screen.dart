import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/result.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../models/event_models.dart';
import '../models/event_type_registry.dart';
import '../providers/event_providers.dart';
import '../widgets/event_widgets.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({required this.eventId, super.key});

  final String eventId;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  String? _selectedOptionId;
  final Set<String> _selectedIds = <String>{};
  final List<String> _rankedIds = <String>[];
  final Map<String, String> _quizAnswers = <String, String>{};
  final _text = TextEditingController();
  bool _opened = false;
  String? _loadedGroupId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid == null) return;
    _opened = true;
    final messenger = context.read<EventProvider>();
    Future<void>.microtask(
      () => messenger.open(eventId: widget.eventId, userId: uid),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _maybeLoadGroup(PubgetEvent event) {
    final groupId = event.groupId;
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (groupId == null || groupId.isEmpty || uid == null) return;
    if (_loadedGroupId == groupId) return;
    _loadedGroupId = groupId;
    final groups = context.read<GroupProvider>();
    Future<void>.microtask(() => groups.load(groupId: groupId, userId: uid));
  }

  @override
  Widget build(BuildContext context) {
    final eventState = context.watch<EventProvider>();
    final event = eventState.event;
    if (event != null) _maybeLoadGroup(event);
    return Scaffold(
      appBar: AppBar(
        title: Text(event?.title ?? 'Event'),
        actions: [
          IconButton(
            tooltip: EventStrings.copyLink,
            onPressed: () {
              context.read<EventProvider>().share(widget.eventId);
              EventLinks.copy(context, widget.eventId);
            },
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: EventStrings.share,
            onPressed: () {
              context.read<EventProvider>().share(widget.eventId);
              EventLinks.share(context, widget.eventId);
            },
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: PubgetLoadingStateView(
        state: eventState.state,
        onRetry: () {
          final uid = context.read<AuthProvider>().currentUser?.id;
          if (uid == null) return;
          context.read<EventProvider>().open(
            eventId: widget.eventId,
            userId: uid,
          );
        },
        empty: const PubgetEmptyState(
          title: EventStrings.missing,
          icon: Icons.event_busy_outlined,
        ),
        error: PubgetErrorState(
          message: eventState.failure?.message ?? EventStrings.missing,
        ),
        offline: const PubgetOfflineState(),
        child: event == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: <Widget>[
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      PubgetBadge(
                        label: EventTypeRegistry.of(event.type).label,
                      ),
                      PubgetBadge(label: event.status.name),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(event.description),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  EventCountdown(event: event),
                  Text('${event.participantsCount} participating'),
                  if (event.status == EventStatus.cancelled)
                    const Text(EventStrings.cancelled),
                  if (event.status == EventStatus.archived)
                    const Text(EventStrings.archived),
                  if (event.status == EventStatus.ended)
                    const Text(EventStrings.ended),
                  const SizedBox(height: AppSpacing.lg),
                  if (!event.isReadOnly) _Participation(event: event),
                  if (event.isHistorical && event.result != null)
                    _ResultCard(event: event),
                  if (!event.isReadOnly) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _ResponseForm(
                      event: event,
                      selectedOptionId: _selectedOptionId,
                      selectedIds: _selectedIds,
                      rankedIds: _rankedIds,
                      quizAnswers: _quizAnswers,
                      text: _text,
                      onSelect: (id) => setState(() => _selectedOptionId = id),
                      onToggle: (id, selected) {
                        setState(() {
                          if (selected) {
                            _selectedIds.add(id);
                          } else {
                            _selectedIds.remove(id);
                          }
                        });
                      },
                      onRank: (id) {
                        setState(() {
                          if (!_rankedIds.contains(id)) _rankedIds.add(id);
                        });
                      },
                      onResetRank: () => setState(_rankedIds.clear),
                      onQuizAnswer: (questionId, optionId) {
                        setState(() => _quizAnswers[questionId] = optionId);
                      },
                    ),
                  ],
                  _ManageActions(event: event),
                ],
              ),
      ),
    );
  }
}

class _Participation extends StatelessWidget {
  const _Participation({required this.event});

  final PubgetEvent event;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventProvider>();
    return Row(
      children: <Widget>[
        PubgetPrimaryButton(
          onPressed: provider.submitting
              ? null
              : () => _run(context, () => provider.join(event.id)),
          semanticLabel: EventStrings.join,
          child: const Text(EventStrings.join),
        ),
        const SizedBox(width: AppSpacing.sm),
        PubgetTextButton(
          onPressed: provider.submitting
              ? null
              : () => _run(context, () => provider.leave(event.id)),
          semanticLabel: EventStrings.leave,
          child: const Text(EventStrings.leave),
        ),
      ],
    );
  }
}

class _ResponseForm extends StatelessWidget {
  const _ResponseForm({
    required this.event,
    required this.selectedOptionId,
    required this.selectedIds,
    required this.rankedIds,
    required this.quizAnswers,
    required this.text,
    required this.onSelect,
    required this.onToggle,
    required this.onRank,
    required this.onResetRank,
    required this.onQuizAnswer,
  });

  final PubgetEvent event;
  final String? selectedOptionId;
  final Set<String> selectedIds;
  final List<String> rankedIds;
  final Map<String, String> quizAnswers;
  final TextEditingController text;
  final ValueChanged<String> onSelect;
  final void Function(String id, bool selected) onToggle;
  final ValueChanged<String> onRank;
  final VoidCallback onResetRank;
  final void Function(String questionId, String optionId) onQuizAnswer;

  @override
  Widget build(BuildContext context) {
    final spec = EventTypeRegistry.of(event.type);
    final provider = context.watch<EventProvider>();
    if (provider.hasSubmitted && !event.configuration.allowUpdate) {
      return const PubgetEmptyState(
        title: EventStrings.alreadyParticipated,
        message: EventStrings.noParticipation,
      );
    }
    final multi =
        event.configuration.maxSelections > 1 ||
        event.configuration.allowMultiple;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (spec.usesRanking) ...[
          const Text('Tap options in the order you want to rank them.'),
          ...event.configuration.options.map((option) {
            final rank = rankedIds.indexOf(option.id);
            return ListTile(
              title: Text(option.label),
              trailing: Text(rank < 0 ? '' : '${rank + 1}'),
              onTap: () => onRank(option.id),
            );
          }),
          PubgetTextButton(
            onPressed: onResetRank,
            semanticLabel: 'Reset ranking',
            child: const Text('Reset ranking'),
          ),
        ] else if (spec.usesOptions && multi)
          ...event.configuration.options.map(
            (option) => CheckboxListTile(
              title: Text(option.label),
              value: selectedIds.contains(option.id),
              onChanged: (value) => onToggle(option.id, value ?? false),
            ),
          )
        else if (spec.usesOptions)
          ...event.configuration.options.map(
            (option) => RadioListTile<String>(
              title: Text(option.label),
              value: option.id,
              groupValue: selectedOptionId,
              onChanged: (value) {
                if (value != null) onSelect(value);
              },
            ),
          ),
        if (spec.usesTextResponse)
          PubgetTextArea(
            controller: text,
            label: event.configuration.prompt.isEmpty
                ? 'Your response'
                : event.configuration.prompt,
          ),
        if (spec.usesQuiz)
          ...event.configuration.questions.map(
            (question) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    question.prompt,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...question.options.map(
                    (option) => RadioListTile<String>(
                      title: Text(option.label),
                      value: option.id,
                      groupValue: quizAnswers[question.id],
                      onChanged: (value) {
                        if (value != null) onQuizAnswer(question.id, value);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        PubgetPrimaryButton(
          loading: provider.submitting,
          onPressed: provider.submitting
              ? null
              : () => _submit(context, provider),
          semanticLabel: EventStrings.submit,
          child: const Text(EventStrings.submit),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context, EventProvider provider) async {
    final spec = EventTypeRegistry.of(event.type);
    Map<String, dynamic> data;
    if (spec.usesRanking) {
      if (rankedIds.length != event.configuration.options.length) return;
      data = <String, dynamic>{'rankedIds': rankedIds};
    } else if (spec.usesTextResponse) {
      data = <String, dynamic>{'text': text.text, 'completed': true};
    } else if (spec.usesQuiz) {
      if (quizAnswers.length != event.configuration.questions.length) return;
      data = <String, dynamic>{'answers': quizAnswers};
    } else if (event.configuration.maxSelections > 1 ||
        event.configuration.allowMultiple) {
      if (selectedIds.isEmpty) return;
      data = <String, dynamic>{'optionIds': selectedIds.toList()};
    } else {
      if (selectedOptionId == null) return;
      data = <String, dynamic>{'optionId': selectedOptionId};
    }
    final result = await provider.submit(eventId: event.id, responseData: data);
    if (!context.mounted) return;
    if (result is FailureResult) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.failure.message)));
    }
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.event});

  final PubgetEvent event;

  @override
  Widget build(BuildContext context) {
    final result = event.result!;
    final labels = <String, String>{
      for (final option in event.configuration.options) option.id: option.label,
    };
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            EventStrings.resultTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('${result.submissions} submissions'),
          if (result.winnerIds.isNotEmpty)
            Text(
              'Winner: ${result.winnerIds.map((id) => labels[id] ?? id).join(', ')}',
            ),
          ...result.votes.entries.map(
            (entry) =>
                Text('${labels[entry.key] ?? entry.key}: ${entry.value}'),
          ),
          ...result.scores.entries.map(
            (entry) =>
                Text('${labels[entry.key] ?? entry.key}: ${entry.value} pts'),
          ),
        ],
      ),
    );
  }
}

class _ManageActions extends StatelessWidget {
  const _ManageActions({required this.event});

  final PubgetEvent event;

  @override
  Widget build(BuildContext context) {
    final member = context.watch<GroupProvider>().membership;
    final uid = context.watch<AuthProvider>().currentUser?.id;
    final canManage = member?.canManageEvents == true || event.creatorId == uid;
    if (!canManage) return const SizedBox.shrink();
    final provider = context.read<EventProvider>();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Wrap(
        spacing: AppSpacing.sm,
        children: <Widget>[
          if (event.status == EventStatus.active)
            PubgetSecondaryButton(
              onPressed: () => provider.end(event.id),
              semanticLabel: EventStrings.endEvent,
              child: const Text(EventStrings.endEvent),
            ),
          if (event.status == EventStatus.ended)
            PubgetSecondaryButton(
              onPressed: () => provider.archive(event.id),
              semanticLabel: EventStrings.archiveEvent,
              child: const Text(EventStrings.archiveEvent),
            ),
          if (event.status != EventStatus.archived &&
              event.status != EventStatus.cancelled)
            PubgetTextButton(
              onPressed: () => provider.cancel(event.id),
              semanticLabel: EventStrings.cancelEvent,
              child: const Text(EventStrings.cancelEvent),
            ),
        ],
      ),
    );
  }
}

Future<void> _run(
  BuildContext context,
  Future<Result<void>> Function() action,
) async {
  final result = await action();
  if (!context.mounted) return;
  if (result is FailureResult) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.failure.message)));
  }
}
