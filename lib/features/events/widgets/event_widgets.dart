import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/links/pubget_links.dart';
import '../models/event_models.dart';

abstract final class EventLinks {
  static const host = PubgetLinks.host;

  static String path(String eventId) => PubgetLinks.eventPath(eventId);

  static String canonical(String eventId) => PubgetLinks.event(eventId);

  static Future<void> copy(BuildContext context, String eventId) async {
    final copy = AppStrings.of(context);
    await PubgetLinks.copy(
      context,
      canonical(eventId),
      type: 'event',
      message: copy.eventLinkCopied,
    );
  }

  static Future<void> share(
    BuildContext context,
    String eventId, {
    String? title,
  }) => PubgetLinks.share(
    context,
    url: canonical(eventId),
    title: title ?? AppStrings.of(context).eventShare,
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
        final copy = AppStrings.of(context);
        final now = snapshot.data ?? DateTime.now();
        final remaining = event.remaining(now);
        if (event.status != EventStatus.active || remaining == null) {
          return Text(copy.eventTypeLabel(event.type.name));
        }
        final hours = remaining.inHours;
        final minutes = remaining.inMinutes.remainder(60);
        final seconds = remaining.inSeconds.remainder(60);
        final clock =
            '${hours.toString().padLeft(2, '0')}:'
            '${minutes.toString().padLeft(2, '0')}:'
            '${seconds.toString().padLeft(2, '0')}';
        return Text(
          copy.pick('$clock left', '$clock متبقٍ'),
          semanticsLabel: copy.pick('Time remaining', 'الوقت المتبقي'),
        );
      },
    );
  }
}
