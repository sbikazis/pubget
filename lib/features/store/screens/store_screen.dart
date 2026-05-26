// lib/features/store/screens/store_screen.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/store_constants.dart';
import 'package:pubget/widgets/shiny_coin_widget.dart';

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
    // إعداد التبويب للتحكم بالأقسام الثلاثة للمتجر
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // استخدام الألوان الداكنة الصارمة للتطبيق لبروز البريق الياباني للعملات
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
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00FF87), // خط التحديد بلون الأخضر النيون البراق
          labelColor: const Color(0xFF00FF87),
          unselectedLabelColor: textSecondary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Roboto'),
          tabs: const [
            Tab(
              icon: Icon(Icons.developer_board_rounded, size: 22),
              text: 'توسعات تقنية',
            ),
            Tab(
              icon: Icon(Icons.auto_awesome_rounded, size: 22),
              text: 'رفاهية وزينة',
            ),
            Tab(
              icon: Icon(Icons.local_shipping_rounded, size: 22),
              text: 'منتجات فيزيائية',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // القسم الأول: التوسعات التقنية الثلاثة (مفصولة تماماً عن البريميوم وسعرها 200 عملة)
          _buildTechnicalTab(cardColor, textPrimary, textSecondary),
          
          // القسم الثاني: الرفاهية (إطارات وملصقات مجهزة للمستقبل)
          _buildComingSoonTab(
            icon: Icons.style_outlined,
            title: 'مملكة الرفاهية والزينة 🎭',
            subtitle: 'انتظر إطارات التنين الأسطورية، الهالات المشعة للحسابات، والملصقات المتحركة الخاصة قريباً جداً!',
            textSecondary: textSecondary,
          ),
          
          // القسم الثالث: المنتجات الفيزيائية (الدروب شيبينغ مجهز للمستقبل)
          _buildComingSoonTab(
            icon: Icons.shopping_bag_outlined,
            title: 'سوق الأنمي الواقعي 🎒',
            subtitle: 'تجهّز لاقتناء مجسمات حصرية، ملابس بطابع ياباني، وإكسسوارات حقيقية تصل لباب منزلك بنظام الدروب شيبينغ!',
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  // بناء التبويب الخاص بالتوسعات التقنية الثلاثة
  Widget _buildTechnicalTab(Color cardColor, Color textPrimary, Color textSecondary) {
    final List<Map<String, dynamic>> expansions = [
      {
        'title': 'توسيع حد أعضاء المجموعة',
        'description': 'ارفع الحد الأقصى لأعضاء مجموعتك إلى ${StoreConstants.domainExpansionPrice + 150} عضو دفعة واحدة لتستوعب جيشك.',
        'icon': Icons.groups_rounded,
      },
      {
        'title': 'توسيع نطاق الانضمام',
        'description': 'هل تريد مراقبة الساحة؟ انظم إلى حتى 7 مجموعات في نفس الوقت بدلاً من حدك الحالي.',
        'icon': Icons.add_moderator_rounded,
      },
      {
        'title': 'تأسيس إمبراطوريات جديدة',
        'description': 'امتلك القوة الكاملة وأنشئ حتى 3 مجموعات مختلفة تحت إدارتك المباشرة.',
        'icon': Icons.create_new_folder_rounded,
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
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              // حاوية أيقونة الميزة المصبوغة بالهوية الملكية
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item['icon'],
                  color: AppColors.primaryLight,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              // تفاصيل التوسعة التقنية
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'],
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['description'],
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // كارت السعر الزاهي وزر التفعيل الثابت بـ 200 عملة
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB800FF), Color(0xFF00FF87)], // دمج البنفسجي الميتاليك والأخضر النيون
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00FF87).withOpacity(0.3),
                          blurRadius: 6,
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          '${StoreConstants.domainExpansionPrice}', // 200 عملة
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 4),
                        ShinyCoinWidget(size: 14),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: () {
                      // سيتم ربط المنطق ودوالمزود في المرحلة الخامسة
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'امتلاك',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // واجهة لعرض الأقسام المستقبلية بطريقة تسويقية مشوقة
  Widget _buildComingSoonTab({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 58,
            color: textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFB800FF).withOpacity(0.5)),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'ترقّب الإطلاق 🚀',
              style: TextStyle(
                color: Color(0xFFB800FF),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}