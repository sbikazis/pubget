import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../groups/widgets/chat_action_sheets.dart';
import '../models/event_models.dart';
import '../models/event_type_registry.dart';
import '../providers/event_providers.dart';
import '../widgets/event_crosspost_sheet.dart';
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
  String? _stance;
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
    final provider = context.read<EventProvider>();
    Future<void>.microtask(
      () => provider.open(eventId: widget.eventId, userId: uid),
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

  Future<void> _report(PubgetEvent event) async {
    final copy = AppStrings.of(context);
    await runReportFlow(
      context,
      onSubmit: (reason) async {
        final repository = context.read<EventProvider>();
        final result = await repository.report(
          eventId: event.id,
          category: reason,
        );
        if (!context.mounted) return false;
        _showMessage(
          result.isSuccess ? copy.reportSubmitted : copy.reportFailed,
        );
        return result.isSuccess;
      },
    );
  }

  void _showMessage(String message) {
    if (message.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final provider = context.watch<EventProvider>();
    final event = provider.event;
    if (event != null) {
      _syncRanking(event);
      _maybeLoadGroup(event);
    }
    final uid = context.watch<AuthProvider>().currentUser?.id;
    final canReport =
        event != null &&
        event.creatorId != uid &&
        event.status != EventStatus.draft &&
        event.status != EventStatus.deleted;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(event?.title ?? copy.eventTitleFallback),
        actions: <Widget>[
          IconButton(
            tooltip: copy.eventCopyLink,
            onPressed: () {
              context.read<EventProvider>().share(widget.eventId);
              EventLinks.copy(context, widget.eventId);
            },
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: copy.eventShare,
            onPressed: () {
              context.read<EventProvider>().share(widget.eventId);
              EventLinks.share(context, widget.eventId, title: event?.title);
            },
            icon: const Icon(Icons.ios_share),
          ),
          if (canReport)
            IconButton(
              key: const Key('event-report'),
              tooltip: copy.eventReport,
              onPressed: () => _report(event),
              icon: const Icon(Icons.flag_outlined),
            ),
        ],
      ),
      body: PubgetLoadingStateView(
        state: provider.state,
        onRetry: () {
          final viewer = context.read<AuthProvider>().currentUser?.id;
          if (viewer == null) return;
          context.read<EventProvider>().open(
            eventId: widget.eventId,
            userId: viewer,
          );
        },
        empty: PubgetEmptyState(
          title: copy.eventMissing,
          icon: Icons.event_busy_outlined,
        ),
        error: PubgetErrorState(
          message: provider.failure?.message ?? copy.eventMissing,
        ),
        offline: const PubgetOfflineState(),
        child: event == null
            ? const SizedBox.shrink()
            : _EventBody(
                event: event,
                provider: provider,
                selectedOptionId: _selectedOptionId,
                selectedIds: _selectedIds,
                rankedIds: _rankedIds,
                quizAnswers: _quizAnswers,
                text: _text,
                stance: _stance,
                onSelect: (id) => setState(() => _selectedOptionId = id),
                onToggle: (id, selected) => setState(() {
                  if (selected) {
                    _selectedIds.add(id);
                  } else {
                    _selectedIds.remove(id);
                  }
                }),
                onRankReorder: (ids) => setState(() {
                  _rankedIds
                    ..clear()
                    ..addAll(ids);
                }),
                onResetRank: () => setState(() {
                  _rankedIds
                    ..clear()
                    ..addAll(
                      event.configuration.options.map((option) => option.id),
                    );
                }),
                onQuizAnswer: (questionId, optionId) => setState(() {
                  if (optionId.isEmpty) {
                    _quizAnswers.remove(questionId);
                  } else {
                    _quizAnswers[questionId] = optionId;
                  }
                }),
                onStance: (value) => setState(() => _stance = value),
                onMessage: _showMessage,
              ),
      ),
    );
  }
}

class _EventBody extends StatelessWidget {
  const _EventBody({
    required this.event,
    required this.provider,
    required this.selectedOptionId,
    required this.selectedIds,
    required this.rankedIds,
    required this.quizAnswers,
    required this.text,
    required this.stance,
    required this.onSelect,
    required this.onToggle,
    required this.onRankReorder,
    required this.onResetRank,
    required this.onQuizAnswer,
    required this.onStance,
    required this.onMessage,
  });

  final PubgetEvent event;
  final EventProvider provider;
  final String? selectedOptionId;
  final Set<String> selectedIds;
  final List<String> rankedIds;
  final Map<String, String> quizAnswers;
  final TextEditingController text;
  final String? stance;
  final ValueChanged<String> onSelect;
  final void Function(String id, bool selected) onToggle;
  final ValueChanged<List<String>> onRankReorder;
  final VoidCallback onResetRank;
  final void Function(String questionId, String optionId) onQuizAnswer;
  final ValueChanged<String> onStance;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final isPoll = event.type == EventType.poll;
    final isTheory = event.type == EventType.theory;
    final interactable = event.isInteractable();
    final myOptionId = _myOptionId();
    final myStance =
        stance ?? provider.myResponse?.responseData['stance'] as String?;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            PubgetBadge(label: copy.eventTypeLabel(event.type.name)),
            PubgetBadge(label: copy.eventStatusLabel(event.status.name)),
            PubgetBadge(label: copy.eventScopeLabel(event.scope.name)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(event.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        if (isPoll) _PollSection(
          event: event,
          provider: provider,
          myOptionId: myOptionId,
          enabled: interactable && !provider.submitting,
          onVote: (id) => _submit(
            context,
            provider,
            <String, dynamic>{'optionId': id},
          ),
        )
        else if (isTheory) _TheorySection(
          event: event,
          provider: provider,
          stance: myStance,
          enabled: interactable && !provider.submitting,
          onStance: (value) {
            onStance(value);
            _submit(context, provider, <String, dynamic>{'stance': value});
          },
        )
        else if (event.description.isNotEmpty)
          Text(event.description),
        const SizedBox(height: AppSpacing.md),
        EventCountdown(event: event),
        if (event.participantsCount > 0)
          Text(copy.eventParticipants(event.participantsCount)),
        if (event.isReadOnly) ...[
          const SizedBox(height: AppSpacing.sm),
          _StatusNotice(
            message: switch (event.status) {
              EventStatus.deleted => copy.eventDeleted,
              EventStatus.archived => copy.eventArchived,
              _ => copy.eventEndedNotice,
            },
          ),
        ] else if (event.status == EventStatus.active &&
            event.startAt != null &&
            event.startAt!.isAfter(DateTime.now()))
          _StatusNotice(message: copy.eventNotStartedYet),
        const SizedBox(height: AppSpacing.lg),
        _ReactionBar(event: event, provider: provider),
        if (interactable && !isPoll && !isTheory) ...[
          const SizedBox(height: AppSpacing.md),
          _Participation(event: event, provider: provider),
        ],
        if ((event.isHistorical || event.isExpired()) && event.result != null)
          _ResultCard(event: event),
        if (interactable && !isPoll && !isTheory) ...[
          const SizedBox(height: AppSpacing.lg),
          _ResponseForm(
            event: event,
            provider: provider,
            selectedOptionId: selectedOptionId,
            selectedIds: selectedIds,
            rankedIds: rankedIds,
            quizAnswers: quizAnswers,
            text: text,
            onSelect: onSelect,
            onToggle: onToggle,
            onRankReorder: onRankReorder,
            onResetRank: onResetRank,
            onQuizAnswer: onQuizAnswer,
          ),
        ],
        _ManageActions(event: event, provider: provider),
        const SizedBox(height: AppSpacing.lg),
        _CommentsSection(event: event, text: text),
      ],
    );
  }

  String? _myOptionId() {
    final data = provider.myResponse?.responseData;
    if (data == null) return null;
    final single = data['optionId'];
    if (single is String && single.isNotEmpty) return single;
    return null;
  }

  Future<void> _submit(
    BuildContext context,
    EventProvider provider,
    Map<String, dynamic> payload,
  ) async {
    final result = await provider.submit(
      eventId: event.id,
      responseData: payload,
    );
    if (!context.mounted) return;
    if (result is FailureResult) {
      onMessage(_failureText(AppStrings.of(context), result.failure));
    }
  }
}

class _StatusNotice extends StatelessWidget {
  const _StatusNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- poll --

class _PollSection extends StatelessWidget {
  const _PollSection({
    required this.event,
    required this.provider,
    required this.myOptionId,
    required this.enabled,
    required this.onVote,
  });

  final PubgetEvent event;
  final EventProvider provider;
  final String? myOptionId;
  final bool enabled;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final source = event.result?.votes ?? event.tally.votes;
    final counts = <String, int>{
      for (final option in event.configuration.options)
        option.id: source[option.id] ?? 0,
    };
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    final percentages = _percentages(counts);
    final best = counts.values.isEmpty
        ? 0
        : counts.values.reduce((a, b) => a > b ? a : b);
    final locked = provider.hasSubmitted && !event.configuration.allowUpdate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (event.configuration.question.isNotEmpty) ...[
          Text(
            event.configuration.question,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (final option in event.configuration.options) ...[
          _PollOptionTile(
            option: option,
            count: counts[option.id] ?? 0,
            percent: percentages[option.id] ?? 0,
            yourVote: myOptionId == option.id,
            leading: best > 0 && counts[option.id] == best,
            enabled: enabled && !locked,
            onTap: () => onVote(option.id),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          total == 0 ? copy.eventNoVotesYet : copy.eventTotalVotes(total),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (locked && total > 0)
          Text(
            copy.eventResultLocked,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
      ],
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  const _PollOptionTile({
    required this.option,
    required this.count,
    required this.percent,
    required this.yourVote,
    required this.leading,
    required this.enabled,
    required this.onTap,
  });

  final EventOption option;
  final int count;
  final int percent;
  final bool yourVote;
  final bool leading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final theme = Theme.of(context);
    return PubgetCard(
      key: Key('poll-option-${option.id}'),
      onTap: enabled ? onTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (option.imageUrl.startsWith('https://')) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  child: AppImageLoader(
                    imageUrl: option.imageUrl,
                    width: 48,
                    height: 48,
                    memCacheWidth: 96,
                    memCacheHeight: 96,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  option.label,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (yourVote) ...[
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  copy.eventYourVote,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ] else if (leading) ...[
                Icon(
                  Icons.leaderboard_outlined,
                  size: 18,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  copy.eventLeading,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: percent / 100),
            duration: const Duration(milliseconds: 350),
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.xs),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  yourVote
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$percent% · $count ${copy.eventVotesCount}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- theory --

class _TheorySection extends StatelessWidget {
  const _TheorySection({
    required this.event,
    required this.provider,
    required this.stance,
    required this.enabled,
    required this.onStance,
  });

  final PubgetEvent event;
  final EventProvider provider;
  final String? stance;
  final bool enabled;
  final ValueChanged<String> onStance;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final stances = event.result?.stances ?? event.tally.stances;
    final agree = stances['agree'] ?? 0;
    final disagree = stances['disagree'] ?? 0;
    final anime = event.configuration.anime;
    final locked = provider.hasSubmitted && !event.configuration.allowUpdate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (event.description.isNotEmpty) Text(event.description),
        if (anime != null && anime.title.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _AnimeCard(anime: anime),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: _StanceButton(
                key: const Key('theory-agree'),
                label: copy.eventAgree,
                count: agree,
                selected: stance == 'agree',
                icon: Icons.thumb_up_alt_outlined,
                onTap: enabled && !locked ? () => onStance('agree') : null,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StanceButton(
                key: const Key('theory-disagree'),
                label: copy.eventDisagree,
                count: disagree,
                selected: stance == 'disagree',
                icon: Icons.thumb_down_alt_outlined,
                onTap: enabled && !locked ? () => onStance('disagree') : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StanceButton extends StatelessWidget {
  const _StanceButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final bool selected;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PubgetCard(
      highlighted: selected,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: theme.textTheme.titleSmall),
          const SizedBox(width: AppSpacing.xs),
          Text('$count', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AnimeCard extends StatelessWidget {
  const _AnimeCard({required this.anime});

  final EventAnimeLink anime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppStrings.of(context);
    return PubgetCard(
      child: Row(
        children: <Widget>[
          if (anime.imageUrl.startsWith('https://')) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.xs),
              child: AppImageLoader(
                imageUrl: anime.imageUrl,
                width: 56,
                height: 72,
                memCacheWidth: 112,
                memCacheHeight: 144,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  copy.pick('Attached anime', 'أنمي مرفق'),
                  style: theme.textTheme.labelSmall,
                ),
                Text(anime.title, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- reactions --

class _ReactionBar extends StatelessWidget {
  const _ReactionBar({required this.event, required this.provider});

  final PubgetEvent event;
  final EventProvider provider;

  @override
  Widget build(BuildContext context) {
    if (event.status == EventStatus.deleted ||
        event.status == EventStatus.draft) {
      return const SizedBox.shrink();
    }
    final copy = AppStrings.of(context);
    final likes = event.reactionCounts['like'] ?? 0;
    final dislikes = event.reactionCounts['dislike'] ?? 0;
    final myReaction = provider.myReaction;
    final enabled = event.isInteractable() && !provider.submitting;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        _ReactionButton(
          key: const Key('event-react-like'),
          icon: myReaction == 'like'
              ? Icons.thumb_up_alt
              : Icons.thumb_up_alt_outlined,
          label: copy.eventLike,
          count: likes,
          active: myReaction == 'like',
          onTap: enabled ? () => _react(context, 'like') : null,
        ),
        _ReactionButton(
          key: const Key('event-react-dislike'),
          icon: myReaction == 'dislike'
              ? Icons.thumb_down_alt
              : Icons.thumb_down_alt_outlined,
          label: copy.eventDislike,
          count: dislikes,
          active: myReaction == 'dislike',
          onTap: enabled ? () => _react(context, 'dislike') : null,
        ),
        _ReactionButton(
          icon: Icons.mode_comment_outlined,
          label: copy.eventComments,
          count: provider.comments.length,
          active: false,
          onTap: null,
        ),
        _ReactionButton(
          icon: Icons.ios_share,
          label: copy.eventShare,
          active: false,
          onTap: () {
            provider.share(event.id);
            EventLinks.share(context, event.id, title: event.title);
          },
        ),
      ],
    );
  }

  Future<void> _react(BuildContext context, String reaction) async {
    final result = await provider.react(event.id, reaction);
    if (!context.mounted) return;
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _failureText(AppStrings.of(context), result.failureOrNull),
          ),
        ),
      );
    }
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? theme.colorScheme.primary : null;
    return PubgetTextButton(
      onPressed: onTap,
      semanticLabel: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            count == null ? label : '$label $count',
            style: theme.textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- participation --

class _Participation extends StatelessWidget {
  const _Participation({required this.event, required this.provider});

  final PubgetEvent event;
  final EventProvider provider;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final canSubmit = event.isInteractable() && !provider.submitting;
    return Row(
      children: <Widget>[
        PubgetPrimaryButton(
          onPressed: canSubmit
              ? () => _run(context, copy, () => provider.join(event.id))
              : null,
          semanticLabel: copy.eventJoinCta,
          child: Text(copy.eventJoinCta),
        ),
        const SizedBox(width: AppSpacing.sm),
        PubgetTextButton(
          onPressed: canSubmit
              ? () => _run(context, copy, () => provider.leave(event.id))
              : null,
          semanticLabel: copy.eventLeaveCta,
          child: Text(copy.eventLeaveCta),
        ),
      ],
    );
  }
}

class _ResponseForm extends StatefulWidget {
  const _ResponseForm({
    required this.event,
    required this.provider,
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
  final EventProvider provider;
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
  State<_ResponseForm> createState() => _ResponseFormState();
}

class _ResponseFormState extends State<_ResponseForm> {
  Future<void> _submit() async {
    final copy = AppStrings.of(context);
    final event = widget.event;
    final spec = EventTypeRegistry.of(event.type);
    Map<String, dynamic> data;
    if (spec.usesRanking) {
      if (widget.rankedIds.length != event.configuration.options.length) {
        return;
      }
      data = <String, dynamic>{'rankedIds': widget.rankedIds};
    } else if (spec.usesQuiz) {
      if (widget.quizAnswers.isEmpty) return;
      data = <String, dynamic>{'answers': widget.quizAnswers};
    } else if (spec.usesTextResponse) {
      data = <String, dynamic>{
        if (widget.text.text.trim().isNotEmpty) 'text': widget.text.text.trim(),
      };
    } else if (event.configuration.maxSelections > 1 ||
        event.configuration.allowMultiple) {
      if (widget.selectedIds.isEmpty) return;
      data = <String, dynamic>{'optionIds': widget.selectedIds.toList()};
    } else {
      if (widget.selectedOptionId == null) return;
      data = <String, dynamic>{'optionId': widget.selectedOptionId};
    }
    final result = await widget.provider.submit(
      eventId: event.id,
      responseData: data,
    );
    if (!mounted) return;
    if (result is FailureResult) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_failureText(copy, result.failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final spec = EventTypeRegistry.of(event.type);
    final copy = AppStrings.of(context);
    final provider = widget.provider;
    if (provider.hasSubmitted && !event.configuration.allowUpdate) {
      return PubgetEmptyState(
        title: copy.eventAlreadyParticipated,
        message: copy.eventJoinToParticipate,
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
          Text(copy.eventRankOptionsHint),
          const SizedBox(height: AppSpacing.sm),
          ReorderableListView.builder(
            key: const Key('event-ranking-options'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: event.configuration.options.length,
            onReorder: (oldIndex, newIndex) {
              final next = <String>[
                for (final option in event.configuration.options)
                  if (widget.rankedIds.contains(option.id)) option.id,
                for (final option in event.configuration.options)
                  if (!widget.rankedIds.contains(option.id)) option.id,
              ];
              if (newIndex > oldIndex) newIndex -= 1;
              next.insert(newIndex, next.removeAt(oldIndex));
              widget.onRankReorder(next);
            },
            itemBuilder: (context, index) {
              final id = widget.rankedIds.isEmpty
                  ? event.configuration.options[index].id
                  : widget.rankedIds[index];
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
            onPressed: widget.onResetRank,
            semanticLabel: copy.eventResetRanking,
            child: Text(copy.eventResetRanking),
          ),
        ] else if (spec.usesOptions && multi)
          ...event.configuration.options.map(
            (option) => CheckboxListTile(
              title: Text(option.label),
              value: widget.selectedIds.contains(option.id),
              onChanged: (value) =>
                  widget.onToggle(option.id, value ?? false),
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
              groupValue: widget.selectedOptionId,
              onChanged: (value) {
                if (value != null) widget.onSelect(value);
              },
            ),
          ),
        if (spec.usesTextResponse && !spec.usesQuiz)
          PubgetTextArea(
            controller: widget.text,
            label: event.configuration.prompt.isEmpty
                ? copy.eventYourResponse
                : event.configuration.prompt,
          ),
        if (spec.usesQuiz)
          ...event.configuration.questions.map(
            (question) => _QuizQuestionTile(
              question: question,
              selectedId: widget.quizAnswers[question.id],
              onSelect: (optionId) =>
                  widget.onQuizAnswer(question.id, optionId),
              onExpire: () {
                if (widget.quizAnswers.containsKey(question.id)) {
                  widget.onQuizAnswer(question.id, '');
                }
              },
            ),
          ),
        PubgetPrimaryButton(
          loading: provider.submitting,
          onPressed: provider.submitting ? null : _submit,
          semanticLabel: copy.eventSubmitCta,
          child: Text(copy.eventSubmitCta),
        ),
      ],
    );
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
    final copy = AppStrings.of(context);
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
                  _expired ? copy.eventTimeUp : '$minutes:$seconds',
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
                copy.eventQuestionLocked,
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

// ---------------------------------------------------------------- results --

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.event});

  final PubgetEvent event;

  @override
  Widget build(BuildContext context) {
    final result = event.result!;
    final copy = AppStrings.of(context);
    final labels = <String, String>{
      for (final option in event.configuration.options) option.id: option.label,
    };
    final isTheory = event.type == EventType.theory;
    if (isTheory) {
      final agree = result.stances['agree'] ?? 0;
      final disagree = result.stances['disagree'] ?? 0;
      return PubgetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              copy.eventResultTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${copy.eventAgree}: $agree'),
            Text('${copy.eventDisagree}: $disagree'),
          ],
        ),
      );
    }
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.eventResultTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('${copy.eventSubmissions}: ${result.submissions}'),
          if (event.type == EventType.quiz &&
              result.leaderboard.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              copy.eventLeaderboard,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final entry
                in result.leaderboard.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
              Text('${entry.key}: ${entry.value} ${copy.eventPoints}'),
          ],
          if (event.type == EventType.prediction &&
              result.winnerOptionId != null)
            Text(
              '${copy.eventWinner}: ${labels[result.winnerOptionId] ?? result.winnerOptionId}',
            ),
          if (result.winnerIds.isNotEmpty && event.type != EventType.prediction)
            Text(
              '${copy.eventWinner}: ${result.winnerIds.map((id) => labels[id] ?? id).join(', ')}',
            ),
          ...result.votes.entries.map(
            (entry) => Text('${labels[entry.key] ?? entry.key}: ${entry.value}'),
          ),
          if (event.type == EventType.ranking &&
              result.orderedOptionIds.isNotEmpty)
            for (final entry in result.orderedOptionIds.indexed)
              Text(
                '${entry.$1 + 1}. ${labels[entry.$2] ?? entry.$2}: '
                '${result.scores[entry.$2] ?? 0} ${copy.eventPoints}',
              )
          else
            ...result.scores.entries.map(
              (entry) => Text(
                '${labels[entry.key] ?? entry.key}: ${entry.value} ${copy.eventPoints}',
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- manage --

class _ManageActions extends StatelessWidget {
  const _ManageActions({required this.event, required this.provider});

  final PubgetEvent event;
  final EventProvider provider;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final uid = context.watch<AuthProvider>().currentUser?.id;
    final canManage =
        context.watch<GroupProvider>().canManageEvents || event.creatorId == uid;
    if (!canManage) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          if (event.status == EventStatus.active)
            PubgetSecondaryButton(
              onPressed: () => offerEventCrosspost(
                context,
                event,
                onMessage: (message) {
                  if (!context.mounted || message.isEmpty) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                },
              ),
              semanticLabel: copy.eventShareMore,
              child: Text(copy.eventShareMore),
            ),
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
              semanticLabel: copy.eventResolveResult,
              child: Text(copy.eventResolveResult),
            ),
          if (event.status == EventStatus.active ||
              event.status == EventStatus.ended)
            PubgetSecondaryButton(
              onPressed: () => _openAnalytics(context),
              semanticLabel: copy.eventAnalyticsTitle,
              child: Text(copy.eventAnalyticsTitle),
            ),
          if (event.status == EventStatus.active)
            PubgetSecondaryButton(
              onPressed: () => _confirmAndRun(
                context,
                title: copy.eventEndConfirmTitle,
                message: copy.eventEndConfirmMessage,
                acceptLabel: copy.eventEndCta,
                action: () => provider.end(event.id),
              ),
              semanticLabel: copy.eventEndCta,
              child: Text(copy.eventEndCta),
            ),
          if (event.status == EventStatus.ended)
            PubgetSecondaryButton(
              onPressed: () => _confirmAndRun(
                context,
                title: copy.eventArchiveConfirmTitle,
                message: copy.eventArchiveConfirmMessage,
                acceptLabel: copy.eventArchiveCta,
                action: () => provider.archive(event.id),
              ),
              semanticLabel: copy.eventArchiveCta,
              child: Text(copy.eventArchiveCta),
            ),
          if (event.status != EventStatus.archived &&
              event.status != EventStatus.deleted)
            PubgetTextButton(
              onPressed: () => _confirmAndRun(
                context,
                title: copy.eventCancelConfirmTitle,
                message: copy.eventCancelConfirmMessage,
                acceptLabel: copy.eventCancelCta,
                action: () => provider.cancel(event.id),
              ),
              semanticLabel: copy.eventCancelCta,
              child: Text(copy.eventCancelCta),
            ),
        ],
      ),
    );
  }

  Future<void> _openAnalytics(BuildContext context) async {
    final copy = AppStrings.of(context);
    final result = await provider.openAnalytics(event.id);
    if (!context.mounted) return;
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _failureText(copy, result.failureOrNull) ,
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
  }

  Future<void> _confirmAndRun(
    BuildContext context, {
    required String title,
    required String message,
    required String acceptLabel,
    required Future<Result<void>> Function() action,
  }) async {
    final copy = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('event-manage-confirm'),
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(copy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(acceptLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await action();
    if (!context.mounted) return;
    if (result is FailureResult) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_failureText(copy, result.failure))),
      );
    }
  }
}

class _CommentsSection extends StatefulWidget {
  const _CommentsSection({required this.event, required this.text});

  final PubgetEvent event;
  final TextEditingController text;

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    if (event.status == EventStatus.deleted ||
        event.status == EventStatus.draft) {
      return const SizedBox.shrink();
    }
    final copy = AppStrings.of(context);
    final provider = context.watch<EventProvider>();
    final comments = provider.comments;
    final readable = event.status != EventStatus.archived;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          copy.eventCommentsCount(comments.length),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (comments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(copy.eventNoComments),
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
        if (readable) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: widget.text,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: copy.eventCommentHint,
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PubgetPrimaryButton(
                loading: provider.submitting,
                onPressed:
                    (provider.submitting || widget.text.text.trim().isEmpty)
                    ? null
                    : () async {
                        final message = widget.text.text.trim();
                        widget.text.clear();
                        final result = await provider.addComment(
                          event.id,
                          message,
                        );
                        if (!context.mounted) return;
                        if (!result.isSuccess) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _failureText(
                                  AppStrings.of(context),
                                  result.failureOrNull,
                                ),
                              ),
                            ),
                          );
                        } else {
                          setState(() {});
                        }
                      },
                semanticLabel: copy.eventPost,
                child: Text(copy.eventPost),
              ),
            ],
          ),
        ],
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

  @override
  void initState() {
    super.initState();
    if (widget.event.type == EventType.challenge) {
      _loadParticipants();
    }
  }

  Future<void> _loadParticipants() async {
    setState(() => _loading = true);
    final provider = context.read<EventProvider>();
    final result = await provider.openAnalytics(widget.event.id);
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
    final copy = AppStrings.of(context);
    final isPrediction = widget.event.type == EventType.prediction;
    return AlertDialog(
      title: Text(
        isPrediction ? copy.eventSelectWinner : copy.eventSelectWinners,
      ),
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
                      Text(copy.eventNoChallengeResponses)
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
          semanticLabel: copy.cancel,
          child: Text(copy.cancel),
        ),
        PubgetPrimaryButton(
          onPressed: () => _resolve(context),
          semanticLabel: copy.eventLockResult,
          child: Text(copy.eventLockResult),
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
        SnackBar(
          content: Text(_failureText(AppStrings.of(context), result.failureOrNull)),
        ),
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
    final copy = AppStrings.of(context);
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
                copy.eventAnalyticsTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('${copy.eventSubmissions}: ${analytics?.tally.submissions ?? 0}'),
              Text(
                copy.eventActiveParticipants(
                  participants.where((item) => item.isActive).length,
                ),
              ),
              if (analytics?.tally.votes.isNotEmpty ?? false) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  copy.eventVotesLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final entry in analytics!.tally.votes.entries)
                  Text('${labels[entry.key] ?? entry.key}: ${entry.value}'),
              ],
              if (analytics?.tally.scores.isNotEmpty ?? false) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  copy.eventScoresLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final entry in analytics!.tally.scores.entries)
                  Text(
                    '${labels[entry.key] ?? entry.key}: ${entry.value} ${copy.eventPoints}',
                  ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                copy.eventResponsesCount(responses.length),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (responses.isEmpty)
                Text(copy.eventNoResponses)
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

// ----------------------------------------------------------------- helpers --

/// Largest-remainder rounding so integer percentages always add up to 100.
Map<String, int> _percentages(Map<String, int> counts) {
  final total = counts.values.fold<int>(0, (sum, value) => sum + value);
  final floors = <String, int>{for (final key in counts.keys) key: 0};
  if (total <= 0) return floors;
  final raw = <String, double>{};
  for (final entry in counts.entries) {
    raw[entry.key] = entry.value * 100 / total;
    floors[entry.key] = raw[entry.key]!.floor();
  }
  var remainder =
      100 - floors.values.fold<int>(0, (sum, value) => sum + value);
  final order = raw.keys.toList()
    ..sort((a, b) {
      final left = raw[a]! - floors[a]!;
      final right = raw[b]! - floors[b]!;
      return right.compareTo(left);
    });
  for (var index = 0; index < order.length && remainder > 0; index += 1) {
    floors[order[index]] = floors[order[index]]! + 1;
    remainder -= 1;
  }
  return floors;
}

String _failureText(AppStrings copy, Failure? failure) {
  if (failure == null) return '';
  if (failure is ValidationError) {
    return copy.eventValidationMessage(failure.message);
  }
  return failure.message;
}

Future<void> _run(
  BuildContext context,
  AppStrings copy,
  Future<Result<void>> Function() action,
) async {
  final result = await action();
  if (!context.mounted) return;
  if (result is FailureResult) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_failureText(copy, result.failure))),
    );
  }
}
