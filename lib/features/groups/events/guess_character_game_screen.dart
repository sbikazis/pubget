// lib/features/groups/events/guess_character_game_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/game_model.dart';
import '../../../providers/game_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../core/constants/game_status.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_textfield.dart';

class GuessCharacterGameScreen extends StatefulWidget {
  final String groupId;
  final String gameId;

  const GuessCharacterGameScreen({
    Key? key,
    required this.groupId,
    required this.gameId,
  }) : super(key: key);

  @override
  State<GuessCharacterGameScreen> createState() =>
      _GuessCharacterGameScreenState();
}

class _GuessCharacterGameScreenState extends State<GuessCharacterGameScreen> {
  final TextEditingController _animeIdController = TextEditingController(); // تم التغيير لـ ID
  final TextEditingController _characterController = TextEditingController();
  final TextEditingController _guessController = TextEditingController();

  @override
  void dispose() {
    _animeIdController.dispose();
    _characterController.dispose();
    _guessController.dispose();
    super.dispose();
  }

  bool _isPlayer(GameModel game, String? userId) {
    if (userId == null) return false;
    return game.playerOneId == userId || game.playerTwoId == userId;
  }

  String? _myCharacter(GameModel game, String? userId) {
    if (userId == null) return null;
    if (game.playerOneId == userId) return game.playerOneCharacter;
    if (game.playerTwoId == userId) return game.playerTwoCharacter;
    return null;
  }

  bool _isMyTurn(GameModel game, String? userId) {
    if (userId == null) return false;
    return game.currentTurnUserId == userId;
  }

  // ✅ التعديل: تمرير animeId بدلاً من animeName
  Future<void> _setCharacter(
    BuildContext context,
    GameProvider provider,
    dynamic animeId,
    String characterName,
    String userId,
  ) async {
    try {
      await provider.setCharacter(
        groupId: widget.groupId,
        gameId: widget.gameId,
        userId: userId,
        animeId: animeId, // استخدام الـ ID الموثق
        characterName: characterName,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعيين الشخصية بنجاح')),
      );
      _characterController.clear();
      _animeIdController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تعيين الشخصية: ${e.toString()}')),
      );
    }
  }

  Future<void> _joinGame(
    BuildContext context,
    GameProvider provider,
    String userId,
  ) async {
    try {
      await provider.joinGame(
        groupId: widget.groupId,
        gameId: widget.gameId,
        userId: userId,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انضممت إلى اللعبة')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الانضمام: ${e.toString()}')),
      );
    }
  }

  Future<void> _guessCharacter(
    BuildContext context,
    GameProvider provider,
    String userId,
    String guess,
  ) async {
    try {
      await provider.guessCharacter(
        groupId: widget.groupId,
        gameId: widget.gameId,
        userId: userId,
        guessedCharacter: guess,
      );
      _guessController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التخمين: ${e.toString()}')),
      );
    }
  }

  Future<void> _cancelGame(
    BuildContext context,
    GameProvider provider,
  ) async {
    try {
      await provider.cancelGame(
        groupId: widget.groupId,
        gameId: widget.gameId,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إلغاء اللعبة: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('لعبة تخمين الشخصية'),
        centerTitle: true,
      ),
      body: StreamBuilder<GameModel?>(
        stream: gameProvider.streamGame(
          groupId: widget.groupId,
          gameId: widget.gameId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingWidget(message: 'جارٍ التحميل...'));
          }

          final game = snapshot.data;

          if (game == null) {
            return const Center(
              child: EmptyStateWidget(
                title: 'اللعبة غير موجودة',
                subtitle: 'ربما تم حذفها أو انتهت',
                icon: Icons.sports_esports,
              ),
            );
          }

          final amPlayer = _isPlayer(game, currentUserId);
          final myCharacter = _myCharacter(game, currentUserId);
          final myTurn = _isMyTurn(game, currentUserId);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game.status.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'المنشأ: ${game.playerOneId}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (game.playerTwoId != null)
                            Text(
                              'الخصم: ${game.playerTwoId}',
                              style: const TextStyle(fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                    if (game.status.isActive && game.winnerUserId == null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            myTurn ? 'دورك الآن' : 'دور الخصم',
                            style: TextStyle(
                              fontSize: 14,
                              color: myTurn ? Colors.green : Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'بدأت: ${game.createdAt.toLocal().toString().split('.').first}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                if (game.status == GameStatus.waiting) ...[
                  if (!amPlayer)
                    AppButton(
                      text: 'انضم إلى اللعبة',
                      onPressed: currentUserId == null
                          ? null
                          : () => _joinGame(context, gameProvider, currentUserId),
                    ),
                  const SizedBox(height: 12),
                  if (amPlayer && (myCharacter == null))
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          label: 'رقم الأنمي (MAL ID)',
                          placeholder: 'مثال: 20 لـ Naruto',
                          controller: _animeIdController,
                        ),
                        const SizedBox(height: 8),
                        AppTextField(
                          label: 'اسم الشخصية',
                          placeholder: 'اكتب اسم الشخصية بدقة',
                          controller: _characterController,
                        ),
                        const SizedBox(height: 8),
                        AppButton(
                          text: 'تعيين الشخصية',
                          onPressed: (currentUserId == null ||
                                     _characterController.text.trim().isEmpty ||
                                     _animeIdController.text.trim().isEmpty)
                              ? null
                              : () {
                                  final animeId = _animeIdController.text.trim();
                                  final characterName = _characterController.text.trim();
                                  _setCharacter(context, gameProvider, animeId, characterName, currentUserId);
                                },
                        ),
                      ],
                    ),
                ],

                if (game.status == GameStatus.active) ...[
                  const SizedBox(height: 8),
                  if (!amPlayer)
                    const Text('اللعبة جارية. فقط اللاعبان يمكنهما التخمين.'),
                  if (amPlayer) ...[
                    if (myCharacter == null)
                      const Text('انتظر حتى يتم تحديث بيانات شخصيتك...'),
                    if (myCharacter != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('شخصيتك المختارة: $myCharacter',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'تخمين شخصية الخصم',
                            placeholder: 'اكتب الاسم الذي تعتقده',
                            controller: _guessController,
                          ),
                          const SizedBox(height: 8),
                          AppButton(
                            text: 'إرسال التخمين',
                            onPressed: (!myTurn || _guessController.text.trim().isEmpty || currentUserId == null)
                                ? null
                                : () => _guessCharacter(context, gameProvider, currentUserId, _guessController.text.trim()),
                          ),
                        ],
                      ),
                  ],
                ],

                if (game.status == GameStatus.finished || game.status == GameStatus.cancelled) ...[
                  const SizedBox(height: 12),
                  if (game.status == GameStatus.finished)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.emoji_events, color: Colors.amber, size: 40),
                          const SizedBox(height: 8),
                          Text('الفائز: ${game.winnerUserId == currentUserId ? "أنت 🎉" : "الخصم"}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Divider(),
                          Text('شخصية P1: ${game.playerOneCharacter ?? "-"}'),
                          Text('شخصية P2: ${game.playerTwoCharacter ?? "-"}'),
                        ],
                      ),
                    )
                  else
                    const EmptyStateWidget(title: 'تم إلغاء اللعبة', icon: Icons.cancel, subtitle: ''),
                ],

                const Spacer(),

                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'إلغاء اللعبة',
                        onPressed: () => _cancelGame(context, gameProvider),
                        expand: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: 'تحديث الحالة',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تحديث البيانات'), duration: Duration(seconds: 1)),
                          );
                        },
                        expand: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (gameProvider.isLoading) const LoadingWidget(message: 'جارٍ المعالجة...'),
              ],
            ),
          );
        },
      ),
    );
  }
}