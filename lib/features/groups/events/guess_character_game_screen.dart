import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../../models/game_model.dart';
import '../../../providers/game_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../core/constants/game_status.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/utils/game_timer_manager.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_textfield.dart';

// الخدمة المسؤولة عن جلب بيانات الشخصيات من MAL
import '../../../services/api/anime_api_service.dart';

class GuessCharacterGameScreen extends StatefulWidget {
  final String groupId;
  final String gameId;
  // ✅ التعديل: أصبح اختيارياً لدعم المجموعات العامة
  final List<int>? animeIds;

  const GuessCharacterGameScreen({
    super.key,
    required this.groupId,
    required this.gameId,
    this.animeIds, // ✅ إزالة required
  });

  @override
  State<GuessCharacterGameScreen> createState() =>
      _GuessCharacterGameScreenState();
}

class _GuessCharacterGameScreenState extends State<GuessCharacterGameScreen> {
  final TextEditingController _searchController = TextEditingController();
 
  Map<String, String>? _selectedCharacter;
  bool _isSearching = false;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
  }

  // ⚠️ الجانب المنطقي القاتل: تنفيذ قاعدة الخسارة عند انتهاء الوقت
  void _handleTimeout(GameModel game) {
    if (!mounted) return;
    context.read<GameProvider>().processAutoJudge(widget.groupId, game);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      // ✅ التعديل: الـ API الآن سيتعامل مع animeIds سواء كانت قائمة أو null (بحث عالمي)
      final char = await AnimeApiService.getCharacterDetails(
        animeIds: widget.animeIds,
        characterName: query,
      );
     
      if (mounted) {
        setState(() {
          _selectedCharacter = char;
          _isSearching = false;
        });
        if (char == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("لم يتم العثور على الشخصية. يرجى التأكد من كتابة الاسم الإنجليزي تماماً كما في MAL."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _handleStart() async {
    if (_selectedCharacter == null) return;
   
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.currentUser?.id;

    if (userId == null) return;

    setState(() => _isConfirming = true);
    try {
      // 1. حفظ الشخصية في Firestore
      await gameProvider.setCharacter(
        groupId: widget.groupId,
        gameId: widget.gameId,
        userId: userId,
        animeIds: widget.animeIds ?? [], // نمرر قائمة فارغة للـ Firestore إذا كانت نول
        characterName: _selectedCharacter!['name']!,
      );

      // 2. إعلان الجاهزية
      await gameProvider.toggleReady(
        groupId: widget.groupId,
        gameId: widget.gameId,
        userId: userId,
      );
     
    } catch (e) {
      if (mounted) {
        setState(() => _isConfirming = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUserId = userProvider.currentUser?.id;

    return StreamBuilder<GameModel?>(
      stream: gameProvider.streamCurrentGame(widget.groupId, widget.gameId),
      builder: (context, snapshot) {
        // 1. حالة التحميل الأولي - لا نعمل pop هنا أبداً
        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final game = snapshot.data!;
       
        // 2. 🛡️ حماية: إذا انتهت اللعبة فعلاً، اخرج من الشاشة
        if (game.status.isOver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.canPop(context)) Navigator.pop(context);
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 🚀 الانتقال الآلي عند جاهزية الطرفين (بداية مرحلة التخمين)
        if (game.status == GameStatus.guessing && game.isPlayerOneReady && game.isPlayerTwoReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && Navigator.canPop(context)) Navigator.pop(context);
            });
          });
        }

        final bool isMeP1 = currentUserId == game.playerOneId;
        final bool iAmReady = isMeP1 ? game.isPlayerOneReady : game.isPlayerTwoReady;
        final bool opponentReady = isMeP1 ? game.isPlayerTwoReady : game.isPlayerOneReady;

        return Scaffold(
          appBar: AppBar(
            title: const Text("تجهيز الشخصية السرية"),
            automaticallyImplyLeading: false, // منع العودة اليدوية لحماية منطق اللعبة
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: StreamBuilder<int>(
                    stream: GameTimerManager.startSyncedCountdown(
                      game.setupStartedAt ?? game.createdAt,
                      GameConstants.characterSelectionDuration,
                    ),
                    builder: (context, timerSnapshot) {
                      final seconds = timerSnapshot.data ?? GameConstants.characterSelectionDuration;
                      
                      // إذا انتهى الوقت، نفذ التحكيم التلقائي
                      if (seconds <= 0 && game.status.isInSetup) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _handleTimeout(game);
                        });
                      }
                      
                      return Text(
                        "$seconds",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: seconds < 10 ? Colors.red : Colors.blue
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPlayerStatus("أنت", iAmReady),
                    const Icon(Icons.bolt, size: 40, color: Colors.grey),
                    _buildPlayerStatus("الخصم", opponentReady),
                  ],
                ),
                const Divider(height: 40),

                if (!iAmReady) ...[
                  const Text(
                    "اختر شخصيتك السرية:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "تنبيه: يجب كتابة اسم الشخصية بالإنجليزية تماماً كما في MAL لضمان التحقق.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _searchController,
                          label: "اسم الشخصية (مثال: Levi Ackerman)",
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        onPressed: _isSearching ? null : _onSearch,
                        icon: _isSearching
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.search),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_selectedCharacter != null) _buildSelectedCard(),
                ] else
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LoadingWidget(message: "تم حفظ الشخصية بنجاح.."),
                        SizedBox(height: 10),
                        Text("بانتظار أن ينهي الخصم اختياره لدخول عالم التخمين..",
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                const Spacer(),
               
                if (!iAmReady)
                  AppButton(
                    text: "بدأ اللعبة",
                    isLoading: _isConfirming,
                    onPressed: _selectedCharacter == null ? null : _handleStart,
                  ),
               
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => gameProvider.finishGame(
                    widget.groupId,
                    widget.gameId,
                    isCancelled: true,
                    reason: "انسحاب أحد اللاعبين أثناء التجهيز"
                  ),
                  child: const Text("انسحاب وإلغاء اللعبة", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlayerStatus(String label, bool ready) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Icon(ready ? Icons.check_circle : Icons.radio_button_unchecked,
             color: ready ? Colors.green : Colors.grey, size: 30),
        Text(ready ? "جاهز" : "يختار...", style: TextStyle(fontSize: 12, color: ready ? Colors.green : Colors.grey)),
      ],
    );
  }

  Widget _buildSelectedCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                _selectedCharacter!['imageUrl']!,
                width: 60,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 50),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedCharacter!['name']!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text("تم التحقق من الشخصية", style: TextStyle(color: Colors.blue, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.verified, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}