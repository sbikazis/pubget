import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/l10n/app_strings.dart';
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
  final TextEditingController _text = TextEditingController();
  bool _opened = false;
  String? _loadedGroupId;
  String? _rankingEventId;

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

  void _syncRanking(PubgetEvent event) {
    if (!EventTypeRegistry.of(event.type).usesRanking ||
        _rankingEventId == event.id) {
      return;
    }
    _rankingEventId = event.id;
    _rankedIds
      ..clear()
      ..addAll(event.configuration.options.map((option) => option.id));
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
    if (event != null) {
      _syncRanking(event);
      _maybeLoadGroup(event);
    }
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
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
              EventLinks.share(context, widget.eventId, title: event?.title);
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
                        label: AppStrings.of(
                          context,
                        ).eventTypeLabel(event.type.name),
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
                  if (event.status == EventStatus.deleted)
                    const Text(EventStrings.deleted),
                  if (event.status == EventStatus.archived)
                    const Text(EventStrings.archived),
                  if (event.status == EventStatus.ended)
                    const Text(EventStrings.ended),
                  const SizedBox(height: AppSpacing.lg),
                  _SocialActionsRow(event: event),
                  if (event.isOpen && !event.isExpired())
                    _Participation(event: event),
                  if ((event.isHistorical || event.isExpired()) &&
                      event.result != null)
                    _ResultCard(event: event),
                  if (event.isInteractable()) ...[
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
                      onRankReorder: (ids) {
                        setState(() {
                          _rankedIds
                            ..clear()
                            ..addAll(ids);
                        });
                      },
                      onResetRank: () {
                        setState(() {
                          _rankedIds
                            ..clear()
                            ..addAll(
                              event.configuration.options.map(
                                (option) => option.id,
                              ),
                            );
                        });
                      },
                      onQuizAnswer: (questionId, optionId) {
                        setState(() {
                          if (optionId.isEmpty) {
                            _quizAnswers.remove(questionId);
                          } else {
                            _quizAnswers[questionId] = optionId;
                          }
                        });
                      },
                    ),
                  ],
                  _ManageActions(event: event),
                  const SizedBox(height: AppSpacing.lg),
                  _CommentsSection(event: event, text: _text),
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
    required this.onRankReorder,
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
  final ValueChanged<List<String>> onRankReorder;
  final VoidCallback onResetRank;
  final void Function(String questionId, String optionId) onQuizAnswer;

  @override
  Widget build(BuildContext context) {
    final spec = EventTypeRegistry.of(event.type);
    final provider = context.watch<EventProvider>();
    final strings = AppStrings.of(context);
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
        if (event.configuration.criterion.isNotEmpty) ...[
          Text(
            event.configuration.criterion,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (spec.usesRanking) ...[
          Text(strings.eventRankOptionsHint),
          const SizedBox(height: AppSpacing.sm),
          ReorderableListView.builder(
            key: const Key('event-ranking-options'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: event.configuration.options.length,
            onReorder: (oldIndex, newIndex) {
              final next = <String>[
                for (final option in event.configuration.options)
                  if (rankedIds.contains(option.id)) option.id,
                for (final option in event.configuration.options)
                  if (!rankedIds.contains(option.id)) option.id,
              ];
              if (newIndex > oldIndex) newIndex -= 1;
              next.insert(newIndex, next.removeAt(oldIndex));
              onRankReorder(next);
            },
            itemBuilder: (context, index) {
              final id = rankedIds.isEmpty
                  ? event.configuration.options[index].id
                  : rankedIds[index];
              final option = event.configuration.options.firstWhere(
                (item) => item.id == id,
              );
              return ListTile(
                key: ValueKey('ranking-$id'),
                leading: Text('${index + 1}'),
                title: Text(option.label),
                trailing: ReorderableDragStartListener(
                  key: Key('ranking-handle-$id'),
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
              );
            },
          ),
          PubgetTextButton(
            onPressed: onResetRank,
            semanticLabel: strings.eventResetRanking,
            child: Text(strings.eventResetRanking),
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
              subtitle: option.characterId.isNotEmpty
                  ? Text(option.characterId)
                  : option.animeId.isNotEmpty
                  ? Text(option.animeId)
                  : option.license.isNotEmpty
                  ? Text('${option.license} · ${option.attribution}')
                  : null,
              secondary: option.imageUrl.startsWith('https://')
                  ? SizedBox(
                      width: 56,
                      height: 56,
                      child: AppImageLoader(
                        imageUrl: option.imageUrl,
                        width: 56,
                        height: 56,
                        memCacheWidth: 112,
                        memCacheHeight: 112,
                      ),
                    )
                  : null,
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
            (question) => _QuizQuestionTile(
              question: question,
              selectedId: quizAnswers[question.id],
              onSelect: (optionId) => onQuizAnswer(question.id, optionId),
              onExpire: () {
                if (quizAnswers.containsKey(question.id)) {
                  onQuizAnswer(question.id, '');
                }
              },
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
      data = <String, dynamic>{
        if (text.text.trim().isNotEmpty) 'text': text.text.trim(),
      };
    } else if (spec.usesQuiz) {
      if (quizAnswers.isEmpty) return;
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

class _QuizQuestionTile extends StatefulWidget {
  const _QuizQuestionTile({
    required this.question,
    required this.selectedId,
    required this.onSelect,
    required this.onExpire,
  });

  final EventQuizQuestion question;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onExpire;

  @override
  State<_QuizQuestionTile> createState() => _QuizQuestionTileState();
}

class _QuizQuestionTileState extends State<_QuizQuestionTile> {
  Timer? _timer;
  int _left = 0;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    if (widget.question.seconds > 0) {
      _left = widget.question.seconds;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_left <= 1) {
          _timer?.cancel();
          setState(() {
            _left = 0;
            _expired = true;
          });
          widget.onExpire();
        } else {
          setState(() => _left -= 1);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final locked = _expired && widget.selectedId == null;
    final minutes = (_left ~/ 60).toString().padLeft(2, '0');
    final seconds = (_left % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.question.prompt,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (widget.question.seconds > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  _expired ? Icons.timer_off_outlined : Icons.timer_outlined,
                  size: 18,
                  color: _expired
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                Text(
                  _expired ? strings.eventTimeUp : '$minutes:$seconds',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _expired
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
          if (_expired && widget.selectedId == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                strings.eventQuestionLocked,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ...widget.question.options.map(
            (option) => RadioListTile<String>(
              title: Text(option.label),
              value: option.id,
              groupValue: widget.selectedId,
              onChanged: locked
                  ? null
                  : (value) {
                      if (value != null) widget.onSelect(value);
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.event});

  final PubgetEvent event;

  @override
  Widget build(BuildContext context) {
    final result = event.result!;
    final strings = AppStrings.of(context);
    final labels = <String, String>{
      for (final option in event.configuration.options) option.id: option.label,
    };
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.eventResultTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('${strings.eventSubmissions}: ${result.submissions}'),
          if (event.type == EventType.quiz &&
              result.leaderboard.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              strings.eventLeaderboard,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final entry
                in result.leaderboard.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
              Text('${entry.key}: ${entry.value} ${strings.eventPoints}'),
          ],
          if (event.type == EventType.prediction &&
              result.winnerOptionId != null)
            Text(
              '${strings.eventResultTitle}: ${labels[result.winnerOptionId] ?? result.winnerOptionId}',
            ),
          if (result.winnerIds.isNotEmpty && event.type != EventType.prediction)
            Text(
              '${strings.eventWinner}: ${result.winnerIds.map((id) => labels[id] ?? id).join(', ')}',
            ),
          ...result.votes.entries.map(
            (entry) =>
                Text('${labels[entry.key] ?? entry.key}: ${entry.value}'),
          ),
          if (event.type == EventType.ranking &&
              result.orderedOptionIds.isNotEmpty)
            for (final entry in result.orderedOptionIds.indexed)
              Text(
                '${entry.$1 + 1}. ${labels[entry.$2] ?? entry.$2}: '
                '${result.scores[entry.$2] ?? 0} ${strings.eventPoints}',
              )
          else
            ...result.scores.entries.map(
              (entry) => Text(
                '${labels[entry.key] ?? entry.key}: ${entry.value} ${strings.eventPoints}',
              ),
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
    final uid = context.watch<AuthProvider>().currentUser?.id;
    final canManage =
        context.watch<GroupProvider>().canManageEvents ||
        event.creatorId == uid;
    if (!canManage) return const SizedBox.shrink();
    final provider = context.read<EventProvider>();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Wrap(
        spacing: AppSpacing.sm,
        children: <Widget>[
          if ((event.type == EventType.prediction ||
                  event.type == EventType.challenge) &&
              event.status == EventStatus.active &&
              event.creatorId == uid)
            PubgetSecondaryButton(
              onPressed: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => _ResolveEventDialog(event: event),
                );
              },
              semanticLabel: 'Resolve result',
              child: const Text('Resolve result'),
            ),
          if (event.status == EventStatus.active ||
              event.status == EventStatus.ended)
            PubgetSecondaryButton(
              onPressed: () async {
                final result = await provider.openAnalytics(event.id);
                if (!context.mounted) return;
                if (!result.isSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.failureOrNull?.message ?? EventStrings.missing,
                      ),
                    ),
                  );
                  return;
                }
                await showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => _AnalyticsSheet(event: event),
                );
              },
              semanticLabel: 'Analytics',
              child: const Text('Analytics'),
            ),
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
              event.status != EventStatus.deleted)
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

class _SocialActionsRow extends StatelessWidget {
  const _SocialActionsRow({required this.event});

  final PubgetEvent event;

  @override
  Widget build(BuildContext context) {
    if (event.status == EventStatus.deleted ||
        event.status == EventStatus.draft) {
      return const SizedBox.shrink();
    }
    final provider = context.read<EventProvider>();
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        PubgetTextButton(
          onPressed: () async {
            final result = await provider.react(event.id, 'like');
            if (!context.mounted) return;
            if (!result.isSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result.failureOrNull?.message ?? '')),
              );
            }
          },
          semanticLabel: 'Like',
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.favorite_border, size: 18),
              SizedBox(width: 4),
              Text('Like'),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({required this.event, required this.text});

  final PubgetEvent event;
  final TextEditingController text;

  @override
  Widget build(BuildContext context) {
    if (event.status == EventStatus.deleted ||
        event.status == EventStatus.draft) {
      return const SizedBox.shrink();
    }
    final provider = context.watch<EventProvider>();
    final comments = provider.comments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Comments (${comments.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text('No comments yet. Start the conversation.'),
          )
        else
          for (final comment in comments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                child: Text(comment.userId.isEmpty ? '?' : comment.userId[0]),
              ),
              title: Text(comment.text),
              subtitle: Text(comment.userId),
            ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: text,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Add a comment…',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            PubgetPrimaryButton(
              loading: provider.submitting,
              onPressed: (provider.submitting || text.text.trim().isEmpty)
                  ? null
                  : () async {
                      final message = text.text.trim();
                      text.clear();
                      final result = await provider.addComment(
                        event.id,
                        message,
                      );
                      if (!context.mounted) return;
                      if (!result.isSuccess) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.failureOrNull?.message ?? ''),
                          ),
                        );
                      }
                    },
              semanticLabel: 'Post comment',
              child: const Text('Post'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResolveEventDialog extends StatefulWidget {
  const _ResolveEventDialog({required this.event});

  final PubgetEvent event;

  @override
  State<_ResolveEventDialog> createState() => _ResolveEventDialogState();
}

class _ResolveEventDialogState extends State<_ResolveEventDialog> {
  String? _winnerOptionId;
  final Set<String> _winnerIds = <String>{};
  bool _loading = false;
  List<EventParticipant> _participants = const <EventParticipant>[];

  String get _predictionLabel => widget.event.type == EventType.prediction
      ? 'Select the winning option'
      : 'Select the winner(s)';

  @override
  void initState() {
    super.initState();
    if (widget.event.type == EventType.challenge) {
      _loadParticipants();
    }
  }

  Future<void> _loadParticipants() async {
    setState(() => _loading = true);
    final repository = context.read<EventProvider>();
    final result = await repository.openAnalytics(widget.event.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _participants =
          result.valueOrNull?.responses
              .map(
                (response) => EventParticipant(
                  userId: response.userId,
                  displayName: response.userId,
                ),
              )
              .toList(growable: false) ??
          const <EventParticipant>[];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPrediction = widget.event.type == EventType.prediction;
    return AlertDialog(
      title: Text(_predictionLabel),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : isPrediction
            ? SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final option in widget.event.configuration.options)
                      RadioListTile<String>(
                        title: Text(option.label),
                        value: option.id,
                        groupValue: _winnerOptionId,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _winnerOptionId = value);
                          }
                        },
                      ),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_participants.isEmpty)
                      const Text('No challenge responses yet.')
                    else
                      for (final participant in _participants)
                        CheckboxListTile(
                          title: Text(participant.userId),
                          value: _winnerIds.contains(participant.userId),
                          onChanged: (checked) {
                            setState(() {
                              if (checked ?? false) {
                                _winnerIds.add(participant.userId);
                              } else {
                                _winnerIds.remove(participant.userId);
                              }
                            });
                          },
                        ),
                  ],
                ),
              ),
      ),
      actions: <Widget>[
        PubgetTextButton(
          onPressed: () => Navigator.of(context).pop(),
          semanticLabel: EventStrings.cancelEvent,
          child: const Text(EventStrings.cancelEvent),
        ),
        PubgetPrimaryButton(
          onPressed: () => _resolve(context),
          semanticLabel: 'Lock result',
          child: const Text('Lock result'),
        ),
      ],
    );
  }

  Future<void> _resolve(BuildContext context) async {
    final provider = context.read<EventProvider>();
    final result = await provider.resolve(
      eventId: widget.event.id,
      winnerOptionId: _winnerOptionId,
      winnerIds: _winnerIds.toList(growable: false),
    );
    if (!context.mounted) return;
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failureOrNull?.message ?? '')),
      );
    } else {
      Navigator.of(context).pop();
    }
  }
}

class _AnalyticsSheet extends StatelessWidget {
  const _AnalyticsSheet({required this.event});

  final PubgetEvent event;

  @override
  Widget build(BuildContext context) {
    final analytics = context.watch<EventProvider>().analyticsData;
    final labels = <String, String>{
      for (final option in event.configuration.options) option.id: option.label,
    };
    final responses = analytics?.responses ?? const <EventResponse>[];
    final participants = analytics?.participants ?? const <EventParticipant>[];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Event analytics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('${analytics?.tally.submissions ?? 0} submissions'),
              Text(
                '${participants.where((item) => item.isActive).length} active participants',
              ),
              if (analytics?.tally.votes.isNotEmpty ?? false) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Votes', style: Theme.of(context).textTheme.titleMedium),
                for (final entry in analytics!.tally.votes.entries)
                  Text('${labels[entry.key] ?? entry.key}: ${entry.value}'),
              ],
              if (analytics?.tally.scores.isNotEmpty ?? false) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Scores', style: Theme.of(context).textTheme.titleMedium),
                for (final entry in analytics!.tally.scores.entries)
                  Text('${labels[entry.key] ?? entry.key}: ${entry.value} pts'),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                'Responses (${responses.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (responses.isEmpty)
                const Text('No responses yet.')
              else
                for (final response in responses)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_outline),
                    title: Text(response.userId),
                    subtitle: Text('${response.responseData}'),
                  ),
            ],
          ),
        ),
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
