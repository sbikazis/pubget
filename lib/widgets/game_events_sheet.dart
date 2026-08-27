// lib/widgets/game_events_sheet.dart
//
// ✅ الإضافة الوحيدة: عنصر "لعبة المافيا" بنفس نمط ListTile المستخدم
// لبقية الفعاليات. يحافظ على نفس شرط الصلاحية (founder/sensei/hakusho)
// الذي كان موجوداً سابقاً في message_input_bar.dart، ويستدعي نفس
// تدفق createGame() + الانتقال لـ MafiaGameScreen دون أي تغيير في
// المنطق، فقط تغيير المكان.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/constants/roles.dart';
import '../models/member_model.dart';
import 'game_info_dialog.dart';
import '../features/groups/events/anime_chain_game_screen.dart';
import '../features/groups/events/mafia_lobby_screen.dart';
import '../providers/mafia_game_provider.dart';

class GameEventsSheet extends StatelessWidget {
  final String groupId;
  final MemberModel currentMember;

  const GameEventsSheet({
    super.key,
    required this.groupId,
    required this.currentMember,
  });

  bool get _canOpenMafia {
    return currentMember.role == Roles.founder ||
        currentMember.role == Roles.sensei ||
        currentMember.role == Roles.hakusho;
  }

  Future<void> _handleMafiaTap(BuildContext context) async {
    if (!_canOpenMafia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذه الفعالية متاحة فقط لأعضاء الشوغن، السينسي، والهكشو.'),
        ),
      );
      return;
    }

    Navigator.pop(context); // إغلاق الـ Sheet قبل المتابعة

    final mafiaProvider = context.read<MafiaGameProvider>();
    try {
      final gameId = await mafiaProvider.createGame(
        groupId: groupId,
        createdBy: currentMember.userId,
      );
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MafiaLobbyScreen(gameId: gameId)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text(
            'اختر فعالية',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          ListTile(
            leading: const Icon(Icons.psychology, color: AppColors.primary, size: 28),
            title: Text(
              'تخمين الشخصية',
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'لعبة الأسئلة نعم/لا',
              style: theme.textTheme.bodyMedium,
            ),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => GameInfoDialog(groupId: groupId, currentMember: currentMember),
              );
            },
          ),

          const Divider(height: 16),

          ListTile(
            leading: const Icon(Icons.link, color: Colors.orange, size: 28),
            title: Text(
              'سلسلة الأنمي',
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Luffy → Yami → Ichigo...',
              style: theme.textTheme.bodyMedium,
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnimeChainGameScreen(groupId: groupId, currentMember: currentMember),
                ),
              );
            },
          ),

          const Divider(height: 16),

          // ✅ جديد: لعبة المافيا — منقولة من زر شريط الدردشة المنفصل.
          ListTile(
            leading: Icon(
              Icons.theater_comedy_rounded,
              color: _canOpenMafia ? AppColors.error : theme.disabledColor,
              size: 28,
            ),
            title: Text(
              'لعبة المافيا',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: _canOpenMafia ? null : theme.disabledColor,
              ),
            ),
            subtitle: Text(
              _canOpenMafia
                  ? 'أدوار خفية، ليل ونهار، ومن سيبقى حتى النهاية؟'
                  : 'متاحة فقط لأعضاء الشوغن، السينسي، والهكشو',
              style: theme.textTheme.bodyMedium,
            ),
            onTap: () => _handleMafiaTap(context),
          ),
        ],
      ),
    );
  }
}