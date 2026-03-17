import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_theme.dart';

import '../../providers/auth_provider.dart';

import '../../widgets/app_button.dart';

import 'permissions_screen.dart';
import 'package:pubget/features/settings/giude_screen.dart';
import 'package:pubget/features/settings/theme_selectore_widget.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("الإعدادات"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // =========================
            //  THEME
            // =========================

            _sectionTitle("المظهر"),

            const SizedBox(height: 12),

            const ThemeSelectorWidget(),

            const SizedBox(height: 30),

            // =========================
            //  PERMISSIONS
            // =========================

            _sectionTitle("تمكينات الوصول"),

            const SizedBox(height: 12),

            _settingsTile(
              context: context,
              icon: Icons.security,
              title: "إدارة التمكينات",
              subtitle: "التحكم في الإشعارات والوصول للميزات",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PermissionsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 30),

            // =========================
            //  GUIDE
            // =========================

            _sectionTitle("المساعدة"),

            const SizedBox(height: 12),

            _settingsTile(
              context: context,
              icon: Icons.menu_book,
              title: "دليل استخدام Pubget",
              subtitle: "تعرف على جميع ميزات التطبيق",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GuideScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            // =========================
            //  LOGOUT
            // =========================

            AppButton(
              text: "تسجيل الخروج",
              icon: Icons.logout,
              isLoading: auth.isLoading,
              onPressed: () async {
                await auth.logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // SECTION TITLE
  // ======================================================

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: AppTextTheme.lightTextTheme.headlineMedium?.copyWith(
        color: AppColors.primary,
      ),
    );
  }

  // ======================================================
  // SETTINGS TILE
  // ======================================================

  Widget _settingsTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.settings,
              color: AppColors.primary,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextTheme.lightTextTheme.bodyLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextTheme.lightTextTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}