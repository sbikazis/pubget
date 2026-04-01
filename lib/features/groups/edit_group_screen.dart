import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/group_model.dart';
import '../../providers/group_provider.dart';
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
  bool _isUploading = false;
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _descriptionController = TextEditingController(text: widget.group.description);
    _sloganController = TextEditingController(text: widget.group.slogan);
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
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      String finalImageUrl = widget.group.imageUrl;

      // 1. رفع الصورة الجديدة إذا تم اختيارها
      if (_imageFile != null) {
        finalImageUrl = await _storageService.uploadGroupImage(
          groupId: widget.group.id,
          file: _imageFile!,
        );
      }

      // 2. تحديث البيانات في Firestore عبر الـ Provider
      final Map<String, dynamic> updateData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'slogan': _sloganController.text.trim(),
        'imageUrl': finalImageUrl,
      };

      await context.read<GroupProvider>().updateGroup(
        groupId: widget.group.id,
        data: updateData,
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
                  // قسم الصورة بتصميم فخم
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 3),
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
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // حقول الإدخال باستخدام الـ Widgets الخاصة بك
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
                child: Center(child: LoadingWidget(message: 'جاري الحفظ...')),
              ),
            ),
        ],
      ),
    );
  }
}