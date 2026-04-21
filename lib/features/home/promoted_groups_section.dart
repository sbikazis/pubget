//promoted_groups_section
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pubget/models/group_model.dart';
import 'package:pubget/providers/home_provider.dart';
import 'package:pubget/widgets/loading_widget.dart';
import 'package:pubget/widgets/empty_state_widget.dart';
import 'package:pubget/widgets/app_button.dart';
import 'package:pubget/core/theme/app_colors.dart';
import 'package:pubget/features/groups/group_details_screen.dart'; // استيراد صفحة التفاصيل

class PromotedGroupsSection extends StatelessWidget {
  const PromotedGroupsSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final homeProvider = Provider.of<HomeProvider>(context);

    // تم إزالة شرط الـ isLoading من هنا لأن الصفحة الرئيسية (HomeScreen) 
    // تدير حالة التحميل بشكل مركزي، ووجوده هنا يسبب تعليق الواجهة.

    // نستخدم القائمة المدمجة (مروجة + مقترحة) التي أنشأناها في الـ Provider
    final discoveryGroups = homeProvider.allDiscoveryGroups;

    if (discoveryGroups.isEmpty) {
      return const EmptyStateWidget(
        title: "لا توجد مجموعات حالياً",
        subtitle: "المجموعات المقترحة والمروجة ستظهر هنا.",
        icon: Icons.explore_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Text(
            "اكتشف المجموعات",
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        // عرض المجموعات بشكل عمودي سكرول مرن
        ListView.builder(
          shrinkWrap: true, // مهم جداً لأنها داخل Column في الصفحة الرئيسية
          physics: const NeverScrollableScrollPhysics(), // لترك السكرول للشاشة الرئيسية
          itemCount: discoveryGroups.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final group = discoveryGroups[index];
            return _DiscoveryGroupCard(group: group);
          },
        ),
      ],
    );
  }
}

class _DiscoveryGroupCard extends StatelessWidget {
  final GroupModel group;

  const _DiscoveryGroupCard({Key? key, required this.group}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // تعريف التدرج الذهبي الملكي
    final goldenGradient = LinearGradient(
      colors: [
        const Color(0xFFFFD700), // ذهبي ساطع
        const Color(0xFFB8860B), // ذهبي داكن (ملك")
        const Color(0xFFFFD700), 
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupDetailsScreen(groupId: group.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          // إذا كانت مروجة نطبق التدرج، وإلا نستخدم لون الكارت العادي
          gradient: group.isPromoted ? goldenGradient : null,
          color: group.isPromoted ? null : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: group.isPromoted 
                ? const Color(0xFFB8860B).withOpacity(0.4) 
                : Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight( // لحل مشكلة الـ Overflow وتوحيد الارتفاع بناءً على المحتوى
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // صورة المجموعة (جانبية في العرض العمودي تبدو أفخم)
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                child: group.imageUrl.isNotEmpty
                    ? Image.network(
                        group.imageUrl,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 110,
                        color: AppColors.primary.withOpacity(0.2),
                        child: const Icon(Icons.group, size: 40),
                      ),
              ),
              // معلومات المجموعة
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // اسم المجموعة
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: group.isPromoted ? Colors.black87 : (isDark ? Colors.white : Colors.black),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // نوع المجموعة والعدد (10-70)
                      Row(
                        children: [
                          Icon(
                            group.type.name == "roleplay" ? Icons.theater_comedy : Icons.public,
                            size: 14,
                            color: group.isPromoted ? Colors.black54 : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "${group.type.name.toUpperCase()} • ${group.membersCount} عضو",
                              style: TextStyle(
                                fontSize: 12,
                                color: group.isPromoted ? Colors.black54 : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // زر الانضمام (مرن لمنع الـ Overflow)
                      SizedBox(
                        height: 35,
                        child: AppButton(
                          text: "انضمام",
                          onPressed: () {
                            final homeProvider = Provider.of<HomeProvider>(context, listen: false);
                            homeProvider.joinGroup(user: homeProvider.currentUser!, group: group)
                              .then((errorMessage) {
                                if (errorMessage != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(errorMessage)),
                                  );
                                }
                              });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // علامة "مروجة" إذا كانت مروجة
              if (group.isPromoted)
                Container(
                  width: 30,
                  decoration: const BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
                  ),
                  child: const RotatedBox(
                    quarterTurns: 3,
                    child: Center(
                      child: Text(
                        "PROMOTED",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}