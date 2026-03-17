// lib/features/groups/create_roleplay_group_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/group_type.dart';
import '../../core/constants/limits.dart';

import '../../core/constants/roles.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_textfield.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_widget.dart';
import '../../services/api/anime_api_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../providers/group_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/group_model.dart';
import '../../models/member_model.dart';

class CreateRoleplayGroupScreen extends StatefulWidget {
  const CreateRoleplayGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateRoleplayGroupScreen> createState() =>
      _CreateRoleplayGroupScreenState();
}

class _CreateRoleplayGroupScreenState
    extends State<CreateRoleplayGroupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _sloganCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _animeCtrl = TextEditingController();

  File? _pickedImage;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() => _pickedImage = File(file.path));
  }

  String? _validateName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'الرجاء إدخال اسم المجموعة';
    if (s.length > Limits.maxGroupNameLength) {
      return 'الاسم طويل جداً (حد أقصى ${Limits.maxGroupNameLength} حرف)';
    }
    return null;
  }

  String? _validateSlogan(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'الرجاء إدخال شعار قصير للمجموعة';
    // شعار محدود بكلمات، لكن هنا نتحقق من الطول فقط
    if (s.split(' ').length > Limits.maxGroupSloganLength) {
      return 'الشعار يجب أن يكون ${Limits.maxGroupSloganLength} كلمات أو أقل';
    }
    return null;
  }

  String? _validateDescription(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'الرجاء إدخال وصف للمجموعة';
    if (s.length > Limits.maxGroupDescriptionLength) {
      return 'الوصف طويل جداً (حد أقصى ${Limits.maxGroupDescriptionLength} حرف)';
    }
    return null;
  }

  String? _validateAnime(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'الرجاء إدخال اسم الأنمي المرتبط بالمجموعة';
    return null;
  }

  Future<void> _createGroup() async {
    final auth = context.read<AuthProvider>();
    final groupProvider = context.read<GroupProvider>();
    final currentUser = auth.user;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1) تحقق من وجود الأنمي عبر API
      final animeName = _animeCtrl.text.trim();
      final animeExists = await AnimeApiService.validateAnimeExists(animeName);
      if (!animeExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الأنمي غير موجود في قاعدة البيانات')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 2) جهز بيانات المجموعة
      final groupId = DateTime.now().millisecondsSinceEpoch.toString();
      String imageUrl = '';

      // 3) ارفع الصورة إن وجدت
      if (_pickedImage != null) {
        final storage = StorageService();
        imageUrl = await storage.uploadGroupImage(
          groupId: groupId,
          file: _pickedImage!,
        );
      }

      final group = GroupModel(
        id: groupId,
        name: _nameCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        slogan: _sloganCtrl.text.trim(),
        imageUrl: imageUrl,
        type: GroupType.roleplay,
        animeName: animeName,
        founderId: currentUser.id,
        membersCount: 1,
        maxMembers: Limits.maxMembersFree, // يمكن تعديل حسب الاشتراك لاحقاً
        isPromoted: false,
        promotionExpiresAt: null,
        createdAt: DateTime.now(),
      );

      // 4) أنشئ عضو المؤسس
      final founderMember = MemberModel(
        userId: currentUser.id,
        groupId: groupId,
        role: Roles.founder,
        joinedAt: DateTime.now(),
        displayName: currentUser.username,
      );

      // 5) أنشئ المجموعة عبر Provider
      await groupProvider.createGroup(
        group: group,
        founderMember: founderMember,
      );

      // 6) احتياطي: احجز شخصية افتراضياً إن أردت (لا نفعل هنا لأن الحجز يتم عند انضمام الأعضاء)

      // 7) إرجاع المستخدم مع رسالة نجاح
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء المجموعة بنجاح')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الإنشاء: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sloganCtrl.dispose();
    _descriptionCtrl.dispose();
    _animeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء مجموعة تقمص أدوار'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // صورة المجموعة
                  GestureDetector(
                    onTap: _pickImage,
                    child: Center(
                      child: _pickedImage == null
                          ? Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? AppColors.darkCard
                                    : AppColors.lightCard,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.lightBorder),
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 40,
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _pickedImage!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _nameCtrl,
                    label: 'اسم المجموعة',
                    placeholder: 'أدخل اسم المجموعة',
                    maxLength: Limits.maxGroupNameLength,
                    prefixIcon: Icons.group,
                    validator: _validateName,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _sloganCtrl,
                    label: 'شعار المجموعة (قصير)',
                    placeholder: 'مثال: عشاق ناروتو',
                    maxLength: 60,
                    prefixIcon: Icons.flag,
                    validator: _validateSlogan,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _descriptionCtrl,
                    label: 'وصف المجموعة',
                    placeholder: 'أضف وصفاً مختصراً للمجموعة',
                    isMultiline: true,
                    maxLength: Limits.maxGroupDescriptionLength,
                    validator: _validateDescription,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _animeCtrl,
                    label: 'اسم الأنمي (مطلوب)',
                    placeholder: 'مثال: Naruto',
                    prefixIcon: Icons.movie,
                    validator: _validateAnime,
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    text: 'إنشاء المجموعة',
                    onPressed: _isLoading ? null : _createGroup,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ملاحظة: سيتم التحقق من وجود الأنمي عبر قاعدة بيانات عامة. تأكد من كتابة الاسم بشكل صحيح.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: LoadingWidget(message: 'جاري الإنشاء...')),
              ),
            ),
        ],
      ),
    );
  }
}