import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/member_model.dart';
import '../../../widgets/game_info_dialog.dart';
import '../features/groups/events/anime_chain_game_screen.dart';

class GameEventsSheet extends StatelessWidget {
  final String groupId;
  final MemberModel currentMember;

  const GameEventsSheet({
    super.key, 
    required this.groupId, 
    required this.currentMember,
  });

  @override
  Widget build(BuildContext context) {
    // جلب الـ ThemeData الحالي للوصول إلى ألوان الـ ColorScheme وثيم النصوص ديناميكيًا
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // تم استبدال Colors.white بلون السطح الديناميكي الخاص بالثيم الحالي
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // سحب شكل جمالي علوي (Handle Bar) يعطي إيحاء بأن الـ Sheet قابلة للسحب لأسفل
          Container(
            width: 40,
            height: 4,
            // ✅ تم التصحيح هنا: استخدام EdgeInsets.only لتحديد الجهة السفلية بشكل صحيح
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              // ✅ تم التصحيح هنا: استخدام withValues ليتوافق مع التحديث الجديد وإصلاح التحذير الأزرق
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
          
          const Divider(height: 16), // فاصل بسيط بين الفعاليات يعتمد على ثيم التطبيق
          
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
        ],
      ),
    );
  }
}
