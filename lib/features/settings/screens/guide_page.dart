import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';

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
    final needle = _query.text.trim().toLowerCase();
    final topics = GuideTopic.all.where((topic) {
      if (needle.isEmpty) return true;
      return topic.title.toLowerCase().contains(needle) ||
          topic.body.toLowerCase().contains(needle);
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Guide')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          PubgetSearchField(
            controller: _query,
            hint: 'Search the guide',
            onChanged: (_) => setState(() {}),
            onClear: () {
              _query.clear();
              setState(() {});
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          if (topics.isEmpty)
            PubgetEmptyState(
              title: 'No matching topics',
              message: 'Try a different word, like groups or Respect.',
              action: PubgetTextButton(
                onPressed: () {
                  _query.clear();
                  setState(() {});
                },
                semanticLabel: 'Clear guide search',
                child: const Text('Clear search'),
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
                      topic.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(topic.body),
                    if (topic.route != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Open ${topic.route}',
                        style: Theme.of(context).textTheme.labelLarge,
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

final class GuideTopic {
  const GuideTopic({
    required this.title,
    required this.body,
    this.route,
  });

  final String title;
  final String body;
  final String? route;

  static const all = <GuideTopic>[
    GuideTopic(
      title: 'Groups',
      body:
          'Groups are communities. Open a group to chat if you are a member, '
          'or read details first if you are not.',
      route: '/groups',
    ),
    GuideTopic(
      title: 'Chat',
      body:
          'Group chat supports text, media, replies, and delivery colors: '
          'red failed, yellow delivered, green read.',
    ),
    GuideTopic(
      title: 'Roles',
      body:
          'Roles are group-scoped. You can be Shogun in one group and a '
          'Member in another. Permissions stay explicit.',
    ),
    GuideTopic(
      title: 'Roleplay',
      body:
          'Roleplay identity is separate from your global username. Pubget '
          'never silently assigns a character — you choose.',
    ),
    GuideTopic(
      title: 'Games',
      body:
          'Games live in their own domain. Start them from a group, then play '
          'in a dedicated room. Chat shows activity cards, not the game state.',
      route: '/games',
    ),
    GuideTopic(
      title: 'Mafia',
      body:
          'Mafia is a private-role game. The server owns timers, roles, and '
          'results. Your client never receives another player’s secret role.',
      route: '/games',
    ),
    GuideTopic(
      title: 'Achievements',
      body:
          'Milestones unlock on the server when you create a group, publish, '
          'make a friend, or win. Rewards are granted once.',
      route: '/achievements',
    ),
    GuideTopic(
      title: 'Events',
      body:
          'Events are interactive posts such as polls, quizzes, and versus '
          'matchups. They close after at most seven days.',
      route: '/events',
    ),
    GuideTopic(
      title: 'Edits',
      body:
          'Edits are short videos, not a photo gallery. Views count only after '
          'real watch time — opening a page is not a view.',
      route: '/edits',
    ),
    GuideTopic(
      title: 'Respect and Fans',
      body:
          'Respect is social currency you give. Five or more Respect can become '
          'a Fan relationship. A Fan is not the same as a Friend.',
    ),
    GuideTopic(
      title: 'Friends',
      body:
          'Friend requests can be sent, accepted, rejected, cancelled, or '
          'removed. Blocking has real effects on messaging and discovery.',
      route: '/friend-requests',
    ),
    GuideTopic(
      title: 'Anime Hub',
      body:
          'Discover current, upcoming, trending, and seasonal anime. Save lists '
          'and favorites without leaking API details into the rest of the app.',
      route: '/anime',
    ),
    GuideTopic(
      title: 'Fan Works',
      body:
          'Share manga, drawings, stories, and worlds with creator attribution. '
          'Reports and copyright complaints go to moderation.',
      route: '/fan-works',
    ),
    GuideTopic(
      title: 'Coins and Store',
      body:
          'Coins come from meaningful participation, never spam. The Store is '
          'digital: cosmetics and extensions. Coins cannot remove ads.',
      route: '/store',
    ),
    GuideTopic(
      title: 'Premium',
      body:
          'Premium can add a badge, cosmetics, and extra limits. It is not '
          'pay-to-win, and the free app stays usable.',
      route: '/premium',
    ),
    GuideTopic(
      title: 'Privacy',
      body:
          'Profile, activity, and messaging visibility are real settings with '
          'server enforcement. Hidden profiles stay out of Search.',
      route: '/profile/edit',
    ),
    GuideTopic(
      title: 'Moderation',
      body:
          'Report content, mute or restrict in groups, and block users. '
          'Blocking is not just a hidden button.',
    ),
  ];
}
