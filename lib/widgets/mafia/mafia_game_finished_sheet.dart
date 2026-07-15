// lib/widgets/mafia/mafia_game_finished_sheet.dart
//
// ✅ جديد: البند المؤجَّل من المرحلة 6 — يظهر تلقائياً عند
// status == finished. يجلب mafia_history/{gameId} (متاح للقراءة لأي
// مستخدم مسجّل دخول بعد انتهاء المباراة)، يعرض الفائز، كل الأدوار
// المكشوفة الآن، وإشارة عامة للمكافأة (بدون رقم دقيق، لأن القيمة
// الفعلية تُقرأ من محفظة كل مستخدم بشكل منفصل).

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/mafia_role_colors.dart';
import '../../models/mafia/mafia_history_model.dart';
import '../../services/mafia/mafia_game_repository.dart';

class MafiaGameFinishedSheet extends StatefulWidget {
  final String gameId;

  const MafiaGameFinishedSheet({super.key, required this.gameId});

  static Future<void> show(BuildContext context, {required String gameId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MafiaGameFinishedSheet(gameId: gameId),
    );
  }

  @override
  State<MafiaGameFinishedSheet> createState() => _MafiaGameFinishedSheetState();
}

class _MafiaGameFinishedSheetState extends State<MafiaGameFinishedSheet> {
  final _repository = MafiaGameRepository();
  MafiaHistoryModel? _history;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // ✅ historyWriter.js يكتب السجل بعد status=finished مباشرة، لكن
    // بفارق زمني بسيط. نعيد المحاولة عدة مرات قبل الاستسلام.
    for (int attempt = 0; attempt < 5; attempt++) {
      final history = await _repository.fetchGameHistory(widget.gameId);
      if (history != null) {
        if (mounted) setState(() { _history = history; _loading = false; });
        return;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_history == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('انتهت المباراة.'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ]),
      );
    }

    final history = _history!;
    final winnerLabel = history.winner == 'mafias'
        ? 'المافيا'
        : history.winner == 'citizens'
            ? 'القرية'
            : 'لا فائز';
    final winnerColor = history.winner == 'mafias' ? AppColors.error : const Color(0xFF10B981);

    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Icon(Icons.emoji_events_rounded, size: 56, color: winnerColor),
                const SizedBox(height: 8),
                Text('فاز $winnerLabel!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: winnerColor,
                    )),
                const SizedBox(height: 4),
                const Text('🪙 حصل الفائزون على مكافأة عملات', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('كشف الأدوار', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: history.playerDetails.length,
              itemBuilder: (context, index) {
                final entry = history.playerDetails[index];
                final visual = MafiaRoleColors.of(entry.role);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: visual.badgeBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(visual.icon, color: visual.color, size: 22),
                      const SizedBox(width: 10),
                      Expanded(child: Text(entry.username, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(visual.label, style: TextStyle(color: visual.color, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Icon(
                        entry.won ? Icons.check_circle : Icons.close_rounded,
                        color: entry.won ? const Color(0xFF10B981) : AppColors.disabled,
                        size: 18,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // إغلاق الـ sheet
                Navigator.of(context).pop(); // الخروج من شاشة المباراة
              },
              child: const Text('العودة للمجموعة'),
            ),
          ),
        ],
      ),
    );
  }
}