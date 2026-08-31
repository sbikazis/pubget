// lib/features/groups/events/mafia_lobby_screen.dart
//
// شاشة مستقلة لمرحلتي waiting/starting فقط. بمجرد ما تتغيّر الحالة
// لأي مرحلة أخرى (تم توزيع الأدوار وبدأ الليل)، تنقل تلقائياً
// (pushReplacement) إلى MafiaGameScreen. هذا يجعلها نقطة الدخول
// الوحيدة بعد إنشاء/الانضمام للعبة أو العودة لها لاحقاً — بغض النظر
// عن المرحلة الفعلية وقت الدخول.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../widgets/mafia/mafia_waiting_room.dart';
import '../../../core/constants/mafia_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/mafia_game_provider.dart';
import '../../../providers/user_provider.dart';
import 'mafia_game_screen.dart';

class MafiaLobbyScreen extends StatefulWidget {
  final String gameId;

  const MafiaLobbyScreen({super.key, required this.gameId});

  @override
  State<MafiaLobbyScreen> createState() => _MafiaLobbyScreenState();
}

class _MafiaLobbyScreenState extends State<MafiaLobbyScreen> {
  MafiaGameProvider? _provider;
  bool _forwarded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<MafiaGameProvider>();
    if (_provider != provider) {
      _provider = provider;
      provider.subscribeToGame(gameId: widget.gameId);
    }
  }

  void _maybeForward(MafiaGameStatus status) {
    if (_forwarded) return;
    if (status == MafiaGameStatus.waiting || status == MafiaGameStatus.starting) return;
    if (status == MafiaGameStatus.cancelled) return; // يُعرض إلغاء صريح بدل الانتقال

    _forwarded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MafiaGameScreen(gameId: widget.gameId)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<UserProvider>().currentUser?.id ?? '';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<MafiaGameProvider>(
      builder: (context, provider, child) {
        final game = provider.currentGame;
        final players = provider.players;

        if (game == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (game.status == MafiaGameStatus.cancelled) {
          return Scaffold(
            backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            appBar: AppBar(title: const Text('لعبة المافيا')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cancel_rounded, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    const Text('تم إلغاء المباراة لعدم اكتمال عدد اللاعبين.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('العودة'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        _maybeForward(game.status);

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: AppBar(
            title: const Text('غرفة انتظار المافيا'),
            centerTitle: true,
            elevation: 0,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: MafiaWaitingRoom(
              game: game,
              players: players,
              currentUserId: currentUserId,
            ),
          ),
        );
      },
    );
  }
}