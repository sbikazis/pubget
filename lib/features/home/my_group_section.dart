// lib/features/home/my_groups_section.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/group_model.dart';
import 'package:pubget/providers/auth_provider.dart';
import '../../providers/home_provider.dart';
import '../../providers/group_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_widget.dart';

import '../groups/group_details_screen.dart';

import '../groups/create_group_screen.dart';

class MyGroupsSection extends StatefulWidget {
  // التعديل: إضافة متحكمات لعرض نوع محدد من المجموعات
  final bool showCreatedOnly;
  final bool showJoinedOnly;

  const MyGroupsSection({
    Key? key,
    this.showCreatedOnly = false,
    this.showJoinedOnly = false,
  }) : super(key: key);

  @override
  State<MyGroupsSection> createState() => _MyGroupsSectionState();
}

class _MyGroupsSectionState extends State<MyGroupsSection> {
  Future<void> _openGroupDetails(BuildContext context, GroupModel group) async {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupDetailsScreen(groupId: group.id),
        ),
      );
    } catch (_) {
      final groupProvider = context.read<GroupProvider>();
      final fetched = await groupProvider.getGroup(groupId: group.id);
      if (fetched != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(fetched.name)),
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(fetched.description),
              ),
            ),
          ),
        );
      }
    }
  }

  Widget _buildGroupCard(BuildContext context, GroupModel group) {
    final bool isPromoted = group.isPromoted;
    final borderColor = isPromoted ? AppColors.promotedBorder : Colors.transparent;

    return InkWell(
      onTap: () => _openGroupDetails(context, group),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isPromoted ? 1.6 : 0),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: group.imageUrl.isNotEmpty
                    ? Image.network(group.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
                        return Container(color: AppColors.lightCard);
                      })
                    : Container(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        child: const Icon(Icons.group, size: 36, color: Colors.white70),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          group.type.label,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    group.slogan.isNotEmpty ? group.slogan : group.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Theme.of(context).iconTheme.color),
                      const SizedBox(width: 6),
                      Text('${group.membersCount} عضو'),
                      const SizedBox(width: 12),
                      if (group.type.isRoleplay && group.animeName != null) ...[
                        const Icon(Icons.movie, size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            group.animeName ?? '',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionList({
    required String title,
    required List<GroupModel> groups,
    required VoidCallback onCreatePressed,
  }) {
    if (groups.isEmpty) {
      return EmptyStateWidget(
        title: 'لا توجد مجموعات هنا بعد',
        subtitle: 'أنشئ مجموعتك الأولى أو انضم لمجموعة مهتم بها.',
        icon: Icons.group_off,
        onActionPressed: onCreatePressed,
        actionLabel: 'إنشاء مجموعة',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final group = groups[index];
            return _buildGroupCard(context, group);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    // تم الإبقاء على استدعاء authProvider للحفاظ على منطق الكود الأصلي
    context.watch<AuthProvider>(); 

    final isLoading = homeProvider.isLoading;
    final myGroups = homeProvider.filteredMyGroups;
    final joinedGroups = homeProvider.filteredJoinedGroups;

    // تم إزالة الـ Row العلوي (البحث والبروفايل) لأنه مدمج الآن في HomeScreen
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        children: [
          if (isLoading)
            const SizedBox(height: 220, child: Center(child: LoadingWidget(message: 'جاري تحميل المجموعات...'))),

          if (!isLoading) ...[
            // عرض زر الإنشاء فقط في تبويب "مجموعاتي" أو الوضع الافتراضي
            if (!widget.showJoinedOnly)
              Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: AppButton(
                  text: 'إنشاء مجموعة جديدة',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                    );
                  },
                ),
              ),

            // منطق العرض بناءً على التبويب المختار
            if (!widget.showJoinedOnly)
              _buildSectionList(
                title: 'المجموعات التي أنشأتها',
                groups: myGroups,
                onCreatePressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                  );
                },
              ),

            if (!widget.showCreatedOnly && !widget.showJoinedOnly)
              const SizedBox(height: 18),

            if (!widget.showCreatedOnly)
              _buildSectionList(
                title: 'المجموعات التي انضممت إليها',
                groups: joinedGroups,
                onCreatePressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}