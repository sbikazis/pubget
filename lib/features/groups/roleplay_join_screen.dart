import 'dart:io';
import 'dart:async'; 

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/group_model.dart';
import '../../models/user_model.dart';
import '../../models/member_model.dart';
import '../../models/invite_model.dart';

import '../../providers/group_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/home_provider.dart'; // إضافة HomeProvider لجلب عدد المجموعات

import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../services/api/anime_api_service.dart';

import '../../core/logic/group_join_validator.dart';
import '../../core/theme/app_colors.dart';

import '../../core/constants/roles.dart';
import '../../core/constants/firestore_paths.dart';

import '../../widgets/app_textfield.dart';
import '../../widgets/app_button.dart';

import '../../widgets/app_dialog.dart';
import '../../widgets/empty_state_widget.dart';

class RoleplayJoinScreen extends StatefulWidget {
  final GroupModel group;
  final InviteModel? invite;

  const RoleplayJoinScreen({
    super.key,
    required this.group,
    this.invite,
  });

  @override
  State<RoleplayJoinScreen> createState() => _RoleplayJoinScreenState();
}

class _RoleplayJoinScreenState extends State<RoleplayJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _characterController = TextEditingController();
  final _reasonController = TextEditingController();
  final _inviterController = TextEditingController();

  File? _pickedImage;
  String? _autoFetchedImageUrl;
  bool _isProcessing = false;
  bool _isFetchingPreview = false;
  bool _hasInviter = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _characterController.dispose();
    _reasonController.dispose();
    _inviterController.dispose();
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
        _autoFetchedImageUrl = null;
      });
    }
  }

  // =========================================================
  // ✅ التعديل: تحسين جلب معاينة الشخصية لدعم كافة المواسم
  // =========================================================
  Future<void> _fetchCharacterPreview() async {
    final name = _characterController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء كتابة اسم الشخصية أولاً')),
      );
      return;
    }

    setState(() => _isFetchingPreview = true);

    try {
      // البحث عن الصورة بشكل عام (التي تجلب أفضل نتيجة مطابقة للاسم من أي موسم)
      final imageUrl = await AnimeApiService.getCharacterImage(name);

      if (imageUrl != null) {
        setState(() {
          _autoFetchedImageUrl = imageUrl;
          _pickedImage = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم نجد صورة لهذه الشخصية، تأكد من كتابة الاسم بالإنجليزية بدقة')),
        );
      }
    } catch (e) {
      debugPrint("Error fetching character image: $e");
    } finally {
      if (mounted) setState(() => _isFetchingPreview = false);
    }
  }

  Future<void> _submitJoinRequest(UserModel currentUser) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isProcessing = true);

      final groupProvider = context.read<GroupProvider>();
      final homeProvider = context.read<HomeProvider>(); // جلب الـ HomeProvider
      final firestore = context.read<FirestoreService>();
      final storage = context.read<StorageService>();

      final characterName = _characterController.text.trim();
      final reason = _reasonController.text.trim();
      final inviterName = _hasInviter ? _inviterController.text.trim() : null;

      final hasImage = _pickedImage != null || (_autoFetchedImageUrl != null && _autoFetchedImageUrl!.isNotEmpty);

      final validator = GroupJoinValidator(firestoreService: firestore);
      
      // ✅ تم الإصلاح: تمرير المعاملات المطلوبة (user و عدد المجموعات الحالية)
      final validation = await validator.validateJoin(
        user: currentUser,
        currentJoinedGroupsCount: homeProvider.joinedGroups.length,
        groupId: widget.group.id,
        groupType: widget.group.type,
        characterName: characterName,
        characterImageUrl: hasImage ? 'valid' : null,
        animeName: widget.group.animeName,
        animeId: widget.group.animeId,
        inviterName: inviterName,
      );

      if (!validation.isValid) {
        setState(() => _isProcessing = false);
        if (!mounted) return;
       
        await AppDialog.show(
          context,
          title: validation.shouldShowUpgrade ? 'ترقية الحساب' : 'تنبيه',
          content: validation.errorMessage ?? 'فشل التحقق من البيانات.',
          confirmText: validation.shouldShowUpgrade ? 'ترقية الآن' : 'حسناً',
          onConfirm: () {
            Navigator.of(context, rootNavigator: true).pop();
            if (validation.shouldShowUpgrade) {
              // Navigator.pushNamed(context, '/premium');
            }
          },
        );
        return;
      }

      String? finalImageUrl = _autoFetchedImageUrl;
      if (_pickedImage != null) {
        finalImageUrl = await storage.uploadRoleplayCharacterImage(
          groupId: widget.group.id,
          userId: currentUser.id,
          file: _pickedImage!,
        );
      }

      final String finalRealName = (currentUser.username.isNotEmpty)
          ? currentUser.username
          : "مستخدم جديد";

      final memberRequest = MemberModel(
        userId: currentUser.id,
        groupId: widget.group.id,
        role: Roles.member,
        joinedAt: DateTime.now(),
        displayName: characterName,
        characterName: characterName,
        characterImageUrl: finalImageUrl,
        characterReason: reason.isNotEmpty ? reason : null,
        realUserName: finalRealName,
        realUserImageUrl: currentUser.avatarUrl,
        invitedByUserId: validation.foundInviterId,
      );

      await groupProvider.sendJoinRequest(
        groupId: widget.group.id,
        groupName: widget.group.name,
        founderId: widget.group.founderId,
        memberRequest: memberRequest,
      );

      if (widget.invite != null) {
        await firestore.deleteDocument(
          path: FirestorePaths.groupInvites(widget.group.id),
          docId: widget.invite!.inviteId,
        );
      }

      setState(() => _isProcessing = false);

      if (!mounted) return;

      await AppDialog.show(
        context,
        title: 'تم إرسال الطلب',
        content: 'لقد تم إرسال طلبك بنجاح. سيقوم الشوغو بمراجعته وقبوله قريباً!',
        confirmText: 'حسناً',
        onConfirm: () {
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.of(context).pop(true);
        },
      );

    } catch (e) {
      debugPrint("❌ Error in _submitJoinRequest: $e");
      if (mounted) setState(() => _isProcessing = false);
      if (!mounted) return;
      await AppDialog.show(
        context,
        title: 'فشل العملية',
        content: 'حدث خطأ: ${e.toString().contains('Timeout') ? 'انتهت مهلة الاتصال، حاول مجدداً' : e.toString()}',
        confirmText: 'حسناً',
        onConfirm: () => Navigator.of(context, rootNavigator: true).pop(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
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
                subtitle: 'سجل الدخول للانضمام كممثل.',
                icon: Icons.lock_outline,
              ),
            )
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: 'اسم الشخصية (بالانجليزية)',
                                placeholder: 'مثال: Levi Ackerman',
                                controller: _characterController,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'الرجاء إدخال اسم الشخصية';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: SizedBox(
                                height: 56,
                                child: IconButton.filled(
                                  onPressed: _isFetchingPreview || _isProcessing ? null : _fetchCharacterPreview,
                                  icon: _isFetchingPreview
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.search),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          ' تلميح: اكتب الاسم بالإنجليزية كما يظهر في MyAnimeList.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                       
                        SwitchListTile(
                          title: const Text('هل تمت دعوتك من قبل عضو؟', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          value: _hasInviter,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: _isProcessing ? null : (val) => setState(() => _hasInviter = val),
                        ),
                        if (_hasInviter) ...[
                          AppTextField(
                            label: 'اسم العضو الداعي',
                            placeholder: 'اكتب اسم العضو أو اسم شخصيته',
                            controller: _inviterController,
                            validator: (v) {
                              if (_hasInviter && (v == null || v.trim().isEmpty)) return 'الرجاء إدخال اسم الداعي';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        AppTextField(
                          label: 'لماذا اخترت هذه الشخصية؟',
                          placeholder: 'اكتب سبب اختيارك (اختياري)',
                          controller: _reasonController,
                          isMultiline: true,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _isProcessing ? null : _pickImage,
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? AppColors.darkSurface
                                      : AppColors.lightSurface,
                                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                ),
                                child: _pickedImage != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(_pickedImage!, fit: BoxFit.cover),
                                      )
                                    : _autoFetchedImageUrl != null
                                        ? SizedBox(
                                            width: 100,
                                            height: 100,
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.network(
                                                _autoFetchedImageUrl!, 
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                                ),
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                                },
                                              ),
                                            ),
                                          )
                                        : const Center(child: Icon(Icons.add_a_photo, size: 32)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'سيتم استخدام هذه الصورة كصورتك الشخصية داخل هذه المجموعة فقط.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                       
                        AppButton(
                          text: 'تقديم طلب الانضمام',
                          isLoading: _isProcessing,
                          onPressed: _isProcessing ? null : () => _submitJoinRequest(currentUser),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('إلغاء'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isProcessing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black12,
                      child: const AbsorbPointer(),
                    ),
                  ),
              ],
            ),
    );
  }
}