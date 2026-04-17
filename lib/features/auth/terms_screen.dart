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
      await profileProvider.markProfileCompleted(userId: currentUser.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قبول الشروط وحفظ الإعدادات')),
      );

      Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
);
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

    return Card(
      elevation: 2, // إضافة ظل خفيف للفخامة
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: DefaultTextStyle(
              style: TextStyle(color: textColor, height: 1.6, fontSize: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'شروط استخدام Pubget',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  Divider(height: 24), // خط فاصل أنيق
                  Text('١) الاحترام المتبادل: يمنع السب، الإهانات، والتحرش بأي شكل.'),
                  SizedBox(height: 10),
                  Text('٢) الخصوصية: لا تحاول التجسس أو مشاركة بيانات شخصية للآخرين بدون موافقتهم.'),
                  SizedBox(height: 10),
                  Text('٣) المحتوى: يمنع نشر محتوى مسيء، عنصري، أو يحرض على العنف.'),
                  SizedBox(height: 10),
                  Text('٤) التقمص: عند الانضمام لمجموعات تقمص الأدوار التزم باستخدام أسماء وصور شخصيات حقيقية من الأنمي فقط، ولا تحجز أسماء الآخرين.'),
                  SizedBox(height: 10),
                  Text('٥) الإعلانات والسلوك التجاري: لا تستخدم التطبيق لنشر إعلانات مزعجة دون استخدام أدوات الترويج المخصصة.'),
                  SizedBox(height: 10),
                  Text('٦) العقوبات: مخالفة الشروط قد تؤدي إلى تحذير أو حظر أو إزالة محتوى.'),
                  SizedBox(height: 16),
                  Text(
                    'باستمرارك، أنت توافق على الالتزام بهذه القواعد لتحافظ على مجتمع آمن وممتع للجميع.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
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
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // الحل الرئيسي: استخدام SingleChildScrollView لمنع الـ Overflow
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'قبل المتابعة، يرجى قراءة الشروط التالية والموافقة عليها.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                
                // تحديد طول مناسب للكارد لكي لا يستهلك كل الشاشة
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: _buildTermsCard(context),
                ),

                Row(
                  children: [
                    Checkbox(
                      activeColor: theme.primaryColor,
                      value: _accepted,
                      onChanged: (v) {
                        setState(() => _accepted = v ?? false);
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'أوافق على الشروط والأحكام',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                AppButton(
                  text: 'المتابعة',
                  onPressed: (!_accepted || _isSaving) ? null : _onAccept,
                  isLoading: _isSaving,
                ),
                
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('ليس الآن', style: TextStyle(color: Colors.grey)),
                ),

                const SizedBox(height: 30),
                
                Text(
                  'إذا كان لديك سؤال حول الشروط، يمكنك مراجعة دليل الاستخدام لاحقاً من الإعدادات.',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20), // مساحة أمان في الأسفل
              ],
            ),
          ),

          if (_isSaving)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black45,
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