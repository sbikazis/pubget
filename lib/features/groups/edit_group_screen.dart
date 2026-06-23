// lib/features/groups/edit_group_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/group_model.dart';
import '../../providers/group_provider.dart';
import '../../providers/chat_background_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/firebase/storage_service.dart';
import '../../widgets/app_button.dart';
import 'package:pubget/widgets/app_textfield.dart';
import '../../widgets/loading_widget.dart';

class EditGroupScreen extends StatefulWidget {
  final GroupModel group;

  const EditGroupScreen({Key? key, required this.group}) : super(key: key);

  @override
  State<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends State<EditGroupScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _sloganController;

  File? _imageFile;
  File? _backgroundFile;        // ✅ صورة الخلفية المختارة
  String? _backgroundPreviewUrl; // ✅ للعرض المؤقت (URL الحالي أو مسار الملف)

  bool _isUploading = false;
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _descriptionController =
        TextEditingController(text: widget.group.description);
    _sloganController = TextEditingController(text: widget.group.slogan);

    // ✅ تحميل الخلفية الحالية للمجموعة إن وجدت
    _backgroundPreviewUrl = widget.group.chatBackgroundUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sloganController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // ✅ اختيار صورة الخلفية
  Future<void> _pickBackground() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        _backgroundFile = File(pickedFile.path);
        _backgroundPreviewUrl = pickedFile.path; // عرض مؤقت محلي
      });
    }
  }

  // ✅ إزالة الخلفية
  void _removeBackground() {
    setState(() {
      _backgroundFile = null;
      _backgroundPreviewUrl = null;
    });
  }

  // ════════════════════════════════════════════════════════
  // ✅ اسم المستخدم الحالي ليُستخدم في رسائل النظام
  // ════════════════════════════════════════════════════════
  String _getEditorName() {
    final user = context.read<UserProvider>().currentUser;
    return user?.nickname?.trim().isNotEmpty == true
        ? user!.nickname!.trim()
        : (user?.username ?? 'المؤسس');
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      final chatProvider = context.read<ChatProvider>();
      final editorName = _getEditorName();

      // ════════════════════════════════════════════════════
      // ✅ تتبع الحقول التي تغيّرت فعلياً مقارنة بالقديم
      // ════════════════════════════════════════════════════
      final Map<String, dynamic> changedFields = {};

      final String newName = _nameController.text.trim();
      final String newDescription = _descriptionController.text.trim();
      final String newSlogan = _sloganController.text.trim();

      if (newName != widget.group.name) {
        changedFields['name'] = newName;
      }
      if (newDescription != widget.group.description) {
        changedFields['description'] = newDescription;
      }
      if (newSlogan != widget.group.slogan) {
        changedFields['slogan'] = newSlogan;
      }

      String finalImageUrl = widget.group.imageUrl;

      // 1. رفع صورة المجموعة إن تغيرت
      if (_imageFile != null) {
        finalImageUrl = await _storageService.uploadGroupImage(
          groupId: widget.group.id,
          file: _imageFile!,
        );
        changedFields['imageUrl'] = finalImageUrl; // ✅ تسجيل التغيير
      }

      // ════════════════════════════════════════════════════════
      // 2. ✅ رفع/حذف خلفية الدردشة عبر ChatBackgroundProvider
      // ── الرسالة النظامية لتغيير الخلفية تُصدَر من داخل
      //    uploadGroupBackground/deleteGroupBackground نفسها
      //    (عبر تمرير chatProvider + editorName هنا)
      //    لذلك لا نُصدر أي رسالة "background" بشكل منفصل هنا
      //    تجنباً لتكرار الرسالة.
      // ════════════════════════════════════════════════════════
      String? finalBackgroundUrl = widget.group.chatBackgroundUrl;

      if (_backgroundFile != null) {
        // خلفية جديدة مختارة → ارفعها (سترسل رسالة النظام داخلياً)
        finalBackgroundUrl =
            await context.read<ChatBackgroundProvider>().uploadGroupBackground(
                  groupId: widget.group.id,
                  file: _backgroundFile!,
                  chatProvider: chatProvider,
                  editorName: editorName,
                );
      } else if (_backgroundPreviewUrl == null &&
          widget.group.chatBackgroundUrl != null) {
        // المستخدم أزال الخلفية → احذفها (سترسل رسالة النظام داخلياً)
        await context.read<ChatBackgroundProvider>().deleteGroupBackground(
              groupId: widget.group.id,
              chatProvider: chatProvider,
              editorName: editorName,
            );
        finalBackgroundUrl = null;
      }

      // 3. تحديث Firestore — التعديلات النصية/الصورة فقط
      // (chatBackgroundUrl لا يُمرَّر هنا لأنه يُحدَّث مباشرة من
      // chat_background_service عند الرفع/الحذف أعلاه)
      final Map<String, dynamic> updateData = {
        'name': newName,
        'description': newDescription,
        'slogan': newSlogan,
        'imageUrl': finalImageUrl,
      };

      await context.read<GroupProvider>().updateGroup(
            groupId: widget.group.id,
            data: updateData,
            chatProvider: chatProvider,
            editorName: editorName,
            changedFields: changedFields, // ✅ يصدر رسالة نظام لكل حقل تغيّر
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث بيانات المجموعة بنجاح')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء التحديث: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ✅ ويدجت معاينة الخلفية الحالية
  Widget _buildBackgroundPreview() {
    final bool hasBackground = _backgroundPreviewUrl != null;
    final bool isLocalFile = hasBackground &&
        !_backgroundPreviewUrl!.startsWith('http');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.wallpaper, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text(
              'خلفية الدردشة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            if (hasBackground)
              GestureDetector(
                onTap: _removeBackground,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'إزالة',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickBackground,
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasBackground
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.3),
                width: hasBackground ? 2 : 1,
              ),
              image: hasBackground
                  ? DecorationImage(
                      fit: BoxFit.cover,
                      image: isLocalFile
                          ? FileImage(File(_backgroundPreviewUrl!))
                              as ImageProvider
                          : NetworkImage(_backgroundPreviewUrl!),
                    )
                  : null,
              color: hasBackground ? null : AppColors.primary.withValues(alpha: 0.04),
            ),
            child: hasBackground
                ? Stack(
                    children: [
                      // طبقة overlay للمعاينة
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'تغيير الخلفية',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: AppColors.primary,
                        size: 36,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'اضغط لاختيار خلفية للدردشة',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ستظهر للجميع في دردشة المجموعة',
                        style: TextStyle(
                          color: AppColors.darkTextHint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل المجموعة'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // قسم صورة المجموعة
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.primary, width: 3),
                            image: DecorationImage(
                              fit: BoxFit.cover,
                              image: _imageFile != null
                                  ? FileImage(_imageFile!) as ImageProvider
                                  : NetworkImage(widget.group.imageUrl),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              radius: 20,
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  AppTextField(
                    label: 'اسم المجموعة',
                    controller: _nameController,
                    prefixIcon: Icons.group_outlined,
                    validator: (v) => v!.isEmpty ? 'الاسم مطلوب' : null,
                  ),
                  const SizedBox(height: 20),

                  AppTextField(
                    label: 'شعار المجموعة (Slogan)',
                    controller: _sloganController,
                    placeholder: 'كلمات تمثل المجموعة...',
                    prefixIcon: Icons.auto_awesome_outlined,
                  ),
                  const SizedBox(height: 20),

                  AppTextField(
                    label: 'الوصف',
                    controller: _descriptionController,
                    placeholder: 'اكتب وصفاً جذاباً لمجموعتك...',
                    isMultiline: true,
                    prefixIcon: Icons.description_outlined,
                    validator: (v) => v!.isEmpty ? 'الوصف مطلوب' : null,
                  ),
                  const SizedBox(height: 28),

                  // ✅ قسم خلفية الدردشة (للمؤسس فقط)
                  _buildBackgroundPreview(),
                  const SizedBox(height: 40),

                  AppButton(
                    text: 'حفظ التعديلات',
                    onPressed: _isUploading ? null : _saveChanges,
                    isLoading: _isUploading,
                    icon: Icons.check_circle_outline,
                  ),
                ],
              ),
            ),
          ),
          if (_isUploading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black45,
                child:
                    Center(child: LoadingWidget(message: 'جاري الحفظ...')),
              ),
            ),
        ],
      ),
    );
  }
}