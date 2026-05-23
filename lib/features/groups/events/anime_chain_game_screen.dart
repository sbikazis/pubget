import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/game_provider.dart';
import '../../../models/member_model.dart';

class AnimeChainGameScreen extends StatefulWidget {
  final String groupId;
  final MemberModel currentMember;
  const AnimeChainGameScreen({super.key, required this.groupId, required this.currentMember});

  @override
  State<AnimeChainGameScreen> createState() => _AnimeChainGameScreenState();
}

class _AnimeChainGameScreenState extends State<AnimeChainGameScreen> {
  final _controller = TextEditingController();
  String? gameId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سلسلة الأنمي')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                final id = await context.read<GameProvider>().startAnimeChain(
                  groupId: widget.groupId,
                  creatorUserId: widget.currentMember.userId,
                  startWord: 'Luffy',
                );
                setState(() => gameId = id);
              },
              child: const Text('ابدأ بـ Luffy'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: 'اكتب كلمة تبدأ بالحرف الأخير'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (gameId == null) return;
                final ok = await context.read<GameProvider>().submitChainWord(
                  groupId: widget.groupId,
                  gameId: gameId!,
                  word: _controller.text,
                  userId: widget.currentMember.userId,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok? 'صحيح!' : 'خطأ - حرف غلط أو مكرر'))
                );
                _controller.clear();
              },
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
    );
  }
}