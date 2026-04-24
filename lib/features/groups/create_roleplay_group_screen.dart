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
import '../../widgets/app_dialog.dart'; 
import '../../services/api/anime_api_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../providers/group_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_provider.dart'; 
import '../../models/group_model.dart';
import '../../models/member_model.dart';
import '../../core/logic/subscription_limits_logic.dart'; 

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

  // ✅ الإضافة: التحكم بنوع المجموعة (محدد أو مفتوح)
  GroupType _selectedGroupType = GroupType.roleplay;

  File? _pickedImage;
  File? _charPickedImage; // ✅ الإضافة: لحفظ صورة الشخصية المختارة يدوياً
  bool _isLoading = false;
 
  bool _isVerifyingAnime = false;
  String? _confirmedAnimeName;
  String? _confirmedAnimeImage;
  dynamic _confirmedAnimeId; 
  
  List<Map<String, dynamic>> _confirmedFranchiseData = [];

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

  // ✅ الإضافة: دالة لاختيار صورة الشخصية يدوياً
  Future<void> _pickCharImage() async {
    final XFile? file =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() => _charPickedImage = File(file.path));
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
      _confirmedFranchiseData = []; 
      _confirmedCharName = null;
      _charPickedImage = null; // تصفير الصورة اليدوية عند تغيير الأنمي
    });

    try {
      final result = await AnimeApiService.searchAnime(name);
      if (result != null) {
        final int malId = result['id'];
        final franchiseFullData = await AnimeApiService.getAnimeFranchiseFullDetails(malId, result['title']);

        setState(() {
          _confirmedAnimeName = result['title'];
          _confirmedAnimeImage = result['image_url'];
          _confirmedAnimeId = malId;
          _confirmedFranchiseData = franchiseFullData; 
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

    // ✅ التعديل: فحص الشرط بناءً على نوع المجموعة
    if (_selectedGroupType == GroupType.roleplay) {
      if (_confirmedAnimeId == null || _confirmedAnimeName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء التحقق من اسم الأنمي أولاً')),
        );
        return;
      }
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
      _charPickedImage = null; // ✅ التعديل: تصفير الصورة اليدوية عند البحث عن شخصية جديدة لضمان التزامن
    });

    try {
      bool exists = false;

      if (_selectedGroupType == GroupType.openRoleplay) {
        // ✅ التعديل: في التقمص المفتوح، نتأكد من وجود الشخصية عالمياً فقط
        final charImageUrl = await AnimeApiService.getCharacterImage(charName);
        if (charImageUrl != null) {
          exists = true;
          setState(() => _confirmedCharImage = charImageUrl);
        }
      } else {
        // التقمص المحدد: البحث داخل السلسلة
        final List<int> franchiseIds = _confirmedFranchiseData
            .map((item) => item['id'] as int)
            .toList();
        
        if (franchiseIds.isEmpty) franchiseIds.add(_confirmedAnimeId);

        exists = await AnimeApiService.validateCharacterExists(
          animeIds: franchiseIds,
          characterName: charName,
        );

        if (!exists) {
          exists = await AnimeApiService.isCharacterInFranchise(
            animeName: _confirmedAnimeName!,
            characterName: charName,
          );
        }

        if (exists) {
          final charImageUrl = await AnimeApiService.getCharacterImage(charName);
          setState(() => _confirmedCharImage = charImageUrl);
        }
      }

      if (exists) {
        setState(() => _confirmedCharName = charName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_selectedGroupType == GroupType.openRoleplay 
            ? 'لم نجد هذه الشخصية في قاعدة البيانات' 
            : 'هذه الشخصية غير موجودة في السلسلة المحددة')),
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
    if (_selectedGroupType == GroupType.roleplay && _confirmedAnimeName == null) {
      return 'يجب التحقق من اسم الأنمي أولاً';
    }
    return null;
  }

  String? _validateCharacter(String? v) {
    if (_confirmedCharName == null) return 'يجب التحقق من وجود الشخصية أولاً';
    return null;
  }

  Future<void> _createGroup() async {
    final auth = context.read<AuthProvider>();
    final groupProvider = context.read<GroupProvider>();
    final homeProvider = context.read<HomeProvider>(); 
    final currentUser = auth.user;

    if (currentUser == null) return;
    if (!_formKey.currentState!.validate()) return;

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

    setState(() => _isLoading = true);

    try {
      final storage = StorageService();
      final groupId = DateTime.now().millisecondsSinceEpoch.toString();
      String groupImageUrl = '';

      if (_pickedImage != null) {
        groupImageUrl = await storage.uploadGroupImage(
          groupId: groupId,
          file: _pickedImage!,
        );
      }

      // ✅ التعديل: التعامل مع صورة الشخصية (سواء كانت من MAL أو مرفوعة يدوياً)
      String finalCharImageUrl = _confirmedCharImage ?? '';
      if (_charPickedImage != null) {
        finalCharImageUrl = await storage.uploadRoleplayCharacterImage(
          groupId: groupId,
          userId: currentUser.id,
          file: _charPickedImage!,
        );
      }

      final List<int> franchiseIds = _confirmedFranchiseData
          .map((item) => item['id'] as int)
          .toList();

      final group = GroupModel(
        id: groupId,
        name: _nameCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        slogan: _sloganCtrl.text.trim(),
        imageUrl: groupImageUrl,
        type: _selectedGroupType, // ✅ إرسال النوع المختار
        animeName: _selectedGroupType == GroupType.roleplay ? _confirmedAnimeName : null,
        animeId: _selectedGroupType == GroupType.roleplay ? _confirmedAnimeId : null, 
        franchiseIds: _selectedGroupType == GroupType.roleplay ? franchiseIds : [],
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
        characterImageUrl: finalCharImageUrl, // ✅ استخدام الرابط النهائي
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

  // ✅ التعديل: تطوير الويدجت لدعم اختيار صورة يدوية وعرضها
  Widget _buildSimpleTile(String title, String? imageUrl, bool isDark) {
    return GestureDetector(
      onTap: _pickCharImage, // ✅ السماح بتغيير الصورة عند النقر
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.lightCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _charPickedImage != null 
                    ? Image.file(_charPickedImage!, width: 45, height: 45, fit: BoxFit.cover)
                    : (imageUrl != null
                        ? Image.network(imageUrl, width: 45, height: 45, fit: BoxFit.cover)
                        : Container(color: Colors.grey, width: 45, height: 45)),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.edit, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text('اضغط على الصورة لتغييرها اختيارياً', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFranchiseTile(String title, String? imageUrl, bool isDark) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 10),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null 
              ? Image.network(imageUrl, height: 60, width: 60, fit: BoxFit.cover)
              : Container(color: Colors.grey, height: 60, width: 60),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 9), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
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
                    // ✅ 1. اختيار نوع المجموعة (محدد أو مفتوح)
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('أنمي محدد')),
                            selected: _selectedGroupType == GroupType.roleplay,
                            onSelected: (val) {
                              if (val) setState(() {
                                _selectedGroupType = GroupType.roleplay;
                                _confirmedCharName = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('تقمص مفتوح')),
                            selected: _selectedGroupType == GroupType.openRoleplay,
                            onSelected: (val) {
                              if (val) setState(() {
                                _selectedGroupType = GroupType.openRoleplay;
                                _confirmedCharName = null;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

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
                    
                    // ✅ 2. إخفاء/إظهار قسم الأنمي بناءً على النوع
                    if (_selectedGroupType == GroupType.roleplay) ...[
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
                                    _confirmedFranchiseData = [];
                                    _confirmedCharName = null;
                                    _charPickedImage = null;
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
                      // ✅ الإضافة: تنويه نصي للمستخدم
                      const Padding(
                        padding: EdgeInsets.only(top: 4, right: 4),
                        child: Text(
                          '* يرجى كتابة اسم الأنمي بدقة للبحث في السلسلة كاملة',
                          style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      ),

                      if (_confirmedAnimeName != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 12, bottom: 8),
                              child: Text(
                                "السلسلة المكتشفة (${_confirmedFranchiseData.length}):",
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                            SizedBox(
                              height: 90,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _confirmedFranchiseData.length,
                                itemBuilder: (context, index) {
                                  final item = _confirmedFranchiseData[index];
                                  return _buildFranchiseTile(
                                    item['title'], 
                                    item['image_url'], 
                                    isDark
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                    ],

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
                                setState(() {
                                  _confirmedCharName = null;
                                  _charPickedImage = null;
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
                      _buildSimpleTile(_confirmedCharName!, _confirmedCharImage, isDark),

                    const SizedBox(height: 32),
                    AppButton(
                      text: 'إنشاء المجموعة',
                      onPressed: _isLoading ? null : _createGroup,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'بصفتك الشوغو، سيتم حجز هذه الشخصية لك تلقائياً ولا يمكن لأحد تغييرها.',
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
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}