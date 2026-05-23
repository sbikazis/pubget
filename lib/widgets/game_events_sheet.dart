import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/member_model.dart';
import '../../../widgets/game_info_dialog.dart';
import '../features/groups/events/anime_chain_game_screen.dart';

class GameEventsSheet extends StatelessWidget {
  final String groupId;
  final MemberModel currentMember;

  const GameEventsSheet({super.key, required this.groupId, required this.currentMember});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('اختر فعالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.psychology, color: AppColors.primary),
            title: const Text('تخمين الشخصية'),
            subtitle: const Text('لعبة الأسئلة نعم/لا'),
            onTap: () {
              Navigator.pop(context);
              showDialog(context: context, builder: (_) =>
                GameInfoDialog(groupId: groupId, currentMember: currentMember));
            },
          ),
          ListTile(
            leading: const Icon(Icons.link, color: Colors.orange),
            title: const Text('سلسلة الأنمي'),
            subtitle: const Text('Luffy → Yami → Ichigo...'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) =>
                AnimeChainGameScreen(groupId: groupId, currentMember: currentMember)));
            },
          ),
        ],
      ),
    );
  }
}