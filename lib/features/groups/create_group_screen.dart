// lib/features/groups/create_group_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../widgets/app_textfield.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_widget.dart';

import '../../providers/group_provider.dart';
import '../../providers/auth_provider.dart';

import '../../models/group_model.dart';
import '../../models/member_model.dart';

import '../../core/constants/group_type.dart';
import '../../core/constants/limits.dart';
import '../../core/theme/app_colors.dart';
import 'package:pubget/core/constants/roles.dart';

import '../../services/firebase/storage_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sloganController = TextEditingController();

  final GroupType _groupType = GroupType.public; // ثابت على العامة
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
      // رفع صورة المجموعة إن وجدت
      String imageUrl = '';
      if (_selectedImage != null) {
        imageUrl = await storageService.uploadGroupImage(
          groupId: DateTime.now().millisecondsSinceEpoch.toString(),
          file: _selectedImage!,
        );
      }

      // إنشاء نموذج المجموعة
      final groupId = DateTime.now().millisecondsSinceEpoch.toString();
      final group = GroupModel(
        id: groupId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        slogan: _sloganController.text.trim(),
        imageUrl: imageUrl,
        type: _groupType,
        animeName: null, // لا يوجد أنمي للمجموعات العامة
        founderId: user.id,
        membersCount: 1,
        maxMembers: user.subscriptionType.name == 'premium'
            ? Limits.maxMembersPremium
            : Limits.maxMembersFree,
        isPromoted: false,
        promotionExpiresAt: null,
        createdAt: DateTime.now(),
      );

      // إنشاء نموذج العضو المؤسس
      final founderMember = MemberModel(
        userId: user.id,
        groupId: groupId,
        role: Roles.founder,
        joinedAt: DateTime.now(),
        displayName: user.username,
      );

      // إنشاء المجموعة عبر Provider
      await groupProvider.createGroup(group: group, founderMember: founderMember);

      if (mounted) {
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
      setState(() => _isLoading = false);
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
      appBar: AppBar(title: const Text('إنشاء مجموعة عامة')),
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