import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pubget/models/group_model.dart';
import 'package:pubget/providers/home_provider.dart';
import 'package:pubget/widgets/loading_widget.dart';
import 'package:pubget/widgets/empty_state_widget.dart';
import 'package:pubget/widgets/app_button.dart';
import 'package:pubget/core/theme/app_colors.dart';


class PromotedGroupsSection extends StatelessWidget {
  const PromotedGroupsSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final homeProvider = Provider.of<HomeProvider>(context);

    if (homeProvider.isLoading) {
      return const LoadingWidget(message: "Loading promoted groups...");
    }

    final promotedGroups = homeProvider.filteredPromotedGroups;

    if (promotedGroups.isEmpty) {
      return const EmptyStateWidget(
        title: "No promoted groups",
        subtitle: "Groups that are promoted will appear here.",
        icon: Icons.campaign,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "Promoted Groups",
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220, // ارتفاع البطاقات
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: promotedGroups.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final group = promotedGroups[index];
              return _PromotedGroupCard(group: group);
            },
          ),
        ),
      ],
    );
  }
}

class _PromotedGroupCard extends StatelessWidget {
  final GroupModel group;

  const _PromotedGroupCard({Key? key, required this.group}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: group.isPromoted ? AppColors.promotedBorder : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.grey.shade300,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // صورة المجموعة
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: group.imageUrl.isNotEmpty
                ? Image.network(
                    group.imageUrl,
                    height: 100,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 100,
                    color: AppColors.primaryLight,
                    child: const Icon(Icons.group, size: 50, color: Colors.white),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // اسم المجموعة
                Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                // نوع المجموعة
                Text(
                  group.type.name.toUpperCase() + (group.type.name == "roleplay" && group.animeName != null ? " - ${group.animeName}" : ""),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                // زر الانضمام
                AppButton(
                  text: "Join",
                  onPressed: () {
                    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
                    // الانضمام مع تحقق
                    homeProvider.joinGroup(user: homeProvider.currentUser!, group: group)
                      .then((errorMessage) {
                        if (errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(errorMessage)),
                          );
                        }
                      });
                  },
                  expand: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
