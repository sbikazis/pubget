import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/game_provider.dart';
import '../../../models/game_model.dart';
import '../../../models/member_model.dart';
import '../../../core/constants/game_status.dart';
import 'package:pubget/widgets/game_bottom_bar.dart';

class AnimeChainGameScreen extends StatefulWidget {
  final String groupId;
  final MemberModel currentMember;
  final String? existingGameId; // يمرر فقط في حال الضغط على لعبة قائمة بالشات

  const AnimeChainGameScreen({
    super.key,
    required this.groupId,
    required this.currentMember,
    this.existingGameId,
  });

  @override
  State<AnimeChainGameScreen> createState() => _AnimeChainGameScreenState();
}

class _AnimeChainGameScreenState extends State<AnimeChainGameScreen> {
  final TextEditingController _startWordController = TextEditingController();
  String? _activeGameId;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _activeGameId = widget.existingGameId;
  }

  @override
  Widget build(BuildContext context) {
    // إذا كان هناك معرف لعبة نشط، نربطه مباشرة ببث البيانات الحي من الفايربيز
    if (_activeGameId != null) {
      return StreamBuilder<GameModel?>(
        stream: context.read<GameProvider>().streamCurrentGame(widget.groupId, _activeGameId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final game = snapshot.data;
          // إذا انتهت اللعبة أو تم حذفها، نعود لواجهة البدء
          if (game == null || game.status.isOver) {
            return _buildSetupScaffold(context);
          }

          return _buildActiveGameScaffold(context, game);
        },
      );
    }

    return _buildSetupScaffold(context);
  }

  /// 1. واجهة إعداد وبدء اللعبة (Setup Phase)
  Widget _buildSetupScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء سلسلة أنمي جديدة'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🔗\nسلسلة كلمات الأنمي',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'تحدى أصدقائك في المجموعة! ستقوم بكتابة اسم شخصية أو أنمي، ويجب على الخصم الإتيان باسم يبدأ بآخر حرف للكلمة السابقة قبل انتهاء الوقت!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _startWordController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'كلمة البداية (مثال: Luffy)',
                      hintText: 'اكتب الكلمة الأولى لانطلاق السلسلة',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isCreating ? null : () => _handleCreateGame(),
                      child: _isCreating
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('أنشئ الغرفة وانتظر خصماً ⚔️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 2. لوحة التحكم التفاعلية القتالية أثناء اللعب (Active Gameplay Interface)
  Widget _buildActiveGameScaffold(BuildContext context, GameModel game) {
    final bool isMyTurn = game.currentTurnUserId == widget.currentMember.userId;
    final String opponentName = (widget.currentMember.userId == game.playerOneId)
        ? (game.playerTwoName ?? 'بانتظار انضمام خصم...')
        : (game.playerOneName ?? 'المستضيف');

    // تفعيل وظيفة الفحص والتحكيم التلقائي مع كل تحديث للحالة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && game.status == GameStatus.guessing) {
        context.read<GameProvider>().processAutoJudge(widget.groupId, game);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة السلسلة الحية'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Chip(
              avatar: const Icon(Icons.layers, size: 16, color: Colors.blue),
              label: Text('الكلمات: ${game.usedWords.length}'),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // لوحة استعراض اللاعبين والأدوار الحالية
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: isMyTurn ? Colors.green.withOpacity(0.08) : Colors.amber.withOpacity(0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPlayerStatusNode(widget.currentMember.displayName ?? 'لاعب مجهول', 'أنت', isMyTurn),
                const Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 16)),
                _buildPlayerStatusNode(opponentName, 'الخصم', !isMyTurn && game.status != GameStatus.waitingForOpponent),
              ],
            ),
          ),

          Expanded(
            child: game.status == GameStatus.waitingForOpponent
                ? _buildWaitingForOpponentState(game)
                : _buildGameplayCoreState(game, isMyTurn),
          ),

          // تضمين الشريط السفلي التفاعلي الموحد لإدارة الإدخال والمؤقت والانسحاب
          GameBottomBar(
            groupId: widget.groupId,
            game: game,
            currentMember: widget.currentMember,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerStatusNode(String name, String role, bool isActive) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isActive ? Colors.green : Colors.transparent, width: 3),
          ),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: isActive ? Colors.green[100] : Colors.grey[200],
            child: Icon(Icons.person, color: isActive ? Colors.green : Colors.grey),
          ),
        ),
        const SizedBox(height: 6),
        Text(name, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
        Text(role, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildWaitingForOpponentState(GameModel game) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          // تم إزالة كلمة const من السطر بالأسفل لتفادي الـ Invalid constant value بسبب الـ Emoji
          Text('تم نشر اللعبة في دردشة المجموعة... 📣', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('كود الغرفة المتصلة: ${game.id.substring(0, 8).toUpperCase()}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGameplayCoreState(GameModel game, bool isMyTurn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('آخِر كَلِمَة تَمَّ قَبُولُهَا', style: TextStyle(fontSize: 13, color: Colors.grey, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          Text(
            game.currentWord ?? '—',
            // تم تعديل FontWeight.black إلى FontWeight.w900 لتجنب عدم التعرف على الخاصية
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.blueAccent),
          ),
          const SizedBox(height: 32),
          // عرض الحرف المطلوب بشكل مكبر وجميل جداً داخل كارت دائري محاط بهالة بصرية
          const Text('الحرف المطلوب للكلمة القادمة هو:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: isMyTurn ? Colors.green : Colors.grey[300],
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isMyTurn ? Colors.green : Colors.grey).withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 4,
                )
              ],
            ),
            child: Center(
              child: Text(
                game.lastLetter?.toUpperCase() ?? '?',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: isMyTurn ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isMyTurn ? 'أسرع! دورك الآن لرمي الكلمة التالية ⚔️' : 'الخصم يفكر الآن في كلمة مناسبة... ⏳',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isMyTurn ? FontWeight.bold : FontWeight.normal,
              color: isMyTurn ? Colors.green[700] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  /// معالجة إنشاء اللعبة وضخ الكلمة الأولى وانطلاقها التلقائي
  void _handleCreateGame() async {
    final startWord = _startWordController.text.trim();
    if (startWord.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء كتابة كلمة افتتاحية صحيحة لبدء السلسلة!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final provider = context.read<GameProvider>();
      
      // 1. إنشاء المستند وحجز اللعبة في وضع الانتظار
      // تم إضافة الـ Null check (?? 'مجهول') هنا لتمرير String صريح وحل المشكلة الأولى
      final id = await provider.createAnimeChain(
        groupId: widget.groupId,
        creatorUserId: widget.currentMember.userId,
        creatorName: widget.currentMember.displayName ?? 'مجهول',
      );

      // 2. تفعيل وضخ الكلمة الأولى لتصبح الغرفة جاهزة للعب فور انضمام الطرف الثاني
      await provider.startAnimeChain(
        groupId: widget.groupId,
        gameId: id,
        startWord: startWord,
      );

      setState(() => _activeGameId = id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الإنشاء: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }

  @override
  void dispose() {
    _startWordController.dispose();
    super.dispose();
  }
}
