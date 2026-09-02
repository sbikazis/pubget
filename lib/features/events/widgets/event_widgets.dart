import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/links/pubget_links.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../models/event_models.dart';
import '../models/event_type_registry.dart';
import '../providers/event_providers.dart';

abstract final class EventLinks {
  static const host = PubgetLinks.host;

  static String path(String eventId) => PubgetLinks.eventPath(eventId);

  static String canonical(String eventId) => PubgetLinks.event(eventId);

  static Future<void> copy(BuildContext context, String eventId) =>
      PubgetLinks.copy(
        context,
        canonical(eventId),
        type: 'event',
        message: EventStrings.copied,
      );

  static Future<void> share(
    BuildContext context,
    String eventId, {
    String? title,
  }) => PubgetLinks.share(
    context,
    url: canonical(eventId),
    title: title ?? EventStrings.share,
    type: 'event',
  );

  static void open(BuildContext context, String eventId) {
    AppNavigation.go(context, path(eventId));
  }
}

class EventCountdown extends StatelessWidget {
  const EventCountdown({required this.event, super.key});

  final PubgetEvent event;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final remaining = event.remaining(now);
        if (event.status != EventStatus.active || remaining == null) {
          return Text(EventTypeRegistry.of(event.type).label);
        }
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes.remainder(60);
        final seconds = remaining.inSeconds.remainder(60);
        return Text(
          '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} left',
          semanticsLabel: 'Time remaining',
        );
      },
    );
  }
}

class EventHomeStrip extends StatelessWidget {
  const EventHomeStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final list = context.watch<EventListProvider>();
    if (list.state == LoadingState.initial) {
      Future<void>.microtask(list.loadHome);
    }
    final events = <PubgetEvent>[...list.active, ...list.upcoming];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Events',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                PubgetTextButton(
                  onPressed: () => AppNavigation.go(context, '/events'),
                  semanticLabel: EventStrings.seeAll,
                  child: const Text(EventStrings.seeAll),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (list.state == LoadingState.loading && events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PubgetSkeleton.card(height: 120),
            )
          else if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PubgetEmptyState(
                title: EventStrings.noEventsTitle,
                message: EventStrings.noEventsMessage,
                action: PubgetSecondaryButton(
                  onPressed: () => AppNavigation.go(context, '/groups'),
                  semanticLabel: 'Discover groups',
                  child: const Text('Discover groups'),
                ),
              ),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                scrollDirection: Axis.horizontal,
                itemCount: events.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return SizedBox(
                    width: 220,
                    child: PubgetCard(
                      onTap: () => EventLinks.open(context, event.id),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          PubgetBadge(
                            label: EventTypeRegistry.of(event.type).label,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          EventCountdown(event: event),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
