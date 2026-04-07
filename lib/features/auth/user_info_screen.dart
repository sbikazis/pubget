// lib/features/auth/user_info_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/limits.dart';
import '../../core/utils/validators.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_textfield.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_widget.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';

// استيراد صفحة الشروط للتوجيه إليها
import 'terms_screen.dart'; 

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({Key? key}) : super(key: key);

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _animeController = TextEditingController();

  File? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  List<String> _favoriteAnimes = [];
  String? _selectedCountry;

  bool _isSaving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _nicknameController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _animeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
    }
  }

  void _removeAnime(String anime) {
    setState(() {
      _favoriteAnimes.remove(anime);
    });
  }

  Future<void> _submit() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

    final currentUser = authProvider.user;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ: المستخدم غير مسجل')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // 1) رفع الصورة إذا تم اختيارها
      if (_pickedImage != null) {
        await profileProvider.updateAvatar(
          userId: currentUser.id,
          imageFile: _pickedImage!,
        );
      }

      // 2) تحديث بيانات الملف الشخصي
      final username = _usernameController.text.trim();
      final nickname = _nicknameController.text.trim().isEmpty ? null : _nicknameController.text.trim();
      final bio = _bioController.text.trim();
      final age = _ageController.text.trim().isEmpty ? null : int.tryParse(_ageController.text.trim());
      final country = _selectedCountry;

      await profileProvider.updateProfile(
        userId: currentUser.id,
        username: username,
        nickname: nickname,
        bio: bio.isEmpty ? null : bio,
        favoriteAnimes: _favoriteAnimes,
        age: age,
        country: country,
      );

      // تحديد أن الملف الشخصي قد اكتمل
      await profileProvider.markProfileCompleted(userId: currentUser.id);
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الملف الشخصي بنجاح')),
      );

      // 🔥 التعديل: الانتقال لصفحة الشروط بدلاً من pop
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TermsScreen()),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final profileProvider = Provider.of<ProfileProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.user;

    if (currentUser != null && _usernameController.text.isEmpty) {
      _usernameController.text = currentUser.username;
      _nicknameController.text = currentUser.nickname ?? '';
      _bioController.text = currentUser.bio;
      if (currentUser.age != null) _ageController.text = currentUser.age.toString();
      _favoriteAnimes = List<String>.from(currentUser.favoriteAnimes);
      _selectedCountry = currentUser.country;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إكمال الملف الشخصي'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                            backgroundImage: _pickedImage != null
                                ? FileImage(_pickedImage!)
                                : (currentUser != null && currentUser.avatarUrl.isNotEmpty
                                    ? NetworkImage(currentUser.avatarUrl) as ImageProvider
                                    : null),
                            child: (_pickedImage == null && (currentUser == null || currentUser.avatarUrl.isEmpty))
                                ? Icon(Icons.person, size: 48, color: isDark ? AppColors.textHintDark : AppColors.textHintLight)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _pickImage,
                          child: const Text('قم بتعيين صورة'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'الإسم',
                    placeholder: 'أدخل اسم المستخدم',
                    controller: _usernameController,
                    validator: Validators.validateUsername,
                    prefixIcon: Icons.person,
                    maxLength: Limits.maxUsernameLength,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'اللقب (اختياري)',
                    placeholder: 'لقبك داخل المجتمع',
                    controller: _nicknameController,
                    validator: Validators.validateNickname,
                    prefixIcon: Icons.badge,
                    maxLength: Limits.maxNicknameLength,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'نبذة عنك (بايو)',
                    placeholder: 'اكتب شيئاً عن نفسك',
                    controller: _bioController,
                    validator: Validators.validateBio,
                    isMultiline: true,
                    maxLength: Limits.maxBioLength,
                    prefixIcon: Icons.info_outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'الأنميات المفضلة',
                    style: TextStyle(
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._favoriteAnimes.map(
                        (a) => Chip(
                          label: Text(a),
                          onDeleted: () => _removeAnime(a),
                        ),
                      ),
                      if (_favoriteAnimes.length < Limits.maxFavoriteAnime)
                        ActionChip(
                          label: const Text('إضافة'),
                          avatar: const Icon(Icons.add, size: 18),
                          onPressed: () => _showAddAnimeDialog(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'العمر (اختياري)',
                          placeholder: 'مثال: 21',
                          controller: _ageController,
                          validator: Validators.validateAge,
                          prefixIcon: Icons.cake,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildCountryDropdown()),
                    ],
                  ),
                  const SizedBox(height: 30),
                  AppButton(
                    text: 'متابعة',
                    onPressed: _isSaving ? null : _submit,
                    isLoading: _isSaving || profileProvider.isLoading,
                  ),
                  const SizedBox(height: 12),
                  // 🔥 تم إزالة زر "ليس الآن" لضمان التزام المستخدم
                ],
              ),
            ),
          ),
          if (_isSaving || profileProvider.isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: LoadingWidget(message: 'جاري الحفظ...'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCountryDropdown() {
    final countries = <String>[
      'المغرب', 'الجزائر', 'تونس', 'مصر', 'السعودية', 'الإمارات',
      'لبنان', 'سوريا', 'الأردن', 'تركيا', 'اليابان', 'الولايات المتحدة', 'أخرى',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6.0),
          child: Text(
            'البلد (اختياري)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        DropdownButtonFormField<String>(
          value: _selectedCountry,
          items: countries
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _selectedCountry = v),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddAnimeDialog() async {
    _animeController.clear();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('أضف أنمي مفضل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                placeholder: 'اسم الأنمي',
                controller: _animeController,
                maxLength: 60,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                final value = _animeController.text.trim();
                if (value.isEmpty) return;
                if (_favoriteAnimes.length >= Limits.maxFavoriteAnime) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('وصلت الحد الأقصى للأنميات')),
                  );
                  return;
                }
                setState(() {
                  if (!_favoriteAnimes.contains(value)) _favoriteAnimes.add(value);
                });
                Navigator.of(context).pop();
              },
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
  }
}