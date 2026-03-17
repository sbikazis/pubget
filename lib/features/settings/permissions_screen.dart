import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_theme.dart';

import '../../providers/settings_provider.dart';

import '../../widgets/app_button.dart';

class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();


    return Scaffold(
      appBar: AppBar(
        title: const Text("تمكينات الوصول"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _sectionTitle("الإشعارات"),

              const SizedBox(height: 12),

              _permissionTile(
                context: context,
                title: "الإشعارات",
                description:
                    "السماح للتطبيق بإرسال إشعارات مثل طلبات الانضمام للمجموعات، الرسائل الخاصة، والفعاليات.",
                value: settings.notificationsEnabled,
                onChanged: (value) {
                  settings.setNotificationsEnabled(value);
                },
              ),

              const Spacer(),

              AppButton(
                text: "حفظ الإعدادات",
                icon: Icons.check,
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: AppTextTheme.lightTextTheme.headlineMedium?.copyWith(
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _permissionTile({
    required BuildContext context,
    required String title,
    required String description,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.notifications,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTextTheme.lightTextTheme.bodyLarge,
                ),
              ),
              Switch(
                value: value,
                activeColor: AppColors.primary,
                onChanged: onChanged,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTextTheme.lightTextTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}