import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

// Imports
import '../../widgets/app_textfield.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/app_dialog.dart'; // تم إضافة استيراد الديالوج
import '../../providers/group_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_provider.dart'; // تم إضافة الهوم بروفايدر لفحص العدد الفعلي
import '../../models/group_model.dart';
import '../../models/member_model.dart';
import '../../core/constants/group_type.dart';
import '../../core/constants/limits.dart';
import '../../core/theme/app_colors.dart';
import 'package:pubget/core/constants/roles.dart';
import '../../services/firebase/storage_service.dart';
import '../../core/logic/subscription_limits_logic.dart'; // تم إضافة منطق الحدود

// ✅ استيراد خدمة الإعلانات لتفعيل منطق الأشباح
import '../../services/monetization/ad_service.dart';

// استيراد شاشة تقمص الأدوار التي كانت معزولة
import 'create_roleplay_group_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  // متغير للتحكم في ما إذا كان المستخدم اختار نوع المجموعة أم لا
  GroupType? _selectedType;

  // دالة موحدة للتحقق من الصلاحية قبل الانتقال للخطوة التالية
  void _checkLimitAndProceed(VoidCallback onAllowed) {
    final authProvider = context.read<AuthProvider>();
    final homeProvider = context.read<HomeProvider>();
    final user = authProvider.user;

    if (user == null) return;

    // فحص المنطق: هل يسمح للمستخدم بإنشاء مجموعة أخرى؟
    final result = SubscriptionLimitsLogic.canCreateGroup(
      user,
      homeProvider.myGroups.length,
    );

    if (result.isAllowed) {
      onAllowed();
    } else {
      // إظهار صفحة "لقد وصلت لحدود النسخة المجانية" أو التنبيه
      showDialog(
        context: context,
        builder: (context) => AppDialog(
          title: 'وصلت للحد الأقصى',
          content: result.message ?? '',
          confirmText: result.shouldShowUpgrade ? 'ترقية الآن' : 'حسناً',
          onConfirm: () {
            Navigator.pop(context);
            if (result.shouldShowUpgrade) {
              // هنا نتوجه لصفحة البريميوم التي سنبنيها لاحقاً
              // Navigator.pushNamed(context, '/premium_details');
            }
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // إذا لم يختار المستخدم نوعاً بعد، نعرض له خيارات الاختيار (البوابة)
    if (_selectedType == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('إنشاء مجموعة جديدة'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTypeSelectionCard(
                title: "مجموعة عامة",
                description: GroupType.public.description,
                icon: Icons.public,
                color: AppColors.primary,
                onTap: () {
                  _checkLimitAndProceed(() {
                    setState(() => _selectedType = GroupType.public);
                  });
                },
              ),
              const SizedBox(height: 20),
              _buildTypeSelectionCard(
                title: "تقمص أدوار (Roleplay)",
                description: GroupType.roleplay.description,
                icon: Icons.theater_comedy,
                color: Colors.amber[700]!, // لون ذهبي للفخامة
                onTap: () {
                  _checkLimitAndProceed(() {
                    // نتوجه مباشرة للشاشة الجاهزة التي لديك
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CreateRoleplayGroupScreen()),
                    ).then((value) {
                      // إذا عاد المستخدم ولم ينشئ، نصفر الاختيار
                      if (value == null) setState(() => _selectedType = null);
                    });
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    // إذا اختار "عامة"، نعرض له النموذج الأصلي الخاص بك (الموجود بالأسفل)
    return GeneralGroupForm(onBack: () => setState(() => _selectedType = null));
  }

  Widget _buildTypeSelectionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(description, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

// --- هذا هو الكود الأصلي الخاص بك وضعته في Widget منفصل للحفاظ على الترتيب ---

class GeneralGroupForm extends StatefulWidget {
  final VoidCallback onBack;
  const GeneralGroupForm({Key? key, required this.onBack}) : super(key: key);

  @override
  State<GeneralGroupForm> createState() => _GeneralGroupFormState();
}

class _GeneralGroupFormState extends State<GeneralGroupForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sloganController = TextEditingController();
 
  File? _selectedImage;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final groupProvider = context.read<GroupProvider>();
    final adService = context.read<AdService>(); // ✅ استدعاء خدمة الإعلانات
    final storageService = StorageService();

    final user = authProvider.user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول لإنشاء مجموعة')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String imageUrl = '';
      if (_selectedImage != null) {
        imageUrl = await storageService.uploadGroupImage(
          groupId: DateTime.now().millisecondsSinceEpoch.toString(),
          file: _selectedImage!,
        );
      }

      final groupId = DateTime.now().millisecondsSinceEpoch.toString();
      final group = GroupModel(
        id: groupId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        slogan: _sloganController.text.trim(),
        imageUrl: imageUrl,
        type: GroupType.public,
        animeName: null,
        founderId: user.id,
        membersCount: 1,
        maxMembers: user.isPremium
            ? Limits.maxMembersPremium
            : Limits.maxMembersFree,
        isPromoted: false,
        promotionExpiresAt: null,
        createdAt: DateTime.now(),
      );

      final founderMember = MemberModel(
        userId: user.id,
        groupId: groupId,
        role: Roles.founder,
        joinedAt: DateTime.now(),
        displayName: user.username,
      );

      await groupProvider.createGroup(group: group, founderMember: founderMember);

      if (mounted) {
        // 🚀 تفعيل إعلان "إنشاء مجموعة" (منطق الأشباح) قبل إغلاق الشاشة
        // يتم التحقق داخلياً من شروط (الـ 5 دقائق، 3 إعلانات يومياً، البريميوم)
        await adService.tryShowGroupAd(isPremium: user.isPremium);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء المجموعة بنجاح')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء الإنشاء: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sloganController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء مجموعة عامة'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'جاري إنشاء المجموعة...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                        backgroundColor: AppColors.lightCard,
                        child: _selectedImage == null
                            ? const Icon(Icons.camera_alt, size: 32)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'اسم المجموعة',
                      controller: _nameController,
                      maxLength: Limits.maxGroupNameLength,
                      validator: (v) => v == null || v.isEmpty ? 'الاسم مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'الوصف',
                      controller: _descriptionController,
                      isMultiline: true,
                      maxLength: Limits.maxGroupDescriptionLength,
                      validator: (v) => v == null || v.isEmpty ? 'الوصف مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'الشعار (3-4 كلمات)',
                      controller: _sloganController,
                      maxLength: Limits.maxGroupSloganLength,
                      validator: (v) => v == null || v.isEmpty ? 'الشعار مطلوب' : null,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      text: 'إنشاء المجموعة',
                      onPressed: _createGroup,
                      icon: Icons.check,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}