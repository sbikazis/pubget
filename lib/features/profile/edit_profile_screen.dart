// lib/features/profile/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firebase/storage_service.dart';

import '../../widgets/app_button.dart';
import '../../widgets/app_textfield.dart';
import '../../widgets/loading_widget.dart';

import '../../core/constants/limits.dart';
import '../../core/theme/app_colors.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _usernameController;
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late TextEditingController _ageController;
  late TextEditingController _countryController;
  late TextEditingController _favoriteAnimesController;

  File? _newAvatarFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _nicknameController = TextEditingController(text: widget.user.nickname ?? '');
    _bioController = TextEditingController(text: widget.user.bio);
    _ageController = TextEditingController(text: widget.user.age?.toString() ?? '');
    _countryController = TextEditingController(text: widget.user.country ?? '');
    _favoriteAnimesController = TextEditingController(text: widget.user.favoriteAnimes.join(', '));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nicknameController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _countryController.dispose();
    _favoriteAnimesController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _newAvatarFile = File(picked.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    String avatarUrl = widget.user.avatarUrl;

    try {
      if (_newAvatarFile != null) {
        final storage = StorageService();
        avatarUrl = await storage.uploadUserAvatar(
          userId: widget.user.id,
          file: _newAvatarFile!,
        );
      }

      final List<String> favoriteAnimes = _favoriteAnimesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .take(Limits.maxFavoriteAnime)
          .toList();

      await userProvider.updateProfile(
        username: _usernameController.text.trim(),
        nickname: _nicknameController.text.trim().isEmpty ? null : _nicknameController.text.trim(),
        avatarUrl: avatarUrl,
        bio: _bioController.text.trim(),
        favoriteAnimes: favoriteAnimes,
        age: _ageController.text.trim().isEmpty ? null : int.tryParse(_ageController.text.trim()),
        country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ التعديلات بنجاح')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل حفظ التعديلات: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل الملف الشخصي'),
        centerTitle: true,
      ),
      body: _isSaving
          ? const LoadingWidget(message: 'جارٍ حفظ التعديلات...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.lightBorder,
                        backgroundImage: _newAvatarFile != null
                            ? FileImage(_newAvatarFile!)
                            : (widget.user.avatarUrl.isNotEmpty
                                ? NetworkImage(widget.user.avatarUrl)
                                : null) as ImageProvider?,
                        child: (_newAvatarFile == null && widget.user.avatarUrl.isEmpty)
                            ? const Icon(Icons.camera_alt, size: 32, color: Colors.grey)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    AppTextField(
                      label: 'اسم المستخدم',
                      controller: _usernameController,
                      maxLength: Limits.maxUsernameLength,
                      validator: (val) =>
                          (val == null || val.isEmpty) ? 'الاسم مطلوب' : null,
                    ),
                    const SizedBox(height: 12),

                    AppTextField(
                      label: 'اللقب (اختياري)',
                      controller: _nicknameController,
                      maxLength: Limits.maxNicknameLength,
                    ),
                    const SizedBox(height: 12),

                    AppTextField(
                      label: 'البايو',
                      controller: _bioController,
                      maxLength: Limits.maxBioLength,
                      isMultiline: true,
                    ),
                    const SizedBox(height: 12),

                    AppTextField(
                      label: 'العمر (اختياري)',
                      controller: _ageController,
                      placeholder: 'مثال: 20',
                      validator: (val) {
                        if (val != null && val.isNotEmpty && int.tryParse(val) == null) {
                          return 'أدخل رقمًا صحيحًا';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    AppTextField(
                      label: 'البلد (اختياري)',
                      controller: _countryController,
                    ),
                    const SizedBox(height: 12),

                    AppTextField(
                      label: 'الأنميات المفضلة (افصل بينها بفاصلة)',
                      controller: _favoriteAnimesController,
                      maxLength: Limits.maxFavoriteAnime * 30, // تقريبًا
                    ),
                    const SizedBox(height: 20),

                    AppButton(
                      text: 'حفظ التعديلات',
                      onPressed: _saveProfile,
                      isLoading: _isSaving,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}