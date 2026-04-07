// lib/features/home/search_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/app_textfield.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/empty_state_widget.dart';

import '../../providers/home_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/auth_provider.dart';

import '../../models/group_model.dart';
import '../../core/theme/app_colors.dart';

import '../groups/group_details_screen.dart';
import '../groups/create_group_screen.dart';
import 'package:pubget/features/profile/profile_sceen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showOnlyPromoted = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final homeProvider = context.read<HomeProvider>();
    // 🔥 التعديل: استدعاء setSearchQuery الذي يطلق الآن بحث السيرفر
    homeProvider.setSearchQuery(value);
  }

  Future<void> _openGroup(BuildContext context, GroupModel group) async {
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (fetched.imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          fetched.imageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      fetched.slogan.isNotEmpty ? fetched.slogan : fetched.description,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Text('الأعضاء: ${fetched.membersCount} / ${fetched.maxMembers}'),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }
  }

  Widget _buildGroupTile(BuildContext context, GroupModel group) {
    final isPromoted = group.isPromoted;
    return ListTile(
      onTap: () => _openGroup(context, group),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 56,
          height: 56,
          child: group.imageUrl.isNotEmpty
              ? Image.network(
                  group.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: AppColors.lightCard),
                )
              : Container(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkCard
                      : AppColors.lightCard,
                  child: const Icon(Icons.group, color: Colors.white70),
                ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              group.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isPromoted)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.premiumBadgeBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'مُروّج',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Text(
            group.slogan.isNotEmpty ? group.slogan : group.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
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
                  child: Text(group.animeName ?? '', overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final authProvider = context.watch<AuthProvider>();

    final isLoading = homeProvider.isLoading;
    
    // 🔥 التعديل: جلب النتائج من القائمة العالمية الجديدة في الـ Provider
    final promoted = homeProvider.filteredPromotedGroups;
    final myGroups = homeProvider.filteredMyGroups;
    final joined = homeProvider.filteredJoinedGroups;
    final globalResults = homeProvider.globalSearchResults;

    final List<GroupModel> results = [];

    if (!_showOnlyPromoted) {
      // إذا كان هناك نص بحث، نعطي الأولوية لنتائج السيرفر العالمية
      if (_searchController.text.isNotEmpty) {
        results.addAll(globalResults);
      } else {
        // الحالة الافتراضية عند عدم وجود بحث (عرض المجموعات المحلية)
        results.addAll(promoted);
        results.addAll(myGroups.where((g) => !results.any((r) => r.id == g.id)));
        results.addAll(joined.where((g) => !results.any((r) => r.id == g.id)));
      }
    } else {
      results.addAll(promoted);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث المجموعات'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'تصفية',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SwitchListTile(
                          value: _showOnlyPromoted,
                          onChanged: (v) {
                            setState(() => _showOnlyPromoted = v);
                            Navigator.of(ctx).pop();
                          },
                          title: const Text('عرض المجموعات المروّجة فقط'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() => _showOnlyPromoted = false);
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('إلغاء'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundImage: authProvider.user != null && authProvider.user!.avatarUrl.isNotEmpty
                  ? NetworkImage(authProvider.user!.avatarUrl)
                  : null,
              child: authProvider.user == null || authProvider.user!.avatarUrl.isEmpty
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            AppTextField(
              placeholder: 'ابحث عن اسم المجموعة أو المسار...',
              controller: _searchController,
              prefixIcon: Icons.search,
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),
            // 🔥 التعديل: isLoading سيظهر الآن بوضوح لأن setSearchQuery أصبحت Async
            if (isLoading)
              const Expanded(
                child: Center(child: LoadingWidget(message: 'جاري البحث في السيرفر...')),
              ),
            if (!isLoading)
              Expanded(
                child: results.isEmpty
                    ? EmptyStateWidget(
                        title: 'لم يتم العثور على نتائج',
                        subtitle: _searchController.text.isEmpty
                            ? 'ابحث عن مجموعات حسب الاسم أو المسار أو استعرض المجموعات المروّجة.'
                            : 'لا توجد مجموعات تطابق بحثك حالياً في السيرفر.',
                        icon: Icons.search_off,
                        onActionPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateGroupScreen(),
                            ),
                          );
                        },
                        actionLabel: 'إنشاء مجموعة',
                      )
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const Divider(height: 8),
                        itemBuilder: (context, index) {
                          final group = results[index];
                          return _buildGroupTile(context, group);
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}