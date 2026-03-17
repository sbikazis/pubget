// lib/features/auth/terms_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../widgets/app_button.dart';
import '../../widgets/loading_widget.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({Key? key}) : super(key: key);

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _accepted = false;
  bool _isSaving = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onAccept() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

    final currentUser = authProvider.user;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ: لم يتم العثور على حساب المستخدم')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Use provider method to mark profile completed.
      // Ensure ProfileProvider implements markProfileCompleted(userId:).
      await profileProvider.markProfileCompleted(userId: currentUser.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قبول الشروط وحفظ الإعدادات')),
      );

      // Navigate to home or pop the flow
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحفظ: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildTermsCard(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color;

    // Short, clear terms — replace or extend with real terms as needed.
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: DefaultTextStyle(
                style: TextStyle(color: textColor, height: 1.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'شروط استخدام Pubget',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '١) الاحترام المتبادل: يمنع السب، الإهانات، والتحرش بأي شكل.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      '٢) الخصوصية: لا تحاول التجسس أو مشاركة بيانات شخصية للآخرين بدون موافقتهم.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      '٣) المحتوى: يمنع نشر محتوى مسيء، عنصري، أو يحرض على العنف.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      '٤) التقمص: عند الانضمام لمجموعات تقمص الأدوار التزم باستخدام أسماء وصور شخصيات حقيقية من الأنمي فقط، ولا تحجز أسماء الآخرين.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      '٥) الإعلانات والسلوك التجاري: لا تستخدم التطبيق لنشر إعلانات مزعجة دون استخدام أدوات الترويج المخصصة.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      '٦) العقوبات: مخالفة الشروط قد تؤدي إلى تحذير أو حظر أو إزالة محتوى.',
                    ),
                    SizedBox(height: 12),
                    Text(
                      'باستمرارك، أنت توافق على الالتزام بهذه القواعد لتحافظ على مجتمع آمن وممتع للجميع.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الموافقة على الشروط'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                const Text(
                  'قبل المتابعة، يرجى قراءة الشروط التالية والموافقة عليها.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                _buildTermsCard(context),
                Row(
                  children: [
                    Checkbox(
                      value: _accepted,
                      onChanged: (v) {
                        setState(() => _accepted = v ?? false);
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'أوافق على الشروط والأحكام',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AppButton(
                  text: 'المتابعة',
                  onPressed: (!_accepted || _isSaving) ? null : _onAccept,
                  isLoading: _isSaving,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: const Text('ليس الآن'),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'إذا كان لديك سؤال حول الشروط، يمكنك مراجعة دليل الاستخدام لاحقاً من الإعدادات.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          if (_isSaving)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: LoadingWidget(message: 'جاري حفظ موافقتك...'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}