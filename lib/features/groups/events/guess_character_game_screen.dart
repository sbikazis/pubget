import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../../models/game_model.dart';
import '../../../providers/game_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../core/constants/game_status.dart';
import '../../../widgets/loading_widget.dart';
import '../../../widgets/empty_state_widget.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_textfield.dart';

// ✅ استخدام الخدمة الصحيحة الموجودة في مشروعك
import '../../../services/api/anime_api_service.dart';

class GuessCharacterGameScreen extends StatefulWidget {
  final String groupId;
  final String gameId;
  final List<int> animeIds; // ✅ مضاف لجلب الشخصيات من السلسلة المحددة

  const GuessCharacterGameScreen({
    Key? key,
    required this.groupId,
    required this.gameId,
    required this.animeIds,
  }) : super(key: key);

  @override
  State<GuessCharacterGameScreen> createState() =>
      _GuessCharacterGameScreenState();
}

class _GuessCharacterGameScreenState extends State<GuessCharacterGameScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, String>> _searchResults = [];
  bool _isSearching = false;
  Map<String, String>? _selectedCharacter;
  
  Timer? _timer;
  int _secondsLeft = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        if (mounted) setState(() => _secondsLeft--);
      } else {
        _timer?.cancel();
        _handleTimeout();
      }
    });
  }

  // ✅ التعامل مع انتهاء الوقت (المنطق القاتل: خسارة اللعبة فوراً)
  void _handleTimeout() {
    if (mounted && _selectedCharacter == null) {
      final gameProvider = Provider.of<GameProvider>(context, listen: false);
      final currentUserId = Provider.of<UserProvider>(context, listen: false).currentUser?.id;
      
      // إنهاء اللعبة بسبب انسحاب/تايم آوت
      gameProvider.finishGame(
        widget.groupId, 
        widget.gameId,
        isCancelled: false,
        reason: "انتهى الوقت المخصص لاختيار الشخصية",
        winnerId: null, // سيؤدي للتعادل أو خسارة الطرف المتأخر
      );
      
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ✅ البحث باستخدام AnimeApiService المطور
  Future<void> _searchCharacters(String query) async {
    if (query.length < 3) return; // تقليل ضغط الـ API
    setState(() => _isSearching = true);
    
    try {
      // نبحث في السلسلة المختارة فقط لضمان دقة اللعبة
      final char = await AnimeApiService.getCharacterDetails(
        animeIds: widget.animeIds,
        characterName: query,
      );
      
      if (char != null) {
        setState(() => _searchResults = [char]);
      } else {
        setState(() => _searchResults = []);
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _confirmCharacter(
    BuildContext context,
    GameProvider provider,
    String userId,
  ) async {
    if (_selectedCharacter == null) return;
    
    try {
      await provider.setCharacter(
        groupId: widget.groupId,
        gameId: widget.gameId,
        userId: userId,
        animeIds: widget.animeIds,
        characterName: _selectedCharacter!['name']!,
      );
      
      // بعد تعيين الشخصية، ننتقل للجاهزية
      await provider.toggleReady(
        groupId: widget.groupId, 
        gameId: widget.gameId, 
        userId: userId
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم التأكيد! انتظر الخصم لبدء اللعبة...')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final currentUserId = Provider.of<UserProvider>(context, listen: false).currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تجهيز اللعبة'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('$_secondsLeft s', 
                style: TextStyle(
                  color: _secondsLeft < 10 ? Colors.red : Colors.blue, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 18
                )
              ),
            ),
          )
        ],
      ),
      body: StreamBuilder<GameModel?>(
        stream: gameProvider.streamCurrentGame(widget.groupId, widget.gameId),
        builder: (context, snapshot) {
          final game = snapshot.data;
          if (game == null) return const LoadingWidget(message: 'جارٍ المزامنة...');

          // الانتقال التلقائي للدردشة عند بدء التخمين
          if (game.status == GameStatus.guessing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.pop(context);
            });
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildStatusHeader(game),
                const SizedBox(height: 20),
                
                _buildSearchSection(),
                
                const Spacer(),
                if (_selectedCharacter != null)
                  AppButton(
                    text: 'تأكيد وبدء اللعبة',
                    onPressed: () => _confirmCharacter(context, gameProvider, currentUserId!),
                  ),
                const SizedBox(height: 10),
                AppButton(
                  text: 'انسحاب',
                  onPressed: () => gameProvider.finishGame(widget.groupId, widget.gameId, isCancelled: true, reason: "انسحاب أحد اللاعبين"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader(GameModel game) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.3))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _playerIndicator("أنت", (game.playerOneCharacter != null)),
          const Icon(Icons.bolt, size: 30, color: Colors.orange),
          _playerIndicator("الخصم", (game.playerTwoCharacter != null)),
        ],
      ),
    );
  }

  Widget _playerIndicator(String label, bool isReady) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Icon(
          isReady ? Icons.check_circle : Icons.hourglass_top_rounded,
          color: isReady ? Colors.green : Colors.grey,
        ),
        Text(isReady ? "جاهز" : "يختار...", style: TextStyle(fontSize: 12, color: isReady ? Colors.green : Colors.grey)),
      ],
    );
  }

  Widget _buildSearchSection() {
    return Expanded(
      child: Column(
        children: [
          const Text('اكتب اسم شخصيتك السرية بدقة (MAL):', 
            style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          AppTextField(
            label: 'مثال: Levi Ackerman',
            controller: _searchController,
            onChanged: (val) => _searchCharacters(val),
          ),
          if (_isSearching) const Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final char = _searchResults[index];
                final isSelected = _selectedCharacter?['name'] == char['name'];
                return ListTile(
                  leading: CircleAvatar(backgroundImage: NetworkImage(char['imageUrl']!)),
                  title: Text(char['name']!),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  onTap: () => setState(() => _selectedCharacter = char),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}