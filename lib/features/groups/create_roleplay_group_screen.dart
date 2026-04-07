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
  
  // متغيرات للتحقق من الأنمي
  bool _isVerifyingAnime = false;
  String? _confirmedAnimeName;
  String? _confirmedAnimeImage;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() => _pickedImage = File(file.path));
  }

  // دالة التحقق من الأنمي قبل الإنشاء
  Future<void> _verifyAnime() async {
    final name = _animeCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء كتابة اسم الأنمي للبحث')),
      );
      return;
    }

    setState(() {
      _isVerifyingAnime = true;
      _confirmedAnimeName = null;
    });

    try {
      final result = await AnimeApiService.searchAnime(name);
      if (result != null) {
        setState(() {
          _confirmedAnimeName = result['title'];
          _confirmedAnimeImage = result['image_url'];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على هذا الأنمي، تأكد من الاسم بالإنجليزية')),
        );
      }
    } catch (e) {
      debugPrint("Anime verification error: $e");
    } finally {
      setState(() => _isVerifyingAnime = false);
    }
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
    if (_confirmedAnimeName == null) return 'يجب التحقق من اسم الأنمي أولاً';
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

    if (_confirmedAnimeName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء الضغط على زر التحقق للتأكد من اسم الأنمي')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final groupId = DateTime.now().millisecondsSinceEpoch.toString();
      String imageUrl = '';

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
        // نستخدم الاسم الرسمي الذي أكده الـ API لضمان دقة البحث عن الشخصيات لاحقاً
        animeName: _confirmedAnimeName!, 
        founderId: currentUser.id,
        membersCount: 1,
        maxMembers: Limits.maxMembersFree,
        isPromoted: false,
        promotionExpiresAt: null,
        createdAt: DateTime.now(),
      );

      final founderMember = MemberModel(
        userId: currentUser.id,
        groupId: groupId,
        role: Roles.founder,
        joinedAt: DateTime.now(),
        displayName: currentUser.username,
      );

      await groupProvider.createGroup(
        group: group,
        founderMember: founderMember,
      );

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
                              child: const Icon(Icons.camera_alt_outlined, size: 40),
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
                  
                  // حقل الأنمي مع زر التحقق
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _animeCtrl,
                          label: 'اسم الأنمي (بالإنجليزية)',
                          placeholder: 'مثال: Naruto',
                          prefixIcon: Icons.movie,
                          validator: _validateAnime,
                          onChanged: (_) {
                            if (_confirmedAnimeName != null) {
                              setState(() => _confirmedAnimeName = null);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isVerifyingAnime ? null : _verifyAnime,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isVerifyingAnime 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('تحقق'),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // عرض نتيجة التحقق
                  if (_confirmedAnimeName != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          if (_confirmedAnimeImage != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(_confirmedAnimeImage!, width: 50, height: 70, fit: BoxFit.cover),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('تم تأكيد الأنمي:', style: TextStyle(fontSize: 12, color: Colors.green)),
                                Text(_confirmedAnimeName!, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle, color: Colors.green),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  AppButton(
                    text: 'إنشاء المجموعة',
                    onPressed: _isLoading ? null : _createGroup,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ملاحظة: يجب كتابة اسم الأنمي بالإنجليزية والتحقق منه لضمان قبول الشخصيات لاحقاً.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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