// lib/features/groups/create_roleplay_group_screen.dart
import 'dart:io';
import 'dart:async';

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
import '../../widgets/app_dialog.dart'; // إضافة استيراد الديالوج للفحص النهائي
import '../../services/api/anime_api_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../providers/group_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_provider.dart'; // إضافة الهوم بروفايدر للتحقق من العدد
import '../../models/group_model.dart';
import '../../models/member_model.dart';
import '../../core/logic/subscription_limits_logic.dart'; // إضافة منطق الحدود

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
 
  final TextEditingController _charNameCtrl = TextEditingController();
  final TextEditingController _charReasonCtrl = TextEditingController();

  File? _pickedImage;
  bool _isLoading = false;
 
  bool _isVerifyingAnime = false;
  String? _confirmedAnimeName;
  String? _confirmedAnimeImage;
  dynamic _confirmedAnimeId; 

  bool _isVerifyingChar = false;
  String? _confirmedCharName;
  String? _confirmedCharImage;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() => _pickedImage = File(file.path));
  }

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
      _confirmedAnimeId = null;
      _confirmedCharName = null;
    });

    try {
      final result = await AnimeApiService.searchAnime(name);
      if (result != null) {
        setState(() {
          _confirmedAnimeName = result['title'];
          _confirmedAnimeImage = result['image_url'];
          _confirmedAnimeId = result['id'];
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

  Future<void> _verifyCharacter() async {
    final charName = _charNameCtrl.text.trim();
    if (_confirmedAnimeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء التحقق من اسم الأنمي أولاً')),
      );
      return;
    }
    if (charName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسم شخصيتك')),
      );
      return;
    }

    setState(() {
      _isVerifyingChar = true;
      _confirmedCharName = null;
    });

    try {
      final exists = await AnimeApiService.validateCharacterExists(
        animeId: _confirmedAnimeId!,
        characterName: charName,
      );

      if (exists) {
        final charImageUrl = await AnimeApiService.getCharacterImage(charName);
        setState(() {
          _confirmedCharName = charName;
          _confirmedCharImage = charImageUrl;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذه الشخصية غير موجودة في الأنمي المحدد')),
        );
      }
    } catch (e) {
      debugPrint("Character verification error: $e");
    } finally {
      setState(() => _isVerifyingChar = false);
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
    if (_confirmedAnimeName == null) return 'يجب التحقق من اسم الأنمي أولاً';
    return null;
  }

  String? _validateCharacter(String? v) {
    if (_confirmedCharName == null) return 'يجب التحقق من وجود الشخصية أولاً';
    return null;
  }

  Future<void> _createGroup() async {
    final auth = context.read<AuthProvider>();
    final groupProvider = context.read<GroupProvider>();
    final homeProvider = context.read<HomeProvider>(); // للتحقق من العدد الحالي
    final currentUser = auth.user;

    if (currentUser == null) return;
    if (!_formKey.currentState!.validate()) return;

    // --- صمام الأمان البرمجي (التحقق الأخير قبل الرفع للسيرفر) ---
    final limitCheck = SubscriptionLimitsLogic.canCreateGroup(
      currentUser, 
      homeProvider.myGroups.length,
    );

    if (!limitCheck.isAllowed) {
      showDialog(
        context: context,
        builder: (context) => AppDialog(
          title: 'تنبيه الحدود',
          content: limitCheck.message ?? '',
          confirmText: limitCheck.shouldShowUpgrade ? 'ترقية الآن' : 'حسناً',
          onConfirm: () => Navigator.pop(context),
        ),
      );
      return;
    }
    // ---------------------------------------------------------

    setState(() => _isLoading = true);

    try {
      final groupId = DateTime.now().millisecondsSinceEpoch.toString();
      String groupImageUrl = '';

      if (_pickedImage != null) {
        final storage = StorageService();
        groupImageUrl = await storage.uploadGroupImage(
          groupId: groupId,
          file: _pickedImage!,
        );
      }

      final group = GroupModel(
        id: groupId,
        name: _nameCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        slogan: _sloganCtrl.text.trim(),
        imageUrl: groupImageUrl,
        type: GroupType.roleplay,
        animeName: _confirmedAnimeName!,
        animeId: _confirmedAnimeId, 
        founderId: currentUser.id,
        membersCount: 1,
        maxMembers: currentUser.isPremium 
            ? Limits.maxMembersPremium 
            : Limits.maxMembersFree,
        isPromoted: false,
        promotionExpiresAt: null,
        createdAt: DateTime.now(),
      );

      final founderMember = MemberModel(
        userId: currentUser.id,
        groupId: groupId,
        role: Roles.founder,
        joinedAt: DateTime.now(),
        displayName: _confirmedCharName,
        characterName: _confirmedCharName,
        characterImageUrl: _confirmedCharImage,
        characterReason: _charReasonCtrl.text.trim(),
        realUserName: currentUser.username,
        realUserImageUrl: currentUser.avatarUrl,
      );

      await groupProvider.createGroup(
        group: group,
        founderMember: founderMember,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء الإمبراطورية بنجاح، أيها الشوغو!')),
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
    _charNameCtrl.dispose();
    _charReasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('إنشاء مجموعة تقمص أدوار'),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          IgnorePointer(
            ignoring: _isLoading,
            child: SingleChildScrollView(
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
                                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  size: 40,
                                  color: isDark ? AppColors.darkTextSecondary : Colors.grey,
                                ),
                              )
                            : Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary,
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    _pickedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                      placeholder: 'مثال: فيلق الاستطلاع',
                      maxLength: 60,
                      prefixIcon: Icons.flag,
                      validator: _validateSlogan,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _descriptionCtrl,
                      label: 'وصف المجموعة',
                      placeholder: 'أضف وصفاً مختصراً للمجموعة وقوانينها',
                      isMultiline: true,
                      maxLength: Limits.maxGroupDescriptionLength,
                      validator: _validateDescription,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _animeCtrl,
                            label: 'اسم الأنمي (بالإنجليزية)',
                            placeholder: 'مثال: Attack on Titan',
                            prefixIcon: Icons.movie,
                            validator: _validateAnime,
                            onChanged: (_) {
                              if (_confirmedAnimeName != null) {
                                setState(() {
                                  _confirmedAnimeName = null;
                                  _confirmedAnimeId = null; 
                                  _confirmedCharName = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: SizedBox(
                            height: 54,
                            width: 80,
                            child: ElevatedButton(
                              onPressed: _isVerifyingAnime ? null : _verifyAnime,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: EdgeInsets.zero,
                              ),
                              child: _isVerifyingAnime
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('تحقق', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_confirmedAnimeName != null)
                      _buildConfirmationTile(_confirmedAnimeName!, _confirmedAnimeImage, isDark),

                    const Divider(height: 40),

                    const Text(
                      'بيانات شخصيتك (الشوغو)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _charNameCtrl,
                            label: 'اسم شخصيتك في الأنمي',
                            placeholder: 'مثال: Levi Ackerman',
                            prefixIcon: Icons.person_outline,
                            validator: _validateCharacter,
                            onChanged: (_) {
                              if (_confirmedCharName != null) {
                                setState(() => _confirmedCharName = null);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: SizedBox(
                            height: 54,
                            width: 80,
                            child: ElevatedButton(
                              onPressed: _isVerifyingChar ? null : _verifyCharacter,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: EdgeInsets.zero,
                              ),
                              child: _isVerifyingChar
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('فحص', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _charReasonCtrl,
                      label: 'لماذا اخترت هذه الشخصية؟',
                      placeholder: 'اختياري: اكتب سبب تقمصك لهذه الشخصية',
                      isMultiline: true,
                      maxLength: 150,
                    ),

                    if (_confirmedCharName != null)
                      _buildConfirmationTile(_confirmedCharName!, _confirmedCharImage, isDark, isChar: true),

                    const SizedBox(height: 32),
                    AppButton(
                      text: 'إنشاء المجموعة',
                      onPressed: _isLoading ? null : _createGroup,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'بصفتك الشوغو, سيتم حجز هذه الشخصية لك تلقائياً ولا يمكن لأحد تغييرها.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
         
          if (_isLoading)
            Container(
              color: isDark ? const Color(0xFF121212).withOpacity(0.9) : Colors.white.withOpacity(0.8),
              child: const Center(
                child: LoadingWidget(message: 'جاري تأسيس الإمبراطورية...'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmationTile(String name, String? imageUrl, bool isDark, {bool isChar = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isChar ? Colors.orange : Colors.green).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isChar ? Colors.orange : Colors.green).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 45,
            height: 60,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, color: Colors.grey, size: 20),
                      ),
                      loadingBuilder: (context, child, progress) => progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 20),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isChar ? 'تم تأكيد الشخصية:' : 'تم تأكيد الأنمي:',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ?
                Colors.white : Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}