// lib/features/groups/roleplay_join_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';


import '../../models/group_model.dart';
import '../../models/user_model.dart';
import '../../models/member_model.dart';
import '../../models/invite_model.dart';

import '../../providers/group_provider.dart';
import '../../providers/user_provider.dart';

import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/storage_service.dart';

import '../../core/logic/group_join_validator.dart';
import '../../core/theme/app_colors.dart';

import '../../core/constants/roles.dart';
import '../../core/constants/firestore_paths.dart';

import '../../widgets/app_textfield.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/empty_state_widget.dart';

class RoleplayJoinScreen extends StatefulWidget {
  final GroupModel group;
  final InviteModel? invite;

  const RoleplayJoinScreen({
    Key? key,
    required this.group,
    this.invite,
  }) : super(key: key);

  @override
  State<RoleplayJoinScreen> createState() => _RoleplayJoinScreenState();
}

class _RoleplayJoinScreenState extends State<RoleplayJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _characterController = TextEditingController();
  final _reasonController = TextEditingController();

  File? _pickedImage;
  bool _isProcessing = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _characterController.dispose();
    _reasonController.dispose();
    super.dispose();
  }



  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
    }
  }



  Future<void> _submitJoinRequest(UserModel currentUser) async {
    if (!_formKey.currentState!.validate()) return;

    final groupProvider = context.read<GroupProvider>();
    final firestore = context.read<FirestoreService>();
    final storage = context.read<StorageService>();

    final characterName = _characterController.text.trim();
    final reason = _reasonController.text.trim();

    // تحقق باستخدام GroupJoinValidator
    final validator = GroupJoinValidator(firestoreService: firestore);

    final validation = await validator.validateJoin(
      groupId: widget.group.id,
      groupType: widget.group.type,
      characterName: characterName,
      characterImageUrl: _pickedImage != null ? 'temp' : null,
      animeName: widget.group.animeName,
    );

    if (!validation.isValid) {
      await AppDialog.show(
        context,
        title: 'خطأ في الطلب',
        content: validation.errorMessage ?? 'التحقق فشل. حاول مرة أخرى.',
        confirmText: 'حسناً',
        onConfirm: () => Navigator.pop(context),
      );
      return;
    }

    setState(() => _isProcessing = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: LoadingWidget(message: 'جاري إرسال الطلب...'),
        ),
      ),
    );

    try {
      // رفع صورة الشخصية إذا وجدت
      String? characterImageUrl;
      if (_pickedImage != null) {
        characterImageUrl = await storage.uploadRoleplayCharacterImage(
          groupId: widget.group.id,
          userId: currentUser.id,
          file: _pickedImage!,
        );
      }

      // حجز الشخصية
      await groupProvider.reserveCharacter(
        groupId: widget.group.id,
        characterName: characterName,
        imageUrl: characterImageUrl ?? '',
        userId: currentUser.id,
      );

      // إضافة العضو
      final member = MemberModel(
        userId: currentUser.id,
        groupId: widget.group.id,
        role: Roles.member,
        joinedAt: DateTime.now(),
        displayName: currentUser.username,
        characterName: characterName,
        characterImageUrl: characterImageUrl,
        characterReason: reason.isNotEmpty ? reason : null,
      );

      await groupProvider.addMember(member: member);

      // حذف الدعوة إذا موجودة
      if (widget.invite != null) {
        await firestore.deleteDocument(
          path: FirestorePaths.groupInvites(widget.group.id),
          docId: widget.invite!.inviteId,
        );
      }

      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الانضمام كممثل للشخصية بنجاح')),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      await AppDialog.show(
        context,
        title: 'فشل العملية',
        content: 'حدث خطأ أثناء إرسال الطلب: ${e.toString()}',
        confirmText: 'حسناً',
        onConfirm: () => Navigator.pop(context),
      );
    } finally {
      setState(() => _isProcessing = false);
      if (Navigator.canPop(context)) {
        try {
          Navigator.pop(context);
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final currentUser = userProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الانضمام كتقمص دور'),
        centerTitle: true,
        elevation: 0,
      ),
      body: currentUser == null
          ? const Center(
              child: EmptyStateWidget(
                title: 'يجب تسجيل الدخول',
                subtitle: 'سجل الدخول أو أنشئ حسابًا للانضمام كممثل.',
                icon: Icons.lock_outline,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // اسم الشخصية
                    AppTextField(
                      label: 'اسم الشخصية',
                      placeholder: 'اكتب اسم الشخصية كما في الأنمي',
                      controller: _characterController,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'الرجاء إدخال اسم الشخصية';
                        }
                        if (v.trim().length > 25) {
                          return 'الاسم طويل جداً';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // السبب
                    AppTextField(
                      label: 'لماذا اخترت هذه الشخصية؟',
                      placeholder: 'اكتب سبب اختيارك (اختياري)',
                      controller: _reasonController,
                      isMultiline: true,
                      validator: (v) {
                        if (v != null && v.length > 150) {
                          return 'السبب طويل جداً';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // صورة الشخصية
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkSurface
                                  : AppColors.lightSurface,
                            ),
                            child: _pickedImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(_pickedImage!, fit: BoxFit.cover),
                                  )
                                : const Center(
                                    child: Icon(Icons.add_a_photo, size: 28),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _pickedImage != null
                                ? 'تم اختيار صورة'
                                : 'اختياري: اختر صورة للشخصية داخل المجموعة',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      text: 'انضم كممثل',
                      isLoading: _isProcessing,
                      onPressed: _isProcessing ? null : () => _submitJoinRequest(currentUser),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}