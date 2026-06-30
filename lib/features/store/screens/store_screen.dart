// lib/features/store/screens/store_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/store_constants.dart';
import '../../../providers/store_provider.dart';
import '../../../providers/user_provider.dart';
import 'package:pubget/widgets/shiny_coin_widget.dart';
import 'package:pubget/features/store/screens/physical_products_section.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({Key? key}) : super(key: key);

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showResultSnackBar(bool success, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = AppColors.darkBackground;
    const surfaceColor = AppColors.darkSurface;
    const cardColor = AppColors.darkCard;
    const textPrimary = AppColors.darkTextPrimary;
    const textSecondary = AppColors.darkTextSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'متجر التنين Pubget',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00FF87),
          labelColor: const Color(0xFF00FF87),
          unselectedLabelColor: textSecondary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.developer_board_rounded, size: 22), text: 'توسعات تقنية'),
            Tab(icon: Icon(Icons.auto_awesome_rounded, size: 22), text: 'رفاهية وزينة'),
            Tab(icon: Icon(Icons.local_shipping_rounded, size: 22), text: 'منتجات فيزيائية'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTechnicalTab(cardColor, textPrimary, textSecondary),
          _buildComingSoonTab(
            icon: Icons.style_outlined,
            title: 'مملكة الرفاهية والزينة 🎭',
            subtitle: 'انتظر إطارات التنين الأسطورية، الهالات المشعة، والملصقات المتحركة قريباً!',
            textSecondary: textSecondary,
          ),
          // ✅ معدّل: التبويب الثالث أصبح يعرض المنتجات الفيزيائية الحقيقية من Firestore
          const PhysicalProductsSection(),
        ],
      ),
    );
  }

  Widget _buildTechnicalTab(Color cardColor, Color textPrimary, Color textSecondary) {
    final store = context.watch<StoreProvider>();

    final List<Map<String, dynamic>> expansions = [
      {
        'title': 'توسيع حد أعضاء المجموعة',
        'description': 'ارفع الحد الأقصى لأعضاء مجموعتك إلى 350 عضو دفعة واحدة.',
        'icon': Icons.groups_rounded,
        'onBuy': () => store.purchaseGroupMembersExpansion(),
      },
      {
        'title': 'توسيع نطاق الانضمام',
        'description': 'انضم إلى حتى 7 مجموعات في نفس الوقت بدلاً من 2.',
        'icon': Icons.add_moderator_rounded,
        'onBuy': () => store.purchaseJoinedGroupsExpansion(),
      },
      {
        'title': 'تأسيس إمبراطوريات جديدة',
        'description': 'أنشئ حتى 3 مجموعات مختلفة تحت إدارتك المباشرة.',
        'icon': Icons.create_new_folder_rounded,
        'onBuy': () => store.purchaseCreatedGroupsExpansion(),
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: expansions.length,
      itemBuilder: (context, index) {
        final item = expansions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(item['icon'], color: AppColors.primaryLight, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title'], style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(item['description'], style: TextStyle(color: textSecondary, fontSize: 12, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFB800FF), Color(0xFF00FF87)]),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Text('${StoreConstants.domainExpansionPrice}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      SizedBox(width: 4),
                      ShinyCoinWidget(size: 14),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: store.isLoading? null : () async {
                      final success = await item['onBuy']();
                      if (success) {
                        await context.read<UserProvider>().reloadUser();
                        _showResultSnackBar(true, 'تم تفعيل التوسعة بنجاح ✅');
                      } else {
                        _showResultSnackBar(false, 'رصيدك غير كافي أو تملكها مسبقاً');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: store.isLoading
                       ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('امتلاك', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComingSoonTab({required IconData icon, required String title, required String subtitle, required Color textSecondary}) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 58, color: textSecondary.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFB800FF).withOpacity(0.5)),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Text('ترقّب الإطلاق 🚀', style: TextStyle(color: Color(0xFFB800FF), fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ]),
    );
  }
}