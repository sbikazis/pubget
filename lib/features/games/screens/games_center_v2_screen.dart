import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/result.dart';
import '../models/games_schema_v2.dart';
import '../providers/games_session_provider_v2.dart';
import '../repositories/games_repository_v2.dart';
import '../widgets/v2_game_theme.dart';
import 'game_create_v2_screen.dart';
import 'game_history_v2_screen.dart';

class GamesCenterV2Screen extends StatefulWidget {
  const GamesCenterV2Screen({
    required this.groupId,
    required this.userId,
    this.activeGames = const <GameSessionV2>[],
    super.key,
  });
  final String groupId;
  final String userId;
  final List<GameSessionV2> activeGames;

  @override
  State<GamesCenterV2Screen> createState() => _GamesCenterV2ScreenState();
}

class _GamesCenterV2ScreenState extends State<GamesCenterV2Screen> {
  late Future<Result<GameHistoryPage>> _history;

  @override
  void initState() {
    super.initState();
    _history = context.read<GamesRepositoryV2>().groupHistory(
      groupId: widget.groupId,
    );
  }

  void _reload() => setState(() {
    _history = context.read<GamesRepositoryV2>().groupHistory(
      groupId: widget.groupId,
    );
  });

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('مركز الألعاب'),
        actions: [
          IconButton(
            tooltip: 'القواعد',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.pushNamed(context, '/games/rules'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GameV2Palette.gold,
        foregroundColor: GameV2Palette.ink,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GamesCreateV2Screen(
              groupId: widget.groupId,
              userId: widget.userId,
            ),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('إنشاء لعبة'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            _HeroPanel(userId: widget.userId),
            const SizedBox(height: 24),
            Text('الألعاب المتاحة', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            if (widget.activeGames.isNotEmpty) ...[
              for (final game in widget.activeGames)
                _ActiveGameTile(game: game),
              const SizedBox(height: 8),
            ],
            for (final type in GameTypeV2.values) _GameTypeTile(type: type),
            const SizedBox(height: 18),
            Text('أرشيف المجموعة', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            FutureBuilder<Result<GameHistoryPage>>(
              future: _history,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const _LoadingPanel();
                }
                final page = snapshot.data!;
                if (!page.isSuccess) {
                  return _StatePanel(
                    title: 'تعذر تحميل الأرشيف',
                    message: page.failureOrNull?.message ?? 'حاول مرة أخرى',
                    action: _reload,
                  );
                }
                if (page.valueOrNull!.games.isEmpty) {
                  return const _StatePanel(
                    title: 'لا توجد مباريات بعد',
                    message: 'أول بطولة تبدأ من هنا.',
                  );
                }
                return Column(
                  children: [
                    for (final game in page.valueOrNull!.games)
                      _HistoryRow(game: game, userId: widget.userId),
                    if (page.valueOrNull!.hasMore)
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameHistoryV2Screen(
                              groupId: widget.groupId,
                              userId: widget.userId,
                            ),
                          ),
                        ),
                        child: const Text('عرض الأرشيف الكامل'),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActiveGameTile extends StatelessWidget {
  const _ActiveGameTile({required this.game});
  final GameSessionV2 game;
  @override
  Widget build(BuildContext context) => Card(
    color: GameV2Palette.purple.withValues(alpha: .10),
    child: ListTile(
       onTap: () => Navigator.pushNamed(
         context,
         game.status == GameLifecycleStatusV2.waiting
             ? '/games/waiting?gameId=${Uri.encodeComponent(game.id)}'
             : '/games/room?gameId=${Uri.encodeComponent(game.id)}',
       ),
      leading: const Icon(Icons.bolt, color: GameV2Palette.gold),
      title: Text(gameTypeArabic(game.type), style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${game.players.length} لاعبين · ${gameStatusArabic(game.status)}'),
      trailing: const Icon(Icons.chevron_left),
    ),
  );
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        colors: [Color(0xFF3B1C65), Color(0xFF71469F)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PUBGET / GAME LOUNGE', style: TextStyle(color: Color(0xFFD8A84E), letterSpacing: 2, fontSize: 11)),
        SizedBox(height: 12),
        Text('لحظة دخولك، تبدأ الجولة.', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
        SizedBox(height: 8),
        Text('ثلاث ألعاب. منافسة واحدة. اصنع ذكريات تستحق الإعادة.', style: TextStyle(color: Color(0xFFE5D8F2))),
      ],
    ),
  );
}

class _GameTypeTile extends StatelessWidget {
  const _GameTypeTile({required this.type});
  final GameTypeV2 type;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: GameV2Palette.purple.withValues(alpha: .12),
        child: Icon(switch (type) {
          GameTypeV2.guessCharacter => Icons.face_retouching_natural,
          GameTypeV2.animeChain => Icons.link,
          GameTypeV2.emojiAnimeGuess => Icons.auto_awesome,
        }, color: GameV2Palette.purple),
      ),
      title: Text(gameTypeArabic(type), style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(switch (type) {
        GameTypeV2.guessCharacter => 'أسئلة ذكية عن أبطال عالم الأنمي',
        GameTypeV2.animeChain => 'ابنِ السلسلة قبل أن ينتهي الوقت',
        GameTypeV2.emojiAnimeGuess => 'فكّر، خمّن، واضرب الإجابة',
      }),
      trailing: const Icon(Icons.chevron_left),
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.game, required this.userId});
  final GameSessionV2 game;
  final String userId;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: context.read<GamesSessionProviderV2>(),
            child: GameHistoryDetailV2Screen(gameId: game.id, userId: userId),
          ),
        ),
      ),
      title: Text(gameTypeArabic(game.type)),
      subtitle: Text('${game.players.length} لاعبين · ${gameStatusArabic(game.status)}'),
      trailing: Text('${game.players.fold<int>(0, (sum, p) => sum + p.score)} نقطة'),
    ),
  );
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();
  @override
  Widget build(BuildContext context) => const Card(child: Padding(
    padding: EdgeInsets.all(24),
    child: Center(child: CircularProgressIndicator()),
  ));
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({required this.title, required this.message, this.action});
  final String title;
  final String message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        if (action != null) TextButton(onPressed: action, child: const Text('إعادة المحاولة')),
      ]),
    ),
  );
}