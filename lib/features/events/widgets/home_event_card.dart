import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/event_models.dart';
import 'event_widgets.dart';

class HomeEventCard extends StatelessWidget {
  const HomeEventCard({required this.event, super.key});

  final PubgetEvent event;

  static Color badgeColor(EventType type) => switch (type) {
    EventType.poll || EventType.multipleChoice => const Color(0xFF6BA6E8),
    EventType.ranking => const Color(0xFF3FAE6A),
    EventType.versus => const Color(0xFFE26A3A),
    EventType.theory => AppColors.royalPurpleLight,
    EventType.prediction => AppColors.gold,
    EventType.quiz => const Color(0xFF2EB3B0),
    EventType.imageComparison => const Color(0xFFE37AA8),
    EventType.characterComparison => const Color(0xFFB44C7A),
    EventType.animeComparison => const Color(0xFF5A2F8A),
    EventType.openDiscussion => const Color(0xFF8EA0B5),
    EventType.challenge => const Color(0xFFC4621A),
  };

  static IconData badgeIcon(EventType type) => switch (type) {
    EventType.poll || EventType.multipleChoice => Icons.poll_outlined,
    EventType.ranking => Icons.format_list_numbered,
    EventType.versus => Icons.sports_kabaddi_outlined,
    EventType.theory => Icons.auto_stories_outlined,
    EventType.prediction => Icons.insights_outlined,
    EventType.quiz => Icons.quiz_outlined,
    EventType.imageComparison => Icons.photo_library_outlined,
    EventType.characterComparison => Icons.face_outlined,
    EventType.animeComparison => Icons.movie_outlined,
    EventType.openDiscussion => Icons.forum_outlined,
    EventType.challenge => Icons.flag_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final theme = Theme.of(context);
    final ended = event.isHistorical || event.isExpired();
    final recentEnd = ended &&
        event.endAt != null &&
        DateTime.now().difference(event.endAt!) <= const Duration(hours: 24);
    return Opacity(
      opacity: recentEnd || ended ? 0.72 : 1,
      child: PubgetCard(
        onTap: () => EventLinks.open(context, event.id),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          height: 196,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _TypeBadge(type: event.type),
                  const Spacer(),
                  Icon(
                    Icons.groups_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      event.groupId == null || event.groupId!.isEmpty
                          ? copy.hostGroup
                          : copy.hostGroup,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _EventBody(event: event, reveal: ended)),
              const SizedBox(height: AppSpacing.sm),
              _EventFooter(event: event, ended: ended),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final EventType type;

  @override
  Widget build(BuildContext context) {
    final color = HomeEventCard.badgeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(HomeEventCard.badgeIcon(type), size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            AppStrings.of(context).eventTypeLabel(type.name),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventBody extends StatelessWidget {
  const _EventBody({required this.event, required this.reveal});

  final PubgetEvent event;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final options = event.configuration.options;
    final votes = event.tally.votes;
    final total = votes.values.fold<int>(0, (sum, value) => sum + value);
    return switch (event.type) {
      EventType.poll || EventType.multipleChoice => _OptionBars(
        options: options.take(4).toList(growable: false),
        votes: votes,
        total: total,
        reveal: reveal,
      ),
      EventType.ranking => _RankingBody(options: options.take(3).toList()),
      EventType.versus ||
      EventType.imageComparison ||
      EventType.characterComparison ||
      EventType.animeComparison => _VersusBody(
        options: options.take(2).toList(growable: false),
        votes: votes,
        total: total,
        reveal: reveal,
        subtitleKind: event.type,
      ),
      EventType.theory => Text(
        [
          event.configuration.prompt.isNotEmpty
              ? event.configuration.prompt
              : event.description,
          if (event.responsesCount > 1)
            copy.moreTheories(event.responsesCount - 1),
        ].where((line) => line.trim().isNotEmpty).join('\n'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      EventType.prediction => _PredictionBody(
        question: event.configuration.question.isNotEmpty
            ? event.configuration.question
            : event.title,
        options: options,
        votes: votes,
        reveal: reveal,
      ),
      EventType.quiz => Text(
        copy.quizMeta(
          event.configuration.questions.length,
          (event.configuration.questions.length * 0.4).ceil().clamp(1, 12),
        ),
        maxLines: 2,
      ),
      EventType.openDiscussion => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            event.configuration.question.isNotEmpty
                ? event.configuration.question
                : event.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            copy.membersCount(event.participantsCount),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      EventType.challenge => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            event.description.isNotEmpty
                ? event.description
                : event.configuration.prompt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            event.configuration.challengeKind == 'self'
                ? copy.selfReport
                : copy.verifiedAuto,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    };
  }
}

class _OptionBars extends StatelessWidget {
  const _OptionBars({
    required this.options,
    required this.votes,
    required this.total,
    required this.reveal,
  });

  final List<EventOption> options;
  final Map<String, int> votes;
  final int total;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Text(
        AppStrings.of(context).nothingHereYet,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Column(
      children: <Widget>[
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _Bar(
              label: option.label,
              value: reveal && total > 0
                  ? (votes[option.id] ?? 0) / total
                  : 0,
            ),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: <Widget>[
          LinearProgressIndicator(
            minHeight: 18,
            value: value.clamp(0, 1),
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.7),
            color: AppColors.royalPurpleLight,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingBody extends StatelessWidget {
  const _RankingBody({required this.options});

  final List<EventOption> options;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: <Widget>[
                Text('${i + 1}.'),
                const SizedBox(width: 6),
                if (options[i].imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: AppImageLoader(
                        imageUrl: options[i].imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                if (options[i].imageUrl.isNotEmpty) const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    options[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _VersusBody extends StatelessWidget {
  const _VersusBody({
    required this.options,
    required this.votes,
    required this.total,
    required this.reveal,
    required this.subtitleKind,
  });

  final List<EventOption> options;
  final Map<String, int> votes;
  final int total;
  final bool reveal;
  final EventType subtitleKind;

  @override
  Widget build(BuildContext context) {
    if (options.length < 2) {
      return _OptionBars(
        options: options,
        votes: votes,
        total: total,
        reveal: reveal,
      );
    }
    return Row(
      children: <Widget>[
        Expanded(child: _side(context, options[0])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            'VS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(child: _side(context, options[1])),
      ],
    );
  }

  Widget _side(BuildContext context, EventOption option) {
    final share = reveal && total > 0 ? (votes[option.id] ?? 0) / total : 0.0;
    final subtitle = switch (subtitleKind) {
      EventType.characterComparison => option.animeId,
      _ => '',
    };
    return Column(
      children: <Widget>[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: option.imageUrl.isEmpty
                ? ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(child: Icon(Icons.image_outlined)),
                  )
                : AppImageLoader(imageUrl: option.imageUrl, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          option.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        LinearProgressIndicator(
          minHeight: 4,
          value: share.clamp(0, 1),
          color: HomeEventCard.badgeColor(subtitleKind),
        ),
      ],
    );
  }
}

class _PredictionBody extends StatelessWidget {
  const _PredictionBody({
    required this.question,
    required this.options,
    required this.votes,
    required this.reveal,
  });

  final String question;
  final List<EventOption> options;
  final Map<String, int> votes;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    final yes = options.isNotEmpty ? (votes[options.first.id] ?? 0) : 0;
    final no = options.length > 1 ? (votes[options[1].id] ?? 0) : 0;
    final total = yes + no;
    final yesShare = reveal && total > 0 ? yes / total : 0.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(question, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: ((yesShare * 100).round()).clamp(1, 99),
                child: Container(height: 8, color: AppColors.gold),
              ),
              Expanded(
                flex: (100 - (yesShare * 100).round()).clamp(1, 99),
                child: Container(height: 8, color: AppColors.royalPurple),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventFooter extends StatelessWidget {
  const _EventFooter({required this.event, required this.ended});

  final PubgetEvent event;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final action = _actionLabel(copy);
    return Row(
      children: <Widget>[
        const Icon(Icons.people_outline, size: 14),
        const SizedBox(width: 4),
        Text('${event.participantsCount}'),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: ended
              ? Text(copy.eventEnded, maxLines: 1)
              : EventCountdown(event: event),
        ),
        TextButton(
          onPressed: () => EventLinks.open(context, event.id),
          child: Text(action),
        ),
      ],
    );
  }

  String _actionLabel(AppStrings copy) {
    if (ended) return copy.seeResult;
    return switch (event.type) {
      EventType.poll || EventType.multipleChoice => copy.vote,
      EventType.ranking => copy.rankChoices,
      EventType.versus ||
      EventType.imageComparison ||
      EventType.characterComparison ||
      EventType.animeComparison => copy.vote,
      EventType.theory => copy.addTheory,
      EventType.prediction => copy.predictNow,
      EventType.quiz => copy.startQuiz,
      EventType.openDiscussion => copy.shareOpinion,
      EventType.challenge => copy.joinChallenge,
    };
  }
}

class HomeEventsSection extends StatelessWidget {
  const HomeEventsSection({required this.events, super.key});

  final List<PubgetEvent> events;

  static List<PubgetEvent> pickHome(List<PubgetEvent> input, DateTime now) {
    final ranked = [...input]..sort((a, b) {
      int rank(PubgetEvent event) {
        if (event.status == EventStatus.active && !event.isExpired(now)) {
          return 0;
        }
        if (event.status == EventStatus.scheduled) return 1;
        return 2;
      }

      final byStatus = rank(a).compareTo(rank(b));
      if (byStatus != 0) return byStatus;
      final byPeople = b.participantsCount.compareTo(a.participantsCount);
      if (byPeople != 0) return byPeople;
      final aLeft = a.remaining(now)?.inSeconds ?? 1 << 30;
      final bLeft = b.remaining(now)?.inSeconds ?? 1 << 30;
      return aLeft.compareTo(bLeft);
    });
    return ranked.take(2).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PubgetSectionHeader(
            title: copy.sectionEvents,
            icon: Icons.celebration_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: <Widget>[
                for (final event in events) ...[
                  HomeEventCard(event: event),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Align(
                  alignment: AlignmentDirectional.center,
                  child: TextButton(
                    key: const Key('home-events-more'),
                    onPressed: () => AppNavigation.go(context, '/events'),
                    child: Text(
                      copy.seeMore,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
