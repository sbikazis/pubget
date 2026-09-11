import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../models/event_models.dart';
import '../models/event_type_registry.dart';
import '../providers/event_providers.dart';
import '../widgets/event_widgets.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({this.groupId, super.key});

  final String? groupId;

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  String _query = '';
  EventType? _typeFilter;

  List<PubgetEvent> _filter(List<PubgetEvent> events) {
    final query = _query.trim().toLowerCase();
    return events
        .where((event) {
          final matchesQuery =
              query.isEmpty ||
              event.title.toLowerCase().contains(query) ||
              event.description.toLowerCase().contains(query);
          final matchesType = _typeFilter == null || event.type == _typeFilter;
          return matchesQuery && matchesType;
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    final list = context.read<EventListProvider>();
    final uid = context.read<AuthProvider>().currentUser?.id;
    Future<void>.microtask(() async {
      if (widget.groupId != null) {
        await list.loadGroup(widget.groupId!);
      } else {
        await list.loadHome();
      }
      if (uid != null) await list.loadMine(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = context.watch<EventListProvider>();
    final groupId = widget.groupId;
    return DefaultTabController(
      length: groupId == null ? 4 : 1,
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton.maybeOf(context),
          title: Text(groupId == null ? 'Events' : 'Group events'),
          bottom: groupId == null
              ? const TabBar(
                  isScrollable: true,
                  tabs: <Widget>[
                    Tab(text: 'Active'),
                    Tab(text: 'Upcoming'),
                    Tab(text: 'Recent'),
                    Tab(text: 'Mine'),
                  ],
                )
              : null,
        ),
        floatingActionButton:
            groupId == null ||
                context.watch<GroupProvider>().canCreateEvents != true
            ? null
            : FloatingActionButton.extended(
                onPressed: () => AppNavigation.go(
                  context,
                  '/events/create?groupId=${Uri.encodeComponent(groupId)}',
                ),
                label: const Text(EventStrings.create),
                icon: const Icon(Icons.add),
              ),
        body: PubgetLoadingStateView(
          state: list.state,
          onRetry: () => widget.groupId == null
              ? list.loadHome()
              : list.loadGroup(widget.groupId!),
          empty: PubgetEmptyState(
            title: EventStrings.noEventsTitle,
            message: EventStrings.noEventsMessage,
            icon: Icons.celebration_outlined,
            action:
                groupId != null &&
                    context.watch<GroupProvider>().canCreateEvents == true
                ? PubgetPrimaryButton(
                    onPressed: () => AppNavigation.go(
                      context,
                      '/events/create?groupId=${Uri.encodeComponent(groupId)}',
                    ),
                    semanticLabel: EventStrings.create,
                    child: const Text(EventStrings.create),
                  )
                : null,
          ),
          error: PubgetErrorState(
            message: list.failure?.message ?? 'Events could not load.',
            onRetry: () => widget.groupId == null
                ? list.loadHome()
                : list.loadGroup(widget.groupId!),
          ),
          offline: PubgetOfflineState(
            onRetry: () => widget.groupId == null
                ? list.loadHome()
                : list.loadGroup(widget.groupId!),
          ),
          child: Column(
            children: <Widget>[
              if (groupId == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search Events',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      DropdownButton<EventType?>(
                        value: _typeFilter,
                        hint: const Text('Type'),
                        items: <DropdownMenuItem<EventType?>>[
                          const DropdownMenuItem<EventType?>(
                            value: null,
                            child: Text('All'),
                          ),
                          ...EventType.values.map(
                            (type) => DropdownMenuItem<EventType?>(
                              value: type,
                              child: Text(EventTypeRegistry.of(type).label),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _typeFilter = value),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: groupId == null
                    ? TabBarView(
                        children: <Widget>[
                          _EventTiles(events: _filter(list.active)),
                          _EventTiles(events: _filter(list.upcoming)),
                          _EventTiles(events: _filter(list.recent)),
                          _EventTiles(events: _filter(list.mine)),
                        ],
                      )
                    : _EventTiles(events: _filter(list.groupEvents)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventTiles extends StatelessWidget {
  const _EventTiles({required this.events});

  final List<PubgetEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const PubgetEmptyState(
        title: EventStrings.noEventsTitle,
        message: EventStrings.noEventsMessage,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final event = events[index];
        return PubgetCard(
          key: ValueKey<String>('event-${event.id}'),
          onTap: () => EventLinks.open(context, event.id),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(event.title),
            subtitle: Text(
              '${EventTypeRegistry.of(event.type).label} · ${event.status.name}',
            ),
            trailing: EventCountdown(event: event),
          ),
        );
      },
    );
  }
}
