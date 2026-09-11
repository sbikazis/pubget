import 'package:flutter/material.dart';
import '../widgets/v2_game_theme.dart';

class GameRulesV2Screen extends StatelessWidget {
  const GameRulesV2Screen({super.key});
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(title: const Text('دليل الألعاب')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('قواعد الساحة', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('اللعب النظيف أولاً. كل إجابة تمر عبر الخادم، والنتائج تُحفظ في أرشيف المجموعة.'),
        const SizedBox(height: 20),
        for (final item in const [
          ('خمن الشخصية', 'اسأل، حلّل، ثم أرسل اسم الشخصية قبل انتهاء المؤقت.'),
          ('سلسلة الأنمي', 'أضف عنواناً صالحاً إلى السلسلة دون تكرار ما سبق.'),
          ('خمن الأنمي', 'حوّل الدلالات المرئية إلى عنوان أنمي واحد واضح.'),
          ('Mafia', 'قادمة في Prompt 2 — لا يمكن إنشاؤها من هذا المركز.'),
        ]) Card(child: ListTile(leading: const Icon(Icons.menu_book_outlined, color: GameV2Palette.purple), title: Text(item.$1), subtitle: Text(item.$2))),
      ]),
    ),
  );
}